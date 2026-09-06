# Linux Elixir implementation checkpoint

`0.52.0-testing` remains an internal, unreleased Elixir identifier. It does not
replace or change the Ruby 0.51.1 release, `main-ruby`, or `ruby-testing`.

The separate Linux version now implements the Ruby command workflows and safety
controls, optional Bluesky Jetstream, read-only state import, non-overwriting
setup, queue status/rejection, and one ChorusDraft package containing both
platform modes, checksums, and corresponding application/dependency source.

Parity fixes include advancing past seen target/search results, preserving source
content warnings, decoding numeric HTML entities before opt-out checks, accepting
Ruby CLI aliases and optional timeline inspection, local active-hour ranges,
monotonic daemon scheduling, jitter, and isolation of provider failures.

HTTP uses Mint without redirects or automatic request retries and enforces
streaming response limits. State uses crash-released kernel locks, validates
nested history and publication transitions, and refuses symlink/corrupt files.
An imported interrupted publication remains uncertain and cannot be replayed.

Jetstream now reads sockets passively and rejects oversized declared frames
before reading their payloads. A 1 MiB message limit also covers cumulative
fragments. Header limits, fragment-count limits, and receive deadlines prevent
unbounded assembly; unsolicited compression and invalid handshakes are refused.
Socket regressions cover these limits, reconnects, and masked heartbeat replies.
The latest hardening pass passed 64 tests, package integrity and installation
checks, and an offline source rebuild. A credential-free connection also verified
the public Jetstream TLS handshake; account workflows still need live acceptance.

Build requirement: Elixir 1.15+ and Erlang/OTP 25+. Runtime: Linux, Erlang/OTP 25+
and util-linux. Packaging/installing also uses `tar` and `sha256sum`.

The [Elixir verification workflow](https://github.com/buntatoes/chorusdraft/actions/workflows/elixir.yml)
passed 64 tests in [the verified Linux run](https://github.com/buntatoes/chorusdraft/actions/runs/34012077368),
including Ruby-generated state import. The run also verified escript creation,
package integrity, installation of the combined package, both platform modes,
overwrite refusal, and rebuilding from shipped dependency source. CI used
Ubuntu 22.04, OTP 25.3, and Elixir 1.15.8.

Successful [Elixir checks](https://github.com/buntatoes/chorusdraft/actions/workflows/elixir.yml)
upload the `chorusdraft-elixir-linux` artifact for 30 days. It includes the
ChorusDraft Linux archive and its SHA-256 file; these are untagged build
artifacts. Local builds write the same package types to `dist/`.

Live Bluesky/Mastodon/AI acceptance and a sustained daemon soak require a test
account and have not been performed. An independent release security audit also
remains outstanding. No tag or public release is created by this
checkpoint. See [PARITY.md](PARITY.md) and [README.md](README.md) for scope,
commands, package installation, and migration steps.
