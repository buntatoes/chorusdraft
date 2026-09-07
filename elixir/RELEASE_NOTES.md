# ChorusDraft for Elixir — 0.51.3 preview

ChorusDraft now uses Elixir for both Bluesky and Mastodon. The desktop download
includes a React launcher; choose a social platform to set up, draft, review,
search, or monitor. Ruby is no longer included in new preview packages.

Desktop **Settings** accepts account and AI credentials using masked fields.
**Save securely** uses operating-system protected storage; **Use for this session**
keeps newly entered settings in memory when persistent secure storage is
unavailable. GUI credentials apply to GUI launches. Secure saving removes only
managed fields from the selected platform's `.env`, preserving advanced settings.

**History** provides searchable local published posts and GUI activity with a
copy action. Completed published and rejected records expire after 10 days;
activity files expire within 10 days and may rotate sooner at 50 MB. Cleanup runs
while the app is open and at its next launch. Pending and uncertain drafts,
opt-outs, and safety state remain retained separately. ChorusDraft does not upload
history, and local expiry does not remove social posts or external backups.

Short commands include `setup`, `draft`, `review`, `post`, `reply`, `quote`,
`replies`, `search`, `random`, `discover`, `targets`, `start`, `listen`, `delete`,
`history`, `status`, `import FILE`, `reject ID`, `help`, and `version`.
Existing flags and optional Bluesky Jetstream monitoring remain available.
Every AI-generated draft requires individual review before publication.

Packaged bots require Erlang/OTP 25+. Linux uses `flock`; macOS and Windows
require Python 3 for state locking. Build from source with Elixir 1.15+ and Mix.
The preview executable reports `0.51.3-testing`.

Setup preserves existing configuration. Each platform uses its own folder under
`elixir/` in desktop downloads, or the platform folder in standalone bot packages.
See [README.md](README.md) for local retention, command-line configuration, and
explicit import of compatible legacy state.
