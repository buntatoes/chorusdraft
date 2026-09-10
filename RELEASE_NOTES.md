# ChorusDraft 0.53.2

Downloads: [GitHub Releases](https://github.com/buntatoes/chorusdraft/releases).

0.53.2 is the current published GitHub Release. Earlier GitHub Releases and
tags were withdrawn and are not downloadable.

Draft and automatic mode talk to Bluesky’s AppView and the account PDS from
the session DID document, so creating a draft no longer 404s against
`bsky.social`. If a local, Gemini, or OpenAI request still fails, the error
names the provider and model. A deleted post in a thread no longer aborts
mention drafting; the missing parent is skipped. The desktop app rejects
review input after the bot session ends instead of leaving the UI stuck on
"Session running". `service install` writes Windows Task Scheduler XML as
UTF-16 LE with a BOM so `schtasks /Create /XML` accepts it.

**Desktop (recommended).** Extract the archive, then run `./install.sh`
(double-click `Install ChorusDraft.command` on macOS) or `install.cmd` on
Windows. No install path is required. Run the installer again to update; your
account files stay. Then use **Open configuration** in the app.

Default install locations:

- Linux: `~/.local/share/chorusdraft`
- macOS: `~/Library/Application Support/chorusdraft-app` (with ChorusDraft in Applications)
- Windows: `%LOCALAPPDATA%\Programs\ChorusDraft` (with a Start menu shortcut)

Pass a path when you want a custom install directory.

## Packages

**Desktop (recommended).** GUI plus the bot. Download
`chorusdraft-v0.53.2-<os>-<arch>` (`.tar.gz` on Unix, `.zip` on Windows):

- Linux x64
- macOS arm64 (Apple Silicon)
- macOS x64 (Intel)
- Windows x64

**CLI only (no GUI).** Bot and terminal launchers only. These do not include
the desktop app and will not open a window:

- `ChorusDraft-elixir-0.53.2-linux.tar.gz`
- `ChorusDraft-elixir-0.53.2-macos.tar.gz`
- `ChorusDraft-elixir-0.53.2-windows.zip`

Each archive has setup/install/verify scripts, config examples, docs, Guard,
licenses, a manifest, and a SHA-256 sidecar. Desktop archives include the
launcher; they do not include GUI or Elixir rebuild source. Stop the old
process, then import state if you need it.
