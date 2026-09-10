# ChorusDraft 0.53.0

Downloads: [GitHub Releases](https://github.com/buntatoes/chorusdraft/releases).

Publication screening is now proprietary ChorusDraft Guard. Official builds
include it. The Apache-licensed bot loads Guard through `ChorusDraft.Safety`
and `ChorusDraft.PII` and refuses to run if Guard is missing.

Default install locations:

- Linux: `~/.local/share/chorusdraft-0.53.0`
- macOS: `~/Library/Application Support/chorusdraft-0.53.0` (with ChorusDraft in Applications)
- Windows: `%LOCALAPPDATA%\ChorusDraft-0.53.0` (with a Start menu shortcut)

Pass a path when you want a custom install directory. CLI-only packages still
use the same install scripts for the bot; they do not launch a GUI.

Details: [CHANGELOG.md](CHANGELOG.md).

## Packages

CLI:

- `ChorusDraft-elixir-0.53.0-linux.tar.gz`
- `ChorusDraft-elixir-0.53.0-macos.tar.gz`
- `ChorusDraft-elixir-0.53.0-windows.zip`

Desktop (`chorusdraft-v0.53.0-<os>-<arch>`, `.tar.gz` on Unix, `.zip` on
Windows) includes the Elixir bot and the launcher.

Each archive has the executable, setup/install/verify scripts, config
examples, docs, application source, Guard, pinned dependency source and
licenses, a manifest, and a SHA-256 sidecar. Stop the old process, then import
state if you need it.
