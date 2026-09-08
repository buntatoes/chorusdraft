defmodule ChorusDraft.Store do
  alias ChorusDraft.{Error, Lock, Platform, Safety}

  @active_statuses ["pending", "publishing", "uncertain"]
  @automatic_limit 5
  @publication_lease_seconds 300

  def new(dir) do
    storage_path!(dir)
    File.mkdir_p!(dir)

    unless File.lstat!(dir).type == :directory,
      do: raise(Error, "State directory must not be a symlink.")

    Platform.private_directory!(dir)

    for file <- ~w(state.json state.lock) do
      path = Path.join(dir, file)

      case File.lstat(path) do
        {:ok, %{type: :regular}} ->
          Platform.private_file!(path)

        {:error, :enoent} ->
          :ok

        {:ok, _} ->
          raise Error, "Storage path must be a regular file, not a symlink or directory."
      end
    end

    dir
  end

  def transaction(dir, fun) do
    lock = acquire_lock(Path.join(dir, "state.lock"))

    try do
      stored = read_state(Path.join(dir, "state.json"))
      original = recover_stale_publications(stored, System.system_time(:second))
      {result, state} = fun.(prune_history(original))
      validate_state!(state)
      if state != stored, do: write_state(Path.join(dir, "state.json"), state)
      result
    after
      if Port.info(lock), do: Port.close(lock)
    end
  end

  def import_state(dir, source, platform, account) do
    source = Path.expand(source)

    if source == Path.expand(Path.join(dir, "state.json")),
      do: raise(Error, "Import requires a separate read-only source file.")

    regular_file!(source, false)
    raw = File.read!(source)

    state =
      raw
      |> Jason.decode!()
      |> Map.put_new("blocked", [])
      |> Map.put_new("automatic", [])
      |> validate_state!()

    Enum.each(state["drafts"], fn draft ->
      validate_draft!(draft)

      unless draft["platform"] == platform and draft["account"] == account,
        do: raise(Error, "Imported draft belongs to a different account or platform.")
    end)

    state =
      Map.update!(state, "drafts", fn drafts ->
        Enum.map(drafts, fn draft ->
          if draft["status"] == "publishing",
            do: Map.put(draft, "status", "uncertain"),
            else: draft
        end)
      end)

    transaction(dir, fn original ->
      unless original == default_state(),
        do: raise(Error, "Import requires empty destination state.")

      unless File.read!(source) == raw,
        do: raise(Error, "Source changed during import; stop the source process first.")

      {length(state["drafts"]), state}
    end)
  rescue
    error in Error -> raise error
    _ -> raise Error, "Could not import state; source must be a valid ChorusDraft state.json."
  end

  def validate_draft!(draft) do
    required = ["platform", "account", "text", "action", "visibility", "language"]
    optional = ["reply_to", "quote_to", "author", "author_id", "cw", "publication_mode"]

    valid =
      is_map(draft) and Enum.all?(required, &is_binary(draft[&1])) and
        Enum.all?(optional, &(is_nil(draft[&1]) or is_binary(draft[&1]))) and
        draft["platform"] in ["bluesky", "mastodon"] and
        draft["action"] in ["manual", "ai_generated"] and
        draft["visibility"] in ["public", "unlisted", "private", "direct"] and
        (is_nil(draft["reply_to"]) or is_nil(draft["quote_to"])) and
        Enum.all?(required ++ optional, fn key ->
          not Regex.match?(~r/[\x00-\x08\x0b-\x1f\x7f]/u, draft[key] || "")
        end)

    unless valid, do: raise(Error, "Draft metadata is invalid; refusing to publish.")
    draft
  end

  def drafts(dir),
    do: transaction(dir, fn state -> {Enum.map(state["drafts"], &Map.new/1), state} end)

  def automatic_budget(dir) do
    transaction(dir, fn state ->
      now = System.system_time(:second)
      pruned = prune_automatic(state, now)
      used = length(pruned["automatic"])

      {%{
         limit: @automatic_limit,
         used: used,
         remaining: max(@automatic_limit - used, 0),
         frozen: Enum.any?(pruned["drafts"], &(&1["status"] in ["publishing", "uncertain"]))
       }, pruned}
    end)
  end

  def replace_pending(dir, id, attrs) when is_map(attrs) do
    unless is_binary(attrs["text"]) and String.trim(attrs["text"]) != "",
      do: raise(Error, "Replacement text is required.")

    replace_pending(dir, id, fn draft ->
      changed = Map.put(draft, "text", attrs["text"])
      if Map.has_key?(attrs, "cw"), do: Map.put(changed, "cw", attrs["cw"]), else: changed
    end)
  end

  def replace_pending(dir, id, updater) when is_function(updater, 1) do
    replace_pending(dir, id, fn draft, _state -> updater.(draft) end)
  end

  def replace_pending(dir, id, updater) when is_function(updater, 2) do
    transaction(dir, fn state ->
      index = Enum.find_index(state["drafts"], &(&1["id"] == id and &1["status"] == "pending"))

      if is_nil(index),
        do: raise(Error, "Draft is unavailable or not pending.")

      changed = updater.(Enum.at(state["drafts"], index), state)

      unless is_map(changed) and is_binary(changed["text"]) and
               String.trim(changed["text"]) != "",
             do: raise(Error, "Replacement text is required.")

      validate_draft!(changed)
      {changed, put_in(state, ["drafts", Access.at(index)], changed)}
    end)
  end

  def seen?(dir, id),
    do: transaction(dir, fn state -> {id in state["seen"], state} end)

  def blocked?(dir, author) do
    key = Safety.actor_key(author)
    key != "" and transaction(dir, fn state -> {key in state["blocked"], state} end)
  end

  def block(dir, author) do
    key = Safety.actor_key(author)

    if key == "" do
      false
    else
      transaction(dir, fn state ->
        blocked =
          if key in state["blocked"], do: state["blocked"], else: state["blocked"] ++ [key]

        {true, Map.put(state, "blocked", blocked)}
      end)
    end
  end

  def available?(dir, opts \\ []) do
    transaction(dir, fn state -> {available_state?(state, opts), state} end)
  end

  def stage(dir, draft, opts \\ []) do
    transaction(dir, fn state ->
      source = Keyword.get(opts, :source)
      unsolicited? = Keyword.get(opts, :unsolicited, false)
      author = Safety.actor_key(draft["author"])
      now = System.system_time(:second)
      active = Enum.count(state["drafts"], &(&1["status"] in @active_statuses))

      cond do
        source && source in state["seen"] ->
          {nil, state}

        active >= 100 ->
          {nil, state}

        author != "" and author in state["blocked"] ->
          {nil, state}

        unsolicited? and unsolicited_unavailable?(state, author, now) ->
          {nil, prune_interactions(state, now)}

        true ->
          state = if unsolicited?, do: record_interaction(state, author, now), else: state

          item =
            draft
            |> Map.put("id", uuid())
            |> Map.put("record_key", record_key())
            |> Map.put("created_at", DateTime.utc_now() |> DateTime.to_iso8601())
            |> Map.put("status", "pending")

          seen =
            if source,
              do:
                Enum.take((state["seen"] ++ [source]) |> Enum.reverse(), 10_000) |> Enum.reverse(),
              else: state["seen"]

          state =
            state
            |> Map.update!("drafts", &(&1 ++ [item]))
            |> Map.put("seen", seen)

          {item, state}
      end
    end)
  end

  def transition(dir, id, from, to, opts \\ []) do
    expected = Keyword.get(opts, :expected)
    from = List.wrap(from)

    allowed = [
      {"pending", "publishing"},
      {"pending", "rejected"},
      {"publishing", "published"},
      {"publishing", "uncertain"},
      {"uncertain", "rejected"}
    ]

    unless Enum.all?(from, &({&1, to} in allowed)), do: raise(Error, "Invalid draft transition.")

    transaction(dir, fn state ->
      index = Enum.find_index(state["drafts"], &(&1["id"] == id and &1["status"] in from))

      if is_nil(index),
        do: raise(Error, "Draft is unavailable or already claimed by another reviewer.")

      draft = Enum.at(state["drafts"], index)

      if expected && draft != expected do
        raise Error, "Draft changed after review; review the new content before publishing."
      end

      changed = draft |> Map.put("status", to) |> maybe_record_claim(to)

      changed =
        if to in ["published", "rejected"],
          do: Map.put(changed, "finished_at", DateTime.to_iso8601(DateTime.utc_now())),
          else: changed

      {changed, put_in(state, ["drafts", Access.at(index)], changed)}
    end)
  end

  def claim_automatic(dir, expected, opts \\ []) do
    actors =
      opts
      |> Keyword.get(:actors, [])
      |> Enum.map(&Safety.actor_key/1)
      |> Enum.reject(&(&1 == ""))
      |> Enum.uniq()

    transaction(dir, fn state ->
      now = System.system_time(:second)
      state = prune_automatic(state, now)

      index =
        Enum.find_index(
          state["drafts"],
          &(&1["id"] == expected["id"] and &1["status"] == "pending")
        )

      cond do
        is_nil(index) ->
          {{:error, :unavailable}, state}

        Enum.at(state["drafts"], index) != expected ->
          {{:error, :unavailable}, state}

        Enum.any?(state["drafts"], &(&1["status"] in ["publishing", "uncertain"])) ->
          {{:error, :unresolved}, state}

        Enum.any?(actors, &(&1 in state["blocked"])) ->
          {{:error, :blocked}, state}

        length(state["automatic"]) >= @automatic_limit ->
          {{:error, :limit}, state}

        true ->
          draft = Enum.at(state["drafts"], index)

          claimed =
            draft
            |> Map.put("status", "publishing")
            |> Map.put("publication_mode", "automatic")
            |> Map.put("claimed_at", now)

          state =
            state
            |> put_in(["drafts", Access.at(index)], claimed)
            |> Map.update!("automatic", &(&1 ++ [now]))

          {{:ok, claimed}, state}
      end
    end)
  end

  def record_key do
    value =
      Bitwise.bor(Bitwise.bsl(System.system_time(:microsecond), 10), :rand.uniform(1024) - 1)

    encode_base32(value, 13, "")
  end

  defp available_state?(state, opts) do
    source = Keyword.get(opts, :source)
    author = Safety.actor_key(Keyword.get(opts, :author))
    unsolicited? = Keyword.get(opts, :unsolicited, false)
    now = System.system_time(:second)

    author not in state["blocked"] and source not in state["seen"] and
      Enum.count(state["drafts"], &(&1["status"] in @active_statuses)) < 100 and
      (not unsolicited? or not unsolicited_unavailable?(state, author, now))
  end

  defp unsolicited_unavailable?(state, author, now) do
    recent = Enum.count(state["daily"], &(&1 > now - 86_400))
    recent >= 5 or Map.get(state["authors"], author, 0) > now - 2_592_000
  end

  def history(base) do
    storage_path!(Path.join(base, "data"))
    data = Path.join(base, "data")

    if File.exists?(data) do
      unless File.lstat!(data).type == :directory,
        do: raise(Error, "History directory must not be a link.")

      File.ls!(data)
      |> Enum.filter(&Regex.match?(~r/^[a-f0-9]{24}$/, &1))
      |> Enum.flat_map(fn entry ->
        folder = Path.join(data, entry)

        if File.lstat!(folder).type == :directory and
             File.regular?(Path.join(folder, "state.json")),
           do: folder |> new() |> drafts() |> Enum.filter(&(&1["status"] == "published")),
           else: []
      end)
    else
      []
    end
  end

  # Check the account/data/base boundary before creating or pruning anything.
  defp storage_path!(dir) do
    base =
      if Path.basename(Path.dirname(dir)) == "data",
        do: Path.dirname(Path.dirname(dir)),
        else: Path.dirname(dir)

    paths = [dir, Path.dirname(dir), base]

    paths =
      if Path.basename(Path.dirname(base)) == "elixir",
        do: [Path.dirname(base) | paths],
        else: paths

    Enum.each(paths, fn path ->
      case File.lstat(path) do
        {:ok, %{type: :directory}} -> :ok
        {:error, :enoent} -> :ok
        _ -> raise Error, "Storage directories must not contain links."
      end
    end)
  end

  defp prune_history(state) do
    cutoff = System.system_time(:second) - 10 * 86_400

    Map.update!(state, "drafts", fn drafts ->
      Enum.reject(drafts, fn draft ->
        draft["status"] in ["published", "rejected"] and
          case DateTime.from_iso8601(draft["finished_at"] || draft["created_at"]) do
            {:ok, date, _} -> DateTime.to_unix(date) <= cutoff
            _ -> false
          end
      end)
    end)
  end

  defp prune_interactions(state, now) do
    state
    |> Map.put("daily", Enum.filter(state["daily"], &(&1 > now - 86_400)))
    |> Map.put(
      "authors",
      Map.filter(state["authors"], fn {_actor, time} -> time > now - 2_592_000 end)
    )
  end

  defp record_interaction(state, author, now) do
    state
    |> prune_interactions(now)
    |> Map.update!("daily", &(&1 ++ [now]))
    |> Map.update!("authors", &Map.put(&1, author, now))
  end

  defp default_state do
    %{
      "drafts" => [],
      "seen" => [],
      "authors" => %{},
      "daily" => [],
      "blocked" => [],
      "automatic" => []
    }
  end

  defp read_state(path) do
    case regular_file!(path, true) do
      :missing ->
        default_state()

      :ok ->
        case File.read!(path) |> Jason.decode() do
          {:ok, state} -> state |> Map.put_new("automatic", []) |> validate_state!()
          {:error, _} -> raise Error, "State JSON is corrupt; refusing to reset posting history."
        end
    end
  end

  defp validate_state!(state) do
    valid? =
      is_map(state) and is_list(state["drafts"]) and is_list(state["seen"]) and
        is_map(state["authors"]) and is_list(state["daily"]) and is_list(state["blocked"]) and
        is_list(state["automatic"])

    unless valid?, do: raise(Error, "State is invalid; restore a backup before continuing.")

    valid? =
      Enum.all?(state["seen"] ++ state["blocked"], &is_binary/1) and
        Enum.all?(state["daily"] ++ state["automatic"], &(is_integer(&1) and &1 >= 0)) and
        Enum.all?(state["authors"], fn {key, time} ->
          is_binary(key) and is_integer(time) and time >= 0
        end) and
        Enum.all?(state["drafts"], &valid_saved_draft?/1)

    ids = Enum.map(state["drafts"], fn draft -> if is_map(draft), do: draft["id"] end)

    unless valid? and length(ids) == length(Enum.uniq(ids)),
      do: raise(Error, "State entries are invalid; refusing to reset posting history.")

    state
  end

  defp valid_saved_draft?(draft) when is_map(draft) do
    draft["status"] in ["pending", "publishing", "uncertain", "published", "rejected"] and
      is_binary(draft["id"]) and Regex.match?(~r/^[0-9a-f-]{36}$/, draft["id"]) and
      is_binary(draft["record_key"]) and Regex.match?(~r/^[234567a-z]{13}$/, draft["record_key"]) and
      is_binary(draft["created_at"]) and
      match?({:ok, _, _}, DateTime.from_iso8601(draft["created_at"])) and
      Enum.all?(
        [
          "platform",
          "account",
          "text",
          "action",
          "visibility",
          "language",
          "reply_to",
          "quote_to",
          "author",
          "author_id",
          "publication_mode",
          "cw"
        ],
        fn key -> is_nil(draft[key]) or is_binary(draft[key]) end
      ) and
      (is_nil(draft["claimed_at"]) or
         (is_integer(draft["claimed_at"]) and draft["claimed_at"] >= 0))
  end

  defp valid_saved_draft?(_), do: false

  defp regular_file!(path, missing?) do
    case File.lstat(path) do
      {:ok, %{type: :regular}} -> :ok
      {:error, :enoent} when missing? -> :missing
      _ -> raise Error, "Storage path must be a regular file, not a symlink or directory."
    end
  end

  defp write_state(path, state) do
    temporary = path <> ".#{Base.url_encode64(:crypto.strong_rand_bytes(8), padding: false)}.tmp"

    try do
      {:ok, io} = File.open(temporary, [:write, :binary, :exclusive])
      IO.binwrite(io, Jason.encode!(state, pretty: true))
      :ok = :file.sync(io)
      File.close(io)
      Platform.private_created_file!(temporary)
      Platform.replace_file!(temporary, path)
    after
      File.rm(temporary)
    end
  end

  defp maybe_record_claim(draft, "publishing"),
    do: Map.put(draft, "claimed_at", System.system_time(:second))

  defp maybe_record_claim(draft, _status), do: draft

  defp prune_automatic(state, now) do
    Map.put(state, "automatic", Enum.filter(state["automatic"], &(&1 > now - 86_400)))
  end

  defp recover_stale_publications(state, now) do
    Map.update!(state, "drafts", fn drafts ->
      Enum.map(drafts, fn draft ->
        stale? =
          draft["status"] == "publishing" and
            (is_nil(draft["claimed_at"]) or
               draft["claimed_at"] <= now - @publication_lease_seconds)

        if stale?, do: Map.put(draft, "status", "uncertain"), else: draft
      end)
    end)
  end

  # Keep a persistent lock file; unlinking it could split concurrent owners.
  defp acquire_lock(path) do
    regular_file!(path, true)
    {:ok, io} = File.open(path, [:append, :binary])
    File.close(io)
    Platform.private_created_file!(path)

    Lock.acquire(path)
  end

  defp uuid do
    hex = :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)

    Enum.join(
      [
        String.slice(hex, 0, 8),
        String.slice(hex, 8, 4),
        String.slice(hex, 12, 4),
        String.slice(hex, 16, 4),
        String.slice(hex, 20, 12)
      ],
      "-"
    )
  end

  defp encode_base32(_value, 0, acc), do: acc

  defp encode_base32(value, remaining, acc) do
    alphabet = "234567abcdefghijklmnopqrstuvwxyz"
    char = String.at(alphabet, Bitwise.band(value, 31))
    encode_base32(Bitwise.bsr(value, 5), remaining - 1, char <> acc)
  end
end
