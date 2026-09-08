# ChorusDraft — Elixir version for Linux, macOS, and Windows

This directory contains ChorusDraft 0.51.4 for Linux, macOS, and Windows. One
Elixir application and executable support both Bluesky and Mastodon.

ChorusDraft writes comic social drafts for both platforms using a local
OpenAI-compatible/Ollama model, Gemini, or ChatGPT through the OpenAI Responses
API. The style favors dry wit, light sarcasm, playful exaggeration, and absurd
comparisons. Serious or sensitive posts receive a sincere response. Review is
the default; explicit automatic mode may publish only newly generated originals
and eligible public-mention replies after stricter safeguards pass.

## Requirements

- Linux, macOS, or Windows with Erlang/OTP 25 or later
- Elixir 1.15 or later, Mix, and the Erlang development headers to build or test
- Linux: util-linux (`flock`); `tar` and `sha256sum` for package verification
- macOS: Python 3; `tar` and `shasum` for package verification
- Windows: Python 3 and PowerShell
- A Bluesky app password or Mastodon access token
- A local AI endpoint, Gemini credentials, or OpenAI API credentials and model

## Build and inspect

From this `elixir` directory:

```sh
mix deps.get
MIX_ENV=prod mix escript.build
```

Check the command interface before adding credentials:

```sh
./chorusdraft bluesky --help
./chorusdraft mastodon --help
```

On Windows, use `escript .\chorusdraft ...` from a source checkout. Extracted
Windows packages provide `run.ps1` and `setup.ps1` launchers.

To create local configuration files for hands-on testing:

```sh
./chorusdraft bluesky --setup
./chorusdraft mastodon --setup
```

Edit `bluesky/.env` and/or `mastodon/.env`. The setup script creates private files
only when they do not already exist. It never starts a service or overwrites an
existing configuration.

Use separate test credentials for initial live acceptance. Run only one daemon
against an account at a time.

## Common workflows

Version 0.51.4 accepts these short commands:

```sh
./chorusdraft bluesky draft
./chorusdraft bluesky review
./chorusdraft bluesky start
./chorusdraft bluesky automatic
./chorusdraft mastodon reply STATUS_ID "Thanks for the context."
./chorusdraft mastodon search "open source"
```

Short commands translate to the same validated options. `start` remains
review-first; only `automatic` adds automatic AI-publication permission. The
advanced interface remains available:

```sh
# Stage one AI draft. This cannot publish directly.
./chorusdraft bluesky --post-only

# Fetch public mentions and stage up to five eligible replies.
./chorusdraft mastodon --replies-only

# Review pending drafts in an interactive terminal.
./chorusdraft bluesky --process-queue

# Stage manual text, or explicitly publish manual text.
./chorusdraft mastodon --text "The server has entered its artisanal latency era."
./chorusdraft mastodon --text "Maintenance is complete." --publish

# Inspect public posts without generating or publishing anything.
./chorusdraft bluesky --search "elixir linux"
```

Additional commands cover target commentary, discovery, public-post inspection,
interactive deletion, active hours, polling, and daemon operation. Manual text,
quotes, target/discovery commentary, safeguard-held drafts, and pre-existing
queue items remain review-only even while automatic mode is running.

## Automatic mode

Use `automatic` for an explicit unattended daemon:

```sh
./chorusdraft bluesky automatic --active-hours 08:30-22:00
./chorusdraft mastodon --daemon --automatic --poll-interval 60
```

Only the exact original or eligible incoming public-mention reply created in
that cycle can be claimed. Before an automatic reply, the source is re-fetched;
its ID, text, content warning, handle, and immutable author identity must match
the generation context, and it must retain supported public visibility.
Injection, opt-out, and do-not-contact checks run again. Generated output is
also held if it contains account mentions, links, common personal-contact
patterns, normalized prompt-injection patterns, pile-ons, or expanded harassment
language. Any content warning is subject to the same strict automatic screen,
and opt-outs in source text or its content warning are honored.

Each account receives at most five automatic publication attempts per rolling
24 hours. Attempts are reserved atomically and failures count. Only one may be
in flight, and any `publishing` or `uncertain` item blocks later automatic
claims. A crash-stranded claim ages into `uncertain`; it is never retried.

## Bluesky Jetstream

Jetstream is required and starts automatically for Bluesky listener and daemon
modes, including the automatic daemon:

```sh
./chorusdraft bluesky --listen
./chorusdraft bluesky start
./chorusdraft bluesky automatic
```

