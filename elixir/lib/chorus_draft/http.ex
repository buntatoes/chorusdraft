defmodule ChorusDraft.HTTP do
  alias ChorusDraft.{Error, HTTPError}

  @max_bytes 4 * 1024 * 1024
  @loopback ["localhost", "127.0.0.1", "::1"]

  def validate_url!(url, opts \\ []) do
    uri = URI.parse(url)
    local? = Keyword.get(opts, :local, false)

    allowed_scheme? =
      uri.scheme == "https" or (local? and uri.scheme == "http" and uri.host in @loopback)

    if not allowed_scheme? or is_nil(uri.host) or uri.host == "" or not is_nil(uri.userinfo) or
         not is_nil(uri.fragment) do
      raise Error, "Use HTTPS; HTTP is allowed only for a loopback local AI server."
    end

    uri
  rescue
    _ in URI.Error -> raise Error, "Invalid endpoint URL."
  end

  def request(method, url, opts \\ []) do
    uri = validate_url!(url, local: Keyword.get(opts, :local, false))
    if uri.query, do: raise(Error, "Endpoint must not contain a query string.")

    query = Keyword.get(opts, :query, %{})
    uri = if map_size(Map.new(query)) > 0, do: %{uri | query: URI.encode_query(query)}, else: uri

    headers = [
      {"accept", "application/json"}
      | Enum.map(Keyword.get(opts, :headers, %{}), fn {k, v} -> {to_string(k), to_string(v)} end)
    ]

    body = Keyword.get(opts, :body)
    headers = if body, do: [{"content-type", "application/json"} | headers], else: headers
    body = if body, do: Jason.encode!(body)

    path =
      if(uri.path in [nil, ""], do: "/", else: uri.path) <>
        if(uri.query, do: "?" <> uri.query, else: "")

    scheme = if uri.scheme == "https", do: :https, else: :http
    transport = [timeout: 10_000, send_timeout: 30_000] ++ ssl_options(uri)

    {:ok, conn} =
      Mint.HTTP.connect(scheme, uri.host, uri.port,
        mode: :passive,
        protocols: [:http1],
        log: false,
        max_header_list_size: 16_384,
        transport_opts: transport
      )

    try do
      {:ok, conn, ref} =
        Mint.HTTP.request(conn, method |> to_string() |> String.upcase(), path, headers, body)

      response = receive_body(conn, ref, System.monotonic_time(:millisecond) + 45_000, [], 0)
      if response == "", do: %{}, else: Jason.decode!(response)
    after
      Mint.HTTP.close(conn)
    end
  rescue
    error in [Error, HTTPError] ->
      raise error

    _ ->
      raise Error,
            "Network or response decoding failure; details omitted to protect credentials and content."
  end

  # One connection and one request. Never follow redirects or retry writes.
  defp receive_body(conn, ref, deadline, chunks, size) do
    timeout = deadline - System.monotonic_time(:millisecond)
    if timeout <= 0, do: raise(Error, "Network request timed out.")
    {:ok, conn, responses} = Mint.HTTP.recv(conn, 0, timeout)

    {chunks, size, done} =
      Enum.reduce(responses, {chunks, size, false}, fn
        {:status, ^ref, status}, acc when status in 100..299 ->
          acc

        {:status, ^ref, status}, _ ->
          raise HTTPError, status

        {:headers, ^ref, headers}, acc ->
          Enum.each(headers, fn
            {"content-length", value} ->
              case Integer.parse(value) do
                {length, ""} when length > @max_bytes ->
                  raise Error, "Remote response exceeded size limit."

                _ ->
                  :ok
              end

            _ ->
              :ok
          end)

          acc

        {:data, ^ref, data}, {chunks, size, done} ->
          size = size + byte_size(data)
          if size > @max_bytes, do: raise(Error, "Remote response exceeded size limit.")
          {[data | chunks], size, done}

        {:done, ^ref}, {chunks, size, _} ->
          {chunks, size, true}

        {:error, ^ref, _}, _ ->
          raise Error, "Network response failed."

        _, acc ->
          acc
      end)

    if done,
      do: chunks |> Enum.reverse() |> IO.iodata_to_binary(),
      else: receive_body(conn, ref, deadline, chunks, size)
  end

  defp ssl_options(%URI{scheme: "https", host: host}) do
    [
      verify: :verify_peer,
      cacerts: :public_key.cacerts_get(),
      depth: 10,
      server_name_indication: String.to_charlist(host),
      customize_hostname_check: [match_fun: :public_key.pkix_verify_hostname_match_fun(:https)]
    ]
  end

  defp ssl_options(_), do: []
end
