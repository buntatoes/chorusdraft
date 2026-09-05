defmodule ChorusDraft.Store do
  alias ChorusDraft.{Error, Safety}

  @active_statuses ["pending", "publishing", "uncertain"]
  @lock_timeout 5_000
  @stale_lock 300

  def new(dir) do
    File.mkdir_p!(dir)
    File.chmod(dir, 0o700)
    dir
  end

  def transaction(dir, fun) do
    lock = dir <> "/state.lock.d"
    acquire_lock(lock, System.monotonic_time(:millisecond) + @lock_timeout)

    try do
      state = read_state(dir <> "/state.json")
      {result, state} = fun.(state)
      validate_state!(state)
      write_state(dir <> "/state.json", state)
      result
    after
      release_lock(lock)
    end
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
    if File.regular?(path) do
      case File.read!(path) |> Jason.decode() do
        {:ok, state} -> validate_state!(state)
        {:error, _} -> raise Error, "State JSON is corrupt; refusing to reset posting history."
      end
    else
      default_state()
    end
  end

  defp validate_state!(state) do
    valid? =
      is_map(state) and is_list(state["drafts"]) and is_list(state["seen"]) and
        is_map(state["authors"]) and is_list(state["daily"]) and is_list(state["blocked"])

    if valid?,
      do: state,
      else: raise(Error, "State is invalid; restore a backup before continuing.")
  end

  defp write_state(path, state) do
    temporary = path <> ".#{Base.url_encode64(:crypto.strong_rand_bytes(8), padding: false)}.tmp"

    try do
      {:ok, io} = File.open(temporary, [:write, :binary, :exclusive])
      IO.binwrite(io, Jason.encode!(state, pretty: true))
      :ok = :file.sync(io)
      File.close(io)
      File.chmod!(temporary, 0o600)
      File.rename!(temporary, path)
    after
      File.rm(temporary)
    end
  end

  defp acquire_lock(lock, deadline) do
    case File.mkdir(lock) do
      :ok ->
        File.chmod(lock, 0o700)

        File.write!(lock <> "/owner", Integer.to_string(System.pid() |> String.to_integer()), [
          :exclusive
        ])

      {:error, :eexist} ->
        recover_stale_lock(lock)

        if System.monotonic_time(:millisecond) >= deadline do
          raise Error, "State is busy; ensure only one process uses this account."
        end

        Process.sleep(50)
        acquire_lock(lock, deadline)

      {:error, _} ->
        raise Error, "Could not lock state storage."
    end
  end

  defp recover_stale_lock(lock) do
    owner = lock <> "/owner"

    with {:ok, stat} <- File.stat(owner, time: :posix),
         true <- System.system_time(:second) - stat.mtime > @stale_lock,
         {:ok, pid_text} <- File.read(owner),
         {pid, ""} <- Integer.parse(pid_text),
         false <- File.exists?("/proc/#{pid}") do
      File.rm(owner)
      File.rmdir(lock)
    else
      _ -> :ok
    end
  end

  defp release_lock(lock) do
    File.rm(lock <> "/owner")
    File.rmdir(lock)
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
