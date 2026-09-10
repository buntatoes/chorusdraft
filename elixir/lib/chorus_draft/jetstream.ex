defmodule ChorusDraft.Jetstream do
  @moduledoc """
  Jetstream live-tail signals for the existing Bluesky notification workflow.

  Stream records are untrusted wake-up hints, never AI input. Fetching through
  Runner.mentions/1 retains opt-out, deduplication, safety, and publication-policy behavior.
  Initial and periodic notification checks cover disconnects and AppView lag.
  """
  alias ChorusDraft.Error
  alias ChorusDraft.Jetstream.Socket

  @path "/xrpc/network.bsky.jetstream.subscribeEvents"
  @default "wss://jetstream.us-east.bsky.network"
  @commit_type "network.bsky.jetstream.subscribeEvents#commit"
  @max_bytes 1_048_576

  def endpoint!(env) do
    uri = URI.parse(Map.get(env, "BLUESKY_JETSTREAM_URL", @default))

    unless uri.scheme == "wss" and is_binary(uri.host) and uri.host != "" and
             is_nil(uri.userinfo) and is_nil(uri.query) and is_nil(uri.fragment) and
             uri.path in [nil, "", "/", @path] and
             (is_nil(uri.port) or uri.port in 1..65_535) do
      raise Error,
            "Jetstream requires a WSS origin or subscribeEvents URL without credentials, query or fragment."
    end

    %{
      uri
      | path: @path,
        query: URI.encode_query(collections: "app.bsky.feed.post", kinds: "commit")
    }
    |> URI.to_string()
  rescue
    _ in [URI.Error, ArgumentError] -> raise Error, "Invalid Jetstream endpoint."
  end

  def subscription(did, owner \\ self()) when is_binary(did) and did != "" do
    %{did: did, owner: owner, signal: :atomics.new(1, []), tag: make_ref()}
  end

  def with_stream(did, env, fun) do
    stream = subscription(did)
    options = [stream: stream, url: endpoint!(env)]
    child = %{id: Socket, start: {Socket, :start_link, [options]}, restart: :permanent}
    {:ok, supervisor} = Supervisor.start_link([child], strategy: :one_for_one)

    try do
      fun.(stream)
    after
      Supervisor.stop(supervisor)
      flush(stream)
    end
  end

  # A single pending wake-up bounds the consumer mailbox even during slow AI calls.
  def notify(stream) do
    if :atomics.compare_exchange(stream.signal, 1, 0, 1) == :ok do
      send(stream.owner, {__MODULE__, stream.tag})
    end

    :ok
  end

  def wait(stream, timeout, cooldown \\ 0) do
    tag = stream.tag

    receive do
      {__MODULE__, ^tag} ->
        # Keep the latch set during the cooldown so bursts cannot queue work.
        if cooldown > 0, do: Process.sleep(cooldown)
        :atomics.put(stream.signal, 1, 0)
        :activity
    after
      timeout -> :timeout
    end
  end

  defp flush(stream) do
    tag = stream.tag

    receive do
      {__MODULE__, ^tag} -> :ok
    after
      0 -> :ok
    end
  end

  def decode(frame, did) when is_binary(frame) and byte_size(frame) <= @max_bytes do
    case Jason.decode(frame) do
      {:ok, %{"$type" => "message", "payload" => payload}} ->
        if relevant?(payload, did), do: :activity, else: :ignore

      {:ok, %{"$type" => "error"}} ->
        :reconnect

      _ ->
        :ignore
    end
  end

  def decode(_, _), do: :ignore

  def relevant?(
        %{
          "$type" => @commit_type,
          "operation" => operation,
          "collection" => "app.bsky.feed.post",
          "did" => author,
          "record" => record
        },
        did
      )
      when operation in ["create", "update"] and is_binary(author) and
             is_binary(did) and did != "" and author != did and is_map(record) do
    reply?(record["reply"], did) or mention?(record["facets"], did)
  end

  def relevant?(_, _), do: false

  defp reply?(%{"parent" => %{"uri" => uri}}, did) when is_binary(uri) do
    case String.split(uri, "/") do
      ["at:", "", ^did, "app.bsky.feed.post", key] when key != "" -> true
      _ -> false
    end
  end

  defp reply?(_, _), do: false

  defp mention?(facets, did) when is_list(facets) do
    Enum.any?(facets, fn
      %{"features" => features} when is_list(features) ->
        Enum.any?(features, fn
          %{"$type" => "app.bsky.richtext.facet#mention", "did" => ^did} -> true
          _ -> false
        end)

      _ ->
        false
    end)
  end

  defp mention?(_, _), do: false
end
