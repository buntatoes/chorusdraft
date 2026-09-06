# Changelog

This file records user-visible changes to ChorusDraft.

## 0.51.3 — 2026-09-06

### Elixir runtime

- Promoted the Elixir implementation as the primary ChorusDraft runtime while
  retaining Ruby 0.51.2 source for history and migration reference.
- Combined Bluesky and Mastodon in one executable with shared AI, safety, queue,
  scheduling, and state behavior.
- Added the Ruby 0.51.2 short commands alongside the complete advanced flag
  interface. Command translation cannot add `--publish`.
- Added explicit, read-only import of compatible Ruby state into an empty
  account-scoped store.

### Platforms and packaging

- Added native `.tar.gz` packages for Linux and macOS and a `.zip` package for
  Windows. Every package contains both social platform modes.
- Added Unix and PowerShell setup, install, run, and verification scripts.
- Added private Unix modes and protected Windows ACLs for configuration and
  state, plus native cross-process locks and atomic state replacement.
- Included complete application source, pinned dependency source and licenses,
  file manifests, and SHA-256 sidecars while excluding credentials, state, logs,
  and build caches.
- Added native CI tests on Ubuntu 22.04, macOS 14, and Windows Server 2022.

### Bluesky Jetstream

- Added optional Jetstream wake-ups for Bluesky listeners and daemons while
  retaining periodic notification API catch-up.
- Added bounded frames, fragmented messages, handshake headers, fragment counts,
  receive deadlines, reconnect backoff, and heartbeat handling.
- Kept streamed post bodies outside AI context, terminal output, and persistent
  state. Stream events cannot generate or publish directly.

### Safety and reliability

- Preserved mandatory interactive review for AI drafts and explicit publication
  only for owner-written text.
- Preserved privacy filtering, opt-outs, do-not-contact enforcement, harassment
  screening, interaction budgets, ownership checks, and disabled engagement
  actions.
- Added crash-released locks, strict state validation, idempotent publication
  identifiers, and `uncertain` handling without automatic publication retries.
- Disabled HTTP redirects and automatic retries and added request timeouts and
  streaming response limits.

## 0.51.2 — 2026-09-06

- Raised the Ruby implementation requirement to Ruby 4.0.
- Added short commands and cross-platform `bot` launchers.
- Added credential-free setup that preserves existing configuration.
- Preserved the complete advanced flag interface and state format.

## 0.51.1 — 2026-09-05

- Recorded all fetched public opt-outs before reply generation or batch limits.
- Expanded normalization for opt-out and harassment screening.
- Extended do-not-contact checks to generated, manual, and queued mentions and
  Mastodon content warnings.
- Prevented new opt-outs from replacing earlier block-list entries.
- Added complete validation of Mastodon content warnings.

## 0.51 — 2026-09-05

- Added the dry comic voice with sincere handling of serious subjects.
- Added varied original posts and topic-focused reply, target, and discovery
  prompts without personal attacks or unsupported allegations.
- Preserved review, privacy, interaction limits, and provider safety controls.

## 0.50 — 2026-09-05

- Began the ChorusDraft release line with Bluesky and Mastodon drafting,
  interactive review, local AI and Gemini support, scheduling, account-scoped
  state, opt-outs, privacy filtering, and cross-platform Ruby packages.
