defmodule ChorusDraft.Setup do
  def run([platform]) when platform in ["bluesky", "mastodon"] do
    base = Path.expand(platform, __DIR__)
    File.mkdir_p!(Path.join(base, "config"))
    File.chmod(Path.join(base, "config"), 0o700)

    [
      {".env.example", ".env"},
      {"config/target_accounts.txt.example", "config/target_accounts.txt"},
      {"config/do_not_contact.txt.example", "config/do_not_contact.txt"}
    ]
    |> Enum.each(fn {source, destination} -> copy_new(base, source, destination) end)

    IO.puts("Setup complete. Edit #{platform}/.env, then run ./chorusdraft #{platform} --help. No services were started.")
  end

  def run(_), do: raise("Usage: elixir setup.exs bluesky|mastodon")

  defp copy_new(base, source, destination) do
    target = Path.join(base, destination)

    case File.open(target, [:write, :exclusive]) do
      {:ok, io} ->
        IO.binwrite(io, File.read!(Path.join(base, source)))
        File.close(io)
        File.chmod!(target, 0o600)
        IO.puts("Created #{destination}")

      {:error, :eexist} ->
        IO.puts("Preserved existing #{destination}")

      {:error, reason} ->
        raise "Could not create #{destination}: #{inspect(reason)}"
    end
  end
end

ChorusDraft.Setup.run(System.argv())
