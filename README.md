# ChorusDraft — Elixir version

This branch contains the Linux Elixir version of **ChorusDraft**, with support for
both Bluesky and Mastodon through one application and one executable. Development
lives on `elixir-experimental`.

The Ruby builds remain on `main-ruby` and `ruby-testing`. Ruby source inherited
by this branch is kept as a read-only feature reference. The internal Elixir
version is `0.52.0-testing`; it is not an official tagged release.

## What ChorusDraft supports

- Bluesky and Mastodon login, public feeds, search, mentions, replies, quotes,
  original drafts, target/discovery commentary, and interactive deletion.
- Local OpenAI-compatible/Ollama and Gemini AI providers.
- Mandatory interactive approval for every AI-generated draft.
- Optional Bluesky Jetstream wake-ups for listeners and daemons. Mastodon uses
  polling. Streaming checks message lengths before payload reads and bounds
  fragmented messages, handshake headers, and receive times.
- Account-scoped state, opt-outs, do-not-contact lists, interaction limits,
  privacy filtering, and uncertain-publication handling.
- Read-only import of Ruby 0.51.1 state into an empty Elixir account store.
- One Linux package containing both platform modes, setup scripts, checksums,
  application source, and dependency source/licenses.

## Requirements

| Task | Requirements |
|---|---|
| Run the package | Linux, Erlang/OTP 25+, and util-linux (`flock`) |
| Build or test | Elixir 1.15+, Mix, Erlang/OTP 25+, and util-linux |
| Package or install | `tar`, `sha256sum`, and standard Linux shell tools |
| Connect an account | Bluesky app password or Mastodon access token |
| Generate drafts | Local AI endpoint, or Gemini API key and model |

The packaged escript does not require Ruby or Elixir at runtime.

## Build and configure

```sh
cd elixir
mix deps.get
MIX_ENV=prod mix escript.build

./chorusdraft bluesky --setup
./chorusdraft mastodon --setup
./chorusdraft bluesky --help
./chorusdraft mastodon --help
```

Setup creates separate configuration and account-state directories for each
platform while both modes continue to use the same ChorusDraft executable.

Common commands:

```sh
./chorusdraft bluesky --post-only
./chorusdraft bluesky --listen --jetstream
./chorusdraft mastodon --replies-only
./chorusdraft mastodon --process-queue
./chorusdraft mastodon --status
```

## Package and verification

```sh
cd elixir
mix format --check-formatted
mix test --warnings-as-errors
MIX_ENV=prod mix run scripts/build_release.exs
./scripts/check_packages.sh
```

This creates `ChorusDraft-elixir-0.52.0-testing-linux.tar.gz` and its SHA-256
file under `elixir/dist/`. The archive contains both Bluesky and Mastodon modes.
Successful [Elixir checks](https://github.com/buntatoes/chorusdraft/actions/workflows/elixir.yml)
also upload a `chorusdraft-elixir-linux` artifact for 30 days.

Verification includes 64 passing offline regressions, state import generated
by the pinned Ruby reference, package installation, checksum verification,
overwrite refusal, an offline source rebuild, and adversarial WebSocket fixtures.
Live account acceptance and a sustained daemon soak still require test
credentials; no live posts were made.

## Documentation

- [Detailed usage, installation, Jetstream, and migration](elixir/README.md)
- [Changelog](CHANGELOG.md) and [detailed Elixir history](elixir/CHANGELOG.md)
- [Release status](RELEASE_NOTES.md)
- [Feature parity and verification scope](elixir/PARITY.md)
- [Security policy](SECURITY.md) and [implementation safeguards](elixir/SECURITY.md)

ChorusDraft is GPLv3; see [LICENSE](LICENSE), [NOTICE](NOTICE), and
[third-party notices](elixir/THIRD_PARTY_NOTICES.md).
