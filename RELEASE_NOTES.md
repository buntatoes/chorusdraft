# Elixir branch release notes

`elixir-experimental` contains the separate Linux Elixir implementation of
BlueBot and Mastobot. Its internal version is `0.52.0-testing`; it remains
unreleased and does not replace the Ruby builds on `main-ruby` or `ruby-testing`.

## Implemented

The branch includes the Ruby command workflows, local AI and Gemini adapters,
interactive AI draft review, optional Bluesky Jetstream, state safeguards,
read-only state import, setup, and separate Linux product packages.

Packages include product launchers, a non-overwriting installer, SHA-256
checksums, and corresponding application/dependency source with notices.
Install upgrades into a new directory and explicitly import the stopped old
account's state. Ruby source and branches remain read-only references.

## Requirements and verification

Running a package requires Linux, Erlang/OTP 25+, and util-linux. Building or
testing also requires Elixir 1.15+ and Mix; packaging/installing uses `tar` and
`sha256sum`. No Ruby runtime is needed by the Elixir application.

The [implementation verification run](https://github.com/buntatoes/chorusdraft/actions/runs/33999085832)
passed 56 regression tests, Ruby-generated state import, escript creation, both
product installs, checksum checks, overwrite refusal, and offline source rebuilds
on Ubuntu 22.04 / OTP 25.3 / Elixir 1.15.8.

Successful [Elixir checks](https://github.com/buntatoes/chorusdraft/actions/workflows/elixir.yml)
provide the `chorusdraft-elixir-linux` artifact for 30 days. It contains separate
BlueBot and Mastobot archives and their checksums. Build artifacts are available;
no Elixir tag or GitHub release has been published.

## Remaining live validation

Live Bluesky/Mastodon/AI acceptance, a sustained daemon soak, and an independent
release security audit have not been completed. Offline tests do not establish
live service acceptance. Jetstream accelerates notifications and does not provide
historical replay or guaranteed complete delivery.

See [the usage and migration guide](elixir/README.md),
[implementation details](elixir/RELEASE_NOTES.md),
[feature parity](elixir/PARITY.md), and [security limits](elixir/SECURITY.md).
