# Changelog

## Jetstream integration — unreleased

- Added opt-in `--jetstream` for BlueBot's `--listen` and `--daemon` commands.
- Use the current JSON subscribeEvents protocol over verified TLS, without
  sending platform credentials to Jetstream.
- Match incoming mention facets and direct replies by DID; coalesce activity
  into one pending notification refresh and keep all existing drafting safeguards.
- Reconnect with bounded backoff and heartbeat checks. Retain startup, reconnect,
  and periodic API reconciliation; this is a live-tail mode without cursor replay.
- Add parser, isolation, burst handling, CLI, and local WebSocket/reconnect tests,
  plus an Elixir-only CI workflow targeting the experimental branch.
- Add WebSockex 0.5.1 and its Telemetry dependency. Ruby implementations are unchanged.

## Experimental checkpoint — unreleased

The Mix project currently reports `0.52.0-testing` as a temporary internal build
identifier. This is not an official release version.

### Elixir and Linux

- Reimplemented the shared BlueBot and Mastobot Linux runtime in Elixir 1.14.
- Added a single escript with product-specific commands and configuration
  directories. Separate Linux launchers are not implemented yet.
- Added pinned Jason 1.4.5 JSON handling. Packaging and inclusion of corresponding
  dependency source and notices remain unfinished.

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

This is an experimental build on `elixir-experimental`. It has no packaging
script, Git tag, GitHub release, or supported upgrade path.
