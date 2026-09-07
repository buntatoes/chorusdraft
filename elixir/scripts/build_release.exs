defmodule ChorusDraft.Package do
  @documents ~w(README.md RELEASE_NOTES.md SECURITY.md NOTICE THIRD_PARTY_NOTICES.md VERSION CHANGELOG.md)
  @platforms ~w(bluesky mastodon)

  def build do
    unless Mix.env() == :prod,
      do: raise("Build with MIX_ENV=prod mix run scripts/build_release.exs")

    Mix.Task.run("escript.build")
    root = File.cwd!()
    license = if File.regular?("LICENSE"), do: "LICENSE", else: "../LICENSE"
    dist = Path.join(root, "dist")
    File.mkdir_p!(dist)
    work = Path.join(dist, ".package-#{System.unique_integer([:positive])}")
    File.mkdir!(work)

    try do
      os = ChorusDraft.Platform.os()
      name = "ChorusDraft-elixir-#{ChorusDraft.version()}-#{os}"
      package = Path.join(work, name)
      File.mkdir!(package)

      for file <- @documents, do: copy(root, package, file)
      File.cp!(Path.join(root, license), Path.join(package, "LICENSE"))
      copy(root, package, "chorusdraft")

      if os == "windows" do
        for file <- ~w(run.ps1 setup.ps1 install.ps1 verify.ps1),
            do: File.cp!(Path.join(root, "scripts/" <> file), Path.join(package, file))
      else
        File.cp!(Path.join(root, "scripts/install.sh"), Path.join(package, "install.sh"))
        File.write!(Path.join(package, "run.sh"), run_launcher())
        File.write!(Path.join(package, "setup.sh"), setup_launcher())
      end

      for platform <- @platforms do
        copy(root, package, platform <> "/.env.example")

        for file <- ~w(target_accounts.txt.example do_not_contact.txt.example),
            do: copy(root, package, platform <> "/config/" <> file)
      end

      if os != "windows" do
        for file <- ~w(chorusdraft run.sh setup.sh install.sh),
            do: File.chmod!(Path.join(package, file), 0o755)
      end

      source = Path.join(package, "source")
      File.mkdir!(source)

      for file <- @documents ++ ~w(mix.exs mix.lock .formatter.exs setup.exs),
          do: copy(root, source, file)

      File.cp!(Path.join(root, license), Path.join(source, "LICENSE"))
      for dir <- ~w(lib test scripts), do: copy_tree(root, source, dir)

      for platform <- @platforms do
        copy(root, source, platform <> "/.env.example")

        for file <- ~w(target_accounts.txt.example do_not_contact.txt.example),
            do: copy(root, source, platform <> "/config/" <> file)
      end

      for {_app, path} <- Mix.Project.deps_paths() do
        relative = "deps/" <> Path.basename(path)
        copy_tree(root, source, relative)
      end

      files = regular_files(package)

      manifest =
        Enum.map_join(files, "\n", fn file ->
          digest =
            File.read!(Path.join(package, file))
            |> then(&:crypto.hash(:sha256, &1))
            |> Base.encode16(case: :lower)

          digest <> "  " <> file
        end) <> "\n"

      File.write!(Path.join(package, "MANIFEST.sha256"), manifest)
      archive = Path.join(dist, name <> if(os == "windows", do: ".zip", else: ".tar.gz"))

      File.cd!(work, fn ->
        if os == "windows" do
          entries = regular_files(package) |> Enum.map(&String.to_charlist(name <> "/" <> &1))
          {:ok, _} = :zip.create(String.to_charlist(archive), entries)
        else
          :ok =
            :erl_tar.create(String.to_charlist(archive), [String.to_charlist(name)], [:compressed])
        end
      end)

      digest =
        File.read!(archive) |> then(&:crypto.hash(:sha256, &1)) |> Base.encode16(case: :lower)

      File.write!(archive <> ".sha256", digest <> "  " <> Path.basename(archive) <> "\n")
      IO.puts("Built #{archive}")
    after
      File.rm_rf!(work)
    end
  end

  defp run_launcher do
    """
    #!/bin/sh
    set -eu
    umask 077
    base=$(CDPATH= cd "$(dirname "$0")" && pwd)
    if [ "$#" -lt 1 ]; then
      echo 'Usage: ./run.sh bluesky|mastodon [options]' >&2
      exit 1
    fi
    platform=$1
    shift
    case "$platform" in
      bluesky|mastodon) ;;
      *) echo 'Choose bluesky or mastodon.' >&2; exit 1 ;;
    esac
    exec "$base/chorusdraft" "$platform" --base "$base/$platform" "$@"
    """
  end

  defp setup_launcher do
    """
    #!/bin/sh
    set -eu
    umask 077
    base=$(CDPATH= cd "$(dirname "$0")" && pwd)
    if [ "$#" -eq 0 ]; then
      "$base/chorusdraft" bluesky --base "$base/bluesky" --setup
      exec "$base/chorusdraft" mastodon --base "$base/mastodon" --setup
    fi
    platform=$1
    shift
    case "$platform" in
      bluesky|mastodon) ;;
      *) echo 'Usage: ./setup.sh [bluesky|mastodon]' >&2; exit 1 ;;
    esac
    exec "$base/chorusdraft" "$platform" --base "$base/$platform" --setup "$@"
    """
  end

  defp copy(root, destination, file) do
    source = Path.join(root, file)

    unless File.lstat!(source).type == :regular,
      do: raise("Package input must be a regular file: #{file}")

    target = Path.join(destination, file)
    File.mkdir_p!(Path.dirname(target))
    File.cp!(source, target)
  end

  defp copy_tree(root, destination, relative) do
    path = Path.join(root, relative)

    unless File.lstat!(path).type == :directory,
      do: raise("Package source directory cannot be a symlink")

    for entry <- File.ls!(path) |> Enum.sort() do
      excluded =
        entry in [".git", "_build", "ebin", ".fetch"] or
          String.ends_with?(entry, [".beam", ".ez", ".tmp"])

      forbidden = entry in [".env", "data", "logs"]

      unless excluded do
        if forbidden, do: raise("Unexpected runtime data in package source")
        file = Path.join(relative, entry)

        case File.lstat!(Path.join(root, file)).type do
          :directory -> copy_tree(root, destination, file)
          :regular -> copy(root, destination, file)
          _ -> raise("Package source cannot contain symlinks or special files")
        end
      end
    end
  end

  defp regular_files(root, relative \\ "") do
    Enum.flat_map(File.ls!(Path.join(root, relative)) |> Enum.sort(), fn entry ->
      path = Path.join(relative, entry)

      if File.dir?(Path.join(root, path)),
        do: regular_files(root, path),
        else: [String.replace(path, "\\", "/")]
    end)
  end
end

ChorusDraft.Package.build()
