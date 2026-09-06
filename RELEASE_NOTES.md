# ChorusDraft Elixir branch notes

`elixir-experimental` contains one Linux Elixir implementation of ChorusDraft
with Bluesky and Mastodon modes. Its internal version is
`0.52.0-testing`; it remains unreleased and does not replace the Ruby builds on
`main-ruby` or `ruby-testing`. Those branches now share the tested Ruby 0.51.2
source baseline; the latest published Ruby tag remains `v0.51.1`. The Ruby merge
does not change this implementation's pinned 0.51.1 parity reference.

The branch includes the Ruby 0.51.1 command workflows, local AI and Gemini adapters,
interactive AI draft review, optional Bluesky Jetstream, state safeguards,
read-only state import, setup, and a Linux package containing both platform
modes. The package includes launchers, a non-overwriting installer, SHA-256
checksums, and corresponding application/dependency source with notices.

The latest unreleased hardening bounds Jetstream frame and fragmented-message
sizes before payload reads, handshake headers, fragment counts, and receive
deadlines. Reconnect and notification catch-up remain active.

Running the package requires Linux, Erlang/OTP 25+, and util-linux. Building or
testing also requires Elixir 1.15+ and Mix. Packaging/installing uses `tar` and
`sha256sum`. The packaged application does not require Ruby or Elixir.

The implementation checks cover 64 offline regressions, Ruby-generated state import,
escript creation, package installation, checksum checks, overwrite refusal, and
an offline source rebuild. Successful
[Elixir checks](https://github.com/buntatoes/chorusdraft/actions/workflows/elixir.yml)
upload the `chorusdraft-elixir-linux` artifact for 30 days.

Live Bluesky, Mastodon, and AI acceptance, a sustained daemon soak, and an
independent release security audit have not been completed. Offline tests do not
establish live-service acceptance. No Elixir tag or GitHub release has been
published.

See [the usage and migration guide](elixir/README.md),
[implementation details](elixir/RELEASE_NOTES.md),
[feature parity](elixir/PARITY.md), and [security limits](elixir/SECURITY.md).
