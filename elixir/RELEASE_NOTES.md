# ChorusDraft 0.52.1

Downloads: [GitHub Releases](https://github.com/buntatoes/chorusdraft/releases).

Patch release. `./install.sh` and `install.ps1` no longer need a destination
argument. Run them from the extracted package and they install into a versioned
folder under your user data directory, then run setup.

Default locations:

- Linux: `~/.local/share/chorusdraft-0.52.1`
- macOS: `~/Library/Application Support/chorusdraft-0.52.1`
- Windows: `%LOCALAPPDATA%\ChorusDraft-0.52.1`

Pass a path when you want a custom install directory.

Details: [CHANGELOG.md](CHANGELOG.md).

## Packages

CLI:

- `ChorusDraft-elixir-0.52.1-linux.tar.gz`
- `ChorusDraft-elixir-0.52.1-macos.tar.gz`
- `ChorusDraft-elixir-0.52.1-windows.zip`

Desktop (`chorusdraft-v0.52.1-<os>-<arch>`, `.tar.gz` on Unix, `.zip` on
Windows) includes the Elixir bot and the launcher.

Each archive has the executable, setup/install/verify scripts, config
examples, docs, application source, pinned dependency source and licenses, a
manifest, and a SHA-256 sidecar. Stop the old process, then import state if
you need it.
