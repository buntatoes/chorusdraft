defmodule ChorusDraft.CLI do
  alias ChorusDraft.{Config, Error, Jetstream, Runner, Store}
  alias ChorusDraft.Clients.{Bluesky, Mastodon}

  @switches [
    help: :boolean,
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
    ignore_active_hours: :boolean
  ]
  @aliases [h: :help, v: :version, m: :text]

  def main(argv), do: System.halt(run(argv))

  def run(argv, io_opts \\ []) do
    with {:ok, platform, argv} <- platform(argv),
         {:ok, options} <- parse(argv),
         :ok <- validate_platform(platform, options),
         :ok <- maybe_help(platform, options) do
      execute(platform, options, io_opts)
    else
      {:exit, code} ->
        code

      {:error, message} ->
        IO.puts(:stderr, message)
        1
    end
  rescue
    error in Error ->
      IO.puts(:stderr, error.message)
      1

    _ ->
      IO.puts(:stderr, "Operation failed; details omitted to protect credentials and content.")
      1
  catch
    :exit, {:shutdown, _} -> 0
  end

  def active?(spec, now \\ Time.utc_now())
  def active?(spec, _now) when spec in [nil, ""], do: true

  def active?(spec, now) do
    case Regex.run(~r/^(\d{1,2})(?::(\d{2}))?-(\d{1,2})(?::(\d{2}))?$/, spec) do
      [_, sh, sm, eh, em] -> active_range(sh, sm, eh, em, now)
      [_, sh, eh] -> active_range(sh, "0", eh, "0", now)
      _ -> raise Error, "ACTIVE_HOURS must use HH:MM-HH:MM."
    end
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
       "Choose a product first: chorusdraft bluesky [options] or chorusdraft mastodon [options]."}

  defp parse(argv) do
    argv = normalize_compatibility_args(argv)

    case OptionParser.parse(argv, strict: @switches, aliases: @aliases) do
      {[], [], []} ->
        {:ok, %{help: true, poll_interval: 60, interval: 120, jitter: 0, limit: 5}}

      {options, [], []} ->
        validate_options(Map.new(options))

      {_options, positional, []} ->
        {:error, "Unexpected positional arguments: #{Enum.join(positional, " ")}"}

      {_options, _positional, invalid} ->
        {:error, "Invalid option: #{inspect(invalid)}"}
    end
  end

  defp normalize_compatibility_args(argv) do
    Enum.map(argv, fn
      "--reply-uri" -> "--reply-to"
      "--quote-only" -> "--targets-only"
      "--staging" -> "--queue"
      "--poll" -> "--poll-interval"
      value -> value
    end)
    |> drop_compatibility_value("--reply-cid")
    |> drop_compatibility_value("--quote-cid")
  end

  defp drop_compatibility_value([], _flag), do: []

  defp drop_compatibility_value([flag, _value | rest], flag),
    do: drop_compatibility_value(rest, flag)

  defp drop_compatibility_value([head | rest], flag),
    do: [head | drop_compatibility_value(rest, flag)]

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
      :delete
    ]

    mode_count = Enum.count(modes, &Map.has_key?(options, &1))

    cond do
      options[:help] || options[:version] ->
        {:ok, options}

      mode_count != 1 ->
        {:error, "Choose one command at a time."}

      options[:publish] && (!options[:text] || options[:queue]) ->
        {:error, "--publish requires --text and cannot be combined with --queue."}

      options[:random_reply] && !options[:text] ->
        {:error, "--random-reply requires --text."}

      (options[:reply_to] || options[:quote_uri] || options[:cw]) && !options[:text] ->
        {:error, "Reply, quote and CW options require --text."}

      options[:random_reply] && (options[:reply_to] || options[:quote_uri]) ->
        {:error, "Random reply cannot be combined with reply/quote targets."}

      true ->
        {:ok, options}
    end
  end

  defp maybe_help(platform, options) do
    cond do
      options[:version] ->
        IO.puts(ChorusDraft.version())
        {:exit, 0}

      options[:help] ->
        IO.puts(help(platform))
        {:exit, 0}

      true ->
        :ok
    end
  end

  defp validate_platform(platform, options) do
    cond do
      options[:help] || options[:version] -> :ok
      options[:jetstream] && platform != "bluesky" ->
        {:error, "Jetstream is available only for Bluesky."}
      options[:jetstream] && !(options[:listen] || options[:daemon]) ->
        {:error, "--jetstream requires --listen or --daemon."}
      true -> :ok
    end
  end

  defp execute(platform, options, io_opts) do
    base = Path.expand(Map.get(options, :base, default_base(platform)))
    env = Config.load(Path.join(base, ".env"), System.get_env())
    env = Config.load(Path.join([base, "config", ".env"]), env)
    if options[:jetstream], do: Jetstream.endpoint!(env)
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
    load_do_not_contact(store, Path.join([base, "config", "do_not_contact.txt"]))
    runner = Runner.new(client, store, platform, env, io_opts)

    IO.puts(
      "#{product(platform)} #{ChorusDraft.version()} | AI drafts require review | automatic likes disabled"
    )

    dispatch(runner, options, hours, base)
    0
  end

  defp dispatch(runner, options, hours, base) do
    cond do
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
        if options[:jetstream] do
          Jetstream.with_stream(runner.client.__struct__.identity(runner.client), runner.env, fn stream ->
            IO.puts("Jetstream enabled; notification catch-up remains active.")
            loop(runner, options, hours, base, 0, stream)
          end)
        else
          loop(runner, options, hours, base, 0, nil)
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

  defp cycle(runner, options, hours, base) do
    if options[:ignore_active_hours] || active?(hours) do
      if options.jitter > 0, do: Process.sleep(:rand.uniform(options.jitter * 60_000))

      cond do
        options[:replies_only] || options[:listen] -> Runner.mentions(runner)
        options[:targets_only] -> Runner.targets(runner, targets(options, base))
        options[:discover] -> Runner.discovery(runner, discovery_query(options, runner.env))
        true -> Runner.original(runner)
      end
    end
  end

  defp loop(runner, options, hours, base, last_original, stream) do
    started = System.monotonic_time(:millisecond)
    last_original =
      try do
        if options[:daemon] && (options[:ignore_active_hours] || active?(hours)) do
          Runner.mentions(runner)

          if System.system_time(:second) - last_original >= options.interval * 60 do
            Runner.original(runner)
            Runner.targets(runner, targets(options, base))
            System.system_time(:second)
          else
            last_original
          end
        else
          cycle(runner, options, hours, base)
          last_original
        end
      rescue
        error in Error ->
          IO.puts(:stderr, error.message)
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
    if options[:target] do
      [options.target]
    else
      read_list(Path.join([base, "config", "target_accounts.txt"]))
    end
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
  defp product("bluesky"), do: "BlueBot"
  defp product("mastodon"), do: "Mastobot"

  defp help(platform) do
    """
    #{product(platform)} #{ChorusDraft.version()} — human-reviewed social drafting
    Usage: chorusdraft #{platform} [options]

      -m, --text TEXT          Stage a manual post
          --publish            Publish --text explicitly; never applies to AI
          --reply-to ID        Reply to status ID or at:// URI
          --quote-uri ID       Quote a post
          --cw TEXT            Mastodon content warning
          --post-only          Stage one original AI draft
          --replies-only       Process public mentions once
          --targets-only       Stage public target commentary
          --discover           Stage discovery commentary
          --listen             Poll public mentions
          --daemon             Poll mentions and periodically draft originals
          --jetstream          Wake Bluesky --listen/--daemon on stream activity
          --process-queue      Interactively review AI and manual drafts
          --search QUERY       Display public posts
          --random-post QUERY  Display one random public search result
          --delete ID          Interactively delete your own post
          --base PATH          Product configuration and data directory
      -v, --version            Show version
      -h, --help               Show this help

    AI output always requires review. No arguments prints this help.
    """
  end
end
