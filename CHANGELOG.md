# Elixir branch changelog

This changelog covers `elixir-experimental`. The internal build identifier is
`0.52.0-testing`; no Elixir tag or official release has been published.
Ruby history and maintenance remain on `main-ruby` and `ruby-testing`.

## Documentation alignment — September 5, 2026

- Updated the root and Elixir READMEs, changelogs, release notes, and notices to
  describe the completed Linux implementation and current validation limits.
- Added package download/build guidance, runtime requirements, and links to the
  verified implementation run.
- Preserved earlier implementation history with explicitly historical wording.

## Linux implementation completion — September 5, 2026

- Completed the Linux command workflows against the read-only Ruby 0.51.1
  reference for BlueBot and Mastobot.
- Added read-only state import, non-overwriting setup, queue status/rejection,
  and separate Linux product archives with installation scripts, checksums,
  application source, and dependency source/licenses.
- Fixed target/discovery selection, source content warnings, numeric HTML entity
  decoding, Ruby CLI aliases, local active hours, and daemon scheduling/errors.
- Adopted Mint HTTP transport without redirects or automatic request retries,
  bounded responses, and crash-released kernel state locking.
- Passed 56 regression tests, including Ruby-generated state import, and both
  product installation and offline rebuild checks in the
  [verified build](https://github.com/buntatoes/chorusdraft/actions/runs/33999085832).

## Jetstream integration — September 5, 2026

- Added optional Bluesky Jetstream wake-ups for `--listen` and `--daemon`.
- Preserved API notification checks, coalesced activity, reconnect/backoff,
  privacy boundaries, and mandatory draft review.
- Added WebSockex and Telemetry with protocol and reconnect tests.

See [the detailed Elixir changelog](elixir/CHANGELOG.md) for the initial port and
implementation details. Live account acceptance, a sustained daemon soak, and an
independent release security audit remain outstanding.
