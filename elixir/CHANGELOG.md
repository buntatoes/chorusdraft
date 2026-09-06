# Elixir changelog

Changes to the ChorusDraft Elixir version on `elixir-experimental`, newest first. The current internal identifier
is `0.52.0-testing`; the branch remains unreleased. Ruby 0.51.1 code is a read-only
feature reference.

## Documentation and privacy review — 2026-09-06 (unreleased)

- Correct the current guide to one combined Linux package and 64 passing
  regression tests, while preserving the earlier 56-test checkpoint below.
- Clarify that parity uses pinned Ruby 0.51.1, not the newer Ruby 0.51.2 CLI.
- Record a targeted source/history/package privacy review in SECURITY.md;
  no confirmed credentials or unintended personal data were found in its scope.

## Jetstream receive limits — unreleased

- Replace unbounded WebSocket message assembly with passive reads that inspect
  frame lengths before accepting payloads. Both complete and fragmented messages
  are limited to 1 MiB, with at most 1,024 fragments per message.
- Cap handshake header lines and the aggregate header fields at 16 KiB each,
  enforce a 10-second handshake/frame receive deadline and a 90-second fragmented
  message deadline, and reject unsolicited compression and invalid handshakes.
- Preserve masked ping/pong replies, heartbeat checks, reconnect backoff, and
  coalesced notification refreshes. Stream data still cannot directly publish
  content or supply AI context.
- Add socket-level regressions for oversized length declarations, fragment
  accumulation, malformed handshakes, stalled frames, and idle heartbeats.

## Documentation alignment — September 5, 2026

- Aligned root and Elixir documentation with the current implemented features,
  requirements, package availability, state import, and validation results.
- Clarified the difference between successful offline checks and outstanding
  live account acceptance. Preserved the initial checkpoint as historical notes.

## Linux implementation completion — September 5, 2026

- Completed the Linux Ruby command workflows and added read-only state import
  into empty account storage, setup, queue status, and pending-draft rejection.
- Fixed target/discovery iteration past seen posts, source CW preservation,
  numeric HTML entity decoding for opt-outs, CLI aliases/optional random-post
  queries, local active hours, monotonic scheduling, jitter, and job isolation.
- Replaced HTTP transport with Mint 1.10.0, without redirects or automatic
  request retries, including 503 Retry-After; enforce streaming response limits.
  The source build now requires Elixir 1.15+.
- Added kernel flock locking with crash recovery, nested state validation,
  constrained publication transitions, and refusal of symlink/corrupt state.
  Imported interrupted publications remain uncertain.
- Added a ChorusDraft Linux archive containing both platform modes,
  run/setup/install scripts, checksums, complete application/dependency source,
  and original license files.
  Installation uses a new directory and preserves the previous installation.
- Passed 56 regression tests, Ruby-generated state import, package installation and both platform modes,
  checksum checks, overwrite refusal, and offline source rebuilds in the
  [Elixir verification workflow](https://github.com/buntatoes/chorusdraft/actions/workflows/elixir.yml).

See [PARITY.md](PARITY.md) for the pinned reference and verification scope.
Live account acceptance, a sustained daemon soak, and an independent release
security audit remain outstanding. No Ruby branch or release is modified.

## Jetstream integration — unreleased

- Added opt-in `--jetstream` for the Bluesky `--listen` and `--daemon` commands.
- Use the current JSON subscribeEvents protocol over verified TLS, without
  sending platform credentials to Jetstream.
- Match incoming mention facets and direct replies by DID; coalesce activity
  into one pending notification refresh and keep all existing drafting safeguards.
- Reconnect with bounded backoff and heartbeat checks. Retain startup, reconnect,
  and periodic API reconciliation; this is a live-tail mode without cursor replay.
- Add parser, isolation, burst handling, CLI, and local WebSocket/reconnect tests,
  plus an Elixir-only CI workflow targeting the experimental branch.
- Add WebSockex 0.5.1 and its Telemetry dependency. Ruby implementations are unchanged.

## Initial experimental checkpoint — historical

The initial port used `0.52.0-testing` as an internal build identifier.
The following records that earlier checkpoint; subsequent sections above describe
completed packaging, migration, launchers, and the raised Elixir requirement.

### Elixir and Linux

- Reimplemented the shared ChorusDraft Linux runtime in Elixir 1.14.
- Added a single escript with product-specific commands and configuration
  directories. Product launchers were added in the completion checkpoint above.
- Added pinned Jason 1.4.5 JSON handling. Packaging and bundled dependency source
  were completed in the later implementation checkpoint.

### Platform behavior

- Ported Bluesky login and refresh sessions, public timelines, search, mentions,
  replies, quote embeds, UTF-8 facet offsets, stable record keys, and deletion.
- Ported Mastodon login, public and unlisted status handling, search, mentions,
  replies, link-style quotes, content warnings, idempotency keys, and deletion.
- Kept the dry humor brief for local OpenAI-compatible/Ollama endpoints and
  Gemini, including sincere handling of grief, distress, and serious requests.
- Preserved original, reply, target, discovery, manual, queue-review, search,
  listen, and daemon workflows.

### Safety, privacy, and state

- Every AI-generated post is staged for exact interactive approval; AI generation
  has no direct publishing path.
- Restricted Mastodon bodies are discarded during normalization and never enter
  AI context, output, or state.
- All fetched opt-outs are recorded before reply limits or generation failures.
  Do-not-contact checks cover authors, explicit mentions, Mastodon local aliases,
  manual posts, and queued drafts.
- Retained Unicode-aware opt-out and harassment screening, prompt-injection
  filtering, queue limits, five-per-day unsolicited limits, and 30-day author
  cooldowns.
- State writes use a per-account Linux process lock, private permissions, atomic
  replacement, and fail-closed JSON validation. Ambiguous publishing failures are
  marked `uncertain` and are not retried automatically.
- Credentials are loaded as data, ignored by Git, sent only to validated HTTPS
  origins (or loopback HTTP for local AI), and omitted from error messages.

At this initial checkpoint, packaging and migration were pending. They are now
implemented as described above; the branch still has no official Elixir release.