The client uses the current `network.bsky.jetstream.subscribeEvents` API with the
`xrpc.v1.json` WebSocket subprotocol. It connects to
`wss://jetstream.us-east.bsky.network` by default. Set `BLUESKY_JETSTREAM_URL` in
`bluesky/.env` to another compatible WSS origin or full subscribeEvents URL.
The old `/subscribe` protocol is not supported by this mode.

Only post commits are requested. The client checks mention facets and direct
reply parents for the logged-in account's DID, including updated posts. It does
not filter by the bot's DID on the server: that would select posts *written by*
the bot and miss incoming mentions. This means the connection receives the
network-wide post stream and uses more bandwidth than notification polling.

Matching events wake the existing notification workflow. Raw streamed bodies
never enter AI context, terminal output, or state. The API remains the source of
posts, handles, and thread context; opt-out checks, deduplication, active hours,
queue limits, safety checks, and publication policy still apply. Bursts coalesce
into one pending wake-up, with at least five seconds between the start of
notification cycles. Jetstream does not directly generate or publish posts.

The socket reconnects with bounded exponential backoff and a heartbeat.
An oversized frame is rejected from its declared length before the payload is read.
Complete and fragmented messages are limited to 1 MiB; handshake headers,
fragment counts, and receive deadlines are bounded as described in
[SECURITY.md](SECURITY.md).

An initial notification check, checks after reconnect, and periodic checks at
`--poll-interval` (60 seconds by default) cover disconnects and API indexing lag.
This is live-tail notification acceleration, not a historical replay consumer:
there is no persisted Jetstream cursor or guarantee of complete delivery. The
existing 30-notification fetch window and five-reply batch limit still apply.

The Mastodon mode continues to use polling; Jetstream is a Bluesky service. The
legacy `--jetstream` flag is accepted as a compatibility no-op for Bluesky
`listen`, `start`, and `automatic`, while `--no-jetstream` is rejected.

