# ChorusDraft

ChorusDraft is a social drafting assistant for Bluesky and Mastodon. It helps
account owners write original posts, replies, and commentary while keeping
AI-generated content in a local review queue until they approve it.

Its writing style favors dry wit and playful observations, with a sincere tone
for serious topics. You can use a local AI model or Google Gemini and choose
what reaches your account.

## What it does

- Drafts original posts, replies, quotes, target commentary, and discovery
  commentary for Bluesky and Mastodon.
- Supports owner-written posts, public-post search, public mention processing,
  queue inspection, draft rejection, and interactive deletion of an account's
  own posts.
- Provides a shared workflow for drafting, reviewing, and publishing, with
  concise commands as well as a complete option interface.
- Keeps queues and account state locally, separated by social service, service
  origin, and account.
- Applies opt-outs, do-not-contact lists, interaction limits, and best-effort
  content screening before a draft is staged and again before it is published.
  Screening limits are documented in [SECURITY.md](SECURITY.md).
- Offers optional Bluesky Jetstream wake-ups for listener and daemon workflows;
  Mastodon continues to use polling.

ChorusDraft does **not** automatically like, favourite, boost, or repost. It is
a drafting and approval workflow, not an unattended engagement tool.

## How it works

| Stage | What happens |
|---|---|
| Configure | You choose a Bluesky or Mastodon account and an AI provider in a local configuration file. |
| Discover or draft | The application can search public posts, collect eligible public mentions, or create a draft. |
| Safety checks | Opt-outs, do-not-contact entries, interaction budgets, visibility rules, and best-effort content screening are applied (see [SECURITY.md](SECURITY.md)). |
| Review | Drafts enter a local queue for interactive review, rejection, or approval. |
| Publish | Only an explicit approval can publish an AI draft. Owner-written text needs an explicit `--publish` flag to bypass the queue. |

AI-generated drafts require individual approval. You remain responsible for the
content you publish and how your account interacts with others.

## Get started

