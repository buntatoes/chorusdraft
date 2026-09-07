# Changelog

This file preserves the existing project history. Future updates and release
notes are published in [GitHub Releases](https://github.com/buntatoes/chorusdraft/releases).

## 0.51.4 — 2026-09-07

### Automatic mode

- Added the explicit `automatic` command (`--daemon --automatic`) while keeping
  `start` and every other command review-first by default.
- Allowed only each newly generated original and eligible public-mention reply
  to publish automatically. Older queued drafts, owner-written text, quotes,
  target commentary, and discovery commentary remain review-only.
- Added stricter automatic-output screening for harassment, pile-ons,
  model-added mentions, links, and common personal-contact patterns.
- Added immediate source re-fetch and exact content, content-warning, handle,
  immutable-author, visibility, injection, opt-out, and do-not-contact checks.
- Added an atomic five-attempt rolling 24-hour budget, single-flight claims,
  unresolved-publication lockout, and stale-claim recovery to `uncertain`.

### Providers and Bluesky

- Added ChatGPT through the OpenAI Responses API with `chatgpt` and `openai`
  provider names, configurable API key/model, bounded output, sanitized errors,
  and request-level response storage disabled.
- Made Jetstream the default, non-disableable wake-up transport for Bluesky
  listener and daemon modes. `--jetstream` remains a compatibility no-op.
- Preserved canonical notification/API fetches and periodic catch-up; streamed
  post bodies remain outside AI context, output, and persistent state.

### Release and verification

- Updated all version markers, configuration examples, user/security docs,
  release notes, package paths, and testing-branch CI coverage for 0.51.4.
- Expanded offline regression coverage to 80 tests, including automatic-mode
  publication boundaries, source edits, budgets, crash recovery, and OpenAI
  response validation.

## 0.51.3 — 2026-09-06

### Elixir runtime

- Established Elixir as the sole supported ChorusDraft implementation.
- Combined Bluesky and Mastodon in one executable with shared AI, safety, queue,
  scheduling, and state behavior.
- Added short commands alongside the complete advanced option interface;
  command translation cannot add `--publish`.
- Added explicit import of compatible older state into an empty account store.

### Platforms and packaging

- Added `.tar.gz` packages for Linux and macOS and a `.zip` package for Windows.
  Every package contains both social-platform modes.
- Added Unix and PowerShell setup, install, run, and verification scripts.
- Added private Unix modes and protected Windows ACLs for configuration and
  state, plus native cross-process locks and atomic state replacement.
- Included application source, pinned dependency source and licenses, file
  manifests, and SHA-256 sidecars while excluding credentials, state, logs, and
  build caches.
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

- Raised the earlier implementation requirement to Ruby 4.0.
- Added short commands and cross-platform launchers.
- Added credential-free setup that preserves existing configuration.
- Preserved the complete advanced option interface and state format.

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
  state, opt-outs, privacy filtering, and cross-platform packages.
