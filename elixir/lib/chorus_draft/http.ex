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
    headers = [{~c"accept", ~c"application/json"} | header_list(Keyword.get(opts, :headers, %{}))]
    body = Keyword.get(opts, :body)
    request = build_request(uri, headers, body)
    ssl = ssl_options(uri)
    http_opts = [timeout: 45_000, connect_timeout: 10_000, ssl: ssl, autoredirect: false]

    case :httpc.request(method, request, http_opts, body_format: :binary) do
      {:ok, {{_, status, _}, _response_headers, response}} when status in 200..299 ->
        if byte_size(response) > @max_bytes,
          do: raise(Error, "Remote response exceeded size limit.")

        if response == "", do: %{}, else: Jason.decode!(response)

      {:ok, {{_, status, _}, _, _}} ->
        raise HTTPError, status

      {:error, _} ->
        raise Error,
              "Network or response decoding failure; details omitted to protect credentials and content."
    end
  rescue
    error in [Error, HTTPError] ->
      raise error

    _ ->
      raise Error,
            "Network or response decoding failure; details omitted to protect credentials and content."
  end

  defp build_request(uri, headers, nil),
    do: {uri |> URI.to_string() |> String.to_charlist(), headers}

  defp build_request(uri, headers, body) do
    headers = [{~c"content-type", ~c"application/json"} | headers]

    {uri |> URI.to_string() |> String.to_charlist(), headers, ~c"application/json",
     Jason.encode!(body)}
  end

  defp header_list(headers) do
    Enum.map(headers, fn {key, value} ->
      {key |> to_string() |> String.to_charlist(), value |> to_string() |> String.to_charlist()}
    end)
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
