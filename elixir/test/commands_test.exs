defmodule ChorusDraft.CommandsTest do
  use ExUnit.Case, async: false
  import ExUnit.CaptureIO
  alias ChorusDraft.{CLI, Commands, Error}

  test "short commands preserve literal text and advanced options" do
    text = "spaces & pipes | quotes \"hello\" $HOME; Unicode café"
    assert Commands.normalize(["post", text]) == ["--text=" <> text]

    assert Commands.normalize(["reply", "123", text, "--cw", "note"]) == [
             "--text=" <> text,
             "--reply-to=123",
             "--cw",
             "note"
           ]

    assert Commands.normalize(["quote", "123", text]) == ["--text=" <> text, "--quote-uri=123"]
    assert Commands.normalize(["edit", "draft-id", text]) == ["--edit=draft-id", "--text=" <> text]
    assert Commands.normalize(["start", "--jetstream"]) == ["--daemon", "--jetstream"]
    assert Commands.normalize(["random", "--limit", "3"]) == ["--random-post=", "--limit", "3"]
    assert Commands.normalize(["discover", "ruby"]) == ["--discover", "--query=ruby"]

    assert Commands.normalize(["targets", "account.example"]) == [
             "--targets-only",
             "--target=account.example"
           ]

    assert Commands.normalize(["--text", text]) == ["--text", text]
  end

  test "incomplete commands cannot become other actions" do
    for args <- [
          ["post"],
          ["reply", "123"],
          ["quote", "--publish"],
          ["search", ""],
          ["delete"],
          ["edit"],
          ["edit", "draft-id"]
        ] do
      assert_raise Error, ~r/requires an argument/, fn -> Commands.normalize(args) end
    end

    assert_raise Error, ~r/Unknown command/, fn -> Commands.normalize(["unknown"]) end
  end

  test "AI short commands do not gain a direct publication path" do
    for command <- ["draft", "review", "start", "replies", "discover", "targets"] do
      message =
        capture_io(:stderr, fn -> assert CLI.run(["bluesky", command, "--publish"]) == 1 end)

      assert message =~ "--publish requires --text"
    end
  end

  test "packaged version strings stay aligned with the VERSION file" do
    version = String.trim(File.read!("VERSION"))
    assert version == ChorusDraft.version()
    assert version == String.trim(File.read!("../VERSION"))
    assert File.read!("../desktop/package.json") =~ ~s("version": "#{version}")
  end

  test "edit cannot skip review by adding --publish" do
    message =
      capture_io(:stderr, fn ->
        assert CLI.run(["bluesky", "edit", "draft-id", "hello", "--publish"]) == 1
      end)

    assert message =~ "--publish cannot be combined with --edit"
  end

  test "edit cannot be combined with reply or quote targets" do
    for extra <- [["--reply-to", "1"], ["--quote-uri", "1"], ["--queue"]] do
      message =
        capture_io(:stderr, fn ->
          assert CLI.run(["bluesky", "edit", "draft-id", "hello" | extra]) == 1
        end)

      assert message =~ "--edit cannot be combined with reply, quote, or queue options."
    end
  end

  test "short help and version work without account credentials" do
    for platform <- ["bluesky", "mastodon"] do
      assert capture_io(fn -> assert CLI.run([platform, "version"]) == 0 end) =~
               ChorusDraft.version()

      assert capture_io(fn -> assert CLI.run([platform, "help"]) == 0 end) =~ "Short commands:"
    end
  end

  test "short setup preserves existing configuration and creates no account state" do
    base = Path.join(System.tmp_dir!(), "ChorusDraft setup #{System.unique_integer([:positive])}")
    on_exit(fn -> File.rm_rf!(base) end)
    File.mkdir_p!(Path.join(base, "config"))

    for file <- [
          ".env.example",
          "config/target_accounts.txt.example",
          "config/do_not_contact.txt.example"
        ] do
      File.cp!(Path.join("mastodon", file), Path.join(base, file))
    end

    capture_io(fn -> assert CLI.run(["mastodon", "setup", "--base", base]) == 0 end)
    File.write!(Path.join(base, ".env"), "# existing configuration\n")
    capture_io(fn -> assert CLI.run(["mastodon", "setup", "--base", base]) == 0 end)
    assert File.read!(Path.join(base, ".env")) == "# existing configuration\n"
    refute File.exists?(Path.join(base, "data"))
  end
end
