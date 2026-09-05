defmodule ChorusDraft.Clients.Mastodon do
  alias ChorusDraft.{Config, Error, HTTP, Safety}

  @mention ~r/(?<![=\/\p{L}\p{N}_])@([a-z0-9_]+(?:[.-]+[a-z0-9_]+)*(?:@[\p{L}\p{N}_]+(?:[.-]+[\p{L}\p{N}_]+)*)?)/iu
  defstruct [:base, :headers, :http, :identity]

  def new(env, opts \\ []) do
    http = Keyword.get(opts, :http, HTTP)
    base = env |> Config.required("MASTODON_API_BASE_URL") |> String.trim_trailing("/")
    uri = http.validate_url!(base)

    unless uri.path in [nil, "", "/"] and is_nil(uri.query) do
      raise Error, "Mastodon URL must be an HTTPS origin."
    end

    %__MODULE__{
      base: base,
      headers: %{"Authorization" => "Bearer #{Config.required(env, "MASTODON_ACCESS_TOKEN")}"},
      http: http
    }
  end

  def login(client) do
    identity = call(client, :get, "/api/v1/accounts/verify_credentials")["id"]
    if is_nil(identity), do: raise(Error, "Missing account identity.")
    %{client | identity: identity}
  end

  def identity(client), do: client.identity
  def limit(_client), do: 500
  def account_key(client), do: "#{client.base}:#{client.identity}"

  def mentioned_actors(_client, text) do
    @mention
    |> Regex.scan(to_string_or_empty(text), capture: :all_but_first)
    |> List.flatten()
    |> Enum.map(&Safety.actor_key/1)
    |> Enum.uniq()
  end

  def actor_aliases(client, actor) do
    key = Safety.actor_key(actor)
    domain = URI.parse(client.base).host |> String.downcase()

    cond do
      key == "" -> []
      not String.contains?(key, "@") -> [key, "#{key}@#{domain}"]
      String.ends_with?(key, "@#{domain}") -> [key, String.trim_trailing(key, "@#{domain}")]
      true -> [key]
    end
  end

  def get_post(client, id) do
    unless Regex.match?(~r/^\d+$/, to_string(id)),
      do: raise(Error, "Use a numeric Mastodon status ID.")

    client |> call(:get, "/api/v1/statuses/#{id}") |> normalize()
  end

  def notifications(client) do
    client
    |> call(:get, "/api/v1/notifications", query: %{"types[]" => "mention", "limit" => 30})
    |> Enum.filter(&(&1["type"] == "mention" and is_map(&1["status"])))
    |> Enum.map(&normalize(&1["status"]))
  end

  def search(client, query, limit \\ 20) do
    client
    |> call(:get, "/api/v2/search", query: %{"q" => query, "type" => "statuses", "limit" => limit})
    |> Map.get("statuses", [])
    |> Enum.map(&normalize/1)
  end

  def timeline(client, limit \\ 20) do
    client
    |> call(:get, "/api/v1/timelines/public", query: %{"limit" => limit})
    |> Enum.map(&normalize/1)
  end

  def recent(client, limit \\ 12) do
    unless Regex.match?(~r/^\d+$/, to_string(client.identity)),
      do: raise(Error, "Invalid account identity.")

    client
    |> call(:get, "/api/v1/accounts/#{client.identity}/statuses",
      query: %{"limit" => limit, "exclude_replies" => true, "exclude_reblogs" => true}
    )
    |> Enum.map(&normalize/1)
  end

  def feed(client, account, limit \\ 8) do
    id =
      call(client, :get, "/api/v1/accounts/lookup", query: %{"acct" => account})
      |> Map.fetch!("id")

    unless Regex.match?(~r/^\d+$/, to_string(id)), do: raise(Error, "Invalid account ID.")

    client
    |> call(:get, "/api/v1/accounts/#{id}/statuses",
      query: %{"limit" => limit, "exclude_reblogs" => true}
    )
    |> Enum.map(&normalize/1)
  end

  def context(client, post) do
    id = Map.fetch!(post, "id")
    unless Regex.match?(~r/^\d+$/, id), do: raise(Error, "Invalid status ID.")

    client
    |> call(:get, "/api/v1/statuses/#{id}/context")
    |> Map.get("ancestors", [])
    |> Enum.map(&normalize/1)
    |> Enum.filter(&Safety.eligible?/1)
    |> Enum.take(-5)
  end

  def publish(client, draft) do
    Safety.validate_text!(Map.fetch!(draft, "text"), limit(client))

    if to_string_or_empty(draft["cw"]) != "",
      do: Safety.validate_text!(draft["cw"], limit(client))

    visibility = Map.get(draft, "visibility", "public")

    unless visibility in ["public", "unlisted", "private", "direct"],
      do: raise(Error, "Invalid visibility.")

    visibility =
      if draft["reply_to"] do
        parent = get_post(client, draft["reply_to"])
        unless Safety.public?(parent), do: raise(Error, "Restricted replies are disabled.")

        if parent["visibility"] == "unlisted" and visibility == "public",
          do: "unlisted",
          else: visibility
      else
        visibility
      end

    if draft["quote_to"] && not Safety.public?(get_post(client, draft["quote_to"])) do
      raise Error, "Quoted source is no longer public."
    end

    body = %{
      "status" => draft["text"],
      "visibility" => visibility,
      "language" => Map.get(draft, "language", "en")
    }

    body =
      if draft["reply_to"], do: Map.put(body, "in_reply_to_id", draft["reply_to"]), else: body

    body = if draft["cw"], do: Map.put(body, "spoiler_text", draft["cw"]), else: body

    call(client, :post, "/api/v1/statuses",
      body: body,
      headers: %{"Idempotency-Key" => Map.fetch!(draft, "id")}
    )
  end

  def delete(client, id) do
    post = get_post(client, id)

    unless post["author_id"] == client.identity,
      do: raise(Error, "Can only delete your own posts.")

    call(client, :delete, "/api/v1/statuses/#{id}")
  end

  def normalize(status) do
    public? = status["visibility"] in ["public", "unlisted"]

    %{
      "id" => status["id"],
      "text" => if(public?, do: status |> Map.get("content", "") |> strip_html(), else: ""),
      "visibility" => status["visibility"],
      "author" => get_in(status, ["account", "acct"]),
      "author_id" => get_in(status, ["account", "id"]),
      "url" => if(public?, do: status["url"]),
      "cw" => if(public?, do: status["spoiler_text"]),
      "parent" => status["in_reply_to_id"]
    }
  end

  defp call(client, method, path, opts \\ []) do
    extra = Keyword.get(opts, :headers, %{})

    client.http.request(
      method,
      client.base <> path,
      Keyword.put(opts, :headers, Map.merge(client.headers, extra))
    )
  end

  defp strip_html(text) do
    text
    |> String.replace(~r/<[^>]*>/u, " ")
    |> String.replace(~r/&(?:amp|lt|gt|quot|apos|nbsp|#[0-9]+|#[xX][0-9a-fA-F]+);/, &decode_entity/1)
    |> String.trim()
  end

  defp decode_entity(entity) do
    named = %{"&amp;" => "&", "&lt;" => "<", "&gt;" => ">", "&quot;" => "\"", "&apos;" => "'", "&nbsp;" => " "}
    case named[entity] do
      nil ->
        digits = entity |> String.trim_leading("&#") |> String.trim_trailing(";")
        {digits, base} = if String.starts_with?(String.downcase(digits), "x"), do: {String.slice(digits, 1..-1//1), 16}, else: {digits, 10}
        case Integer.parse(digits, base) do
          {code, ""} when code in 0..0x10FFFF and code not in 0xD800..0xDFFF -> <<code::utf8>>
          _ -> entity
        end
      decoded -> decoded
    end
  end

  defp to_string_or_empty(nil), do: ""
  defp to_string_or_empty(value) when is_binary(value), do: value
  defp to_string_or_empty(value), do: to_string(value)
end
