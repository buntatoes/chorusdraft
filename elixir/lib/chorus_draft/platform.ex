defmodule ChorusDraft.Platform do
  @moduledoc false
  alias ChorusDraft.Error

  def os do
    case :os.type() do
      {:win32, _} -> "windows"
      {:unix, :darwin} -> "macos"
      {:unix, :linux} -> "linux"
      _ -> raise Error, "This build supports Linux, macOS, and Windows."
    end
  end

  def python do
    candidates = if os() == "windows", do: ["python", "python3"], else: ["python3"]

    Enum.find_value(candidates, &System.find_executable/1) ||
      raise(Error, "Install Python 3 and add it to PATH for macOS/Windows state locking.")
  end

  # Windows mode bits do not establish a private ACL. Use the current token SID,
  # not an interpolated username; pass the path separately through the environment.
  def private_directory!(path) do
    unless File.lstat!(path).type == :directory,
      do: raise(Error, "Private directory must not be a symlink.")

    if os() == "windows", do: secure_windows!(path, "directory"), else: File.chmod!(path, 0o700)
  end

  def private_file!(path) do
    unless File.lstat!(path).type == :regular,
      do: raise(Error, "Private file must be a regular file.")

    if os() == "windows", do: secure_windows!(path, "file"), else: File.chmod!(path, 0o600)
  end

  # New files inside a protected Windows directory inherit its private ACL.
  def private_created_file!(path) do
    if os() == "windows", do: :ok, else: File.chmod!(path, 0o600)
  end

  def replace_file!(source, destination) do
    if os() == "windows" do
      case System.cmd(
             python(),
             [
               "-I",
               "-c",
               "import os,sys; os.replace(sys.argv[1], sys.argv[2])",
               Path.expand(source),
               Path.expand(destination)
             ],
             stderr_to_stdout: true
           ) do
        {_, 0} -> :ok
        _ -> raise Error, "Could not atomically replace the Windows state file."
      end
    else
      File.rename!(source, destination)
    end
  end

  # Windows mode bits do not establish a private ACL. Use the current token SID,
  # not an interpolated username; pass paths separately through the environment.
  defp secure_windows!(path, kind) do
    run_powershell!(
      ~S"""
      $sid = [System.Security.Principal.WindowsIdentity]::GetCurrent().User
      $system = [System.Security.Principal.SecurityIdentifier]'S-1-5-18'
      if ($env:CHORUSDRAFT_PRIVATE_KIND -eq 'directory') {
        $acl = New-Object System.Security.AccessControl.DirectorySecurity
        foreach ($identity in @($sid, $system)) {
          $rule = New-Object System.Security.AccessControl.FileSystemAccessRule($identity, 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow')
          $acl.AddAccessRule($rule)
        }
      } else {
        $acl = New-Object System.Security.AccessControl.FileSecurity
        foreach ($identity in @($sid, $system)) {
          $rule = New-Object System.Security.AccessControl.FileSystemAccessRule($identity, 'FullControl', 'Allow')
          $acl.AddAccessRule($rule)
        }
      }
      $acl.SetAccessRuleProtection($true, $false)
      Set-Acl -LiteralPath $env:CHORUSDRAFT_PRIVATE_PATH -AclObject $acl
      """,
      [
        {"CHORUSDRAFT_PRIVATE_PATH", Path.expand(path)},
        {"CHORUSDRAFT_PRIVATE_KIND", kind}
      ],
      "Could not secure Windows file permissions."
    )
  end

  defp run_powershell!(script, env, message) do
    shell =
      System.find_executable("pwsh.exe") || System.find_executable("powershell.exe") ||
        raise(Error, "PowerShell is required for secure Windows storage.")

    script =
      "$ErrorActionPreference = 'Stop'\ntry {\n" <>
        script <>
        ~S"""
        } catch {
          [Console]::Out.WriteLine('CHORUSDRAFT_ERROR_TYPE=' + $_.Exception.GetType().FullName)
          [Console]::Out.WriteLine('CHORUSDRAFT_ERROR_CODE=' + $_.Exception.HResult)
          exit 1
        }
        """

    encoded = script |> :unicode.characters_to_binary(:utf8, {:utf16, :little}) |> Base.encode64()

    case System.cmd(shell, ["-NoProfile", "-NonInteractive", "-EncodedCommand", encoded],
           env: env,
           stderr_to_stdout: true
         ) do
      {_, 0} ->
        :ok

      {output, _} ->
        detail =
          output
          |> String.split(~r/\R/)
          |> Enum.filter(&String.starts_with?(&1, "CHORUSDRAFT_ERROR_"))
          |> Enum.join(" ")

        raise Error, if(detail == "", do: message, else: message <> " " <> detail)
    end
  end
end
