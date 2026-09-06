# ChorusDraft

ChorusDraft 0.51.3 ships supported **Ruby and Elixir implementations** for
Bluesky and Mastodon on Linux, macOS, and Windows. Both write comic social
drafts, keep AI output in a local review queue, and require exact interactive
approval before publication.

**Version 0.51.3** · Ruby 4.0+ or Elixir/Erlang · Linux, macOS, and Windows

[Release notes](RELEASE_NOTES.md) · [Changelog](CHANGELOG.md) ·
[Security policy](SECURITY.md) · [Elixir documentation](elixir/README.md)

## Choose an implementation

| Implementation | Package layout | Best fit |
|---|---|---|
| Ruby 0.51.3 | Separate Bluesky and Mastodon archives for each OS | The established runtime, existing Ruby installs, and one-platform deployments |
| Elixir 0.51.3 | One archive per OS containing both platform modes | A combined deployment and optional Bluesky Jetstream wake-ups |

Both implementations are current releases. Do not run both against the same
account simultaneously or share a live state directory between them.

## Shared features and safeguards

- Bluesky and Mastodon login, feeds, search, mentions, replies, quotes, original
  drafts, target/discovery commentary, interactive review, and deletion.
- Local Ollama/OpenAI-compatible models and Google Gemini.
- Short commands such as `draft`, `review`, `start`, `reply`, `quote`, and
  `search`, plus the complete advanced flag interface.
- Account-scoped queues and history, atomic state updates, opt-outs,
  do-not-contact lists, and interaction budgets.
- AI output cannot bypass the review queue. Short commands never add direct
  publication permission.
- Private or direct Mastodon bodies are discarded before AI, logs, or state.
- Harassment, threats, doxxing, coordinated pile-ons, self-harm encouragement,
  and common direct personal attacks are rejected before staging and checked
  again before publication.
- Automatic likes, favourites, boosts, and reposts are disabled.
- Publication requests are not automatically retried. Ambiguous results become
  `uncertain` and require manual account inspection.

These controls reduce risk but do not replace operator judgment. Review every
draft in its full context before approval.

## Requirements

| Package | Runtime requirements |
|---|---|
| Ruby, all platforms | Ruby 4.0 or newer |
| Elixir, Linux | Erlang/OTP 25+ and util-linux (`flock`) |
| Elixir, macOS | Erlang/OTP 25+ and Python 3 |
| Elixir, Windows | Erlang/OTP 25+, Python 3, and PowerShell |
| Elixir source build | Elixir 1.15+, Mix, and Erlang/OTP 25+ |

An account connection requires a Bluesky app password or Mastodon access token.
AI drafting requires a local AI endpoint or a Gemini API key and model.

## Release packages

Ruby publishes separate application archives:

- `chorusdraft-bluesky-v0.51.3-linux.tar.gz`
- `chorusdraft-bluesky-v0.51.3-macos.tar.gz`
- `chorusdraft-bluesky-v0.51.3-windows.zip`
- `chorusdraft-mastodon-v0.51.3-linux.tar.gz`
- `chorusdraft-mastodon-v0.51.3-macos.tar.gz`
- `chorusdraft-mastodon-v0.51.3-windows.zip`
- `SHA256SUMS`

Elixir publishes one application containing both platform modes:

- `ChorusDraft-elixir-0.51.3-linux.tar.gz`
- `ChorusDraft-elixir-0.51.3-macos.tar.gz`
- `ChorusDraft-elixir-0.51.3-windows.zip`
- one adjacent `.sha256` file per archive

Verify the supplied SHA-256 checksum before extracting a package.

## Run the Ruby release

Extract the archive matching the social platform and operating system. From the
extracted directory:

```sh
./bot setup
./bot search "open source"
./bot draft
./bot review
```

Windows packages use `bot.bat`. Setup creates `.env` only when it is missing and
never starts the bot. Edit `.env` before connecting an account.

Useful commands include:

| Command | Behavior |
|---|---|
| `draft` | Generate and queue one original AI draft |
| `review` | Review pending drafts interactively |
| `post "TEXT"` | Queue owner-written text |
| `reply ID "TEXT"` | Queue an owner-written reply |
| `quote ID "TEXT"` | Queue owner-written quote commentary |
| `search "QUERY"` | Display matching public posts without drafting |
| `replies` | Fetch eligible public mentions and queue reply drafts |
| `start` | Run the foreground polling daemon |

## Run the Elixir release

The packaged executable needs Erlang/OTP but does not need Ruby or an installed
Elixir toolchain. Linux/macOS examples:

```sh
./install.sh /absolute/path/to/chorusdraft-0.51.3
/absolute/path/to/chorusdraft-0.51.3/run.sh bluesky setup
/absolute/path/to/chorusdraft-0.51.3/run.sh bluesky draft
/absolute/path/to/chorusdraft-0.51.3/run.sh bluesky review
/absolute/path/to/chorusdraft-0.51.3/run.sh mastodon search "open source"
```

On Windows, use `install.ps1`, `setup.ps1`, and `run.ps1`. The installer refuses
an existing destination. In-place setup preserves existing configuration and
never starts a bot.

Optional Bluesky Jetstream wake-ups are available only in the Elixir runtime:

```sh
./run.sh bluesky start --jetstream
```

Stream events wake the ordinary notification workflow. Raw streamed bodies do
not enter AI context, terminal output, or state. API fetching, opt-outs,
deduplication, active hours, queue limits, and review still apply.

## Build and verify from source

Ruby 4.0+:

```sh
ruby -Itest -e 'Dir["test/*_test.rb"].sort.each { |file| require_relative file }'
ruby scripts/build_release.rb
python3 scripts/verify_release.py
```

Elixir 1.15+:

```sh
cd elixir
mix deps.get
mix format --check-formatted
mix test --warnings-as-errors
MIX_ENV=prod mix run scripts/build_release.exs
./scripts/check_packages.sh
```

GitHub Actions tests Ruby packages on Ubuntu, both Intel and ARM macOS, and
Windows. Elixir packages are tested on Ubuntu, macOS, and Windows. Checks cover
archive integrity, native launchers, setup behavior, private configuration,
runtime-data exclusion, both platform clients, and offline safety regressions.

Automated fixtures do not establish live-service acceptance. Test login,
read-only search, staging, review, publication, deletion, opt-outs, and reconnect
behavior with disposable accounts before production use.

## License

ChorusDraft is licensed under GPLv3. See [LICENSE](LICENSE), [NOTICE](NOTICE), and
[Elixir third-party notices](elixir/THIRD_PARTY_NOTICES.md).
