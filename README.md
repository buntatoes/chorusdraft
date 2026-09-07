# ChorusDraft

ChorusDraft 0.51.3 is a human-reviewed social drafting bot for Bluesky and
Mastodon. It is written in Elixir and ships as one application with both
platform modes.

It drafts original posts, replies, quotes, and public commentary with a dry,
playful voice. Every AI-generated draft enters a local review queue and requires
exact interactive approval before publication.

**Version 0.51.3** · Linux, macOS, and Windows · Elixir/Erlang runtime

[Release notes](RELEASE_NOTES.md) · [Changelog](CHANGELOG.md) ·
[Security policy](SECURITY.md) · [Detailed documentation](elixir/README.md)

## Features

- Bluesky and Mastodon login, public feeds, search, mentions, replies, quotes,
  original drafts, target/discovery commentary, and interactive deletion.
- Local Ollama/OpenAI-compatible models and Google Gemini.
- Short commands such as `draft`, `review`, `start`, `reply`, `quote`, and
  `search`, plus the complete advanced flag interface.
- Optional Bluesky Jetstream wake-ups with periodic notification catch-up.
- Account-scoped queues and history, atomic state updates, crash-released locks,
  opt-outs, do-not-contact lists, and interaction budgets.
- Separate verified packages for Linux, macOS, and Windows. Every package
  contains both Bluesky and Mastodon modes, checksums, source, and dependency
  license material.

## Requirements

| Platform | Runtime requirements |
|---|---|
| Linux | Erlang/OTP 25+ and util-linux (`flock`) |
| macOS | Erlang/OTP 25+ and Python 3 |
| Windows | Erlang/OTP 25+, Python 3, and PowerShell |
| Source build | Elixir 1.15+, Mix, and Erlang/OTP 25+ |

An account connection requires a Bluesky app password or Mastodon access token.
AI drafting requires a local AI endpoint or a Gemini API key and model. Packaged
executables need Erlang/OTP but do not need an installed Elixir toolchain.

## Release packages

- `ChorusDraft-elixir-0.51.3-linux.tar.gz`
- `ChorusDraft-elixir-0.51.3-macos.tar.gz`
- `ChorusDraft-elixir-0.51.3-windows.zip`

Each archive has an adjacent `.sha256` file. Verify the checksum before
extracting it.

Linux example:

```sh
sha256sum --check ChorusDraft-elixir-0.51.3-linux.tar.gz.sha256
tar -xzf ChorusDraft-elixir-0.51.3-linux.tar.gz
cd ChorusDraft-elixir-0.51.3-linux
./install.sh /absolute/path/to/chorusdraft-0.51.3
```

macOS uses `shasum -a 256 --check` with the macOS archive. On Windows, verify
with `Get-FileHash`, expand the archive, and run:

```powershell
.\install.ps1 C:\Apps\ChorusDraft-0.51.3
```

The installer refuses an existing destination. It creates missing configuration
files, preserves existing files during in-place setup, and never starts a bot.

## Configure and run

Edit `bluesky/.env` or `mastodon/.env` inside the installed directory. The
examples document every setting without containing credentials.

Linux and macOS examples:

```sh
./run.sh bluesky setup
./run.sh bluesky search "open source"
./run.sh bluesky draft
./run.sh bluesky review

./run.sh mastodon setup
./run.sh mastodon replies
./run.sh mastodon review
```

Use `run.ps1` in place of `run.sh` on Windows. Run `--help` for the complete
advanced interface.

| Command | Behavior |
|---|---|
| `draft` | Generate and queue one original AI draft |
| `review` | Review pending drafts interactively |
| `post "TEXT"` | Queue owner-written text |
| `reply ID "TEXT"` | Queue an owner-written reply |
| `quote ID "TEXT"` | Queue owner-written quote commentary |
| `search "QUERY"` | Display matching public posts without drafting |
| `replies` | Fetch eligible public mentions and queue reply drafts |
| `start` | Run the foreground daemon; Ctrl+C stops it |

Short commands never add direct-publication permission. Owner-written text can
be published directly only with the explicit advanced `--publish` flag.

## Safeguards

- AI output cannot bypass the local review queue.
- Private or direct Mastodon bodies are discarded before AI, logs, or state.
- Clear public requests to stop contact are recorded before reply generation.
- Do-not-contact checks cover authors and mentioned accounts.
- Harassment, threats, doxxing, coordinated pile-ons, self-harm encouragement,
  and common direct personal attacks are rejected before staging and checked
  again before publication.
- Unsolicited interactions are limited per day and per author.
- Automatic likes, favourites, boosts, and reposts are disabled.
- Publication requests are not automatically retried. Ambiguous results become
  `uncertain` and require manual account inspection.

These controls reduce risk but do not replace operator judgment. Review every
draft in its full context before approval.

## Bluesky Jetstream

Jetstream is optional for Bluesky listeners and daemons:

```sh
./run.sh bluesky start --jetstream
```

Stream events only wake the ordinary notification workflow. Raw streamed bodies
do not enter AI context, terminal output, or state. API fetching, opt-outs,
deduplication, active hours, queue limits, and review still apply. Mastodon and
Bluesky without `--jetstream` use polling.

## Source and verification

The application source is under [`elixir/`](elixir/). From that directory:

```sh
mix deps.get
mix format --check-formatted
mix test --warnings-as-errors
MIX_ENV=prod mix run scripts/build_release.exs
./scripts/check_packages.sh
```

GitHub Actions runs 65 offline tests and native package checks on Ubuntu 22.04,
macOS 14, and Windows Server 2022. Checks cover checksums, installation, private
configuration, overwrite refusal, runtime-data exclusion, both platform modes,
and an offline rebuild from shipped source.

Automated fixtures do not establish live-service acceptance. Test login,
read-only search, staging, review, publication, deletion, opt-outs, and reconnect
behavior with disposable accounts before production use.

## License

ChorusDraft is licensed under GPLv3. See [LICENSE](LICENSE), [NOTICE](NOTICE), and
[third-party notices](elixir/THIRD_PARTY_NOTICES.md).
