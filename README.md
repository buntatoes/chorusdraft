# ChorusDraft Elixir experiment

> **Experimental branch:** `elixir-experimental`
>
> This is an unfinished Linux rewrite of BlueBot and Mastobot in Elixir. It is
> separate from the supported Ruby release and is not ready for release use.

The current supported version is the Ruby
[ChorusDraft 0.51.1 release](https://github.com/buntatoes/chorusdraft/releases/tag/v0.51.1).
Future Ruby maintenance work lives on `ruby-testing`. This branch is only
for the Elixir experiment.

The experimental executable currently reports `0.52.0-testing`. That is a
temporary internal identifier, not a Git tag, official 0.52 release, compatibility
promise, or replacement for the Ruby version.

## Current checkpoint

- A shared Mix project implements initial BlueBot and Mastobot clients.
- Local OpenAI-compatible/Ollama endpoints and Gemini are supported.
- Original drafts, replies, public commentary, manual posts, queue review,
  searches, polling, and interactive deletion have initial ports.
- Optional Jetstream support wakes BlueBot's listener or daemon for incoming
  mentions and direct replies, with periodic API catch-up checks.
- The primary 0.51.1 safeguards have been carried into the Elixir code.
- The offline suite has 33 tests, including a local WebSocket reconnect fixture.
  It does not log in, call an AI provider, or publish anything.

Live platform compatibility, state migration, long-running daemon behavior,
packaging, upgrade handling, and a complete security audit remain unfinished.
There is no Elixir archive, tag, GitHub release, or supported upgrade path.

## Repository layout

The Elixir project is under [`elixir/`](elixir/). The older Ruby source remains in
the repository as a behavioral reference inherited from the branch base; changes
to that Ruby code are developed and released elsewhere.

- [`elixir/README.md`](elixir/README.md) contains the detailed experimental usage guide.
- [`elixir/CHANGELOG.md`](elixir/CHANGELOG.md) records the current porting checkpoint.
- [`elixir/SECURITY.md`](elixir/SECURITY.md) describes intended safeguards and known limits.
- [`elixir/NOTICE`](elixir/NOTICE) and
  [`elixir/THIRD_PARTY_NOTICES.md`](elixir/THIRD_PARTY_NOTICES.md) contain project
  and dependency notices.

## Requirements

- Linux with Erlang/OTP 25 or later to run the current escript
- Elixir 1.14 or later and Mix to build and test
- Jason, WebSockex, and Telemetry, fetched through Mix and pinned in `mix.lock`
- Test credentials for Bluesky or Mastodon for hands-on API testing
- A local AI endpoint or a Gemini API key and model

## Build without credentials

```sh
cd elixir
mix deps.get
MIX_ENV=prod mix escript.build
./chorusdraft bluesky --help
./chorusdraft mastodon --help
```

The help commands do not require social-platform or AI credentials.

## Configure for experimental testing

From the `elixir` directory:

```sh
elixir setup.exs bluesky
elixir setup.exs mastodon
```

Edit `bluesky/.env` and/or `mastodon/.env`. Setup creates private configuration
files only when they do not already exist. It does not overwrite configuration,
download services, or start a bot.

Use separate test credentials and state until live API behavior and migration are
fully audited. Do not run the Ruby and Elixir programs against the same account at
the same time.

## Experimental workflows

```sh
# Stage an AI draft; this does not publish it.
./chorusdraft bluesky --post-only

# Fetch eligible public mentions and stage reply drafts.
./chorusdraft mastodon --replies-only

# Use Jetstream to wake BlueBot when mentions or direct replies arrive.
./chorusdraft bluesky --listen --jetstream

# Review pending drafts in an interactive terminal.
./chorusdraft bluesky --process-queue

# Stage manually written text.
./chorusdraft mastodon --text "The server has entered its artisanal latency era."

# Explicitly publish manually written text.
./chorusdraft mastodon --text "Maintenance is complete." --publish
```

AI-generated text is designed to remain in the review queue. The `--publish`
option applies only to text supplied manually with `--text`.

Jetstream uses the current JSON subscribeEvents protocol and also works with
`--daemon`. It accelerates notification checks while preserving draft review;
it does not consume historical replay. See the
[Jetstream guide](elixir/README.md#jetstream-for-bluebot) for configuration and limits.

## Safeguard checkpoint

- Private, direct, and unknown-visibility Mastodon source bodies are discarded.
- Public opt-out requests and configured do-not-contact entries block supplied
  interaction paths.
- Explicit mentions, local Mastodon aliases, Unicode variations, harassment
  patterns, content warnings, and prompt-like source text receive initial checks.
- Unsolicited target and discovery drafts use daily and per-author limits.
- State is separated by platform, service origin, and account and uses private
  permissions and atomic replacement.
- Ambiguous publishing failures are marked `uncertain` and are not automatically
  retried.
- Automatic likes, favourites, boosts, and reposts are not implemented.

These are an initial port of the Ruby controls, not a completed security claim.
Human review remains required, and live behavior still needs a separate audit.

## Test

```sh
cd elixir
mix format --check-formatted
mix test --warnings-as-errors
```

There is no packaging script yet. Generated build output, dependencies, live
`.env` files, logs, and state are ignored by Git and were not committed.

## License

ChorusDraft is distributed under the GNU General Public License v3.0. See
[`LICENSE`](LICENSE). Dependency licenses and source requirements are recorded
in [the Elixir third-party notices](elixir/THIRD_PARTY_NOTICES.md).
