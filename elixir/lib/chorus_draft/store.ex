defmodule ChorusDraft.Store do
  alias ChorusDraft.{Error, Safety}

  @active_statuses ["pending", "publishing", "uncertain"]
  @lock_timeout 5_000

  def new(dir) do
    File.mkdir_p!(dir)

    unless File.lstat!(dir).type == :directory,
      do: raise(Error, "State directory must not be a symlink.")

    File.chmod!(dir, 0o700)
    dir
  end

  def transaction(dir, fun) do
    lock = acquire_lock(Path.join(dir, "state.lock"))

    try do
      original = read_state(Path.join(dir, "state.json"))
      {result, state} = fun.(original)
      validate_state!(state)
      if state != original, do: write_state(Path.join(dir, "state.json"), state)
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
    state = raw |> Jason.decode!() |> Map.put_new("blocked", []) |> validate_state!()

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
    _ -> raise Error, "Could not import state; source must be a valid Ruby or Elixir state.json."
  end

  def validate_draft!(draft) do
    required = ["platform", "account", "text", "action", "visibility", "language"]
    optional = ["reply_to", "quote_to", "author", "cw"]

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
      {"publishing", "uncertain"}
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

      changed = Map.put(draft, "status", to)
      {changed, put_in(state, ["drafts", Access.at(index)], changed)}
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
    %{"drafts" => [], "seen" => [], "authors" => %{}, "daily" => [], "blocked" => []}
  end

  defp read_state(path) do
    case regular_file!(path, true) do
      :missing ->
        default_state()

      :ok ->
        case File.read!(path) |> Jason.decode() do
          {:ok, state} -> validate_state!(state)
          {:error, _} -> raise Error, "State JSON is corrupt; refusing to reset posting history."
        end
    end
  end

  defp validate_state!(state) do
    valid? =
      is_map(state) and is_list(state["drafts"]) and is_list(state["seen"]) and
        is_map(state["authors"]) and is_list(state["daily"]) and is_list(state["blocked"])

    unless valid?, do: raise(Error, "State is invalid; restore a backup before continuing.")

    valid? =
      Enum.all?(state["seen"] ++ state["blocked"], &is_binary/1) and
        Enum.all?(state["daily"], &(is_integer(&1) and &1 >= 0)) and
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
          "cw"
        ],
        fn key -> is_nil(draft[key]) or is_binary(draft[key]) end
      )
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
      File.chmod!(temporary, 0o600)
      IO.binwrite(io, Jason.encode!(state, pretty: true))
      :ok = :file.sync(io)
      File.close(io)
      File.chmod!(temporary, 0o600)
      File.rename!(temporary, path)
    after
      File.rm(temporary)
    end
  end

  # The Linux kernel releases flock on process exit, including crashes. The
  # descriptor also interoperates with Ruby's state.lock without deleting it.
  defp acquire_lock(path) do
    regular_file!(path, true)
    {:ok, io} = File.open(path, [:append, :binary])
    File.close(io)
    File.chmod!(path, 0o600)

    executable =
      System.find_executable("flock") ||
        raise(Error, "Install util-linux (flock) to use state storage.")

    port =
      Port.open({:spawn_executable, executable}, [
        :binary,
        :exit_status,
        :use_stdio,
        :hide,
        args: [
          "--exclusive",
          "--timeout",
          "5",
          "--no-fork",
          path,
          "/bin/sh",
          "-c",
          "printf 'locked\\n'; read -r release"
        ]
      ])

    receive do
      {^port, {:data, "locked\n"}} -> port
      {^port, {:exit_status, _}} -> raise Error, "State is busy or could not be locked."
    after
      @lock_timeout + 1_000 ->
        if Port.info(port), do: Port.close(port)
        raise Error, "State lock timed out."
    end
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
