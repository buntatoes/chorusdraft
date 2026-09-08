# ChorusDraft

Elixir app for Linux, macOS, and Windows. One executable, Bluesky and Mastodon
modes. Version 0.51.6. See [CHANGELOG.md](CHANGELOG.md).

Review is the default. `automatic` may publish new originals and eligible
public-mention replies after screening and a source recheck.

## Requirements

- Linux, macOS, or Windows with Erlang/OTP 25+
- Elixir 1.15+, Mix, and Erlang development headers to build or test
- Linux: util-linux (`flock`); `tar` and `sha256sum` to verify packages
- macOS: Python 3; `tar` and `shasum`
- Windows: Python 3 and PowerShell
- A Bluesky app password or Mastodon access token
- A local AI endpoint, Gemini credentials, or OpenAI API credentials and model

## Build

```sh
mix deps.get
MIX_ENV=prod mix escript.build
./chorusdraft bluesky --help
./chorusdraft mastodon --help
./chorusdraft bluesky --setup
```

On Windows, from a source checkout: `escript .\chorusdraft ...`. Edit
`bluesky/.env` and/or `mastodon/.env`. Setup does not start a service or
overwrite existing config. Run one daemon per account.

## Workflows

```sh
./chorusdraft bluesky draft
./chorusdraft bluesky review
./chorusdraft bluesky edit DRAFT_ID "replacement text"
./chorusdraft bluesky status
./chorusdraft bluesky start
./chorusdraft bluesky automatic
./chorusdraft mastodon reply STATUS_ID "Thanks for the context."
./chorusdraft mastodon search "open source"
```

`start` is review-first. Only `automatic` (`--daemon --automatic`) may
auto-publish AI output. Manual text, quotes, target/discovery commentary,
held drafts, and items already in the queue stay review-only.

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

Only the original or eligible public-mention reply created in that cycle can
be claimed. Before an automatic reply, the source is fetched again; ID, text,
content warning, handle, author identity, and public visibility must match.
Injection, opt-out, and do-not-contact run again. Output with extra mentions,
links, contact patterns, pile-ons, or harassment is held for review.

Five automatic attempts per account per rolling 24 hours. Failures count. One
in flight. `publishing` or `uncertain` blocks later claims. A stranded claim
ages to `uncertain` and is not retried. `reject ID` clears it after you inspect
the account.

## Bluesky Jetstream

On for Bluesky `listen` and daemon. `--jetstream` does nothing;
`--no-jetstream` is rejected. Stream bodies never go to AI, the terminal, or
state. A match wakes the normal notification fetch. Mastodon polls.

Default: `wss://jetstream.us-east.bsky.network`. Override with
`BLUESKY_JETSTREAM_URL`. Bounds: [SECURITY.md](SECURITY.md).

## State

Per platform `data/` directory, split by platform, origin, and account.
Do-not-contact and public opt-outs apply. Ambiguous publishes become
`uncertain`. Screens are regex. They miss things. Review is what matters.

## Providers

| Value | Settings | Destination |
|---|---|---|
| `local` or `ollama` | `LOCAL_LLM_URL`, `LOCAL_LLM_MODEL` | Loopback endpoint |
| `gemini` | `GEMINI_API_KEY`, `GEMINI_MODEL` | Google Gemini |
| `chatgpt` or `openai` | `OPENAI_API_KEY`, `OPENAI_MODEL` | OpenAI Responses API |

Local AI URLs must be loopback. Remote endpoints need HTTPS. OpenAI uses bearer
auth, bounded output, and `store: false`.

## Packages

- `ChorusDraft-elixir-0.51.6-linux.tar.gz`
- `ChorusDraft-elixir-0.51.6-macos.tar.gz`
- `ChorusDraft-elixir-0.51.6-windows.zip`

Build: `MIX_ENV=prod mix run scripts/build_release.exs`  
Verify: `./scripts/check_packages.sh` or `.\scripts\check_packages.ps1`

## Upgrade

Stop the old process, install into a new directory, copy `.env` and config:

```sh
./chorusdraft bluesky import /absolute/path/to/old/data/ACCOUNT_HASH/state.json
./chorusdraft bluesky status
```

Inside a release package use `./run.sh` (or `run.ps1`) in place of
`./chorusdraft`.

`reject ID` drops a pending or uncertain draft and unfreezes automatic mode.
Check the live account first. Do not force uncertain back to pending.

## License

Apache 2.0. See LICENSE, [NOTICE](NOTICE), and [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
