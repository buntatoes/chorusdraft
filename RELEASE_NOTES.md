# ChorusDraft 0.51.3 preview

Version 0.51.3 uses Elixir for Bluesky and Mastodon, with a React desktop launcher
for Linux, macOS, and Windows. Ruby is no longer included in new preview packages.
The build identifier is `0.51.3-testing`. This development build is separate from
the published stable releases.

## Desktop workflow

Run `./bot` on Linux, double-click `bot.command` on macOS, or double-click
`bot.bat` on Windows. Choose Bluesky or Mastodon and use the action buttons to
set up, draft, review, search, or monitor. Every AI-generated post still requires
individual approval. Use **Stop session** to end monitoring.

**Settings** accepts social account and AI credentials directly. **Save securely**
uses operating-system protected storage; when it is unavailable, **Use for this
session** keeps newly entered settings in memory. Saved secrets are masked and
are not shown again. GUI credentials apply to GUI launches. Secure saving removes
only the form's managed fields from that platform's `.env`, leaving advanced
settings intact. Separate CLI launches continue to use environment variables or
`.env`.

**History** provides searchable published posts and GUI activity, with **Copy post**
for recalling text. Post records and individual activity events expire after 10 days. Activity is
grouped in hourly files and may rotate sooner at 50 MB. Cleanup runs while
the app is open and at its next launch. Pending drafts, uncertain publications,
and safety state remain intact. History is stored locally and is not uploaded by
ChorusDraft. Local expiry does not delete social posts or copies made by backups,
sync tools, or external log capture.

## Requirements and commands

Desktop packages include the GUI and bridge runtimes. The bot requires
Erlang/OTP 25+, plus `flock` on Linux or Python 3 on macOS and Windows.
Build the bot from source with Elixir 1.15+ and Mix.

Direct commands use `./bot bluesky|mastodon COMMAND`; Windows uses `.\bot.bat`.
Existing Elixir flags and the explicit `./bot elixir PLATFORM COMMAND` form remain
supported. The former Ruby shorthand now launches Elixir. `history` reads local
published-post records; `status`, `import FILE`, and `reject ID` manage account
state. Optional Bluesky Jetstream monitoring remains available.

## Upgrading

Stop the previous bot and install into a new directory. Preserve the complete
account state and configuration as described in the
[Elixir upgrade guide](elixir/README.md#upgrade-or-import-legacy-state).
Compatible Ruby state requires explicit import; changing the launcher does not
migrate it automatically. Run only one bot per social account. Protect any backup
and manage its retention separately from the app.

See the [desktop guide](docs/DESKTOP.md) for launch instructions, local storage locations, and
source builds. Linux systems with restricted user namespaces may require the
included `launcher-source/linux_sandbox.py` setup before opening the desktop GUI.
