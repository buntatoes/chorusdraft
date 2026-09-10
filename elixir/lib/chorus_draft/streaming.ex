defmodule ChorusDraft.Streaming do
  @moduledoc """
  Mastodon user-stream wake-ups for the existing notification workflow.

  Stream bodies are untrusted. A notification event only wakes the normal
  API fetch. Periodic catch-up still runs.
  """
  alias ChorusDraft.{Error, HTTP, Jetstream}
  alias ChorusDraft.Jetstream.Socket

  @path "/api/v1/streaming/user"
  @max_bytes 1_048_576
  @max_headers 16_384
  @idle_timeout 90_000
  @stable_session 30_000
  @read_timeout 10_000

  def endpoint!(env) do
    base = Map.get(env, "MASTODON_STREAMING_URL") || Map.get(env, "MASTODON_API_BASE_URL") || ""
    uri = URI.parse(base)

    unless uri.scheme == "https" and is_binary(uri.host) and uri.host != "" and
             is_nil(uri.userinfo) and is_nil(uri.query) and is_nil(uri.fragment) and
             uri.path in [nil, "", "/", "/api/v1/streaming", @path] and
             (is_nil(uri.port) or uri.port in 1..65_535) do
      raise Error,
            "Mastodon streaming requires an HTTPS origin or /api/v1/streaming URL without credentials, query or fragment."
    end

    %{uri | path: @path, query: nil}
    |> URI.to_string()
  rescue
    _ in [URI.Error, ArgumentError] -> raise Error, "Invalid Mastodon streaming endpoint."
  end

  def with_stream(env, fun) do
    url = endpoint!(env)
    token = env |> Map.get("MASTODON_ACCESS_TOKEN", "") |> String.trim()
    if token == "", do: raise(Error, "Mastodon streaming requires an access token.")
    stream = Jetstream.subscription("mastodon")
    {:ok, task} = Task.start_link(fn -> reconnect(url, token, stream, 0, []) end)

    try do
      fun.(stream)
    after
      Process.exit(task, :shutdown)
      Jetstream.wait(stream, 0)
    end
  end

  def start_link(url, token, stream, opts \\ []) do
    Task.start_link(fn -> reconnect(url, token, stream, 0, opts) end)
  end

  def decode_event(type) when type in ["notification"], do: :activity
  def decode_event(_type), do: :ignore

  defp reconnect(url, token, stream, attempt, opts) do
    stable_after = Keyword.get(opts, :stable_session, @stable_session)
    started = now()
    stable? = session(url, token, stream) and now() - started >= stable_after
    Process.sleep(Socket.reconnect_delay(if stable?, do: 0, else: attempt))
    reconnect(url, token, stream, if(stable?, do: 1, else: min(attempt + 1, 5)), opts)
  end

  defp session(url, token, stream) do
    uri = URI.parse(url)

    case HTTP.open(uri) do
      {:ok, conn} ->
        try do
          path = if(uri.path in [nil, ""], do: "/", else: uri.path)

          {:ok, conn, ref} =
            Mint.HTTP.request(conn, "GET", path, headers(token), nil)

          {conn, parser} = handshake!(conn, ref, stream)
          Jetstream.notify(stream)

          # The loop only exits by raising; a session that completed the
          # handshake still counts as established so the backoff can reset.
          try do
            loop(conn, ref, stream, now(), parser)
          rescue
            _ -> :ok
          end

          true
        rescue
          _ -> false
        after
          Mint.HTTP.close(conn)
        end

      {:error, _} ->
        false
    end
  end

  defp headers(token) do
    [
      {"accept", "text/event-stream"},
      {"authorization", "Bearer " <> token},
      {"cache-control", "no-cache"}
    ]
  end

  defp handshake!(conn, ref, stream) do
    handshake!(conn, ref, stream, now() + @read_timeout, :status, 0, {"", nil, 0})
  end

  defp handshake!(conn, ref, stream, deadline, expect, header_size, parser) do
    timeout = deadline - now()
    if timeout <= 0, do: raise(Error, "Mastodon streaming timed out.")
    {conn, responses} = recv(conn, timeout)

    {expect, header_size, parser, ready} =
      Enum.reduce(responses, {expect, header_size, parser, false}, fn
        {:status, ^ref, status}, {_, header_size, parser, ready} when status in 200..299 ->
          {:headers, header_size, parser, ready}

        {:status, ^ref, _status}, _ ->
          raise Error, "Mastodon streaming handshake failed."

        {:headers, ^ref, headers}, {expect, header_size, parser, _ready}
        when expect in [:headers, :body] ->
          header_size =
            Enum.reduce(headers, header_size, fn {k, v}, acc ->
              acc + byte_size(to_string(k)) + byte_size(to_string(v)) + 4
            end)

          if header_size > @max_headers,
            do: raise(Error, "Mastodon streaming headers exceeded size limit.")

          {:body, header_size, parser, true}

        {:data, ^ref, data}, {:body, header_size, parser, _} ->
          {:body, header_size, feed(parser, data, stream), true}

        {:data, ^ref, _}, _ ->
          raise Error, "Mastodon streaming sent a body before headers finished."

        {:done, ^ref}, _ ->
          raise Error, "Mastodon streaming closed."

        {:error, ^ref, _}, _ ->
          raise Error, "Mastodon streaming handshake failed."

        _, acc ->
          acc
      end)

    if ready,
      do: {conn, parser},
      else: handshake!(conn, ref, stream, deadline, expect, header_size, parser)
  end

  defp loop(conn, ref, stream, idle, parser) do
    if now() >= idle + @idle_timeout, do: raise(Error, "Mastodon streaming timed out.")
    timeout = max(idle + @idle_timeout - now(), 0)
    {conn, responses} = recv(conn, timeout)

    {parser, idle} =
      Enum.reduce(responses, {parser, idle}, fn
        {:data, ^ref, data}, {parser, _idle} ->
          {feed(parser, data, stream), now()}

        {:done, ^ref}, _ ->
          raise Error, "Mastodon streaming closed."

        {:error, ^ref, _}, _ ->
          raise Error, "Mastodon streaming receive failed."

        _, acc ->
          acc
      end)

    loop(conn, ref, stream, idle, parser)
  end

  defp recv(conn, timeout) do
    case Mint.HTTP.recv(conn, 0, timeout) do
      {:ok, conn, responses} ->
        {conn, responses}

      {:error, conn, %Mint.TransportError{reason: :timeout}, responses} ->
        {conn, responses}

      {:error, _conn, _reason, _responses} ->
        raise Error, "Mastodon streaming receive failed."
    end
  end

  # parser: {buffer, event_type, size}. Data payloads are counted, never kept.
  def feed({buffer, event, size}, data, stream) do
    size = size + byte_size(data)
    if size > @max_bytes, do: raise(Error, "Mastodon streaming message exceeded limits.")
    take(buffer <> data, event, size, stream)
  end

  defp take(buffer, event, size, stream) do
    case String.split(buffer, "\n", parts: 2) do
      [rest] ->
        {rest, event, size}

      [line, rest] ->
        line = String.trim_trailing(line, "\r")

        cond do
          line == "" ->
            if decode_event(event) == :activity, do: Jetstream.notify(stream)
            take(rest, nil, 0, stream)

          String.starts_with?(line, ":") ->
            take(rest, event, size, stream)

          String.starts_with?(line, "event:") ->
            take(rest, line |> String.trim_leading("event:") |> String.trim(), size, stream)

          String.starts_with?(line, "data:") ->
            take(rest, event, size, stream)

          true ->
            take(rest, event, size, stream)
        end
    end
  end

  defp now, do: System.monotonic_time(:millisecond)
end
