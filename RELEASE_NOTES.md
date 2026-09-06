# ChorusDraft 0.51.3 preview

Version 0.51.3 brings Ruby and Elixir together in one download with a React desktop GUI
launcher for Linux, macOS, and Windows. This version is not yet a stable release.

## Launch a bot

Run `./bot` on Linux, double-click `bot.command` on macOS, or double-click
`bot.bat` on Windows. Choose Ruby or Elixir and Bluesky or Mastodon. Use the action buttons to set up,
draft, review, search, or monitor. Open configuration edits the selected bot’s
settings.

The desktop window displays activity and interactive review prompts. Send review
responses through its input field. Drafts remain queued until you approve them.
Use **Stop session** to end monitoring. Packaged builds include the GUI runtime.

## Commands and compatibility

Both implementations support `setup`, `draft`, `review`, `post`, `reply`, `quote`,
`replies`, `search`, `random`, `discover`, `targets`, `start`, `listen`, `delete`,
`help`, and `version`. Direct commands use
`./bot ruby|elixir bluesky|mastodon COMMAND`; Windows uses `.\bot.bat`.
Existing Ruby shorthand and both implementations' flags remain supported.

Ruby requires 4.0+. Packaged Elixir requires Erlang/OTP 25+, plus `flock` on Linux
or Python 3 on macOS/Windows. Build Elixir sources with Elixir 1.15+ and Mix.

## Upgrading

Stop the previous bot and back up its configuration and complete `data`
directory. Extract the new package into a new directory. Preserve each
implementation's configuration and state in its corresponding platform folder.
Run only one bot per social account. Choosing another implementation in the launcher
does not migrate state; use the documented Elixir import command when needed.

The build identifier is `0.51.3-testing` during preview testing.
See [README.md](README.md) for launch instructions and configuration locations.

On Ubuntu systems with restricted user namespaces, the combined Linux download
includes `launcher-source/linux_sandbox.py` for one-time, path-specific sandbox
setup. See the README before launching.
