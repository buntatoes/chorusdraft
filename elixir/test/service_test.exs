defmodule ChorusDraft.ServiceTest do
  use ExUnit.Case
  import ExUnit.CaptureIO
  alias ChorusDraft.{CLI, Commands, Service}

  test "service short commands and help" do
    assert Commands.normalize(["service", "install"]) == ["--service=install"]

    assert Commands.normalize(["service", "print", "--automatic"]) == [
             "--service=print",
             "--automatic"
           ]

    assert_raise ChorusDraft.Error, ~r/install, uninstall, or print/, fn ->
      Commands.normalize(["service", "start"])
    end

    help = capture_io(fn -> assert CLI.run(["bluesky", "--help"]) == 0 end)
    assert help =~ "service install"
  end

  test "print shows a user unit and install writes it without starting anything" do
    dir = Path.join(System.tmp_dir!(), "service-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf!(dir) end)
    config = Path.join(dir, "services")
    System.put_env("CHORUSDRAFT_SERVICE_HOME", config)
    on_exit(fn -> System.delete_env("CHORUSDRAFT_SERVICE_HOME") end)

    printed =
      capture_io(fn ->
        assert CLI.run(["bluesky", "service", "print", "--base", dir]) == 0
      end)

    assert printed =~ "chorusdraft"
    assert printed =~ "start"
    refute printed =~ "automatic"
    refute printed =~ "BLUESKY_APP_PASSWORD"
    refute printed =~ "MASTODON_ACCESS_TOKEN"

    automatic =
      capture_io(fn ->
        assert CLI.run(["mastodon", "service", "print", "--automatic", "--base", dir]) == 0
      end)

    assert automatic =~ "automatic"

    capture_io(fn ->
      assert CLI.run(["bluesky", "service", "install", "--base", dir]) == 0
    end)

    spec = Service.spec("bluesky", dir, false)
    assert File.regular?(spec.path)
    unit = File.read!(spec.path)
    assert unit =~ "start"
    refute unit =~ "BLUESKY_APP_PASSWORD"

    capture_io(fn ->
      assert CLI.run(["bluesky", "service", "uninstall", "--base", dir]) == 0
    end)

    refute File.regular?(spec.path)
  end

  test "generated units keep secrets out of the command line" do
    {command, _workdir} =
      Service.command("bluesky", Path.expand("bluesky", File.cwd!()), false)

    joined = Enum.join(command, " ")
    refute joined =~ "PASSWORD"
    refute joined =~ "TOKEN"
    refute joined =~ "API_KEY"
  end

  test "systemd units escape percent specifiers and reject line breaks" do
    if ChorusDraft.Platform.os() == "linux" do
      base = Path.join(System.tmp_dir!(), "100% certain")
      spec = Service.spec("bluesky", base, false)
      assert spec.contents =~ "100%% certain"

      assert_raise ChorusDraft.Error, ~r/line breaks/, fn ->
        Service.spec("bluesky", "/tmp/bad\nWantedBy=evil.target", false)
      end

      assert_raise ChorusDraft.Error, ~r/line breaks/, fn ->
        Service.spec("bluesky", "/tmp/bad\rpath", false)
      end
    end
  end
end
