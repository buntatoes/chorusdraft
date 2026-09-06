# Linux, macOS, and Windows Elixir implementation checkpoint

`0.52.0-testing` remains an internal, unreleased Elixir identifier. It does not
replace or change the tagged Ruby 0.51.1 release. Ruby 0.51.2 source has been
merged into `main-ruby` and synchronized to `ruby-testing`; tagging/publication
remain pending. Elixir continues to use the pinned Ruby 0.51.1 parity reference.

The separate Elixir version implements the Ruby 0.51.1 workflows and safety
controls, optional Bluesky Jetstream, read-only state import, non-overwriting
setup, queue status/rejection, and native Linux, macOS, and Windows packages.
Each package contains both platform modes, checksums, and corresponding
application/dependency source.

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

Build requirement: Elixir 1.15+ and Erlang/OTP 25+. Runtime packages require
Erlang/OTP 25+; Linux also requires util-linux, macOS requires Python 3, and
Windows requires Python 3 and PowerShell. Unix packages use `.tar.gz`; Windows
uses `.zip`.

The [Elixir verification workflow](https://github.com/buntatoes/chorusdraft/actions/workflows/elixir.yml)
runs 64 tests and native package checks on Ubuntu 22.04, macOS 14, and Windows
Server 2022. It verifies escript creation, package integrity, installation, both
platform modes, overwrite refusal, and rebuilding from shipped dependency source.
Linux also checks Ruby-generated state import. CI uses OTP 25.3 and Elixir 1.15.8.

Successful [Elixir checks](https://github.com/buntatoes/chorusdraft/actions/workflows/elixir.yml)
upload separate `chorusdraft-elixir-linux`, `chorusdraft-elixir-macos`, and
`chorusdraft-elixir-windows` artifacts for 30 days. Each includes its native
archive and SHA-256 file; these are untagged build artifacts. Local builds write
the matching package type to `dist/`.

Live Bluesky/Mastodon/AI acceptance and a sustained daemon soak require a test
account and have not been performed. An independent release security audit also
remains outstanding. No tag or public release is created by this
checkpoint. See [PARITY.md](PARITY.md) and [README.md](README.md) for scope,
commands, package installation, and migration steps.
