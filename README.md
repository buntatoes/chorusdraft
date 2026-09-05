# ChorusDraft — separate Elixir version

This branch, `elixir-experimental`, contains the Linux Elixir implementation of
**BlueBot** for Bluesky and **Mastobot** for Mastodon. The Ruby builds remain on
`main-ruby` and `ruby-testing`. Ruby source inherited by this branch is retained
as a read-only reference for feature parity.

The internal Elixir version is `0.52.0-testing`. The Linux implementation and
offline package checks are complete for the scope in [PARITY.md](elixir/PARITY.md).
Live account acceptance and a sustained daemon soak remain outstanding. This is
an unreleased Elixir build; it does not replace an official Ruby release.

## Features

- Original comic drafts, contextual replies, target/discovery commentary, manual
  posts, search, timeline inspection, and interactive deletion.
- Local OpenAI-compatible/Ollama and Gemini AI adapters. Every AI draft requires
  interactive review; `--publish` applies only to manually supplied text.
- Bluesky Jetstream for listener/daemon notification wake-ups, with API catch-up.
  Mastodon uses polling.
- Account-scoped queues, opt-outs, do-not-contact lists, interaction limits,
  privacy filtering, and uncertain-publication handling.
- Read-only Ruby/Elixir state import into an empty destination store.
- Separate Linux product archives with launchers, setup, a new-directory
  installer, checksums, application source, and dependency source/licenses.

## Requirements

| Task | Requirements |
|---|---|
| Run a Linux package | Erlang/OTP 25+ and util-linux (`flock`) |
| Build or test source | Linux, Elixir 1.15+, Mix, Erlang/OTP 25+, and util-linux |
| Package or install | `tar`, `sha256sum`, and standard Linux shell utilities |
| Use an account | Bluesky app password or Mastodon access token |
| Generate AI drafts | Local AI endpoint, or Gemini API key and model |

Elixir and Ruby are not required to run a packaged escript. Ruby is used only for
the optional reference-state test; CI supplies the pinned reference checkout.
The verified CI baseline is Ubuntu 22.04, OTP 25.3, and Elixir 1.15.8.

## Build and configure

From the repository root:

```sh
cd elixir
mix deps.get
MIX_ENV=prod mix escript.build
./chorusdraft bluesky --help
./chorusdraft mastodon --help
./chorusdraft bluesky --setup
./chorusdraft mastodon --setup
```

Edit `elixir/bluesky/.env` and/or `elixir/mastodon/.env`. Setup preserves existing
files and starts no service. From the `elixir/` directory:

```sh
# Stage one AI draft, then review it interactively.
./chorusdraft bluesky --post-only
./chorusdraft bluesky --process-queue

# Run BlueBot's listener with Jetstream.
./chorusdraft bluesky --listen --jetstream

# Inspect Mastobot's queue without publishing.
./chorusdraft mastodon --status
```

For packages, use `./setup.sh` and `./run.sh [options]` in the chosen product
directory. Follow the [installation and import guide](elixir/README.md) when
moving from Ruby; stop the old process and keep its source/state read only.

## Packages and verification

From the repository root:

```sh
cd elixir
mix format --check-formatted
mix test --warnings-as-errors
MIX_ENV=prod mix run scripts/build_release.exs
./scripts/check_packages.sh
```

Builds produce BlueBot and Mastobot archives plus SHA-256 files under
`elixir/dist/`. Successful [Elixir checks](https://github.com/buntatoes/chorusdraft/actions/workflows/elixir.yml)
upload them as the `chorusdraft-elixir-linux` artifact, retained for 30 days.
Select a successful run for `elixir-experimental` and download its artifact;
these are build artifacts, not a tagged GitHub release.

The [implementation verification run](https://github.com/buntatoes/chorusdraft/actions/runs/33999085832)
passed **56 tests**, Ruby-generated state import, both product installations,
checksum verification, overwrite refusal, and offline source rebuilds. It did
not use live account credentials or publish posts.

## Documentation

- [Detailed usage, Jetstream, installation, and migration](elixir/README.md)
- [Root changelog](CHANGELOG.md) and [detailed Elixir history](elixir/CHANGELOG.md)
- [Branch release notes](RELEASE_NOTES.md) and [implementation notes](elixir/RELEASE_NOTES.md)
- [Feature parity and verification scope](elixir/PARITY.md)
- [Security policy](SECURITY.md) and [Elixir safeguards and limitations](elixir/SECURITY.md)

ChorusDraft is GPLv3; see [LICENSE](LICENSE), [NOTICE](NOTICE), and the
[dependency notices](elixir/THIRD_PARTY_NOTICES.md).
