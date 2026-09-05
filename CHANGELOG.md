# ChorusDraft Elixir changelog

This changelog covers the ChorusDraft Elixir version on
`elixir-experimental`. Its internal version is `0.52.0-testing`; no tagged
Elixir release has been published. Ruby history stays on `main-ruby` and
`ruby-testing`.

## ChorusDraft naming and package consolidation — September 5, 2026

- Corrected documentation, command banners, configuration examples, and notices
  to identify the project as ChorusDraft for both supported platforms.
- Consolidated the platform-specific archives into one ChorusDraft Linux archive
  containing both Bluesky and Mastodon modes.
- Removed the temporary CI branch from the workflow configuration.

## Linux implementation completion — September 5, 2026

- Completed the Linux command workflows against the read-only Ruby 0.51.1
  reference for Bluesky and Mastodon.
- Added read-only state import, non-overwriting setup, queue status/rejection,
  Linux packaging, checksums, and bundled application/dependency source.
- Fixed target/discovery selection, content-warning preservation, numeric HTML
  entity decoding, Ruby CLI aliases, local active hours, and daemon scheduling.
- Added Mint HTTP transport without redirect following or automatic request
  retries, bounded responses, and kernel state locking.
- Passed 56 regression tests, Ruby-generated state import, installation checks,
  overwrite refusal, and an offline source rebuild.

## Jetstream integration — September 5, 2026

- Added optional Bluesky Jetstream wake-ups for `--listen` and `--daemon`.
- Kept API notification catch-up, reconnect/backoff, privacy boundaries, and
  mandatory draft review.
- Added WebSockex and Telemetry with protocol and reconnect tests.

Live account acceptance, a sustained daemon soak, and an independent release
security audit remain outstanding.
