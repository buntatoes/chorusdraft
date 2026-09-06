# Changelog

This file records user-visible changes to ChorusDraft.

## 0.51.3 — 2026-09-06

### Supported implementations

- Released Ruby and Elixir as coequal supported implementations on the default
  branch.
- Versioned both implementations and all release packages as 0.51.3.
- Kept separate Ruby packages for Bluesky and Mastodon while providing combined
  Bluesky and Mastodon modes in each Elixir package.
- Added native release verification for both implementations on Linux, macOS,
  and Windows.

### Elixir runtime

- Reimplemented the platform clients, AI adapters, review queue, scheduling,
  safeguards, and account-scoped state in Elixir.
- Added the Ruby short commands alongside the complete advanced flag interface;
  command translation cannot add `--publish`.
- Added explicit, read-only import of compatible Ruby state into an empty store.
- Added optional Bluesky Jetstream wake-ups with periodic API catch-up, bounded
  frames, receive deadlines, reconnect backoff, and heartbeat handling.

### Packaging and reliability

- Added Elixir `.tar.gz` packages for Linux and macOS and a `.zip` package for
  Windows, each containing both platform modes.
- Continued the six Ruby platform-specific archives with shell or batch
  launchers and credential-free setup.
- Added native locks, atomic state replacement, strict state validation,
  idempotent publication identifiers, and `uncertain` outcomes without
  automatic publication retries.
- Pinned GitHub Actions dependencies by commit and moved artifact actions to
  their Node 24 releases.

### Safety

- Preserved mandatory interactive review for AI drafts and explicit publication
  only for owner-written text.
- Preserved privacy filtering, opt-outs, do-not-contact enforcement, harassment
  screening, interaction budgets, ownership checks, and disabled engagement
  actions in both release implementations.

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
