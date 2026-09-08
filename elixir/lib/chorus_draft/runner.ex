defmodule ChorusDraft.Runner do
  alias ChorusDraft.{AI, Error, PII, Safety, Store}

  defstruct [
    :client,
    :store,
    :platform,
    :env,
    :input,
    :output,
    :interactive,
    :automatic,
    :ai,
    :ai_opts
  ]

  def new(client, store, platform, env, opts \\ []) do
    %__MODULE__{
      client: client,
      store: store,
      platform: platform,
      env: env,
      input: Keyword.get(opts, :input, :stdio),
      output: Keyword.get(opts, :output, :stdio),
      interactive: Keyword.get(opts, :interactive, terminal?()),
      automatic: Keyword.get(opts, :automatic, false),
      ai: Keyword.get(opts, :ai, AI),
      ai_opts: Keyword.get(opts, :ai_opts, [])
    }
  end

  def eligible?(runner, post) do
    Safety.eligible?(post) and post["author_id"] != client_call(runner, :identity) and
      not blocked_post?(runner, post)
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
      "author_id" => if(post, do: post["author_id"]),
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
          do: staged_message(runner, item),
          else: "Skipped duplicate or queue/interaction limit reached."
        )
      )

      maybe_publish_automatic(runner, item, generated, post, quote?, unsolicited?)
    end
  end

  def mentions(runner) do
    notifications = client_call(runner, :notifications) |> Enum.take(30)

    Enum.each(notifications, fn post ->
      if Safety.public?(post) and post["author_id"] != client_call(runner, :identity) and
           (Safety.opt_out?(post["text"]) or Safety.opt_out?(post["cw"])) do
        block_post(runner, post)
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
    Enum.find_value(handles, fn handle ->
      client_call(runner, :feed, [handle, 8])
      |> Enum.find_value(fn post -> if eligible?(runner, post), do: commentary(runner, post) end)
    end)
  end

  def discovery(runner, query) do
    client_call(runner, :search, [query, 20])
    |> Enum.find_value(fn post -> if eligible?(runner, post), do: commentary(runner, post) end)
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

    if post && blocked_post?(runner, post),
      do: raise(Error, "This account is on the do-not-contact list.")

    text =
      if quote_to && runner.platform == "mastodon", do: text <> "\n\n#{post["url"]}", else: text

    item = draft(runner, text, "manual", post, not is_nil(quote_to))
    item = if is_nil(cw), do: item, else: Map.put(item, "cw", cw)
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

    Store.validate_draft!(item)
    Safety.validate_text!(Map.fetch!(item, "text"), client_call(runner, :limit))

    if item["action"] == "ai_generated" do
      PII.validate!(item["text"])
      PII.validate!(item["cw"])
    end

    if runner.platform == "bluesky" do
      unless item["visibility"] == "public",
        do: raise(Error, "Bluesky supports public feed posts only.")

      unless empty?(item["cw"]),
        do: raise(Error, "Content warnings are supported only for Mastodon.")
    else
      unless item["visibility"] in ["public", "unlisted", "private", "direct"],
        do: raise(Error, "Invalid visibility.")

      unless empty?(item["cw"]),
        do: Safety.validate_text!(item["cw"], client_call(runner, :limit))
    end

    actors =
      [item["author"], item["author_id"]] ++
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
    publish_claimed(runner, claimed)
  end

  defp publish_claimed(runner, claimed) do
    try do
      client_call(runner, :publish, [claimed])
    rescue
      _ ->
        Store.transition(runner.store, claimed["id"], "publishing", "uncertain")

        raise Error,
              "Publish did not complete cleanly. Draft marked uncertain; check the account before attempting anything again."
    end

    published = Store.transition(runner.store, claimed["id"], "publishing", "published")
    puts(runner, "Published draft #{claimed["id"]}.")
    published
  end

  def review(runner) do
    unless runner.interactive, do: raise(Error, "Queue review requires an interactive terminal.")

    runner.store
    |> Store.drafts()
    |> Enum.filter(&(&1["status"] == "pending"))
    |> Enum.reduce_while(:ok, fn item, _ ->
      Store.validate_draft!(item)
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

  defp maybe_publish_automatic(runner, item, generated, post, quote?, unsolicited?) do
    if runner.automatic and item && not quote? and not unsolicited? do
      preflight =
        try do
          Safety.validate_automatic_text!(generated, client_call(runner, :limit))

          unless empty?(item["cw"]),
            do: Safety.validate_automatic_text!(item["cw"], client_call(runner, :limit))

          validate_draft!(runner, item)
          actors = automatic_source_actors!(runner, item, post)

          case Store.claim_automatic(runner.store, item, actors: actors) do
            {:ok, claimed} -> {:publish, claimed}
            {:error, reason} -> {:hold, reason}
          end
        rescue
          _ -> {:hold, :safety}
        end

      case preflight do
        {:publish, claimed} ->
          publish_claimed(runner, claimed)

        {:hold, reason} ->
          puts(
            runner,
            "Automatic publication held for review (#{automatic_hold_reason(reason)})."
          )

          item
      end
    else
      item
    end
  end

  defp automatic_source_actors!(_runner, _item, nil), do: []

  defp automatic_source_actors!(runner, item, post) do
    current = client_call(runner, :get_post, [post["id"]])

    same_author? =
      Safety.actor_key(current["author_id"]) != "" and
        Safety.actor_key(current["author_id"]) == Safety.actor_key(item["author_id"])

    unless current["id"] == post["id"] and Safety.public?(current) and same_author? do
      raise Error, "Source changed or is no longer eligible for automatic publication."
    end

    if Safety.opt_out?(current["text"]) or Safety.opt_out?(current["cw"]) do
      block_post(runner, current)
      block_post(runner, post)
      raise Error, "Source account opted out of replies."
    end

    same_source? =
      Safety.actor_key(current["author"]) == Safety.actor_key(item["author"]) and
        current["text"] == post["text"] and current["cw"] == post["cw"]

    unless Safety.eligible?(current) and same_source? do
      raise Error, "Source changed or is no longer eligible for automatic publication."
    end

    actors = post_actor_aliases(runner, current)

    if Enum.any?(actors, &Store.blocked?(runner.store, &1)) do
      raise Error, "Source account is on the do-not-contact list."
    end

    actors
  end

  defp blocked_post?(runner, post) do
    runner |> post_actor_aliases(post) |> Enum.any?(&Store.blocked?(runner.store, &1))
  end

  defp block_post(runner, post) do
    runner |> post_actor_aliases(post) |> Enum.each(&Store.block(runner.store, &1))
  end

  defp post_actor_aliases(runner, post) do
    [post["author"], post["author_id"]]
    |> Enum.reject(&is_nil/1)
    |> Enum.flat_map(&client_call(runner, :actor_aliases, [&1]))
    |> Enum.map(&Safety.actor_key/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.uniq()
  end

  defp staged_message(%{automatic: true}, item),
    do: "Staged draft #{item["id"]}; checking automatic-publication safeguards."

  defp staged_message(_runner, item),
    do: "Staged draft #{item["id"]}; use --process-queue to review."

  defp automatic_hold_reason(:unresolved), do: "another publication is unresolved"
  defp automatic_hold_reason(:blocked), do: "the source account is blocked"
  defp automatic_hold_reason(:limit), do: "the five-attempt daily limit was reached"
  defp automatic_hold_reason(:unavailable), do: "the draft was already claimed or changed"
  defp automatic_hold_reason(_reason), do: "a safety or source check did not pass"

  defp client_call(runner, function, args \\ []) do
    apply(runner.client.__struct__, function, [runner.client | args])
  end

  defp empty?(nil), do: true
  defp empty?(""), do: true
  defp empty?(_), do: false
  defp puts(runner, text), do: IO.puts(runner.output, text)
  defp write(runner, text), do: IO.write(runner.output, text)

  defp terminal? do
    match?({:ok, _}, :io.columns(:standard_io)) or
      (match?({:win32, _}, :os.type()) and
         System.get_env("CHORUSDRAFT_WINDOWS_CONSOLE") == "1")
  end
end
