defmodule ChorusDraft.CLI do
  alias ChorusDraft.{
    Config,
    Control,
    Error,
    HTTPError,
    Jetstream,
    Runner,
    Service,
    Setup,
    Store,
    Streaming
  }

  alias ChorusDraft.Clients.{Bluesky, Mastodon}

  @switches [
    help: :boolean,
    setup: :boolean,
    import_state: :string,
    status: :boolean,
    history: :boolean,
    reject: :string,
    edit: :string,
    reply_cid: :string,
    quote_cid: :string,
    version: :boolean,
    base: :string,
    text: :string,
    publish: :boolean,
    reply_to: :string,
    quote_uri: :string,
    cw: :string,
    post_only: :boolean,
    replies_only: :boolean,
    discover: :boolean,
    listen: :boolean,
    daemon: :boolean,
    automatic: :boolean,
    jetstream: :boolean,
    process_queue: :boolean,
    targets_only: :boolean,
    queue: :boolean,
    search: :string,
    random_post: :string,
    random_reply: :string,
    query: :string,
    target: :string,
    delete: :string,
    poll_interval: :integer,
    interval: :integer,
    jitter: :integer,
    limit: :integer,
    active_hours: :string,
    ignore_active_hours: :boolean,
    service: :string
  ]
  @aliases [h: :help, v: :version, m: :text]

  def main(argv), do: System.halt(run(argv))

  def run(argv, io_opts \\ []) do
    Control.setup!()
    ChorusDraft.Guard.required!()

    with {:ok, platform, argv} <- platform(argv),
         {:ok, options} <- parse(argv),
         :ok <- validate_platform(platform, options),
         :ok <- maybe_help(platform, options) do
      execute(platform, options, io_opts)
    else
      {:exit, code} ->
        code

      {:error, message} ->
        Control.warn(message)
        1
    end
  rescue
    error in [Error, HTTPError] ->
      Control.warn(error.message)
      1

    _ ->
      Control.warn("Operation failed; details omitted to protect credentials and content.")
      1
  catch
    :exit, {:shutdown, _} -> 0
  end

  def active?(spec, now \\ local_time())
  def active?(spec, _now) when spec in [nil, ""], do: true

  def active?(spec, now) do
    case Regex.named_captures(
           ~r/^(?<sh>\d{1,2})(?::(?<sm>\d{2}))?-(?<eh>\d{1,2})(?::(?<em>\d{2}))?$/,
           spec
         ) do
      %{"sh" => sh, "sm" => sm, "eh" => eh, "em" => em} ->
        active_range(
          sh,
          if(sm == "", do: "0", else: sm),
          eh,
          if(em == "", do: "0", else: em),
          now
        )

      _ ->
        raise Error, "ACTIVE_HOURS must use HH:MM-HH:MM."
    end
  end

  defp local_time do
    {_date, {hour, minute, second}} = :calendar.local_time()
    Time.new!(hour, minute, second)
  end

  defp active_range(sh, sm, eh, em, now) do
    [sh, sm, eh, em] = Enum.map([sh, sm, eh, em], &String.to_integer/1)
    unless sh < 24 and eh < 24 and sm < 60 and em < 60, do: raise(Error, "Invalid active hours.")
    start = sh * 60 + sm
    finish = eh * 60 + em
    current = now.hour * 60 + now.minute

    start == finish or
      if(start < finish,
        do: current >= start and current < finish,
        else: current >= start or current < finish
      )
  end

  defp platform([platform | rest]) when platform in ["bluesky", "mastodon"],
    do: {:ok, platform, rest}

  defp platform(_),
    do:
      {:error,
       "Choose a platform first: chorusdraft bluesky [options] or chorusdraft mastodon [options]."}

  defp parse(argv) do
    argv = argv |> ChorusDraft.Commands.normalize() |> normalize_compatibility_args()

    case OptionParser.parse(argv, strict: @switches, aliases: @aliases) do
      {[], [], []} ->
        {:ok, %{help: true, poll_interval: 60, interval: 120, jitter: 0, limit: 5}}

      {options, [], []} ->
        if Keyword.get(options, :jetstream, :unspecified) == false do
          {:error, "Jetstream cannot be disabled; Bluesky listen and start use it automatically."}
        else
          validate_options(
            options
            |> Enum.reject(fn {_key, value} -> value == false end)
            |> Map.new()
          )
        end

      {_options, positional, []} ->
        {:error, "Unexpected positional arguments: #{Enum.join(positional, " ")}"}

      {_options, _positional, invalid} ->
        {:error, "Invalid option: #{inspect(invalid)}"}
    end
  end

  defp normalize_compatibility_args([]), do: []
  defp normalize_compatibility_args(["--random-post"]), do: ["--random-post="]

  defp normalize_compatibility_args(["--random-post", "--" <> _ = next | rest]),
    do: ["--random-post=" | normalize_compatibility_args([next | rest])]

  defp normalize_compatibility_args([value | rest]) do
    aliases = %{
      "--reply-uri" => "--reply-to",
      "--quote-only" => "--targets-only",
      "--staging" => "--queue",
      "--poll" => "--poll-interval"
    }

    value =
      case String.split(value, "=", parts: 2) do
        [flag, argument] -> Map.get(aliases, flag, flag) <> "=" <> argument
        [flag] -> Map.get(aliases, flag, flag)
      end

    [value | normalize_compatibility_args(rest)]
  end

  defp validate_options(options) do
    options = Map.merge(%{poll_interval: 60, interval: 120, jitter: 0, limit: 5}, options)

    valid_numbers? =
      options.poll_interval in 10..3600 and options.interval in 1..1440 and
        options.jitter in 0..60 and options.limit in 1..40

    unless valid_numbers?,
      do:
        raise(
          Error,
          "Poll must be 10–3600 seconds; interval 1–1440 minutes; jitter 0–60; limit 1–40."
        )

    modes = [
      :setup,
      :import_state,
      :status,
      :history,
      :reject,
      :edit,
      :text,
      :post_only,
      :replies_only,
      :discover,
      :listen,
      :daemon,
      :process_queue,
      :targets_only,
      :search,
      :random_post,
      :delete,
      :service
    ]

    mode_count =
      Enum.count(modes, fn mode ->
        Map.has_key?(options, mode) and not (mode == :text and Map.has_key?(options, :edit))
      end)

    cond do
      options[:help] || options[:version] ->
        {:ok, options}

      options[:automatic] && !options[:daemon] && !options[:service] ->
        {:error, "--automatic requires --daemon; use the automatic command."}

      mode_count != 1 ->
        {:error, "Choose one command at a time."}

      options[:edit] && !options[:text] ->
        {:error, "--edit requires --text."}

      options[:publish] && options[:edit] ->
        {:error, "--publish cannot be combined with --edit."}

      options[:edit] &&
          (options[:reply_to] || options[:quote_uri] || options[:random_reply] || options[:queue]) ->
        {:error, "--edit cannot be combined with reply, quote, or queue options."}

      options[:publish] && (!options[:text] || options[:queue]) ->
        {:error, "--publish requires --text and cannot be combined with --queue."}

      options[:publish] && options[:random_reply] ->
        {:error, "--random-reply picks the target for you; stage it and publish from review."}

      options[:reply_to] && options[:quote_uri] ->
        {:error, "Choose either a reply or quote."}

      options[:random_reply] && !options[:text] ->
        {:error, "--random-reply requires --text."}

      (options[:reply_to] || options[:quote_uri] || options[:cw]) && !options[:text] ->
        {:error, "Reply, quote and CW options require --text."}

      options[:random_reply] && (options[:reply_to] || options[:quote_uri]) ->
        {:error, "Random reply cannot be combined with reply/quote targets."}

      options[:service] && options.service not in ["install", "uninstall", "print"] ->
        {:error, "service requires install, uninstall, or print."}

      true ->
        {:ok, options}
    end
  end

  defp maybe_help(platform, options) do
    cond do
      options[:version] ->
        Control.log(ChorusDraft.version())
        {:exit, 0}

      options[:help] ->
        Control.log(help(platform))
        {:exit, 0}

      true ->
        :ok
    end
  end

  defp validate_platform(platform, options) do
    cond do
      options[:help] || options[:version] ->
        :ok

      options[:jetstream] && platform != "bluesky" ->
        {:error, "Jetstream is available only for Bluesky."}

      options[:jetstream] && !(options[:listen] || options[:daemon]) ->
        {:error, "--jetstream requires --listen or --daemon."}

      true ->
        :ok
    end
  end

  @doc false
  def jetstream_enabled?(platform, options) do
    platform == "bluesky" and (options[:listen] || options[:daemon])
  end

  @doc false
  def streaming_enabled?(_platform, options) do
    options[:listen] || options[:daemon]
  end

  defp execute(platform, %{history: true} = options, _io_opts) do
    base = Path.expand(Map.get(options, :base, default_base(platform)))
    Control.log(Jason.encode!(Store.history(base)))
    0
  end

  defp execute(platform, %{service: action} = options, _io_opts) do
    base = Path.expand(Map.get(options, :base, default_base(platform)))
    Service.run(platform, action, Map.put(options, :base, base))
    0
  end

  defp execute(platform, %{setup: true} = options, _io_opts) do
    base = Path.expand(Map.get(options, :base, default_base(platform)))
    Setup.run(base)
    0
  end

  defp execute(platform, options, io_opts) do
    base = Path.expand(Map.get(options, :base, default_base(platform)))
    env = Config.load(Path.join(base, ".env"), System.get_env())
    env = Config.load(Path.join([base, "config", ".env"]), env)
    if jetstream_enabled?(platform, options), do: Jetstream.endpoint!(env)

    if platform == "mastodon" and streaming_enabled?(platform, options),
      do: Streaming.endpoint!(env)

    hours = options[:active_hours] || env["ACTIVE_HOURS"]
    active?(hours)
    client = if platform == "bluesky", do: Bluesky.new(env), else: Mastodon.new(env)
    client = client.__struct__.login(client)
    account_key = client.__struct__.account_key(client)

    account_hash =
      :crypto.hash(:sha256, "#{platform}:#{account_key}")
      |> Base.encode16(case: :lower)
      |> String.slice(0, 24)

    store = Store.new(Path.join([base, "data", account_hash]))

    if options[:import_state] do
      count = Store.import_state(store, options.import_state, platform, account_key)
      Control.log("Imported #{count} drafts and interaction history; source was read only.")
    end

    load_do_not_contact(store, Path.join([base, "config", "do_not_contact.txt"]))

    runner =
      Runner.new(
        client,
        store,
        platform,
        env,
        Keyword.put(io_opts, :automatic, Map.get(options, :automatic, false))
      )

    Control.log(
      "#{platform_title(platform)} #{ChorusDraft.version()} | #{publication_banner(options)} | automatic likes disabled"
    )

    dispatch(runner, options, hours, base)
    0
  end

  defp dispatch(runner, options, hours, base) do
    cond do
      options[:import_state] ->
        :ok

      options[:status] ->
        drafts = Store.drafts(runner.store)
        budget = Store.automatic_budget(runner.store)

        Enum.each(["pending", "publishing", "uncertain", "published", "rejected"], fn status ->
          Control.log("#{status}: #{Enum.count(drafts, &(&1["status"] == status))}")
        end)

        Control.log(
          "automatic: #{budget.remaining}/#{budget.limit} attempts remaining in the rolling 24 hours"
        )

        if budget.frozen,
          do: Control.log("automatic frozen until publishing or uncertain drafts are resolved")

        drafts
        |> Enum.filter(&(&1["status"] in ["pending", "publishing", "uncertain"]))
        |> Enum.each(&Control.log("#{&1["id"]} | #{&1["status"]}"))

      options[:reject] ->
        Store.transition(runner.store, options.reject, ["pending", "uncertain"], "rejected")
        Control.log("Rejected draft.")

      options[:edit] ->
        cw = if Map.has_key?(options, :cw), do: [cw: options.cw], else: []
        updated = Runner.replace_pending(runner, options.edit, options.text, cw)
        Control.log("Updated draft #{updated["id"]}. Use review before publishing.")

      options[:text] ->
        manual(runner, options)

      options[:process_queue] ->
        Runner.review(runner)

      options[:delete] ->
        Runner.delete(runner, options.delete)

      options[:search] ->
        Runner.inspect_posts(runner, options.search, limit: options.limit)

      Map.has_key?(options, :random_post) ->
        Runner.inspect_posts(runner, options.random_post, limit: options.limit, random: true)

      options[:listen] || options[:daemon] ->
        cond do
          jetstream_enabled?(runner.platform, options) ->
            Jetstream.with_stream(
              runner.client.__struct__.identity(runner.client),
              runner.env,
              fn stream ->
                Control.log("Jetstream enabled; notification catch-up remains active.")
                loop(runner, options, hours, base, nil, stream)
              end
            )

          runner.platform == "mastodon" ->
            Streaming.with_stream(runner.env, fn stream ->
              Control.log("Mastodon streaming enabled; notification catch-up remains active.")
              loop(runner, options, hours, base, nil, stream)
            end)

          true ->
            loop(runner, options, hours, base, nil, nil)
        end

      true ->
        cycle(runner, options, hours, base)
    end
  end

  defp manual(runner, options) do
    options =
      if options[:random_reply] do
        posts =
          runner.client.__struct__.search(runner.client, options.random_reply, 20)
          |> Enum.filter(&Runner.eligible?(runner, &1))

        if posts == [], do: raise(Error, "No eligible public posts found.")
        Map.put(options, :reply_to, Enum.random(posts)["id"])
      else
        options
      end

    Runner.manual(runner, options.text,
      reply_to: options[:reply_to],
      quote_to: options[:quote_uri],
      cw: options[:cw],
      publish: Map.get(options, :publish, false)
    )
  end

  defp within_hours?(options, hours), do: options[:ignore_active_hours] || active?(hours)

  defp cycle(runner, options, hours, base) do
    if within_hours?(options, hours) do
      jitter(options)

      if within_hours?(options, hours) do
        cond do
          options[:replies_only] || options[:listen] -> Runner.mentions(runner)
          options[:targets_only] -> Runner.targets(runner, targets(options, base))
          options[:discover] -> Runner.discovery(runner, discovery_query(options, runner.env))
          true -> Runner.original(runner)
        end
      end
    end
  end

  defp jitter(options) do
    if options.jitter > 0, do: Process.sleep(:rand.uniform(options.jitter * 60_000))
  end

  def daemon_cycle(runner, options, hours, base, last_original, now) do
    if within_hours?(options, hours) do
      guarded(fn -> Runner.mentions(runner) end)

      if is_nil(last_original) or now - last_original >= options.interval * 60 do
        jitter(options)

        if within_hours?(options, hours) do
          guarded(fn -> Runner.original(runner) end)
          guarded(fn -> Runner.targets(runner, targets(options, base)) end)
          now
        else
          last_original
        end
      else
        last_original
      end
    else
      last_original
    end
  end

  defp guarded(fun) do
    fun.()
  rescue
    error in [Error, HTTPError] -> Control.warn(error.message)
    _ -> Control.warn("Cycle failed; details omitted to protect credentials and content.")
  end

  defp loop(runner, options, hours, base, last_original, stream) do
    started = System.monotonic_time(:millisecond)

    last_original =
      if options[:daemon] do
        daemon_cycle(runner, options, hours, base, last_original, System.monotonic_time(:second))
      else
        guarded(fn -> cycle(runner, options, hours, base) end)
        last_original
      end

    if stream do
      cooldown = max(5_000 - (System.monotonic_time(:millisecond) - started), 0)
      Jetstream.wait(stream, options.poll_interval * 1000, cooldown)
    else
      Process.sleep(options.poll_interval * 1000)
    end

    loop(runner, options, hours, base, last_original, stream)
  end

  defp targets(options, base) do
    if options[:target],
      do: [options.target],
      else: read_list(Path.join([base, "config", "target_accounts.txt"]))
  end

  defp discovery_query(options, env) do
    (options[:query] || env["DISCOVERY_KEYWORDS"] || env["DISCOVERY_TAGS"] || "opensource")
    |> String.split(",")
    |> Enum.random()
    |> String.trim()
  end

  defp load_do_not_contact(store, path), do: Enum.each(read_list(path), &Store.block(store, &1))

  defp read_list(path) do
    if File.regular?(path) do
      path
      |> File.read!()
      |> String.split("\n")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == "" or String.starts_with?(&1, "#")))
    else
      []
    end
  end

  defp default_base(platform), do: Path.expand(platform, File.cwd!())
  defp platform_title("bluesky"), do: "ChorusDraft for Bluesky"
  defp platform_title("mastodon"), do: "ChorusDraft for Mastodon"

  defp help(platform) do
    """
    #{platform_title(platform)} #{ChorusDraft.version()} — review-first social drafting
    Usage: chorusdraft #{platform} [options]

    Short commands:
      setup, draft, review, start, automatic, listen, replies, status, history
      post TEXT, reply ID TEXT, quote ID TEXT, search QUERY, edit ID TEXT
      random [QUERY], discover [QUERY], targets [HANDLE], delete ID, reject ID, import FILE
      service install|uninstall|print

      -m, --text TEXT          Stage a manual post
          --publish            Publish --text explicitly; never applies to AI
          --reply-to ID        Reply to status ID or at:// URI
          --quote-uri ID       Quote a post
          --cw TEXT            Mastodon content warning
          --post-only          Stage one original AI draft
          --replies-only       Process public mentions once
          --targets-only       Stage public target commentary
          --discover           Stage discovery commentary
          --listen             Poll public mentions; Bluesky and Mastodon stream as a wake-up
          --daemon             Poll mentions and periodically draft originals
          --automatic          With --daemon, publish new originals/replies after safety checks
          --jetstream          Compatibility no-op; Bluesky listen/start always streams
          --process-queue      Interactively review AI and manual drafts
          --edit ID            Replace pending draft text; requires --text; then review; not with --publish, reply, quote, or queue
          --search QUERY       Display public posts
          --random-post [QUERY] Display a random public search/timeline result
          --delete ID          Interactively delete your own post
          --setup              Create missing configuration files, without login
          --import-state FILE  Copy compatible state into an empty account store
          --status             Show queue counts, unresolved IDs, and automatic budget
          --history            Print locally recorded published posts as JSON
          --reject ID          Reject one pending or uncertain draft without publishing
          --base PATH          Platform configuration and data directory
          --random-reply QUERY Choose a public reply target for --text
          --target HANDLE      Account for --targets-only
          --query QUERY        Discovery search (or DISCOVERY_KEYWORDS/TAGS)
          --limit N            Inspection results, 1–40 (default 5)
          --poll-interval N    Poll seconds, 10–3600 (default 60)
          --interval N         Daemon original interval in minutes (default 120)
          --jitter N           Random delay up to N minutes, 0–60
          --active-hours RANGE Local HH:MM-HH:MM, including overnight ranges
          --ignore-active-hours Bypass the schedule for this invocation
          --queue              Stage manual text (the default)
          --service ACTION     install, uninstall, or print a user service (not started)

    Compatibility aliases: --reply-uri, --quote-only, --staging, --poll.
    --reply-cid/--quote-cid are accepted; records are re-fetched before posting.
      -v, --version            Show version
      -h, --help               Show this help

    Review is the default. Automatic mode never publishes old queued, manual,
    discovery, target-commentary, or held drafts. No arguments prints this help.
    """
  end

  defp publication_banner(%{automatic: true}), do: "automatic AI publication"
  defp publication_banner(_options), do: "AI drafts require review"
end
