defmodule ChorusDraft.Clients.Bluesky do
  alias ChorusDraft.{Config, Error, HTTP, HTTPError, Safety}

  @facet ~r/https:\/\/[^\s<>]+|(?<![\w@])@[a-zA-Z0-9][a-zA-Z0-9.-]*\.[a-zA-Z]{2,}|(?<!\w)#[\p{L}\p{N}_]+/u
  @uri ~r/\Aat:\/\/[^\/\s]+\/app\.bsky\.feed\.post\/[a-zA-Z0-9._~:-]+\z/
  # bsky.social is an entryway. app.bsky.* lives on the AppView; com.atproto.*
  # after login must use the account PDS from the session DID document.
  @appview "https://public.api.bsky.app"
  defstruct [:base, :pds, :env, :http, :identity, :session]

  def new(env, opts \\ []) do
    http = Keyword.get(opts, :http, HTTP)
    base = env |> Map.get("BLUESKY_PDS_URL", "https://bsky.social") |> String.trim_trailing("/")
    uri = http.validate_url!(base)

    unless uri.path in [nil, "", "/"] and is_nil(uri.query) do
      raise Error, "Bluesky PDS URL must be an HTTPS origin."
    end

    {:ok, session} = Agent.start_link(fn -> %{token: nil, refresh: nil} end)
    %__MODULE__{base: base, pds: base, env: env, http: http, session: session}
  end

  def login(client) do
    response =
      client.http.request(:post, "#{client.base}/xrpc/com.atproto.server.createSession",
        body: %{
          "identifier" => Config.required(client.env, "BLUESKY_HANDLE"),
          "password" => Config.required(client.env, "BLUESKY_APP_PASSWORD")
        }
      )

    identity = Map.fetch!(response, "did")

    Agent.update(client.session, fn _ ->
      %{token: Map.fetch!(response, "accessJwt"), refresh: Map.fetch!(response, "refreshJwt")}
    end)

    %{client | identity: identity, pds: pds_endpoint(client, response)}
  end

  def identity(client), do: client.identity
  def limit(_client), do: 300
  def account_key(client), do: "#{client.base}:#{client.identity}"
  def actor_aliases(_client, actor), do: [Safety.actor_key(actor)]

  def mentioned_actors(_client, text) do
    @facet
    |> Regex.scan(to_string_or_empty(text))
    |> List.flatten()
    |> Enum.filter(&String.starts_with?(&1, "@"))
    |> Enum.map(&(&1 |> String.replace(~r/[.,!?;:)]+$/, "") |> Safety.actor_key()))
    |> Enum.uniq()
  end

  def get_post(client, uri) do
    validate_uri!(uri)

    post =
      call(client, :get, "app.bsky.feed.getPosts", query: %{"uris" => uri})
      |> Map.get("posts", [])
      |> List.first()

    if is_nil(post), do: raise(Error, "Bluesky post unavailable.")
    normalize(post)
  end

  def notifications(client) do
    client
    |> call(:get, "app.bsky.notification.listNotifications", query: %{"limit" => 30})
    |> Map.get("notifications", [])
    |> Enum.filter(&(&1["reason"] in ["mention", "reply"]))
    |> Enum.map(&normalize/1)
  end

  def search(client, query, limit \\ 20) do
    client
    |> call(:get, "app.bsky.feed.searchPosts",
      query: %{"q" => query, "limit" => limit, "sort" => "latest"}
    )
    |> Map.get("posts", [])
    |> Enum.map(&normalize/1)
  end

  def timeline(client, limit \\ 20) do
    client
    |> call(:get, "app.bsky.feed.getTimeline", query: %{"limit" => limit})
    |> Map.get("feed", [])
    |> Enum.map(&(&1 |> Map.fetch!("post") |> normalize()))
  end

  def recent(client, limit \\ 12), do: feed(client, client.identity, limit)

  def feed(client, account, limit \\ 8) do
    client
    |> call(:get, "app.bsky.feed.getAuthorFeed",
      query: %{"actor" => account, "limit" => limit, "filter" => "posts_no_replies"}
    )
    |> Map.get("feed", [])
    |> Enum.reject(& &1["reason"])
    |> Enum.map(&(&1 |> Map.fetch!("post") |> normalize()))
  end

  def context(client, post), do: context(client, post, MapSet.new([post["id"]]), [], 5)

  def facets(client, text) do
    Regex.scan(@facet, text, return: :index)
    |> Enum.map(fn [{start, length}] ->
      raw = binary_part(text, start, length)
      value = String.replace(raw, ~r/[.,!?;:)]+$/, "")

      feature =
        cond do
          String.starts_with?(value, "https://") ->
            %{"$type" => "app.bsky.richtext.facet#link", "uri" => value}

          String.starts_with?(value, "@") ->
            did =
              call(client, :get, "com.atproto.identity.resolveHandle",
                query: %{"handle" => String.trim_leading(value, "@")}
              )
              |> Map.fetch!("did")

            %{"$type" => "app.bsky.richtext.facet#mention", "did" => did}

          true ->
            %{"$type" => "app.bsky.richtext.facet#tag", "tag" => String.trim_leading(value, "#")}
        end

      %{
        "index" => %{"byteStart" => start, "byteEnd" => start + byte_size(value)},
        "features" => [feature]
      }
    end)
  end

  def publish(client, draft) do
    text = Map.fetch!(draft, "text")
    Safety.validate_text!(text, limit(client))

    unless Map.get(draft, "visibility", "public") == "public",
      do: raise(Error, "Bluesky feed posts are public; private visibility is unsupported.")

    unless to_string_or_empty(draft["cw"]) == "",
      do: raise(Error, "Bluesky content warnings are unsupported by this release.")

    record = %{
      "$type" => "app.bsky.feed.post",
      "text" => text,
      "createdAt" => Map.fetch!(draft, "created_at"),
      "langs" => [Map.get(draft, "language", "en")],
      "facets" => facets(client, text)
    }

    record =
      if draft["reply_to"] do
        parent = get_post(client, draft["reply_to"])
        reference = %{"uri" => parent["id"], "cid" => parent["cid"]}
        Map.put(record, "reply", %{"parent" => reference, "root" => parent["root"] || reference})
      else
        record
      end

    record =
      if draft["quote_to"] do
        quote = get_post(client, draft["quote_to"])

        Map.put(record, "embed", %{
          "$type" => "app.bsky.embed.record",
          "record" => %{"uri" => quote["id"], "cid" => quote["cid"]}
        })
      else
        record
      end

    call(client, :post, "com.atproto.repo.createRecord",
      body: %{
        "repo" => client.identity,
        "collection" => "app.bsky.feed.post",
        "rkey" => Map.fetch!(draft, "record_key"),
        "record" => record
      }
    )
  end

  def delete(client, uri) do
    uri =
      if String.starts_with?(uri, "at://"),
        do: uri,
        else: "at://#{client.identity}/app.bsky.feed.post/#{uri}"

    validate_uri!(uri)

    unless uri |> String.split("/") |> Enum.at(2) == client.identity,
      do: raise(Error, "Can only delete your own posts.")

    rkey = uri |> String.split("/") |> List.last()

    call(client, :post, "com.atproto.repo.deleteRecord",
      body: %{"repo" => client.identity, "collection" => "app.bsky.feed.post", "rkey" => rkey}
    )
  end

  def normalize(post) do
    record = Map.get(post, "record", %{})

    %{
      "id" => post["uri"],
      "cid" => post["cid"],
      "text" => to_string_or_empty(record["text"]),
      "visibility" => "public",
      "author" => get_in(post, ["author", "handle"]),
      "author_id" => get_in(post, ["author", "did"]),
      "url" =>
        "https://bsky.app/profile/#{get_in(post, ["author", "did"])}/post/#{post["uri"] |> to_string_or_empty() |> String.split("/") |> List.last()}",
      "root" => get_in(record, ["reply", "root"]),
      "parent" => get_in(record, ["reply", "parent", "uri"])
    }
  end

  defp call(client, method, endpoint, opts) do
    %{token: token} = Agent.get(client.session, & &1)
    headers = Map.put(Keyword.get(opts, :headers, %{}), "Authorization", "Bearer #{token}")

    client.http.request(
      method,
      "#{xrpc_host(client, endpoint)}/xrpc/#{endpoint}",
      Keyword.put(opts, :headers, headers)
    )
  rescue
    error in HTTPError ->
      if error.status == 401 do
        refresh(client)
        %{token: token} = Agent.get(client.session, & &1)
        headers = Map.put(Keyword.get(opts, :headers, %{}), "Authorization", "Bearer #{token}")

        client.http.request(
          method,
          "#{xrpc_host(client, endpoint)}/xrpc/#{endpoint}",
          Keyword.put(opts, :headers, headers)
        )
      else
        raise error
      end
  end

  defp xrpc_host(_client, "app.bsky." <> _), do: @appview
  defp xrpc_host(client, _endpoint), do: client.pds || client.base

  defp pds_endpoint(client, response) do
    services = get_in(response, ["didDoc", "service"])

    origin =
      services
      |> List.wrap()
      |> Enum.find_value(fn service ->
        if is_map(service) and pds_service?(service) do
          service["serviceEndpoint"]
        end
      end)

    if is_binary(origin) do
      https_origin!(client.http, origin)
    else
      client.pds || client.base
    end
  end

  defp pds_service?(service) do
    id = service |> Map.get("id", "") |> to_string()
    type = service |> Map.get("type", "") |> to_string()
    type == "AtprotoPersonalDataServer" or String.ends_with?(id, "#atproto_pds")
  end

  defp https_origin!(http, url) do
    origin = url |> to_string() |> String.trim() |> String.trim_trailing("/")
    uri = http.validate_url!(origin)

    unless uri.path in [nil, "", "/"] and is_nil(uri.query) do
      raise Error, "Bluesky PDS URL must be an HTTPS origin."
    end

    origin
  end

  defp refresh(client) do
    %{refresh: refresh} = Agent.get(client.session, & &1)

    response =
      client.http.request(
        :post,
        "#{client.pds || client.base}/xrpc/com.atproto.server.refreshSession",
        headers: %{"Authorization" => "Bearer #{refresh}"}
      )

    unless response["did"] == client.identity, do: raise(Error, "Session account changed.")

    Agent.update(client.session, fn _ ->
      %{token: Map.fetch!(response, "accessJwt"), refresh: Map.fetch!(response, "refreshJwt")}
    end)
  end

  defp context(_client, _post, _seen, turns, 0), do: turns
  defp context(_client, %{"parent" => nil}, _seen, turns, _remaining), do: turns

  defp context(client, post, seen, turns, remaining) do
    parent_uri = post["parent"]

    if MapSet.member?(seen, parent_uri) do
      turns
    else
      case fetch_parent(client, parent_uri) do
        nil ->
          turns

        parent ->
          turns = if Safety.eligible?(parent), do: [parent | turns], else: turns
          context(client, parent, MapSet.put(seen, parent_uri), turns, remaining - 1)
      end
    end
  end

  defp fetch_parent(_client, uri) when uri in [nil, ""], do: nil

  defp fetch_parent(client, uri) do
    if Regex.match?(@uri, to_string_or_empty(uri)) do
      post =
        call(client, :get, "app.bsky.feed.getPosts", query: %{"uris" => uri})
        |> Map.get("posts", [])
        |> List.first()

      if post, do: normalize(post)
    end
  end

  defp validate_uri!(uri) do
    unless Regex.match?(@uri, to_string_or_empty(uri)),
      do: raise(Error, "Use an at:// URI for a Bluesky post.")
  end

  defp to_string_or_empty(nil), do: ""
  defp to_string_or_empty(value) when is_binary(value), do: value
  defp to_string_or_empty(value), do: to_string(value)
end
