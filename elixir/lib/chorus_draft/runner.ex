defmodule ChorusDraft.Runner do
  alias ChorusDraft.{AI, Error, Safety, Store}

  defstruct [:client, :store, :platform, :env, :input, :output, :interactive, :ai, :ai_opts]

  def new(client, store, platform, env, opts \\ []) do
    %__MODULE__{
      client: client,
      store: store,
      platform: platform,
      env: env,
      input: Keyword.get(opts, :input, :stdio),
      output: Keyword.get(opts, :output, :stdio),
      interactive: Keyword.get(opts, :interactive, terminal?()),
      ai: Keyword.get(opts, :ai, AI),
      ai_opts: Keyword.get(opts, :ai_opts, [])
    }
  end

  def eligible?(runner, post) do
    Safety.eligible?(post) and post["author_id"] != client_call(runner, :identity) and
      not blocked?(runner, post["author"])
  end

  def blocked?(runner, actor) do
    runner
    |> client_call(:actor_aliases, [actor])
    |> Enum.any?(&Store.blocked?(runner.store, &1))
  end

  def draft(runner, text, action, post \\ nil, quote? \\ false) do
    visibility =
      cond do
        runner.platform == "bluesky" -> "public"
        post && not quote? -> "unlisted"
        true -> Map.get(runner.env, "STATUS_VISIBILITY", "public")
      end

    %{
      "platform" => runner.platform,
      "account" => client_call(runner, :account_key),
      "text" => text,
      "action" => action,
      "visibility" => visibility,
      "language" => Map.get(runner.env, "STATUS_LANGUAGE", "en"),
      "reply_to" => if(post && not quote?, do: post["id"]),
      "quote_to" => if(post && quote?, do: post["id"]),
      "author" => if(post, do: post["author"]),
      "cw" => if(post && runner.platform == "mastodon", do: post["cw"])
    }
  end

  def stage_generated(runner, task, opts \\ []) do
    post = Keyword.get(opts, :post)
    quote? = Keyword.get(opts, :quote, false)
    unsolicited? = Keyword.get(opts, :unsolicited, false)
    context = Keyword.get(opts, :context, %{})

    eligible_source? =
      is_nil(post) or (eligible?(runner, post) and not Store.seen?(runner.store, post["id"]))

    available? =
      Store.available?(runner.store,
        source: post && post["id"],
        author: post && post["author"],
        unsolicited: unsolicited?
      )

    if eligible_source? and available? do
      context =
        if post do
          thread =
            client_call(runner, :context, [post])
            |> Enum.filter(&Safety.eligible?/1)
            |> Enum.map(&Safety.clean(&1["text"]))

          Map.merge(context, %{
            "post" => Safety.clean(post["text"]),
            "author" => post["author"],
            "thread" => thread
          })
        else
          context
        end

      prefix = if post && not quote?, do: "@#{post["author"]} ", else: ""

      suffix =
        if post && quote? && runner.platform == "mastodon", do: "\n\n#{post["url"]}", else: ""

      available = client_call(runner, :limit) - String.length(prefix) - String.length(suffix)
      if available < 20, do: raise(Error, "Source URL/handle leaves no room for commentary.")

      generated = runner.ai.generate(runner.env, task, context, available, runner.ai_opts)
      candidate = draft(runner, prefix <> generated <> suffix, "ai_generated", post, quote?)
      validate_draft!(runner, candidate)

      item =
        Store.stage(runner.store, candidate,
          source: post && post["id"],
          unsolicited: unsolicited?
        )

      puts(
        runner,
        if(item,
          do: "Staged draft #{item["id"]}; use --process-queue to review.",
          else: "Skipped duplicate or queue/interaction limit reached."
        )
      )

      item
    end
  end

  def mentions(runner) do
    notifications = client_call(runner, :notifications) |> Enum.take(30)

    Enum.each(notifications, fn post ->
      if Safety.public?(post) and post["author_id"] != client_call(runner, :identity) and
           Safety.opt_out?(post["text"]) do
        runner
        |> client_call(:actor_aliases, [post["author"]])
        |> Enum.each(&Store.block(runner.store, &1))
      end
    end)

    notifications
    |> Enum.reduce_while(0, fn post, replies ->
      cond do
        replies >= 5 ->
          {:halt, replies}

        not eligible?(runner, post) ->
          {:cont, replies}

        true ->
          item =
            stage_generated(
              runner,
              "Write a brief, witty reply grounded in the supplied public post and thread. Share a playful observation about the situation without teasing the author. If the context is serious or sensitive, give a sincere reply instead of a joke.",
              post: post
            )

          {:cont, replies + if(item, do: 1, else: 0)}
      end
    end)
  end

  def original(runner) do
    previous =
      runner
      |> client_call(:recent, [12])
      |> Enum.filter(&Safety.eligible?/1)
      |> Enum.map(&Safety.clean(&1["text"]))

    stage_generated(
      runner,
      "Write an original, brief comic observation about programming or open-source software. Use one concrete setup and an unexpected turn, such as dry sarcasm or an absurd comparison. Keep imagined situations clearly fanciful, avoid unsupported factual claims, and vary both the topic and joke structure from the supplied previous posts.",
      context: %{"previous_posts" => previous}
    )
  end

  def targets(runner, handles) do
    Enum.reduce_while(handles, nil, fn handle, _ ->
      post = client_call(runner, :feed, [handle, 8]) |> Enum.find(&eligible?(runner, &1))

      if post do
        item = commentary(runner, post)
        if item, do: {:halt, item}, else: {:cont, nil}
      else
        {:cont, nil}
      end
    end)
  end

  def discovery(runner, query) do
    post = client_call(runner, :search, [query, 20]) |> Enum.find(&eligible?(runner, &1))
    if post, do: commentary(runner, post)
  end

  def manual(runner, text, opts \\ []) do
    reply_to = Keyword.get(opts, :reply_to)
    quote_to = Keyword.get(opts, :quote_to)
    cw = Keyword.get(opts, :cw)
    publish? = Keyword.get(opts, :publish, false)
    if reply_to && quote_to, do: raise(Error, "Choose either a reply or quote.")
    post = if reply_to || quote_to, do: client_call(runner, :get_post, [reply_to || quote_to])

    if post && not Safety.public?(post),
      do: raise(Error, "Restricted messages are not supported for replies or quotes.")

    if post && blocked?(runner, post["author"]),
      do: raise(Error, "This account is on the do-not-contact list.")

    text =
      if quote_to && runner.platform == "mastodon", do: text <> "\n\n#{post["url"]}", else: text

    item = draft(runner, text, "manual", post, not is_nil(quote_to)) |> Map.put("cw", cw)
    validate_draft!(runner, item)
    saved = Store.stage(runner.store, item)
    if is_nil(saved), do: raise(Error, "Queue is full; review existing drafts first.")

    if publish? do
      publish_draft(runner, saved)
    else
      puts(runner, "Staged manual draft #{saved["id"]}.")
    end

    saved
  end

  def validate_draft!(runner, item) do
    unless item["account"] == client_call(runner, :account_key) and
             item["platform"] == runner.platform do
      raise Error, "Draft belongs to a different account or platform."
    end

    Safety.validate_text!(Map.fetch!(item, "text"), client_call(runner, :limit))

    if runner.platform == "bluesky" do
      unless item["visibility"] == "public",
        do: raise(Error, "Bluesky supports public feed posts only.")

      unless empty?(item["cw"]),
        do: raise(Error, "Content warnings are supported only for Mastodon.")
    else
      unless empty?(item["cw"]),
        do: Safety.validate_text!(item["cw"], client_call(runner, :limit))
    end

    actors =
      [item["author"]] ++
        client_call(runner, :mentioned_actors, [item["text"]]) ++
        client_call(runner, :mentioned_actors, [item["cw"]])

    if actors |> Enum.reject(&is_nil/1) |> Enum.any?(&blocked?(runner, &1)) do
      raise Error, "Draft contacts an account on the do-not-contact list."
    end

    true
  end

  def publish_draft(runner, item) do
    validate_draft!(runner, item)
    claimed = Store.transition(runner.store, item["id"], "pending", "publishing", expected: item)

    try do
      client_call(runner, :publish, [claimed])
      Store.transition(runner.store, item["id"], "publishing", "published")
      puts(runner, "Published draft #{item["id"]}.")
    rescue
      _ ->
        Store.transition(runner.store, item["id"], "publishing", "uncertain")

        raise Error,
              "Publish did not complete cleanly. Draft marked uncertain; check the account before attempting anything again."
    end
  end

  def review(runner) do
    unless runner.interactive, do: raise(Error, "Queue review requires an interactive terminal.")

    runner.store
    |> Store.drafts()
    |> Enum.filter(&(&1["status"] == "pending"))
    |> Enum.reduce_while(:ok, fn item, _ ->
      validate_draft!(runner, item)
      puts(runner, "\n#{item["id"]} | #{item["action"]} | #{item["visibility"]}")
      if item["reply_to"], do: puts(runner, "Reply: #{Safety.clean(item["reply_to"])}")
      if item["quote_to"], do: puts(runner, "Quote: #{Safety.clean(item["quote_to"])}")
      if item["cw"], do: puts(runner, "Content warning: #{Safety.clean(item["cw"])}")
      puts(runner, item["text"])
      write(runner, "Publish this exact draft? [y/N/d=reject/q=quit]: ")

      case runner.input |> IO.gets("") |> to_string() |> String.trim() |> String.downcase() do
        answer when answer in ["y", "yes"] ->
          publish_draft(runner, item)
          {:cont, :ok}

        "d" ->
          Store.transition(runner.store, item["id"], "pending", "rejected")
          {:cont, :ok}

        "q" ->
          {:halt, :ok}

        _ ->
          {:cont, :ok}
      end
    end)
  end

  def inspect_posts(runner, query, opts \\ []) do
    limit = Keyword.get(opts, :limit, 5)
    random? = Keyword.get(opts, :random, false)

    posts =
      if empty?(query),
        do: client_call(runner, :timeline, [limit]),
        else: client_call(runner, :search, [query, limit])

    posts = Enum.filter(posts, &Safety.public?/1)
    posts = if random?, do: Enum.take_random(posts, 1), else: posts

    Enum.each(
      posts,
      &puts(
        runner,
        "\n@#{Safety.clean(&1["author"])} | #{Safety.clean(&1["id"])}\n#{Safety.clean(&1["text"])}"
      )
    )

    posts
  end

  def delete(runner, id) do
    unless runner.interactive, do: raise(Error, "Deletion requires an interactive terminal.")
    write(runner, "Delete #{Safety.clean(id)} from your account? Type delete: ")

    if runner.input |> IO.gets("") |> to_string() |> String.trim() == "delete" do
      client_call(runner, :delete, [id])
      puts(runner, "Deleted.")
    end
  end

  defp commentary(runner, post) do
    stage_generated(
      runner,
      "Write short, witty commentary on this public post. Find the absurdity in the product, claim, or situation without mocking or provoking its author or inventing allegations. Be sincere if the subject is sensitive; do not force a punchline.",
      post: post,
      quote: true,
      unsolicited: true
    )
  end

  defp client_call(runner, function, args \\ []) do
    apply(runner.client.__struct__, function, [runner.client | args])
  end

  defp empty?(nil), do: true
  defp empty?(""), do: true
  defp empty?(_), do: false
  defp puts(runner, text), do: IO.puts(runner.output, text)
  defp write(runner, text), do: IO.write(runner.output, text)

  defp terminal? do
    match?({:ok, _}, :io.columns(:standard_io))
  end
end
