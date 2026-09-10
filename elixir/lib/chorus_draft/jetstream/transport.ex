defmodule ChorusDraft.Jetstream.Transport do
  @moduledoc false
  alias ChorusDraft.{Error, Jetstream}
  alias ChorusDraft.Jetstream.Socket
  alias WebSockex.{Conn, Frame}

  @max_message 1_048_576
  @max_headers 16_384
  @max_fragments 1024
  @read_timeout 10_000
  @heartbeat 30_000
  @idle_timeout 90_000
  @stable_session 30_000
  @guid "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"

  # The socket stays passive. Read lengths before payloads, and never hand an
  # unbounded network buffer to the WebSocket parser or a process mailbox.
  def start_link(conn, stream), do: Task.start_link(fn -> reconnect(conn, stream, 0) end)

  # A session that drops right after the handshake counts as a failure, so a
  # server that accepts and closes cannot hold the client in a one-second loop.
  defp reconnect(conn, stream, attempt) do
    started = now()
    stable? = session(conn, stream) and now() - started >= @stable_session
    Process.sleep(Socket.reconnect_delay(if stable?, do: 0, else: attempt))
    reconnect(conn, stream, if(stable?, do: 1, else: min(attempt + 1, 5)))
  end

  defp session(conn, stream) do
    case Conn.open_socket(conn) do
      {:ok, conn} ->
        try do
          handshake!(conn)
          Jetstream.notify(stream)

          try do
            loop(conn, stream, %{last_frame: now(), next_ping: now() + @heartbeat}, nil)
          rescue
            _ -> :ok
          end

          true
        rescue
          _ -> false
        after
          Conn.close_socket(conn)
        end

      {:error, _} ->
        false
    end
  end

  defp handshake!(conn) do
    key = :crypto.strong_rand_bytes(16) |> Base.encode64()
    {:ok, request} = Conn.build_request(conn, key)
    :ok = Conn.socket_send(conn, request)
    :ok = setopts(conn, packet: :http_bin, packet_size: @max_headers)
    deadline = now() + @read_timeout
    {:http_response, _, 101, _} = recv!(conn, 0, deadline)
    headers = headers!(conn, deadline, [], 0)
    expected = :crypto.hash(:sha, key <> @guid) |> Base.encode64()

    unless headers["sec-websocket-accept"] == [expected] and
             headers["sec-websocket-protocol"] == ["xrpc.v1.json"] and
             tokens(headers["upgrade"]) == ["websocket"] and
             "upgrade" in tokens(headers["connection"]) and
             not Map.has_key?(headers, "sec-websocket-extensions") do
      raise Error, "Jetstream handshake failed."
    end

    :ok = setopts(conn, packet: :raw)
  end

  defp headers!(conn, deadline, headers, size) do
    case recv!(conn, 0, deadline) do
      :http_eoh ->
        Map.new(Enum.group_by(headers, &elem(&1, 0), &elem(&1, 1)))

      {:http_header, _, key, _, value} ->
        key = key |> to_string() |> String.downcase()
        size = size + byte_size(key) + byte_size(value) + 4
        if size > @max_headers, do: raise(Error, "Jetstream headers exceeded size limit.")
        headers!(conn, deadline, [{key, value} | headers], size)

      _ ->
        raise Error, "Invalid Jetstream handshake."
    end
  end

  defp tokens(nil), do: []

  defp tokens(values) do
    values |> Enum.join(",") |> String.downcase() |> String.split(",") |> Enum.map(&String.trim/1)
  end

  defp loop(conn, stream, clock, fragment) do
    {first, clock} = first_byte!(conn, clock, fragment)
    deadline = now() + @read_timeout
    deadline = if fragment, do: min(deadline, fragment.deadline), else: deadline
    <<fin::1, reserved::3, opcode::4>> = first
    <<masked::1, short_length::7>> = recv!(conn, 1, deadline)

    unless reserved == 0 and masked == 0 and opcode in [0, 1, 2, 8, 9, 10],
      do: raise(Error, "Invalid Jetstream frame.")

    {length, extension} = length!(conn, short_length, deadline)
    validate_length!(fin, opcode, length, fragment)
    payload = if length == 0, do: "", else: recv!(conn, length, deadline)
    {:ok, frame, ""} = Frame.parse_frame(first <> <<short_length>> <> extension <> payload)
    fragment = accept_frame!(conn, stream, frame, fragment)
    loop(conn, stream, %{clock | last_frame: now()}, fragment)
  end

  defp length!(conn, 126, deadline) do
    <<length::16>> = extension = recv!(conn, 2, deadline)
    if length < 126, do: raise(Error, "Invalid Jetstream frame length.")
    {length, extension}
  end

  defp length!(conn, 127, deadline) do
    <<0::1, length::63>> = extension = recv!(conn, 8, deadline)
    if length < 65_536, do: raise(Error, "Invalid Jetstream frame length.")
    {length, extension}
  end

  defp length!(_conn, length, _deadline), do: {length, ""}

  defp validate_length!(fin, opcode, length, fragment) do
    cond do
      opcode >= 8 ->
        unless fin == 1 and length <= 125, do: raise(Error, "Invalid Jetstream control frame.")

      opcode == 0 ->
        unless fragment && fragment.size + length <= @max_message and
                 fragment.count < @max_fragments,
               do: raise(Error, "Jetstream fragmented message exceeded limits.")

      true ->
        unless is_nil(fragment) and length <= @max_message,
          do: raise(Error, "Jetstream message exceeded limits.")
    end
  end

  defp accept_frame!(_conn, stream, {:text, text}, nil) do
    notify!(stream, text)
    nil
  end

  defp accept_frame!(_conn, _stream, {:binary, _}, nil), do: nil

  defp accept_frame!(_conn, _stream, {:fragment, type, part}, nil) do
    %{type: type, parts: [part], size: byte_size(part), count: 1, deadline: now() + @idle_timeout}
  end

  defp accept_frame!(_conn, _stream, {:continuation, part}, fragment) do
    %{
      fragment
      | parts: [part | fragment.parts],
        size: fragment.size + byte_size(part),
        count: fragment.count + 1
    }
  end

  defp accept_frame!(_conn, stream, {:finish, part}, fragment) do
    if fragment.type == :text do
      text = [part | fragment.parts] |> Enum.reverse() |> IO.iodata_to_binary()
      unless String.valid?(text), do: raise(Error, "Invalid Jetstream text.")
      notify!(stream, text)
    end

    nil
  end

  defp accept_frame!(conn, _stream, :ping, fragment) do
    send_frame!(conn, :pong)
    fragment
  end

  defp accept_frame!(conn, _stream, {:ping, data}, fragment) do
    send_frame!(conn, {:pong, data})
    fragment
  end

  defp accept_frame!(_conn, _stream, frame, fragment)
       when frame == :pong or elem(frame, 0) == :pong,
       do: fragment

  defp accept_frame!(conn, _stream, frame, _fragment)
       when frame == :close or elem(frame, 0) == :close do
    send_frame!(conn, :close)
    raise Error, "Jetstream closed."
  end

  defp notify!(stream, text) do
    case Jetstream.decode(text, stream.did) do
      :activity -> Jetstream.notify(stream)
      :ignore -> :ok
      :reconnect -> raise Error, "Jetstream requested reconnect."
    end
  end

  defp first_byte!(conn, clock, fragment) do
    if now() >= clock.last_frame + @idle_timeout or (fragment && now() >= fragment.deadline),
      do: raise(Error, "Jetstream timed out.")

    clock =
      if now() >= clock.next_ping do
        send_frame!(conn, :ping)
        %{clock | next_ping: now() + @heartbeat}
      else
        clock
      end

    deadline = min(clock.next_ping, clock.last_frame + @idle_timeout)
    deadline = if fragment, do: min(deadline, fragment.deadline), else: deadline
    timeout = max(deadline - now(), 0)

    case conn.conn_mod.recv(conn.socket, 1, timeout) do
      {:ok, byte} ->
        {byte, clock}

      {:error, :timeout} ->
        if now() >= clock.last_frame + @idle_timeout or (fragment && now() >= fragment.deadline),
          do: raise(Error, "Jetstream timed out.")

        send_frame!(conn, :ping)
        first_byte!(conn, %{clock | next_ping: now() + @heartbeat}, fragment)

      _ ->
        raise Error, "Jetstream receive failed."
    end
  end

  defp send_frame!(conn, frame) do
    {:ok, data} = Frame.encode_frame(frame)
    :ok = Conn.socket_send(conn, data)
  end

  defp recv!(conn, length, deadline) do
    timeout = deadline - now()
    if timeout <= 0, do: raise(Error, "Jetstream receive timed out.")
    {:ok, data} = conn.conn_mod.recv(conn.socket, length, timeout)
    data
  end

  defp setopts(%{conn_mod: :ssl, socket: socket}, opts), do: :ssl.setopts(socket, opts)
  defp setopts(%{socket: socket}, opts), do: :inet.setopts(socket, opts)
  defp now, do: System.monotonic_time(:millisecond)
end