Protocol reference: [Bluesky Jetstream documentation](https://bsky.network/docs/jetstream/).

## State and safeguards

State is stored under each platform's `data/` directory and separated again by
platform, service origin, and account. Credentials are not written to state.
Compatible older state can be imported explicitly as described below. Kernel locks
serialize writers, and malformed state fails closed. Run one daemon per account.

Add handles to `config/do_not_contact.txt` to refuse all supplied interaction
paths for those accounts. Clear public requests to stop contact are also recorded
before reply generation. `config/target_accounts.txt` is empty by default.
Unsolicited target and discovery drafts are capped at five per rolling 24 hours and
one per author every 30 days.

The separate automatic-publication budget is five attempts per rolling 24
hours. It does not expand the target/discovery interaction budget.

The Mastodon mode processes only public and unlisted source statuses; restricted
bodies are discarded immediately. The Bluesky mode supports public feed posts
only. Automatic likes, favourites, boosts, and reposts are not implemented.

If a publication request has an ambiguous result, the draft is marked `uncertain`.
Inspect the account manually before doing anything else with it. The program will
not retry that draft automatically.

## HTTP and dependencies

Configure one AI provider in the selected platform `.env`:

| Provider value | Required settings | Destination |
|---|---|---|
| `local` or `ollama` | `LOCAL_LLM_URL`, `LOCAL_LLM_MODEL` | Configured loopback endpoint |
| `gemini` | `GEMINI_API_KEY`, `GEMINI_MODEL` | Google Gemini |
| `chatgpt` or `openai` | `OPENAI_API_KEY`, `OPENAI_MODEL` | OpenAI Responses API |

Remote providers receive the task and selected cleaned public context. For
ChatGPT through the OpenAI API, either `AI_PROVIDER=chatgpt` or
`AI_PROVIDER=openai` is accepted. The adapter separates system instructions
from the JSON-encoded task and untrusted context, uses bearer authorization,
caps generated output at 256 tokens, and sets `store: false` so the generated
response is not stored for later retrieval through the Responses API. It
rejects failed, incomplete, malformed, and empty responses before applying the
ordinary platform-length and content safeguards. Errors omit credential-bearing
and remote response details. `store: false` does not itself claim zero data
retention; review [OpenAI's current data controls](https://developers.openai.com/api/docs/guides/your-data)
before sending public conversation context.

Mint 1.10.0 handles Bluesky, Mastodon, and AI-provider HTTP requests with explicit
timeouts and response limits, without redirect following or automatic retries.
WebSockex 0.5.1 supplies connection/frame helpers for the custom bounded
Jetstream transport. Jason handles JSON; Telemetry and HPAX are transitive dependencies. Exact versions are pinned
in `mix.lock`; see [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

## Tests

```sh
mix format --check-formatted
mix test --warnings-as-errors
```

The migration tests use a credential-free legacy state fixture and verify that
imports preserve identity, history, opt-outs, and unresolved publications.

## Packages and installation

Download archives and their SHA-256 sidecars from
[GitHub Releases](https://github.com/buntatoes/chorusdraft/releases). Choose the package
for your operating system and follow the instructions for that release.

Build and check a package for the current operating system:

```sh
MIX_ENV=prod mix run scripts/build_release.exs
./scripts/check_packages.sh
```

On Windows, replace the second command with:

```powershell
.\scripts\check_packages.ps1
```

The archive and SHA-256 file are written to `dist/`. The archive includes the
escript, native run/setup/install scripts, configuration examples, a complete
file checksum manifest, GPL source, locked dependency source and original licenses.
Runtime configuration, state, logs and build caches are excluded. The escript
needs Erlang/OTP; it does not need an installed Elixir toolchain to run.

Package names identify their operating system:

- `ChorusDraft-elixir-0.51.4-linux.tar.gz`
- `ChorusDraft-elixir-0.51.4-macos.tar.gz`
- `ChorusDraft-elixir-0.51.4-windows.zip`

Each has an adjacent `.sha256` file. On Linux, in the directory containing both
files:

```sh
sha256sum --check ChorusDraft-elixir-0.51.4-linux.tar.gz.sha256
tar -xzf ChorusDraft-elixir-0.51.4-linux.tar.gz
cd ChorusDraft-elixir-0.51.4-linux
```

On macOS, use `shasum -a 256 --check` and the macOS archive name. On Windows,
use `Get-FileHash` or the CI-verified checksum sidecar, then `Expand-Archive`.

Every extracted package supports both social platforms. Install Linux/macOS into
a new location:

```sh
./install.sh /absolute/path/to/chorusdraft-elixir
/absolute/path/to/chorusdraft-elixir/run.sh bluesky --help
/absolute/path/to/chorusdraft-elixir/run.sh mastodon --help
```

Install and run on Windows:

```powershell
.\install.ps1 C:\Apps\ChorusDraft-Elixir
C:\Apps\ChorusDraft-Elixir\run.ps1 bluesky --help
C:\Apps\ChorusDraft-Elixir\run.ps1 mastodon --help
```

The destination must not exist. Setup creates missing files with private
permissions and never executes `.env` contents. Edit the new `.env` before use.
For an already extracted archive, `setup.sh` or `setup.ps1` configures it in
place. Launchers resolve their own directory, so they work from any current
working directory. Windows setup applies private ACLs to configuration and state.

To rebuild a shipped source bundle with Elixir/Mix available:

```sh
cd source
HEX_OFFLINE=1 MIX_ENV=prod mix escript.build
```

The package's implementation history is included in `source/CHANGELOG.md`.

## Upgrade or import older state

1. Stop the old process. Keep its directory as your rollback copy.
2. Install the new Elixir package into a different directory. Copy the old `.env`
   and desired `config/*.txt` into that new directory, keeping permissions private.
3. Use the same platform, service origin and account credentials. Import that
   account's old `data/<account-hash>/state.json`:

```sh
./run.sh bluesky --import-state /absolute/path/to/old/data/ACCOUNT_HASH/state.json
./run.sh bluesky --status
```

Choose the matching platform in every package command. From a source checkout use
`./chorusdraft bluesky --import-state FILE` (or `mastodon`). The import command
logs in to identify the destination account but never publishes anything.
It refuses nonempty destination state, malformed data and drafts belonging to a
different account. If a source has no drafts, select its matching account hash
carefully: history-only files do not contain account identity. The source is read
only; IDs, record keys, blocks, seen posts and interaction history are preserved.
Interrupted `publishing` drafts become `uncertain`; they are never made pending.
Existing `uncertain`, `published` and `rejected` statuses stay unchanged.

`--status` lists unresolved IDs and counts. `--reject ID` can discard a pending
draft, including one whose author has since opted out. Inspect the remote account
before resolving any uncertain publication; no automatic reset/retry is provided.
Do not resume the old process after using the new one without reconciling the
new posting history. Do not share a live state directory across implementations.

Schedules use the operating system's local timezone, including its `TZ` setting.
`--active-hours 22-6` supports overnight operation; equal endpoints mean all day.
The daemon isolates job failures and uses monotonic intervals. It runs in the
foreground so a service manager can supervise it; no service is started by setup.

Read [SECURITY.md](SECURITY.md) for safeguards and known limits, and
[GitHub Releases](https://github.com/buntatoes/chorusdraft/releases) for release notes.
