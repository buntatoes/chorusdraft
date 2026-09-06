# ChorusDraft for Elixir — 0.51.3 preview

The Elixir implementation is included in the combined ChorusDraft download.
Choose **Elixir** from the root launcher, then **Bluesky** or **Mastodon**.

Short commands now match the Ruby workflow: `setup`, `draft`, `review`, `post`,
`reply`, `quote`, `replies`, `search`, `random`, `discover`, `targets`, `start`,
`listen`, `delete`, `help`, and `version`. Existing flags remain supported.
Elixir also supports `status`, `import FILE`, `reject ID`, and optional Bluesky
Jetstream monitoring.

Packaged builds require Erlang/OTP 25+. Linux uses `flock`; macOS and Windows
require Python 3 for state locking. Build from source with Elixir 1.15+ and Mix.
The preview executable reports `0.51.3-testing`.

Setup preserves existing configuration. Each platform uses its own folder under
`elixir/`. Ruby and Elixir state must remain separate; see [README.md](README.md)
for state import and upgrade instructions. Every AI draft requires review before
publication.
