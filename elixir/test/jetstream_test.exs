defmodule ChorusDraft.JetstreamTest do
  use ExUnit.Case
  import ExUnit.CaptureIO
  alias ChorusDraft.{CLI, Error, Jetstream, Runner, Store, TestClient}
  alias ChorusDraft.Jetstream.Socket

  @did "did:plc:me"

  defp event(record, changes \\ %{}) do
    %{
      "$type" => "message",
      "payload" =>
        Map.merge(
          %{
            "$type" => "network.bsky.jetstream.subscribeEvents#commit",
            "did" => "did:plc:alice",
            "seq" => 123,
            "operation" => "create",
            "collection" => "app.bsky.feed.post",
            "rkey" => "abc",
            "record" => record
          },
          changes
        )
    }
    |> Jason.encode!()
  end

  defp mention do
    %{
      "text" => "UNTRUSTED STREAM BODY",
      "facets" => [
        %{"features" => [%{"$type" => "app.bsky.richtext.facet#mention", "did" => @did}]}
      ]
    }
  end

  test "subscription uses the current JSON endpoint and filters collections, not authors" do
    uri = URI.parse(Jetstream.endpoint!(%{}))
    assert uri.scheme == "wss"
    assert uri.path == "/xrpc/network.bsky.jetstream.subscribeEvents"

    assert URI.decode_query(uri.query) == %{
             "collections" => "app.bsky.feed.post",
             "kinds" => "commit"
           }

    assert is_nil(uri.userinfo)

    assert Jetstream.endpoint!(%{"BLUESKY_JETSTREAM_URL" => "wss://example.org:8443"}) =~
             "example.org:8443/"
  end

  test "endpoint validation refuses plaintext, credentials and caller-supplied filters" do
    for url <- [
          "ws://example.org",
          "https://example.org",
          "wss://u:p@example.org",
          "wss://example.org?dids=did:plc:me",
          "wss://example.org#secret",
          "wss://example.org/subscribe",
          "wss:///",
          "wss://example.org:0"
        ] do
      assert_raise Error, fn -> Jetstream.endpoint!(%{"BLUESKY_JETSTREAM_URL" => url}) end
    end
  end

  test "TLS peer and hostname verification are explicit and no authentication is sent" do
    opts = Socket.connection_options(URI.parse("wss://example.org"))
    assert opts[:insecure] == false
    assert opts[:ssl_options][:verify] == :verify_peer
    assert opts[:ssl_options][:cacerts] != []
    assert opts[:ssl_options][:server_name_indication] == ~c"example.org"
    assert is_function(opts[:ssl_options][:customize_hostname_check][:match_fun], 2)
    assert opts[:extra_headers] == [{"Sec-WebSocket-Protocol", "xrpc.v1.json"}]
  end

  test "mention facets and direct replies trigger activity, including edits" do
    assert Jetstream.decode(event(mention()), @did) == :activity
    assert Jetstream.decode(event(mention(), %{"operation" => "update"}), @did) == :activity
    reply = %{"reply" => %{"parent" => %{"uri" => "at://#{@did}/app.bsky.feed.post/abc"}}}
    assert Jetstream.decode(event(reply), @did) == :activity

    wrong_parent =
      put_in(reply, ["reply", "parent", "uri"], "at://#{@did}other/app.bsky.feed.post/abc")

    assert Jetstream.decode(event(wrong_parent), @did) == :ignore
  end

  test "unrelated, self-authored, deleted and non-post events do not trigger work" do
    for changes <- [
          %{"did" => @did},
          %{"operation" => "delete"},
          %{"collection" => "app.bsky.feed.like"},
          %{"$type" => "identity"}
        ] do
      assert Jetstream.decode(event(mention(), changes), @did) == :ignore
    end

    assert Jetstream.decode(event(%{"text" => "Hello @me.test #{@did}"}), @did) == :ignore
    root_only = %{"reply" => %{"root" => %{"uri" => "at://#{@did}/app.bsky.feed.post/root"}}}
    assert Jetstream.decode(event(root_only), @did) == :ignore
  end

  test "malformed, oversized and legacy messages are harmless" do
    for frame <- [
          "broken",
          "null",
          "[]",
          "42",
          "{}",
          String.duplicate("x", 1_048_577),
          Jason.encode!(%{"kind" => "commit", "commit" => mention()})
        ] do
      assert Jetstream.decode(frame, @did) == :ignore
    end

    for record <- [nil, [], 1, %{"facets" => [nil, %{"features" => 1}]}, %{"reply" => []}] do
      assert Jetstream.decode(event(record), @did) == :ignore
    end

    assert Jetstream.decode(~s({"$type":"error","error":"temporary"}), @did) == :reconnect
  end

  test "a burst leaves only one wake-up pending and receiving it rearms the latch" do
    stream = Jetstream.subscription(@did)
    for _ <- 1..1_000, do: Jetstream.notify(stream)
    assert Jetstream.wait(stream, 0) == :activity
    assert Jetstream.wait(stream, 0) == :timeout
    Jetstream.notify(stream)
    assert Jetstream.wait(stream, 0) == :activity
    assert Jetstream.wait(Jetstream.subscription(@did), 0) == :timeout
  end

  test "retry delays are bounded" do
    assert Socket.reconnect_delay(0) in 1_001..1_250
    assert Socket.reconnect_delay(100) in 30_001..30_250
  end

  test "Jetstream CLI combinations are rejected before logging in" do
    assert CLI.jetstream_enabled?("bluesky", %{listen: true})
    assert CLI.jetstream_enabled?("bluesky", %{daemon: true})
    refute CLI.jetstream_enabled?("bluesky", %{post_only: true})
    refute CLI.jetstream_enabled?("mastodon", %{listen: true})
    refute CLI.jetstream_enabled?("mastodon", %{daemon: true})

    assert capture_io(:stderr, fn ->
             assert CLI.run(["mastodon", "--listen", "--jetstream"]) == 1
           end) =~ "only for Bluesky"

    assert capture_io(:stderr, fn ->
             assert CLI.run(["bluesky", "--post-only", "--jetstream"]) == 1
           end) =~ "requires --listen or --daemon"

    assert capture_io(:stderr, fn ->
             assert CLI.run(["bluesky", "--listen", "--no-jetstream"]) == 1
           end) =~ "cannot be disabled"

    assert capture_io(fn -> assert CLI.run(["bluesky", "--help"]) == 0 end) =~
             "Bluesky listen/start always streams"
  end

  test "Bluesky listener validates its default Jetstream endpoint before login" do
    dir = Path.join(System.tmp_dir!(), "jetstream-cli-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    File.write!(Path.join(dir, ".env"), "BLUESKY_JETSTREAM_URL=https://example.org\n")
    on_exit(fn -> File.rm_rf!(dir) end)

    assert capture_io(:stderr, fn ->
             assert CLI.run(["bluesky", "--listen", "--base", dir]) == 1
           end) =~ "Jetstream requires a WSS origin"

    assert capture_io(:stderr, fn ->
             assert CLI.run(["bluesky", "start", "--base", dir]) == 1
           end) =~ "Jetstream requires a WSS origin"
  end

  test "stream hints cannot supply AI context, bypass opt-outs, publish, or duplicate drafts" do
    dir = Path.join(System.tmp_dir!(), "jetstream-runner-#{System.unique_integer([:positive])}")
    Store.new(dir)
    on_exit(fn -> File.rm_rf!(dir) end)
    {:ok, published} = Agent.start_link(fn -> [] end)

    post = %{
      "id" => "1",
      "text" => "Canonical API post",
      "author" => "alice.test",
      "author_id" => "did:plc:alice",
      "visibility" => "public",
      "url" => "https://example.org/1"
    }

    stop = %{
      post
      | "id" => "2",
        "text" => "Stop replying to me.",
        "author" => "bob.test",
        "author_id" => "did:plc:bob"
    }

    client = %TestClient{identity: @did, posts: [post, stop], published: published}
    runner = Runner.new(client, dir, "bluesky", %{}, ai: ChorusDraft.TestAI, interactive: false)
    stream = Jetstream.subscription(@did)
    assert Jetstream.decode(event(mention()), @did) == :activity
    Jetstream.notify(stream)
    assert Jetstream.wait(stream, 0) == :activity
    capture_io(fn -> Runner.mentions(runner) end)
    assert_receive {:ai_context, context}
    refute Jason.encode!(context) =~ "UNTRUSTED STREAM BODY"
    assert context["post"] == "Canonical API post"
    assert Store.blocked?(dir, "bob.test")
    assert [%{"status" => "pending"}] = Store.drafts(dir)
    capture_io(fn -> Runner.mentions(runner) end)
    assert length(Store.drafts(dir)) == 1
    assert Agent.get(published, & &1) == []
  end

  test "real WebSocket handshake, frame delivery, and reconnect work against a local fixture" do
    {:ok, listener} =
      :gen_tcp.listen(0, [:binary, active: false, reuseaddr: true, ip: {127, 0, 0, 1}])

    {:ok, {_, port}} = :inet.sockname(listener)
    owner = self()
    {:ok, server} = Task.start(fn -> serve(listener, owner) end)
    stream = Jetstream.subscription(@did)

    {:ok, socket} = Socket.start_link(url: "ws://127.0.0.1:#{port}", stream: stream)
    Process.unlink(socket)

    on_exit(fn ->
      Process.exit(socket, :kill)
      Process.exit(server, :kill)
      :gen_tcp.close(listener)
    end)

    assert_receive {:connected, request}, 2_000
    assert request =~ "Sec-WebSocket-Protocol: xrpc.v1.json"
    refute request =~ "Authorization"
    assert Jetstream.wait(stream, 2_000) == :activity
    send(server, {:frame, event(mention())})
    assert Jetstream.wait(stream, 2_000) == :activity
    send(server, :disconnect)
    assert_receive {:connected, _}, 8_000
    assert Jetstream.wait(stream, 2_000) == :activity
    assert Process.alive?(socket)
  end

  defp serve(listener, owner) do
    {:ok, socket} = :gen_tcp.accept(listener)
    request = read_headers(socket, "")
    [_, key] = Regex.run(~r/Sec-WebSocket-Key: ([^\r]+)\r/i, request)
    accept = :crypto.hash(:sha, key <> "258EAFA5-E914-47DA-95CA-C5AB0DC85B11") |> Base.encode64()

    :ok =
      :gen_tcp.send(
        socket,
        "HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: #{accept}\r\nSec-WebSocket-Protocol: xrpc.v1.json\r\n\r\n"
      )

    send(owner, {:connected, request})
    serve_frames(socket)
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

  defp serve_frames(socket) do
    receive do
      {:frame, frame} ->
        size = byte_size(frame)
        header = if size < 126, do: <<0x81, size>>, else: <<0x81, 126, size::16>>
        :ok = :gen_tcp.send(socket, header <> frame)
        serve_frames(socket)

      :disconnect ->
        :gen_tcp.close(socket)
    end
  end
end