Visit [GitHub Releases](https://github.com/buntatoes/chorusdraft/releases) for
the current downloads, installation requirements, upgrade instructions, and
release notes. Use the documentation included with your chosen release for its
supported features and commands.

Release archives include a SHA-256 sidecar and a package manifest. Verify the
download before extracting it, then install into a **new** directory. The
installer refuses to overwrite an existing destination, creates missing
configuration files, and does not start a service.

On Linux and macOS, an extracted package provides this basic flow:

```sh
# Verify the archive with the platform's SHA-256 utility, then extract it.
./install.sh /absolute/path/to/new-chorusdraft-directory
cd /absolute/path/to/new-chorusdraft-directory
./run.sh bluesky --help
```

On Windows, use the corresponding PowerShell launchers from the extracted
package:

```powershell
.\install.ps1 C:\Apps\ChorusDraft
Set-Location C:\Apps\ChorusDraft
.\run.ps1 bluesky --help
```

The package documentation contains the exact archive name, checksum command,
and platform-specific requirements for that release. Packaged executables need
an Erlang/OTP runtime, but do not require an installed Elixir toolchain.

### Choose an installation path

Use a release package when you want the supported launcher, installer,
configuration examples, and checksum manifest for your operating system. Build
from source when you are developing, reviewing a change, or need to run the
test and packaging commands yourself. In both cases, use a new directory for a
new installation rather than sharing a live account's data directory between
versions or machines.

## Requirements at a glance

| Use case | Requirements |
|---|---|
| Run a release package on Linux | Erlang/OTP 25+ and util-linux (`flock`) |
| Run a release package on macOS | Erlang/OTP 25+ and Python 3 |
| Run a release package on Windows | Erlang/OTP 25+, Python 3, and PowerShell |
| Build or test from source | Elixir 1.15+, Mix, and Erlang/OTP 25+ |

To connect an account, you also need a Bluesky app password or a Mastodon
access token. AI drafting needs either a local OpenAI-compatible endpoint or
Google Gemini credentials and a model name. These are local operator settings,
not values to commit to the repository.

## Configure an account and AI provider

Each installed package has separate `bluesky/` and `mastodon/` directories.
Configure only the service you intend to use by editing its local `.env` file;
the checked-in `.env.example` files document the available settings without
containing credentials.

| Service | Account settings |
|---|---|
| Bluesky | `BLUESKY_HANDLE` and `BLUESKY_APP_PASSWORD` |
| Mastodon | `MASTODON_API_BASE_URL` and `MASTODON_ACCESS_TOKEN` |

For a local OpenAI-compatible or Ollama endpoint, configure the AI section in
the same file:

```dotenv
AI_PROVIDER=local
LOCAL_LLM_URL=http://localhost:11434/v1/chat/completions
LOCAL_LLM_MODEL=llama3.2:3b
```

When `AI_PROVIDER` is `local` or `ollama`, `LOCAL_LLM_URL` must use a loopback
host (`localhost`, `127.0.0.1`, or `::1`) over HTTP or HTTPS. Remote HTTPS hosts
are rejected for local AI; Bluesky, Mastodon, and Gemini remote endpoints still
require HTTPS as usual.

To use Gemini, set `AI_PROVIDER=gemini` and provide `GEMINI_API_KEY` and
`GEMINI_MODEL`. Optional settings include `ACTIVE_HOURS`, the status language,
and discovery keywords.

Setup is safe to run again: it creates only missing configuration files and
does not log in, execute `.env` contents, or start a daemon.

```sh
./setup.sh bluesky
./setup.sh mastodon
```

On Windows, use `.\setup.ps1 bluesky` or `.\setup.ps1 mastodon`. Keep
credentials in local `.env` files or process environment variables; never
commit them, paste them into an issue, or include them in logs.

## Everyday workflow

The examples below use an installed Unix package. Replace `./run.sh` with
`.\run.ps1` in PowerShell, and substitute `mastodon` for `bluesky` as needed.

```sh
# Inspect the available commands without connecting to an account.
./run.sh bluesky --help

# Read public posts without generating or publishing anything.
./run.sh bluesky search "open source"

# Generate one AI draft and put it in the review queue.
./run.sh bluesky draft

# Inspect each queued draft and choose what to do with it.
./run.sh bluesky review
```

An owner-written post is queued by default:

```sh
./run.sh mastodon post "The server has entered its artisanal latency era."
./run.sh mastodon review
```

Direct publication is deliberately narrow. It is available only for
owner-written text with an explicit `--publish` flag; it never applies to an
AI-generated draft:

```sh
./run.sh mastodon post "Maintenance is complete." --publish
```

## Keep account state predictable

Configuration, queues, and history are scoped by social service, service
origin, and account. Keep a separate installation or base directory for each
account, and run no more than one daemon against an account at a time. This
avoids competing writers and makes it clear which review queue you are
inspecting.

If you move to a fresh installation, import compatible older state only after
verifying that the destination account store is empty. Do not copy a live state
directory between implementations or resume an old process after a move without
reconciling its publication history.

```sh
# Example: import one account's state.json into a new package install.
./run.sh bluesky --import-state /absolute/path/to/old/data/ACCOUNT_HASH/state.json
./run.sh bluesky status
```

Use `mastodon` instead of `bluesky` when importing that platform. Full upgrade
steps, refusal cases, and `uncertain` handling are in
[Upgrade or import older state](elixir/README.md#upgrade-or-import-older-state).

## Command reference

Run `./run.sh bluesky --help` or `./run.sh mastodon --help` for the complete,
validated interface. Short commands translate to the equivalent options but
never add direct-publication permission.

| Command | Purpose |
|---|---|
| `setup` | Create missing configuration files without logging in |
| `draft` | Stage one original AI draft |
| `review` | Interactively review queued drafts |
| `start` | Run the foreground daemon; stop it with Ctrl+C |
| `listen` | Poll public mentions |
| `replies` | Process eligible public mentions once |
| `post TEXT` | Stage owner-written text |
| `reply ID TEXT` | Stage an owner-written reply |
| `quote ID TEXT` | Stage owner-written quote commentary |
| `search QUERY` | Display public posts without drafting |
| `random [QUERY]` | Show one public search or timeline result |
| `discover [QUERY]` | Stage discovery commentary |
| `targets [HANDLE]` | Stage public target commentary |
| `status` | Show queue counts and unresolved draft IDs |
| `reject ID` | Reject one pending draft without publishing it |
| `delete ID` | Interactively delete one of the account's own posts |

Examples of advanced options:

```sh
# Fetch eligible public mentions and stage reply drafts.
./run.sh mastodon --replies-only --limit 5

# Run the Bluesky daemon with Jetstream wake-ups.
./run.sh bluesky start --jetstream

# Limit a foreground run to a local time range.
./run.sh bluesky start --active-hours 08:30-22:00

# Inspect local queue counts and unresolved publication outcomes.
./run.sh bluesky status
```

`--jetstream` is available only with Bluesky `listen` or `start`. It wakes the
ordinary notification workflow; it does not put streamed post bodies into AI
context, terminal output, or local state, and it cannot publish directly.

## Safety, privacy, and reliability

ChorusDraft enforces safety controls in the application rather than relying
only on documentation:

- AI output always enters a local review queue and is validated again before
  publication.
- Clear public opt-out requests and configured do-not-contact entries block
  supplied interaction paths. Checks cover source authors and mentioned
  accounts.
- Harassment, threats, doxxing, coordinated pile-ons, self-harm encouragement,
  and common direct personal attacks are rejected before staging and before
  publication.
- Mastodon private, direct, and unknown-visibility bodies are discarded before
  AI processing, logging, or persistent state.
- Publication requests are not automatically retried. An ambiguous result is
  marked `uncertain` and needs manual account inspection.
- Local state is separated by social service, service origin, and account.
  Native locks serialize writers, and malformed state fails closed.
- Packages exclude `.env` files, runtime state, logs, and build caches.

These controls reduce risk; they do not replace a review of the full context,
target, visibility, and exact text before approval. Run only one daemon per
account. Use disposable accounts to test login, search, staging, review,
publication, deletion, opt-outs, and reconnect behavior before production use.

### Handling a failed or uncertain publication

Use `status` to see pending and unresolved drafts. If the service response is
ambiguous, ChorusDraft records the draft as `uncertain` rather than retrying it.
Inspect the account directly before deciding what happened, then resolve the
queue deliberately. Pending drafts can be rejected with `reject ID`; do not
assume that a network failure means a post was not published.

Read the [security policy](SECURITY.md) for supported versions, credential
handling, safeguards, known limits, and vulnerability reporting.

## Build from source

The implementation is in [`elixir/`](elixir/). Building and testing require a
compatible Elixir, Mix, and Erlang/OTP runtime; see the
[application documentation](elixir/README.md) for the current requirements.

From `elixir/`:

```sh
mix deps.get
MIX_ENV=prod mix escript.build
./chorusdraft bluesky --help
./chorusdraft mastodon --help
```

For hands-on source testing, initialize the service you need, then edit its
local `.env` file:

```sh
elixir setup.exs bluesky
./chorusdraft bluesky draft
```

On Windows, use `escript .\chorusdraft bluesky --help` when inspecting a
source-built executable.

| Path | Contents |
|---|---|
| [`elixir/lib/`](elixir/lib/) | CLI, service clients, AI adapters, safety checks, state, locks, and Jetstream transport |
| [`elixir/test/`](elixir/test/) | Offline regression tests and fixtures |
| [`elixir/scripts/`](elixir/scripts/) | Package build, installation, checksum, and native verification helpers |
| [`elixir/bluesky/`](elixir/bluesky/) | Bluesky configuration examples and local runtime area |
| [`elixir/mastodon/`](elixir/mastodon/) | Mastodon configuration examples and local runtime area |

## Verify a change or package

Run these checks from `elixir/`:

```sh
mix format --check-formatted
mix test --warnings-as-errors
MIX_ENV=prod mix run scripts/build_release.exs
./scripts/check_packages.sh
```

On Windows, use `.\scripts\check_packages.ps1` for the package check. The
build writes the current platform's archive and SHA-256 sidecar to `elixir/dist/`.
Package checks validate the archive and manifest, installation behavior, private
configuration handling, runtime-data exclusion, both social-service modes, and
an offline rebuild of the shipped source bundle.

The [continuous-integration workflow](.github/workflows/elixir.yml) runs the
offline suite, source build, formatting check, and package checks on Linux,
macOS, and Windows. Automated fixtures do not establish live-service
compatibility; perform the disposable-account checks described above before
relying on a new deployment.

## Documentation and license

This repository keeps a short package landing page at the root and the full
operator manual under [`elixir/README.md`](elixir/README.md). `SECURITY.md`,
`CHANGELOG.md`, and `RELEASE_NOTES.md` are mirrored at the root and under
`elixir/`; keep each pair identical when you edit them.

- [GitHub Releases](https://github.com/buntatoes/chorusdraft/releases) provides
  current downloads, release notes, and upgrade guidance.
- [Application documentation](elixir/README.md) describes the complete CLI,
  configuration, state import, packages, and Jetstream behavior.
- [Changelog](CHANGELOG.md) records user-visible changes.
- [Security policy](SECURITY.md) explains the security boundary and reporting
  guidance.

ChorusDraft is licensed under the GNU General Public License, version 3. See
[LICENSE](LICENSE), [NOTICE](NOTICE), and
[third-party notices](elixir/THIRD_PARTY_NOTICES.md).
