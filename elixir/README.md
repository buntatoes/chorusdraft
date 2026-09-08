# ChorusDraft — Elixir version for Linux, macOS, and Windows

This directory contains ChorusDraft 0.51.4 for Linux, macOS, and Windows. One
Elixir application and executable support both Bluesky and Mastodon.

ChorusDraft writes comic social drafts for both platforms using a local
OpenAI-compatible/Ollama model, Gemini, or ChatGPT through the OpenAI Responses
API. Review is the default; explicit automatic mode may publish only newly
generated originals and eligible public-mention replies after stricter
safeguards pass.

## Requirements

Current main includes unreleased privacy checks, stricter automatic screening of
generated text and inherited content warnings, and content-warning opt-outs.
See CHANGELOG.md; published v0.51.4 downloads do not include these later fixes.

- Linux, macOS, or Windows with Erlang/OTP 25 or later
- Elixir 1.15 or later, Mix, and the Erlang development headers to build or test
- Linux: util-linux (`flock`); `tar` and `sha256sum` for package verification
- macOS: Python 3; `tar` and `shasum` for package verification
- Windows: Python 3 and PowerShell
- A Bluesky app password or Mastodon access token
- A local AI endpoint, Gemini credentials, or OpenAI API credentials and model

## Build and inspect

```sh
mix deps.get
MIX_ENV=prod mix escript.build
./chorusdraft bluesky --help
./chorusdraft mastodon --help
./chorusdraft bluesky --setup
```

On Windows, use `escript .\chorusdraft ...` from a source checkout. Edit
`bluesky/.env` and/or `mastodon/.env`. Setup never starts a service or
overwrites existing configuration. Run only one daemon per account.

## Common workflows

```sh
./chorusdraft bluesky draft
./chorusdraft bluesky review
./chorusdraft bluesky start
./chorusdraft bluesky automatic
./chorusdraft mastodon reply STATUS_ID "Thanks for the context."
./chorusdraft mastodon search "open source"
```

`start` remains review-first; only `automatic` (`--daemon --automatic`) adds
automatic AI-publication permission. Manual text, quotes, target/discovery
commentary, safeguard-held drafts, and pre-existing queue items remain
review-only.

```sh
./chorusdraft bluesky --post-only
./chorusdraft mastodon --replies-only
./chorusdraft bluesky --process-queue
./chorusdraft mastodon --text "Maintenance is complete." --publish
```

## Automatic mode

```sh
./chorusdraft bluesky automatic --active-hours 08:30-22:00
./chorusdraft mastodon --daemon --automatic --poll-interval 60
```

Only the exact original or eligible incoming public-mention reply created in
that cycle can be claimed. Before an automatic reply, the source is re-fetched
and its ID, text, content warning, handle, immutable author identity, and public
visibility must match. Injection, opt-out, and do-not-contact checks run again.
Output with model-added mentions, links, common personal-contact patterns,
pile-ons, or expanded harassment is held for review.

Each account gets at most five automatic publication attempts per rolling 24
hours. Attempts are reserved atomically; failures count. Only one may be in
flight, and any `publishing` or `uncertain` item blocks later automatic claims.
A crash-stranded claim ages into `uncertain` and is never retried. After you
inspect the account, `reject ID` / `--reject ID` clears a pending or uncertain
draft so automatic mode can resume without a blind republish.

## Bluesky Jetstream

Jetstream starts automatically for Bluesky `listen` and daemon modes and cannot
be disabled there. `--jetstream` is a compatibility no-op; `--no-jetstream` is
rejected. Streamed bodies never enter AI context, output, or state. Matching
events wake the ordinary notification fetch, where opt-out, deduplication,
safety, and publication policy still apply. Mastodon continues to use polling.

Default endpoint: `wss://jetstream.us-east.bsky.network`. Override with
`BLUESKY_JETSTREAM_URL`. See [SECURITY.md](SECURITY.md) for frame and handshake
bounds.

## State and safeguards

State lives under each platform `data/` directory, separated by platform,
service origin, and account. Do-not-contact and public opt-outs block supplied
interaction paths. Ambiguous publication results become `uncertain` and are not
retried. Screening (including prompt-injection and automatic-output gates) is
best-effort and deterministic; review mode remains the strongest control.

## Providers

| Provider value | Required settings | Destination |
|---|---|---|
| `local` or `ollama` | `LOCAL_LLM_URL`, `LOCAL_LLM_MODEL` | Configured loopback endpoint |
| `gemini` | `GEMINI_API_KEY`, `GEMINI_MODEL` | Google Gemini |
| `chatgpt` or `openai` | `OPENAI_API_KEY`, `OPENAI_MODEL` | OpenAI Responses API |

Local AI URLs must be loopback. Remote endpoints require HTTPS. OpenAI requests
use bearer auth, bounded output, and `store: false`.

## Packages

- `ChorusDraft-elixir-0.51.4-linux.tar.gz`
- `ChorusDraft-elixir-0.51.4-macos.tar.gz`
- `ChorusDraft-elixir-0.51.4-windows.zip`

Build with `MIX_ENV=prod mix run scripts/build_release.exs` and verify with
`./scripts/check_packages.sh` (or `.\scripts\check_packages.ps1` on Windows).

## Upgrade or import older state

Stop the old process, install into a new directory, copy `.env` and config, then:

```sh
./run.sh bluesky --import-state /absolute/path/to/old/data/ACCOUNT_HASH/state.json
./run.sh bluesky --status
```

`--reject ID` / `reject ID` discards a pending or uncertain draft and clears the
automatic-mode freeze without republishing. Inspect the remote account before
resolving uncertain publications; do not force an uncertain draft back to
pending.

Read [SECURITY.md](SECURITY.md) and
[GitHub Releases](https://github.com/buntatoes/chorusdraft/releases).
