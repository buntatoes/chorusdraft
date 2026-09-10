defmodule ChorusDraft.StreamingTest do
  use ExUnit.Case
  import ExUnit.CaptureIO
  alias ChorusDraft.{CLI, Error, Jetstream, Streaming}

  test "streaming URL is an HTTPS origin and never carries credentials or filters" do
    assert Streaming.endpoint!(%{"MASTODON_API_BASE_URL" => "https://mastodon.example"}) ==
             "https://mastodon.example/api/v1/streaming/user"

    assert Streaming.endpoint!(%{
             "MASTODON_API_BASE_URL" => "https://mastodon.example",
             "MASTODON_STREAMING_URL" => "https://streaming.example:8443"
           }) == "https://streaming.example:8443/api/v1/streaming/user"

    for url <- [
          "http://mastodon.example",
          "wss://mastodon.example",
          "https://u:p@mastodon.example",
          "https://mastodon.example?access_token=secret",
          "https://mastodon.example#fragment",
          "https://mastodon.example/api/v1/streaming?stream=user",
          "https:///"
        ] do
      assert_raise Error, fn -> Streaming.endpoint!(%{"MASTODON_STREAMING_URL" => url}) end
    end
  end

  test "only notification events are a wake-up; payloads are not inspected" do
    assert Streaming.decode_event("notification") == :activity
    assert Streaming.decode_event("update") == :ignore
    assert Streaming.decode_event("delete") == :ignore
    assert Streaming.decode_event(nil) == :ignore
  end

  test "SSE parser wakes on notification and ignores the data payload" do
    stream = Jetstream.subscription("mastodon")

    payload =
      "event: notification\ndata: {\"type\":\"mention\",\"status\":{\"content\":\"UNTRUSTED STREAM BODY\"}}\n\n"

    {rest, event, size} = Streaming.feed({"", nil, 0}, payload, stream)
    assert rest == ""
    assert event == nil
    assert size == 0
    assert Jetstream.wait(stream, 0) == :activity
    assert Jetstream.wait(stream, 0) == :timeout
  end

  test "home-timeline updates and comments do not queue work" do
    stream = Jetstream.subscription("mastodon")
    Streaming.feed({"", nil, 0}, ": heartbeat\n\nevent: update\ndata: {}\n\n", stream)
    assert Jetstream.wait(stream, 0) == :timeout
  end

  test "SSE lines split across chunks still wake on notification" do
    stream = Jetstream.subscription("mastodon")
    state = Streaming.feed({"", nil, 0}, "event: notifi", stream)
    assert Jetstream.wait(stream, 0) == :timeout
    state = Streaming.feed(state, "cation\ndata: {\"a\":1}\n", stream)
    assert Jetstream.wait(stream, 0) == :timeout
    Streaming.feed(state, "\n", stream)
    assert Jetstream.wait(stream, 0) == :activity
  end

  test "an SSE message larger than one megabyte is refused" do
    stream = Jetstream.subscription("mastodon")

    assert_raise Error, ~r/exceeded limits/, fn ->
      Streaming.feed({"", nil, 0}, "data: " <> String.duplicate("x", 1_048_577), stream)
    end

    # Exactly at the cap still parses.
    state = Streaming.feed({"", nil, 0}, "data: " <> String.duplicate("x", 1_048_570), stream)
    assert elem(state, 2) == 1_048_576
  end

  test "a dropped stable session reconnects quickly instead of backing off" do
    {:ok, listener} =
      :gen_tcp.listen(0, [:binary, active: false, reuseaddr: true, ip: {127, 0, 0, 1}])

    {:ok, {_, port}} = :inet.sockname(listener)
    owner = self()
    {:ok, server} = Task.start(fn -> drop_after_handshake(listener, owner, 4) end)
    stream = Jetstream.subscription("mastodon")
    url = "http://127.0.0.1:#{port}/api/v1/streaming/user"
    {:ok, client} = Streaming.start_link(url, "fixture-token", stream, stable_session: 0)
    Process.unlink(client)

    on_exit(fn ->
      Process.exit(client, :kill)
      Process.exit(server, :kill)
      :gen_tcp.close(listener)
    end)

    started = System.monotonic_time(:millisecond)
    for _ <- 1..4, do: assert_receive({:dropped, _request}, 10_000)
    elapsed = System.monotonic_time(:millisecond) - started

    # Stable sessions reset the backoff to about one second per reconnect
    # (~4s for four connections). Without the reset the backoff climbs to the
    # attempt cap and the fourth connection lands after ~7 seconds.
    assert elapsed < 5_500
  end

  defp drop_after_handshake(_listener, owner, 0), do: send(owner, :done)

  defp drop_after_handshake(listener, owner, remaining) do
    {:ok, socket} = :gen_tcp.accept(listener)
    request = read_headers(socket, "")

    :ok =
      :gen_tcp.send(
        socket,
        "HTTP/1.1 200 OK\r\nContent-Type: text/event-stream\r\nCache-Control: no-cache\r\n\r\n"
      )

    :gen_tcp.close(socket)
    send(owner, {:dropped, request})
    drop_after_handshake(listener, owner, remaining - 1)
  end

  test "Mastodon listen validates the streaming URL before login" do
    dir = Path.join(System.tmp_dir!(), "streaming-cli-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    File.write!(Path.join(dir, ".env"), "MASTODON_STREAMING_URL=http://example.org\n")
    on_exit(fn -> File.rm_rf!(dir) end)

    assert capture_io(:stderr, fn ->
             assert CLI.run(["mastodon", "--listen", "--base", dir]) == 1
           end) =~ "Mastodon streaming requires an HTTPS origin"

    assert CLI.streaming_enabled?("mastodon", %{listen: true})
    assert CLI.streaming_enabled?("bluesky", %{daemon: true})
    refute CLI.streaming_enabled?("mastodon", %{post_only: true})
  end

  test "a local fixture streams notifications without putting the token in the URL" do
    {:ok, listener} =
      :gen_tcp.listen(0, [:binary, active: false, reuseaddr: true, ip: {127, 0, 0, 1}])

    {:ok, {_, port}} = :inet.sockname(listener)
    owner = self()
    {:ok, server} = Task.start(fn -> serve(listener, owner) end)
    stream = Jetstream.subscription("mastodon")
    url = "http://127.0.0.1:#{port}/api/v1/streaming/user"
    {:ok, client} = Streaming.start_link(url, "fixture-token", stream)
    Process.unlink(client)

    on_exit(fn ->
      Process.exit(client, :kill)
      Process.exit(server, :kill)
      :gen_tcp.close(listener)
    end)

    assert_receive {:connected, request}, 2_000
    assert request =~ "authorization: Bearer fixture-token"
    refute request =~ "access_token"
    assert Jetstream.wait(stream, 2_000) == :activity
    send(server, :notify)
    assert Jetstream.wait(stream, 2_000) == :activity
  end

  defp serve(listener, owner) do
    {:ok, socket} = :gen_tcp.accept(listener)
    request = read_headers(socket, "")
    send(owner, {:connected, request})

    :ok =
      :gen_tcp.send(
        socket,
        "HTTP/1.1 200 OK\r\nContent-Type: text/event-stream\r\nCache-Control: no-cache\r\n\r\n"
      )

    serve_body(socket)
    serve(listener, owner)
  end

  defp read_headers(socket, buffer) do
    if String.contains?(buffer, "\r\n\r\n") do
      buffer
    else
      {:ok, data} = :gen_tcp.recv(socket, 0, 2_000)
      read_headers(socket, buffer <> data)
    end
  end

  defp serve_body(socket) do
    receive do
      :notify ->
        :ok =
          :gen_tcp.send(
            socket,
            "event: notification\ndata: {\"content\":\"UNTRUSTED STREAM BODY\"}\n\n"
          )

        serve_body(socket)
    after
      8_000 -> :ok
    end
  end
end
