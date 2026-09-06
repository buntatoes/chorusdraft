defmodule ChorusDraft.ParityTest do
  use ExUnit.Case
  import ExUnit.CaptureIO
  alias ChorusDraft.{CLI, Error, Runner, Store, TestClient}

  setup do
    dir = Path.join(System.tmp_dir!(), "parity-#{System.unique_integer([:positive])}")
    Store.new(dir)
    on_exit(fn -> File.rm_rf!(dir) end)
    %{dir: dir}
  end

  defp post(id, author) do
    %{
      "id" => id,
      "text" => "A public post",
      "author" => author,
      "author_id" => author,
      "visibility" => "public",
      "url" => "https://example.org/#{id}",
      "cw" => "Programming"
    }
  end

  defp runner(dir, posts \\ []) do
    Runner.new(%TestClient{posts: posts}, dir, "mastodon", %{}, ai: ChorusDraft.TestAI)
  end

  test "target and discovery modes advance past seen posts", %{dir: dir} do
    posts = [post("seen", "alice"), post("fresh", "bob"), post("fresh2", "carol")]
    Store.stage(dir, %{"text" => "old"}, source: "seen")
    run = runner(dir, posts)
    assert Runner.targets(run, ["target"])["quote_to"] == "fresh"
    assert Runner.discovery(run, "query")["quote_to"] == "fresh2"
  end

  test "manual replies preserve source content warnings unless explicitly overridden", %{dir: dir} do
    run = runner(dir, [post("1", "alice")])
    assert Runner.manual(run, "hello", reply_to: "1")["cw"] == "Programming"
    assert Runner.manual(run, "hello", reply_to: "1", cw: "")["cw"] == ""
  end

  test "Mastodon numeric entities cannot hide public opt-outs" do
    post =
      ChorusDraft.Clients.Mastodon.normalize(%{
        "id" => "1",
        "visibility" => "public",
        "content" => "Stop re&#112;lying to me&#x2e;"
      })

    assert ChorusDraft.Safety.opt_out?(post["text"])
  end

  test "active hours support short, mixed, overnight and full-day local ranges" do
    assert CLI.active?("9-17", ~T[10:00:00])
    assert CLI.active?("9:30-17", ~T[09:30:00])
    refute CLI.active?("9-17:30", ~T[17:30:00])
    assert CLI.active?("22-6", ~T[01:00:00])
    assert CLI.active?("0-0", ~T[19:30:00])
    assert_raise Error, fn -> CLI.active?("25-6") end
    assert_raise Error, fn -> CLI.active?("9:99-17") end
  end

  test "Ruby flags and 0.51.2 short commands translate without publishing" do
    assert CLI.normalize_short_command(["draft"]) == ["--post-only"]
    assert CLI.normalize_short_command(["review"]) == ["--process-queue"]
    assert CLI.normalize_short_command(["start", "--poll", "30"]) == ["--daemon", "--poll", "30"]
    assert CLI.normalize_short_command(["post", "hello"]) == ["--text", "hello"]

    assert CLI.normalize_short_command(["reply", "123", "hello"]) == [
             "--text",
             "hello",
             "--reply-to",
             "123"
           ]

    assert CLI.normalize_short_command(["quote", "123", "hello"]) == [
             "--text",
             "hello",
             "--quote-uri",
             "123"
           ]

    assert CLI.normalize_short_command(["search", "open source", "--limit", "2"]) == [
             "--search",
             "open source",
             "--limit",
             "2"
           ]

    assert CLI.normalize_short_command(["random"]) == ["--random-post="]

    assert CLI.normalize_short_command(["discover", "elixir"]) == [
             "--discover",
             "--query",
             "elixir"
           ]

    assert CLI.normalize_short_command(["targets", "alice.example"]) == [
             "--targets-only",
             "--target",
             "alice.example"
           ]

    for arguments <- [
          ["--random-post"],
          ["--reply-uri=at://example", "--reply-cid=ignored"],
          ["--poll=30", "--quote-only"],
          ["--random-post", "--limit", "2"]
        ] do
      assert capture_io(fn -> assert CLI.run(["bluesky", "--help" | arguments]) == 0 end) =~
               "Usage:"
    end

    assert capture_io(:stderr, fn ->
             assert CLI.run(["bluesky", "--reply-cid", "--post-only"]) == 1
           end) =~ "Invalid option"

    assert capture_io(:stderr, fn -> assert CLI.run(["bluesky", "--no-post-only"]) == 1 end) =~
             "Choose one"

    assert capture_io(:stderr, fn -> assert CLI.run(["bluesky", "draft", "--publish"]) == 1 end) =~
             "--publish requires --text"
  end

  test "short commands never inject direct publication" do
    commands = [
      ["draft"],
      ["post", "hello"],
      ["reply", "123", "hello"],
      ["quote", "123", "hello"],
      ["replies"],
      ["start"]
    ]

    Enum.each(commands, fn command ->
      refute "--publish" in CLI.normalize_short_command(command)
    end)
  end

  test "daemon schedules originals once per interval even after target failure", %{dir: dir} do
    run = runner(dir)
    Process.put({TestClient, :feed_error}, true)
    options = %{interval: 120, jitter: 0, target: "target"}
    assert CLI.daemon_cycle(run, options, nil, dir, nil, -10_000) == -10_000
    assert CLI.daemon_cycle(run, options, nil, dir, -10_000, -9_999) == -10_000
    assert length(Store.drafts(dir)) == 1
  end

  test "blocked pending drafts can be rejected without publication", %{dir: dir} do
    run = runner(dir, [post("1", "alice")])
    Runner.manual(run, "hello", reply_to: "1")
    Store.block(dir, "alice")
    {:ok, input} = StringIO.open("d\n")
    Runner.review(%{run | interactive: true, input: input})
    assert hd(Store.drafts(dir))["status"] == "rejected"
  end
end
