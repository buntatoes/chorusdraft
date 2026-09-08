<p align="center">
  <img src="assets/chorusdraft-logo.png" alt="ChorusDraft logo" width="420">
</p>

# ChorusDraft

<p align="center">
  <a href="https://github.com/buntatoes/chorusdraft/actions/workflows/elixir.yml"><img alt="Elixir checks" src="https://github.com/buntatoes/chorusdraft/actions/workflows/elixir.yml/badge.svg?branch=main"></a>
  <a href="https://github.com/buntatoes/chorusdraft/releases"><img alt="Latest release" src="https://img.shields.io/github/v/release/buntatoes/chorusdraft?display_name=tag&sort=semver"></a>
  <a href="LICENSE"><img alt="License: GPL-3.0" src="https://img.shields.io/badge/license-GPL--3.0-blue.svg"></a>
  <img alt="Top language" src="https://img.shields.io/github/languages/top/buntatoes/chorusdraft">
  <img alt="Platforms: Linux, macOS, Windows" src="https://img.shields.io/badge/platforms-Linux%20%7C%20macOS%20%7C%20Windows-6f42c1">
  <img alt="Services: Bluesky and Mastodon" src="https://img.shields.io/badge/services-Bluesky%20%2B%20Mastodon-0ea5e9">
</p>

ChorusDraft is a social drafting and publishing assistant for Bluesky and
Mastodon. Review-first operation remains the default; an explicit `automatic`
mode (`automatic` / `--daemon --automatic`) may publish only newly generated
originals and eligible public-mention replies after deterministic safeguards.

Writing style favors dry wit and playful observations, with a sincere tone for
serious topics. Providers: local/Ollama, Gemini, or ChatGPT/OpenAI.

## Latest updates

**On `main` — not yet included in release downloads**

- Redacts recognized personal information from context before sending it to an AI provider.
- Rejects detected personal information and common credential formats in AI drafts, with another check before publication.
- Expands automatic link screening while preserving public social mentions.
- Screens inherited content warnings and honors content-warning opt-outs before
  automatic replies; expands checks for threats and coordinated harassment.

**Latest release: [v0.51.4](https://github.com/buntatoes/chorusdraft/releases/tag/v0.51.4)** — adds opt-in automatic publishing, ChatGPT/OpenAI support, and controls for uncertain publications. Review remains the default.

See the [changelog](CHANGELOG.md) for details and [GitHub Releases](https://github.com/buntatoes/chorusdraft/releases) for downloads.

## What it does

- Drafts originals, replies, quotes, target commentary, and discovery commentary
- Owner-written posts, search, mentions, queue review, reject, and delete
- Local queues and state, separated by service, origin, and account
- Opt-outs, do-not-contact, budgets, and content screening (see SECURITY.md)
- Bluesky Jetstream for listen/daemon; Mastodon uses polling
- Explicit automatic daemon with attempt budget, source rechecks, and lockout

Does **not** auto-like, favourite, boost, repost, publish manual text, or publish
unsolicited target/discovery commentary.

## How it works

| Stage | What happens |
|---|---|
| Configure | Choose Bluesky or Mastodon and an AI provider in local `.env`. |
| Discover or draft | Search public posts, collect mentions, or create a draft. |
| Safety checks | Opt-outs, do-not-contact, budgets, visibility, screening. |
| Review | Default: local queue for review, reject, or approval. |
| Publish | Approval publishes the queued draft. Automatic mode may publish only a newly generated original or eligible mention reply after stricter checks. Owner text needs `--publish`. |

## Everyday workflow

```sh
./run.sh bluesky --help
./run.sh bluesky draft
./run.sh bluesky review
./run.sh bluesky start
./run.sh bluesky automatic --active-hours 08:30-22:00
./run.sh mastodon post "Maintenance is complete." --publish
```

## Command reference

| Command | Purpose |
|---|---|
| `setup` | Create missing configuration files |
| `draft` | Stage one original AI draft |
| `review` | Interactively review queued drafts |
| `start` | Foreground daemon (review-first) |
| `automatic` | Daemon with safeguarded auto-publish for new originals/mention replies |
| `listen` / `replies` | Mentions |
| `post` / `reply` / `quote` | Owner-written text |
| `search` / `random` / `discover` / `targets` | Read or stage commentary |
| `status` | Queue counts and unresolved IDs |
| `reject ID` | Reject one pending or uncertain draft without publishing |
| `delete ID` | Interactively delete one of your posts |

## Automatic mode and uncertain drafts

Automatic mode is explicit opt-in. It may auto-post new originals and eligible
mention replies only. Older queued, manual, discovery, target-commentary, and
safeguard-held drafts stay review-only. Screening is residual best-effort.

Ambiguous publishes become `uncertain` and block later automatic claims. After
inspecting the account, `reject ID` / `--reject ID` clears pending or uncertain
drafts so automatic mode can resume without blind republish. Never force an
uncertain draft back to pending.

## Safety notes

- Review is the default; automatic mode is opt-in and narrowly scoped
- Injection and automatic-output screens are best-effort regex on normalized text
- Run one daemon per account; use disposable accounts before production

See [SECURITY.md](SECURITY.md), [CHANGELOG.md](CHANGELOG.md),
[elixir/README.md](elixir/README.md), and
[GitHub Releases](https://github.com/buntatoes/chorusdraft/releases).

`SECURITY.md`, `CHANGELOG.md`, and `RELEASE_NOTES.md` are mirrored under
`elixir/`; keep each pair identical when editing.

ChorusDraft is licensed under the GNU General Public License, version 3. See
[LICENSE](LICENSE) and [NOTICE](NOTICE).
