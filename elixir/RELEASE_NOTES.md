# Linux Elixir implementation checkpoint

`0.52.0-testing` remains an internal, unreleased Elixir identifier. It does not
replace or change the Ruby 0.51.1 release, `main-ruby`, or `ruby-testing`.

The separate Linux version now implements the Ruby command workflows and safety
controls, optional Bluesky Jetstream, read-only state import, non-overwriting
setup, queue status/rejection, and separate BlueBot/Mastobot packages with
checksums and corresponding application/dependency source.

Parity fixes include advancing past seen target/search results, preserving source
content warnings, decoding numeric HTML entities before opt-out checks, accepting
Ruby CLI aliases and optional timeline inspection, local active-hour ranges,
monotonic daemon scheduling, jitter, and isolation of provider failures.

HTTP uses Mint without redirects or automatic request retries and enforces
streaming response limits. State uses crash-released kernel locks, validates
nested history and publication transitions, and refuses symlink/corrupt files.
An imported interrupted publication remains uncertain and cannot be replayed.

Build requirement: Elixir 1.15+ and Erlang/OTP 25+. Runtime: Linux, Erlang/OTP 25+
and util-linux. CI verifies offline regressions, Ruby-generated state import,
escript creation, package integrity, fresh install, overwrite refusal and
rebuilding from shipped dependency source.

Live Bluesky/Mastodon/AI acceptance and a sustained daemon soak require a test
account and have not been performed. No tag or public release is created by this
checkpoint. See PARITY.md and README.md for scope, commands and migration steps.
