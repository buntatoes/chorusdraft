<p align="center">
  <img src="assets/chorusdraft-logo.png" alt="ChorusDraft" width="720">
</p>

# ChorusDraft

<p align="center">
  <a href="https://github.com/buntatoes/chorusdraft/actions/workflows/elixir.yml"><img alt="Elixir checks" src="https://github.com/buntatoes/chorusdraft/actions/workflows/elixir.yml/badge.svg?branch=main"></a>
  <a href="https://github.com/buntatoes/chorusdraft/releases"><img alt="Latest release" src="https://img.shields.io/github/v/release/buntatoes/chorusdraft?display_name=tag&sort=semver"></a>
  <a href="LICENSE"><img alt="License: Apache 2.0" src="https://img.shields.io/badge/license-Apache%202.0-blue.svg"></a>
  <img alt="Top language" src="https://img.shields.io/github/languages/top/buntatoes/chorusdraft">
  <img alt="Platforms: Linux, macOS, Windows" src="https://img.shields.io/badge/platforms-Linux%20%7C%20macOS%20%7C%20Windows-6f42c1">
  <img alt="Services: Bluesky and Mastodon" src="https://img.shields.io/badge/services-Bluesky%20%2B%20Mastodon-0ea5e9">
</p>

Drafts and publishes Bluesky and Mastodon posts. Review is the default.
`automatic` can post new originals and eligible public-mention replies after
checks. Voice is dry wit; serious topics stay sincere.

Providers: local/Ollama, Gemini, or ChatGPT/OpenAI.

## Latest

**[v0.52](https://github.com/buntatoes/chorusdraft/releases/tag/v0.52)**

Desktop review talks to the bot over JSON. Mastodon listen/start uses the user
streaming API as a wake-up. `service install` writes a user unit; it does not
start it. Details in [RELEASE_NOTES.md](RELEASE_NOTES.md).

[Changelog](CHANGELOG.md) · [Releases](https://github.com/buntatoes/chorusdraft/releases) · [Build](elixir/README.md) · [Security](SECURITY.md)

## What it does

- Originals, replies, quotes, target commentary, and discovery commentary
- Owner posts, search, mentions, queue review, reject, and delete
- Local queues, split by service, origin, and account
- Opt-outs, do-not-contact, budgets, and screening
- Bluesky Jetstream and Mastodon user streaming for listen/daemon
- `automatic` daemon: attempt budget, source recheck, lockout

Does not auto-like, favourite, boost, or repost. Does not publish unsolicited
target or discovery commentary. Owner text needs `--publish`.

## Everyday

`./run.sh` is the launcher inside a release package. From a source checkout
use `elixir/chorusdraft` after `mix escript.build`.

```sh
./run.sh bluesky --help
./run.sh bluesky draft
./run.sh bluesky review
./run.sh bluesky start
./run.sh bluesky automatic --active-hours 08:30-22:00
./run.sh mastodon post "Maintenance is complete." --publish
```

| Command | Purpose |
|---|---|
| `setup` | Create missing config files |
| `draft` | Stage one original AI draft |
| `review` | Review queued drafts |
| `start` | Foreground daemon (review-first) |
| `automatic` | Daemon that may auto-post new originals and mention replies |
| `listen` / `replies` | Mentions |
| `post` / `reply` / `quote` | Owner-written text |
| `search` / `random` / `discover` / `targets` | Read or stage commentary |
| `status` | Queue counts, unresolved IDs, automatic budget, freeze |
| `reject ID` | Drop one pending or uncertain draft |
| `edit ID TEXT` | Replace pending draft text; still review before publish |
| `delete ID` | Delete one of your posts |
| `service install` | Write a user service that runs `start` (add `--automatic` for automatic) |

## Automatic mode

Opt-in. It may auto-post only a new original or an eligible public-mention
reply from that cycle. Older queue items, manual text, quotes, and
target/discovery commentary stay review-only.

Ambiguous publishes become `uncertain` and freeze later automatic claims.
After you check the account, `reject ID` clears the freeze. Do not force an
uncertain draft back to pending.

Screening is regex on normalized text. Run one daemon per account. Try a
disposable account first. Details: [SECURITY.md](SECURITY.md).

## License

Copyright 2026 Buntos. [Apache License 2.0](LICENSE). See [NOTICE](NOTICE).

Issues and pull requests follow the [code of conduct](CODE_OF_CONDUCT.md).
