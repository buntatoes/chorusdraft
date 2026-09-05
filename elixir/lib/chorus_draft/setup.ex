defmodule ChorusDraft.Setup do
  alias ChorusDraft.Error

  def run(base) do
    File.mkdir_p!(base)
    File.chmod!(base, 0o700)
    config = Path.join(base, "config")
    File.mkdir_p!(config)
    unless File.lstat!(config).type == :directory,
      do: raise(Error, "Configuration directory must not be a symlink.")
    File.chmod!(config, 0o700)

    for {source, destination} <- [
      {".env.example", ".env"},
      {"config/target_accounts.txt.example", "config/target_accounts.txt"},
      {"config/do_not_contact.txt.example", "config/do_not_contact.txt"}
    ] do
      target = Path.join(base, destination)
      content = File.read!(Path.join(base, source))
      case File.open(target, [:write, :binary, :exclusive]) do
        {:ok, io} ->
          try do
            File.chmod!(target, 0o600)
            IO.binwrite(io, content)
          after
            File.close(io)
          end
          IO.puts("Created #{destination}")
        {:error, :eexist} ->
          unless File.lstat!(target).type == :regular,
            do: raise(Error, "Existing configuration must be a regular file.")
          IO.puts("Preserved existing #{destination}")
        {:error, _} -> raise Error, "Could not create configuration."
      end
    end
    IO.puts("Setup complete. Edit .env before running a command. No service was started.")
  end
end
