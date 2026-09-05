defmodule ChorusDraft.Package do
  @documents ~w(README.md RELEASE_NOTES.md SECURITY.md PARITY.md NOTICE THIRD_PARTY_NOTICES.md VERSION CHANGELOG.md)

  def build do
    unless Mix.env() == :prod, do: raise("Build with MIX_ENV=prod mix run scripts/build_release.exs")
    Mix.Task.run("escript.build")
    root = File.cwd!()
    license = if File.regular?("LICENSE"), do: "LICENSE", else: "../LICENSE"
    dist = Path.join(root, "dist")
    File.mkdir_p!(dist)
    work = Path.join(dist, ".package-#{System.unique_integer([:positive])}")
    File.mkdir!(work)

    try do
      for {platform, product} <- [{"bluesky", "BlueBot"}, {"mastodon", "Mastobot"}] do
        name = "#{product}-elixir-#{ChorusDraft.version()}-linux"
        package = Path.join(work, name)
        File.mkdir!(package)
        for file <- @documents -- ["CHANGELOG.md"], do: copy(root, package, file)
        File.cp!(Path.join(root, license), Path.join(package, "LICENSE"))
        copy(root, package, "chorusdraft")
        copy(Path.join(root, platform), package, ".env.example")
        for file <- ~w(target_accounts.txt.example do_not_contact.txt.example),
          do: copy(Path.join(root, platform), package, "config/" <> file)
        File.cp!(Path.join(root, "scripts/install.sh"), Path.join(package, "install.sh"))
        File.write!(Path.join(package, "run.sh"), launcher(platform, ""))
        File.write!(Path.join(package, "setup.sh"), launcher(platform, "--setup "))
        for file <- ~w(chorusdraft run.sh setup.sh install.sh),
          do: File.chmod!(Path.join(package, file), 0o755)

        source = Path.join(package, "source")
        File.mkdir!(source)
        for file <- @documents ++ ~w(mix.exs mix.lock .formatter.exs setup.exs), do: copy(root, source, file)
        File.cp!(Path.join(root, license), Path.join(source, "LICENSE"))
        for dir <- ~w(lib test scripts), do: copy_tree(root, source, dir)
        for platform <- ~w(bluesky mastodon) do
          copy(root, source, platform <> "/.env.example")
          for file <- ~w(target_accounts.txt.example do_not_contact.txt.example),
            do: copy(root, source, platform <> "/config/" <> file)
        end
        # Resolved Hex dependency source and license/notice files travel with the
        # executable. Build caches, bytecode and runtime configuration never do.
        for {_app, path} <- Mix.Project.deps_paths() do
          relative = "deps/" <> Path.basename(path)
          copy_tree(root, source, relative, dependency: true)
        end
        files = regular_files(package)
        manifest = Enum.map_join(files, "\n", fn file ->
          digest = File.read!(Path.join(package, file)) |> then(&:crypto.hash(:sha256, &1)) |> Base.encode16(case: :lower)
          digest <> "  " <> file
        end) <> "\n"
        File.write!(Path.join(package, "MANIFEST.sha256"), manifest)
        archive = Path.join(dist, name <> ".tar.gz")
        {_, 0} = System.cmd("tar", ["-czf", archive, "-C", work, name], stderr_to_stdout: true)
        digest = File.read!(archive) |> then(&:crypto.hash(:sha256, &1)) |> Base.encode16(case: :lower)
        File.write!(archive <> ".sha256", digest <> "  " <> Path.basename(archive) <> "\n")
        IO.puts("Built #{archive}")
      end
    after
      File.rm_rf!(work)
    end
  end

  defp launcher(platform, extra) do
    "#!/bin/sh\nset -eu\numask 077\nbase=$(CDPATH= cd -- \"$(dirname -- \"$0\")\" && pwd)\nexec \"$base/chorusdraft\" #{platform} --base \"$base\" #{extra}\"$@\"\n"
  end

  defp copy(root, destination, file) do
    source = Path.join(root, file)
    unless File.lstat!(source).type == :regular, do: raise("Package input must be a regular file: #{file}")
    target = Path.join(destination, file)
    File.mkdir_p!(Path.dirname(target))
    File.cp!(source, target)
  end

  defp copy_tree(root, destination, relative, opts \\ []) do
    path = Path.join(root, relative)
    unless File.lstat!(path).type == :directory, do: raise("Package source directory cannot be a symlink")
    for entry <- File.ls!(path) |> Enum.sort() do
      excluded = entry in [".git", "_build", "ebin", ".fetch"] or
        String.ends_with?(entry, [".beam", ".ez", ".tmp"])
      forbidden = entry in [".env", "data", "logs"]
      unless excluded do
        if forbidden, do: raise("Unexpected runtime data in package source")
        file = Path.join(relative, entry)
        case File.lstat!(Path.join(root, file)).type do
          :directory -> copy_tree(root, destination, file, opts)
          :regular -> copy(root, destination, file)
          _ -> raise("Package source cannot contain symlinks or special files")
        end
      end
    end
  end

  defp regular_files(root, relative \\ "") do
    Enum.flat_map(File.ls!(Path.join(root, relative)) |> Enum.sort(), fn entry ->
      path = Path.join(relative, entry)
      if File.dir?(Path.join(root, path)), do: regular_files(root, path), else: [path]
    end)
  end
end

ChorusDraft.Package.build()
