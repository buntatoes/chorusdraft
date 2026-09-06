defmodule ChorusDraft.TestHTTP do
  def set_responses(responses), do: Process.put({__MODULE__, :responses}, responses)
  def calls, do: Process.get({__MODULE__, :calls}, []) |> Enum.reverse()
  def validate_url!(url, opts \\ []), do: ChorusDraft.HTTP.validate_url!(url, opts)

  def request(method, url, opts \\ []) do
    Process.put({__MODULE__, :calls}, [
      {method, url, opts} | Process.get({__MODULE__, :calls}, [])
    ])

    [response | rest] = Process.get({__MODULE__, :responses}, [])
    Process.put({__MODULE__, :responses}, rest)
    if is_exception(response), do: raise(response), else: response
  end
end

defmodule ChorusDraft.TestAI do
  def generate(_env, _task, data, _limit, _opts) do
    send(self(), {:ai_context, data})
    Process.get({__MODULE__, :text}, "A thoughtful response.")
  end
end

defmodule ChorusDraft.TestClient do
  defstruct identity: "me", posts: [], published: nil, platform: "mastodon", limit: 500

  def identity(client), do: client.identity
  def limit(client), do: client.limit
  def account_key(client), do: "https://example.org:#{client.identity}"
  def actor_aliases(_client, actor), do: [ChorusDraft.Safety.actor_key(actor)]

  def mentioned_actors(_client, text) do
    Regex.scan(~r/(?<![=\/\w])@([a-z0-9_.-]+(?:@[a-z0-9.-]+)?)/i, to_string(text || ""),
      capture: :all_but_first
    )
    |> List.flatten()
    |> Enum.map(&ChorusDraft.Safety.actor_key/1)
  end

  def notifications(client), do: client.posts
  def recent(client, limit), do: Enum.take(client.posts, limit)

  def feed(client, _account, limit) do
    if Process.get({__MODULE__, :feed_error}), do: raise(ChorusDraft.HTTPError, 503)
    Enum.take(client.posts, limit)
  end

  def search(client, _query, limit), do: Enum.take(client.posts, limit)
  def timeline(client, limit), do: Enum.take(client.posts, limit)
  def context(client, _post), do: client.posts
  def get_post(client, id), do: Enum.find(client.posts, &(&1["id"] == id))

  def publish(client, draft) do
    if client.published, do: Agent.update(client.published, &[draft | &1])
    if Process.get({__MODULE__, :fail}), do: raise(ChorusDraft.Error, "simulated failure")
    %{}
  end

  def delete(_client, _id), do: %{}
end
