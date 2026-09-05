defmodule ChorusDraft.Jetstream.Socket do
  @moduledoc false
  use WebSockex
  alias ChorusDraft.{Error, Jetstream}

  @heartbeat 30_000
  @idle_timeout 90_000

  def start_link(options) do
    uri = URI.parse(Keyword.fetch!(options, :url))

    state = %{
      stream: Keyword.fetch!(options, :stream),
      attempts: 0,
      timer: nil,
      last_frame: now()
    }

    WebSockex.start_link(
      URI.to_string(uri),
      __MODULE__,
      state,
      connection_options(uri) ++ [async: true, handle_initial_conn_failure: true]
    )
  end

  def connection_options(uri) do
    [
      extra_headers: [{"Sec-WebSocket-Protocol", "xrpc.v1.json"}],
      insecure: false,
      socket_connect_timeout: 10_000,
      socket_recv_timeout: 10_000,
      ssl_options: [
        verify: :verify_peer,
        cacerts: :public_key.cacerts_get(),
        depth: 10,
        server_name_indication: String.to_charlist(uri.host),
        customize_hostname_check: [match_fun: :public_key.pkix_verify_hostname_match_fun(:https)]
      ]
    ]
  end

  @impl true
  def handle_connect(conn, state) do
    unless Enum.any?(conn.resp_headers, fn {key, value} ->
             String.downcase(to_string(key)) == "sec-websocket-protocol" and
               value == "xrpc.v1.json"
           end) do
      raise Error, "Jetstream did not negotiate the JSON subprotocol."
    end

    # Reconcile immediately after each connection; no stream cursor is claimed.
    Jetstream.notify(state.stream)
    {:ok, arm_timer(%{state | attempts: 0, last_frame: now()})}
  end

  @impl true
  def handle_frame({:text, frame}, state) do
    state = %{state | last_frame: now()}

    case Jetstream.decode(frame, state.stream.did) do
      :activity ->
        Jetstream.notify(state.stream)
        {:ok, state}

      :reconnect ->
        {:close, {1011, "Stream error"}, state}

      :ignore ->
        {:ok, state}
    end
  end

  def handle_frame(_, state), do: {:ok, state}

  @impl true
  def handle_ping(:ping, state), do: {:reply, :pong, %{state | last_frame: now()}}

  def handle_ping({:ping, payload}, state),
    do: {:reply, {:pong, payload}, %{state | last_frame: now()}}

  @impl true
  def handle_pong(_, state), do: {:ok, %{state | last_frame: now()}}

  @impl true
  def handle_info(:heartbeat, state) do
    if now() - state.last_frame >= @idle_timeout do
      {:close, {1001, "Idle stream"}, %{state | timer: nil}}
    else
      {:reply, :ping, arm_timer(%{state | timer: nil})}
    end
  end

  def handle_info(_, state), do: {:ok, state}

  @impl true
  def handle_disconnect(_status, state) do
    cancel_timer(state.timer)
    # Socket state contains no platform credentials or received post bodies.
    Process.sleep(reconnect_delay(state.attempts))
    {:reconnect, %{state | attempts: min(state.attempts + 1, 5), timer: nil}}
  end

  def reconnect_delay(attempt) do
    min(1_000 * Integer.pow(2, min(max(attempt, 0), 5)), 30_000) + :rand.uniform(250)
  end

  @impl true
  def terminate(_reason, state) do
    cancel_timer(state.timer)
    :ok
  end

  @impl true
  def format_status(_reason, _status), do: [data: [{~c"State", "Jetstream connection"}]]

  defp now, do: System.monotonic_time(:millisecond)

  defp arm_timer(state) do
    cancel_timer(state.timer)
    %{state | timer: Process.send_after(self(), :heartbeat, @heartbeat)}
  end

  defp cancel_timer(nil), do: :ok

  defp cancel_timer(timer) do
    Process.cancel_timer(timer)

    receive do
      :heartbeat -> :ok
    after
      0 -> :ok
    end
  end
end
