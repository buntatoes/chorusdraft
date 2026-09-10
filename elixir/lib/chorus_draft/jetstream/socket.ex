defmodule ChorusDraft.Jetstream.Socket do
  @moduledoc false
  alias ChorusDraft.Jetstream.Transport

  def start_link(options) do
    uri = URI.parse(Keyword.fetch!(options, :url))
    conn = WebSockex.Conn.new(uri, connection_options(uri))

    Transport.start_link(
      conn,
      Keyword.fetch!(options, :stream),
      Keyword.take(options, [:heartbeat, :read_timeout])
    )
  end

  def connection_options(uri) do
    [
      extra_headers: [{"Sec-WebSocket-Protocol", "xrpc.v1.json"}],
      insecure: false,
      socket_connect_timeout: 10_000,
      socket_recv_timeout: 10_000,
      socket_options: [send_timeout: 10_000, send_timeout_close: true],
      ssl_options: [
        verify: :verify_peer,
        cacerts: :public_key.cacerts_get(),
        depth: 10,
        send_timeout: 10_000,
        send_timeout_close: true,
        server_name_indication: String.to_charlist(uri.host),
        customize_hostname_check: [match_fun: :public_key.pkix_verify_hostname_match_fun(:https)]
      ]
    ]
  end

  def reconnect_delay(attempt) do
    min(1_000 * Integer.pow(2, min(max(attempt, 0), 5)), 30_000) + :rand.uniform(250)
  end
end
