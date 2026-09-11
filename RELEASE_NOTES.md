# ChorusDraft 0.54.0

Downloads: [GitHub Releases](https://github.com/buntatoes/chorusdraft/releases).

0.54.0 is the current published GitHub Release. Releases v0.50 through
v0.53.1 were withdrawn and are not downloadable. 0.53.2 remains available.

`review ID` and `--process-queue ID` review one pending draft. Desktop
review is a card from the `review` event (text, action, visibility, content
warning, reply, quote, id, status). Queue shows reply and quote targets,
**Review this draft**, and Bluesky and Mastodon pending/uncertain counts
with remaining automatic attempts and freeze. Compose uses a live 300/500
count, Mastodon `--cw`, reply id, and quote id, and still queues for
review. Overview starts **Discover**, **Targets**, and **Delete a post**;
search hits are cards. Settings includes `ACTIVE_HOURS`,
`DISCOVERY_KEYWORDS`, and the target and do-not-contact lists.

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
`chorusdraft-v0.54.0-<os>-<arch>` (`.tar.gz` on Unix, `.zip` on Windows):

- Linux x64
- macOS arm64 (Apple Silicon)
- macOS x64 (Intel)
- Windows x64

**CLI only (no GUI).** Bot and terminal launchers only. These do not include
the desktop app and will not open a window:

- `ChorusDraft-elixir-0.54.0-linux.tar.gz`
- `ChorusDraft-elixir-0.54.0-macos.tar.gz`
- `ChorusDraft-elixir-0.54.0-windows.zip`

Each archive has setup/install/verify scripts, config examples, docs, Guard,
licenses, a manifest, and a SHA-256 sidecar. Guard is signed with the ed25519
release key, and the bot checks the Guard code on disk against that signature
before it screens or publishes anything. Desktop archives include the
launcher; they do not include GUI or Elixir rebuild source. Stop the old
process, then import state if you need it.
