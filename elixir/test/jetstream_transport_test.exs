defmodule ChorusDraft.JetstreamTransportTest do
  use ExUnit.Case, async: true
  alias ChorusDraft.Jetstream
  alias ChorusDraft.Jetstream.Socket

  defp connect(extra_headers \\ "", accept_override \\ nil, opts \\ []) do
    {:ok, listener} = :gen_tcp.listen(0, [:binary, active: false, ip: {127, 0, 0, 1}])
    {:ok, port} = :inet.port(listener)
    stream = Jetstream.subscription("did:plc:me")

    {:ok, client} =
      Socket.start_link([url: "ws://127.0.0.1:#{port}/", stream: stream] ++ opts)

    Process.unlink(client)

    on_exit(fn ->
      Process.exit(client, :kill)
      :gen_tcp.close(listener)
    end)

    {:ok, socket} = :gen_tcp.accept(listener, 2_000)
    on_exit(fn -> :gen_tcp.close(socket) end)
    request = read_headers(socket, "")
    [_, key] = Regex.run(~r/Sec-WebSocket-Key: ([^\r]+)\r/i, request)

    accept =
      accept_override ||
        Base.encode64(:crypto.hash(:sha, key <> "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"))

    :ok =
      :gen_tcp.send(
        socket,
        "HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n" <>
          "Sec-WebSocket-Accept: #{accept}\r\nSec-WebSocket-Protocol: xrpc.v1.json\r\n" <>
          extra_headers <> "\r\n"
      )

    {socket, stream, client}
  end

  defp read_headers(socket, buffer) do
    if String.contains?(buffer, "\r\n\r\n") do
      buffer
    else
      {:ok, data} = :gen_tcp.recv(socket, 0, 2_000)
      read_headers(socket, buffer <> data)
    end
  end

  defp frame(first, payload) do
    length = byte_size(payload)

    cond do
      length < 126 -> <<first, length>> <> payload
      length < 65_536 -> <<first, 126, length::16>> <> payload
      true -> <<first, 127, length::64>> <> payload
    end
  end

  test "an oversized declared frame closes before its payload is sent" do
    {socket, stream, client} = connect()
    assert Jetstream.wait(stream, 2_000) == :activity
    :ok = :gen_tcp.send(socket, <<0x81, 127, 1_048_577::64>>)
    assert :gen_tcp.recv(socket, 0, 2_000) == {:error, :closed}
    assert Process.alive?(client)
    assert Jetstream.wait(stream, 0) == :timeout
  end

  test "a partial frame cannot hold the receive loop indefinitely" do
    {socket, stream, _} = connect("", nil, read_timeout: 500)
    assert Jetstream.wait(stream, 2_000) == :activity
    :ok = :gen_tcp.send(socket, <<0x81>>)
    assert :gen_tcp.recv(socket, 0, 3_000) == {:error, :closed}
  end

  test "an idle healthy connection receives masked heartbeats and accepts a pong" do
    {socket, stream, client} = connect("", nil, heartbeat: 1_500)
    assert Jetstream.wait(stream, 2_000) == :activity
    assert {:ok, <<0x89, 0x80, _mask::32>>} = :gen_tcp.recv(socket, 6, 5_000)
    :ok = :gen_tcp.send(socket, <<0x8A, 0, 0x89, 0>>)
    assert {:ok, <<0x8A, 0x80, _mask::32>>} = :gen_tcp.recv(socket, 6, 2_000)
    assert Process.alive?(client)
  end

  test "fragment lengths are added before receiving a continuation payload" do
    {socket, stream, _} = connect()
    assert Jetstream.wait(stream, 2_000) == :activity
    :ok = :gen_tcp.send(socket, frame(0x01, String.duplicate("x", 1_048_576)))
    :ok = :gen_tcp.send(socket, <<0x80, 1>>)
    assert :gen_tcp.recv(socket, 0, 2_000) == {:error, :closed}
    assert Jetstream.wait(stream, 0) == :timeout
  end

  test "empty fragments cannot accumulate without bound" do
    {socket, stream, _} = connect()
    assert Jetstream.wait(stream, 2_000) == :activity
    :ok = :gen_tcp.send(socket, <<0x01, 0>> <> :binary.copy(<<0, 0>>, 1024))
    assert :gen_tcp.recv(socket, 0, 2_000) == {:error, :closed}
  end

  test "valid fragmented messages allow intervening ping and only notify on completion" do
    {socket, stream, _} = connect()
    assert Jetstream.wait(stream, 2_000) == :activity

    event =
      Jason.encode!(%{
        "$type" => "message",
        "payload" => %{
          "$type" => "network.bsky.jetstream.subscribeEvents#commit",
          "operation" => "create",
          "collection" => "app.bsky.feed.post",
          "did" => "did:plc:other",
          "record" => %{
            "reply" => %{"parent" => %{"uri" => "at://did:plc:me/app.bsky.feed.post/x"}}
          }
        }
      })

    {first, last} = String.split_at(event, 25)
    :ok = :gen_tcp.send(socket, frame(0x01, first) <> frame(0x89, "hi"))
    # A client pong must be masked and echo the payload.
    {:ok, <<0x8A, 0x82, a, b, _, _, x, y>>} = :gen_tcp.recv(socket, 8, 2_000)
    assert <<Bitwise.bxor(a, x), Bitwise.bxor(b, y)>> == "hi"
    assert Jetstream.wait(stream, 0) == :timeout
    :ok = :gen_tcp.send(socket, frame(0x80, last))
    assert Jetstream.wait(stream, 2_000) == :activity
  end

  test "oversized and malformed handshakes never trigger reconciliation" do
    for {headers, accept} <- [
          {"X-Large: " <> String.duplicate("x", 17_000) <> "\r\n", nil},
          {:binary.copy("X-Small: abcdefghijklmnop\r\n", 1000), nil},
          {"Sec-WebSocket-Extensions: permessage-deflate\r\n", nil},
          {"", "wrong-challenge"}
        ] do
      {socket, stream, client} = connect(headers, accept)
      assert :gen_tcp.recv(socket, 0, 2_000) == {:error, :closed}
      assert Jetstream.wait(stream, 0) == :timeout
      Process.exit(client, :kill)
    end
  end

  test "invalid frame headers are refused without waiting for payloads" do
    for header <- [<<0x81, 0x80>>, <<0x89, 126, 126::16>>, <<0x80, 1>>, <<0xC1, 1>>] do
      {socket, stream, client} = connect()
      assert Jetstream.wait(stream, 2_000) == :activity
      :ok = :gen_tcp.send(socket, header)
      assert :gen_tcp.recv(socket, 0, 2_000) == {:error, :closed}
      Process.exit(client, :kill)
    end
  end
end
