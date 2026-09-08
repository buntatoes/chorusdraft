defmodule ChorusDraft.Service do
  @moduledoc false
  alias ChorusDraft.{Control, Error, Platform}

  @actions ~w(install uninstall print)

  def run(platform, action, options) when action in @actions do
    automatic? = Map.get(options, :automatic, false)
    base = Path.expand(Map.get(options, :base, Path.expand(platform, File.cwd!())))
    spec = spec(platform, base, automatic?)

    case action do
      "print" ->
        Control.log(spec.contents)

      "install" ->
        File.mkdir_p!(Path.dirname(spec.path))
        File.write!(spec.path, spec.contents)
        if Platform.os() != "windows", do: File.chmod!(spec.path, 0o600)
        Control.log("Wrote #{spec.path}")
        Control.log(spec.enable)

      "uninstall" ->
        File.rm(spec.path)
        Control.log("Removed #{spec.path}")
        Control.log(spec.disable)
    end
  end

  def run(_platform, action, _options),
    do: raise(Error, "service #{action} is not install, uninstall, or print.")

  def spec(platform, base, automatic?) when platform in ["bluesky", "mastodon"] do
    {command, workdir} = command(platform, base, automatic?)
    mode = if automatic?, do: "automatic", else: "start"

    case Platform.os() do
      "linux" ->
        path = Path.join(unit_dir(), "chorusdraft-#{platform}.service")

        %{
          path: path,
          enable:
            "Enable when you want it: systemctl --user enable --now chorusdraft-#{platform}.service\nStay running after logout: loginctl enable-linger $USER",
          disable: "systemctl --user disable --now chorusdraft-#{platform}.service",
          contents: systemd(platform, mode, command, workdir)
        }

      "macos" ->
        label = "org.chorusdraft.#{platform}"
        path = Path.join(unit_dir(), "#{label}.plist")

        %{
          path: path,
          enable: "Load when you want it: launchctl load #{path}",
          disable: "launchctl unload #{path}",
          contents: launchd(label, command, workdir)
        }

      "windows" ->
        path = Path.join(unit_dir(), "chorusdraft-#{platform}.xml")

        %{
          path: path,
          enable:
            "Register when you want it: schtasks /Create /TN \"ChorusDraft #{platform}\" /XML \"#{path}\"",
          disable: "schtasks /Delete /TN \"ChorusDraft #{platform}\" /F",
          contents: windows_task(platform, command, workdir)
        }
    end
  end

  def command(platform, base, automatic?) do
    mode = if automatic?, do: "automatic", else: "start"
    package = Path.dirname(base)
    unix = Path.join(package, "run.sh")
    windows = Path.join(package, "run.ps1")

    cond do
      File.regular?(unix) ->
        {[unix, platform, mode], package}

      File.regular?(windows) ->
        {[
           System.find_executable("powershell.exe") || "powershell.exe",
           "-NoProfile",
           "-File",
           windows,
           platform,
           mode
         ], package}

      true ->
        escript = System.find_executable("escript") || "escript"
        bot = escript_path(package)
        {[escript, bot, platform, mode, "--base", base], base}
    end
  end

  defp escript_path(package) do
    candidates = [
      Path.join(package, "chorusdraft"),
      Path.join(package, "elixir/chorusdraft"),
      Path.expand("chorusdraft", File.cwd!())
    ]

    Enum.find(candidates, List.last(candidates), &File.regular?/1)
  end

  defp unit_dir do
    case System.get_env("CHORUSDRAFT_SERVICE_HOME") do
      dir when is_binary(dir) and dir != "" ->
        dir

      _ ->
        case Platform.os() do
          "linux" ->
            Path.join([config_home(), "systemd", "user"])

          "macos" ->
            Path.join([System.user_home!(), "Library", "LaunchAgents"])

          "windows" ->
            Path.join([
              System.get_env("APPDATA") || Path.join(System.user_home!(), "AppData/Roaming"),
              "ChorusDraft"
            ])
        end
    end
  end

  defp config_home do
    System.get_env("XDG_CONFIG_HOME") || Path.join(System.user_home!(), ".config")
  end

  defp systemd(platform, mode, command, workdir) do
    exec = Enum.map_join(command, " ", &escape_systemd/1)

    """
    [Unit]
    Description=ChorusDraft #{platform} (#{mode})
    Documentation=https://github.com/buntatoes/chorusdraft
    After=network-online.target
    Wants=network-online.target

    [Service]
    Type=simple
    WorkingDirectory=#{escape_systemd(workdir)}
    Environment=ERL_CRASH_DUMP=/dev/null
    Environment=ERL_CRASH_DUMP_SECONDS=0
    ExecStart=#{exec}
    Restart=on-failure
    RestartSec=15
    TimeoutStopSec=30

    [Install]
    WantedBy=default.target
    """
  end

  defp launchd(label, command, workdir) do
    args =
      Enum.map_join(command, "\n", fn arg ->
        "    <string>#{xml(arg)}</string>"
      end)

    """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
      <key>Label</key>
      <string>#{xml(label)}</string>
      <key>ProgramArguments</key>
      <array>
    #{args}
      </array>
      <key>WorkingDirectory</key>
      <string>#{xml(workdir)}</string>
      <key>EnvironmentVariables</key>
      <dict>
        <key>ERL_CRASH_DUMP</key>
        <string>/dev/null</string>
        <key>ERL_CRASH_DUMP_SECONDS</key>
        <string>0</string>
      </dict>
      <key>KeepAlive</key>
      <true/>
      <key>RunAtLoad</key>
      <false/>
    </dict>
    </plist>
    """
  end

  defp windows_task(platform, command, workdir) do
    [program | args] = command
    arguments = Enum.map_join(args, " ", &quote_win/1)

    """
    <?xml version="1.0" encoding="UTF-16"?>
    <Task version="1.4" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
      <RegistrationInfo>
        <Description>ChorusDraft #{xml(platform)}</Description>
      </RegistrationInfo>
      <Triggers>
        <LogonTrigger>
          <Enabled>true</Enabled>
        </LogonTrigger>
      </Triggers>
      <Principals>
        <Principal>
          <LogonType>InteractiveToken</LogonType>
          <RunLevel>LeastPrivilege</RunLevel>
        </Principal>
      </Principals>
      <Settings>
        <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
        <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
        <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
        <StartWhenAvailable>true</StartWhenAvailable>
        <IdleSettings>
          <StopOnIdleEnd>false</StopOnIdleEnd>
        </IdleSettings>
        <Enabled>true</Enabled>
        <Hidden>true</Hidden>
        <ExecutionTimeLimit>PT0S</ExecutionTimeLimit>
        <RestartOnFailure>
          <Interval>PT1M</Interval>
          <Count>3</Count>
        </RestartOnFailure>
      </Settings>
      <Actions>
        <Exec>
          <Command>#{xml(program)}</Command>
          <Arguments>#{xml(arguments)}</Arguments>
          <WorkingDirectory>#{xml(workdir)}</WorkingDirectory>
        </Exec>
      </Actions>
    </Task>
    """
  end

  defp escape_systemd(value) do
    if String.contains?(value, [" ", "\t", "\"", "'", "\\"]) do
      "\"" <> String.replace(value, ~r/["\\]/, fn c -> "\\" <> c end) <> "\""
    else
      value
    end
  end

  defp quote_win(value) do
    if String.contains?(value, [" ", "\t", "\""]),
      do: "\"" <> String.replace(value, "\"", "\\\"") <> "\"",
      else: value
  end

  defp xml(value),
    do:
      value
      |> to_string()
      |> String.replace("&", "&amp;")
      |> String.replace("<", "&lt;")
      |> String.replace(">", "&gt;")
      |> String.replace("\"", "&quot;")
end
