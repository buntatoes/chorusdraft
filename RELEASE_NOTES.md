# ChorusDraft 0.52.1

Downloads: [GitHub Releases](https://github.com/buntatoes/chorusdraft/releases).

Patch release. Desktop downloads include `./install.sh` and `install.ps1`.
Run either with no arguments from the extracted package and ChorusDraft
installs into a versioned folder under your user data directory, registers an
application entry, runs setup, and opens the desktop app.

Default locations:

- Linux: `~/.local/share/chorusdraft-0.52.1`
- macOS: `~/Library/Application Support/chorusdraft-0.52.1` (with ChorusDraft in Applications)
- Windows: `%LOCALAPPDATA%\ChorusDraft-0.52.1` (with a Start menu shortcut)

Pass a path when you want a custom install directory. CLI-only packages still
use the same install scripts for the bot; they do not launch a GUI.

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
