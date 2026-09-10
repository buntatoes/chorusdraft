# ChorusDraft 0.53.1

Downloads: [GitHub Releases](https://github.com/buntatoes/chorusdraft/releases).

0.53.1 is the current published GitHub Release. Earlier GitHub Releases and
tags were withdrawn and are not downloadable.

Patch release: review-driven fixes and hardening. The CLI now disables Erlang
crash dumps so an interactive crash cannot write credentials or session tokens
to disk, Mastodon streaming resets its reconnect backoff after a stable
session, `--history` is a read-only operation, and the desktop publish button
arms only from the bot's structured review event. Installers handle paths
with spaces, re-verify the installed copy, and release archives are
reproducible. See [CHANGELOG.md](CHANGELOG.md) for the full list.

Publication screening remains proprietary ChorusDraft Guard. Official builds
include it. The Apache-licensed bot loads Guard through `ChorusDraft.Safety`
and `ChorusDraft.PII` and refuses to run if Guard is missing.

Default install locations:

- Linux: `~/.local/share/chorusdraft-0.53.1`
- macOS: `~/Library/Application Support/chorusdraft-0.53.1` (with ChorusDraft in Applications)
- Windows: `%LOCALAPPDATA%\ChorusDraft-0.53.1` (with a Start menu shortcut)

Pass a path when you want a custom install directory. CLI-only packages still
use the same install scripts for the bot; they do not launch a GUI.

## Packages

CLI:

- `ChorusDraft-elixir-0.53.1-linux.tar.gz`
- `ChorusDraft-elixir-0.53.1-macos.tar.gz`
- `ChorusDraft-elixir-0.53.1-windows.zip`

Desktop (`chorusdraft-v0.53.1-<os>-<arch>`, `.tar.gz` on Unix, `.zip` on
Windows) includes the Elixir bot and the launcher.

Each archive has the executable, setup/install/verify scripts, config
examples, docs, application source, Guard, pinned dependency source and
licenses, a manifest, and a SHA-256 sidecar. Stop the old process, then import
state if you need it.
