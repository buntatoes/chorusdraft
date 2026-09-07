# Elixir changelog

Changes to the Elixir implementation of ChorusDraft.

## 0.51.3 — Unreleased

### Desktop and commands

- Standardized the active application on Elixir for Bluesky and Mastodon.
- Added a React desktop launcher with drafting, review, monitoring, manual posts,
  search, and session controls.
- Added masked social and AI credential fields, operating-system protected
  storage, and session-only settings when secure storage is unavailable.
- Added searchable local published-post and activity History with a copy action.
- Added 10-day expiry for completed post records and desktop activity. Activity
  can rotate earlier at 50 MB; pending drafts, uncertain publications, and safety
  records remain retained separately.
- Added short commands for setup, drafting, review, posts, replies, quotes,
  search, discovery, monitoring, deletion, and history. Existing flags remain
  supported.

### Social platforms and AI

- Added Bluesky login and session refresh, timelines, search, mentions, native
  replies and quotes, UTF-8 facets, stable record keys, and deletion.
- Added Mastodon login, public and unlisted source handling, search, mentions,
  replies, link-based quotes, content warnings, idempotency keys, and deletion.
- Preserved comic drafting for local OpenAI-compatible/Ollama endpoints and
  Gemini, with sincere responses for serious or sensitive requests.
- Added foreground polling and daemon workflows with local active hours,
  monotonic scheduling, jitter, and isolation between jobs.
- Added optional Bluesky Jetstream notification wake-ups, with coalesced events,
  reconnect backoff, heartbeat checks, and periodic API reconciliation.

### Safety and storage

- Required exact individual approval for AI-generated drafts; AI generation has
  no direct publishing path.
- Discarded restricted Mastodon bodies before AI processing, output, or state.
- Preserved opt-outs, do-not-contact checks, Unicode-aware screening, queue limits,
  unsolicited interaction budgets, and per-author cooldowns.
- Added locked, atomic account storage with private permissions and Windows ACLs.
  Corrupt state fails closed; uncertain publications are not automatically retried.
- Added read-only import of compatible legacy state into an empty account store.
  Interrupted publications remain uncertain.
- Added bounded HTTP transport without redirects or automatic retries, and
  bounded Jetstream frame reception, fragmentation, headers, and deadlines.

### Distribution

- Added Linux and macOS archives and Windows ZIP packages containing both social
  platforms, checksums, application and dependency source, and original licenses.
- Added native launch, setup, non-overwriting installation, and verification tools.
- Required Erlang/OTP 25+ to run and Elixir 1.15+ with Mix to build. Linux uses
  `flock`; macOS and Windows use Python 3 for account-state locking.

See the [root changelog](https://github.com/buntatoes/chorusdraft/blob/bot-testing/CHANGELOG.md) for earlier published releases and
[PARITY.md](PARITY.md) for the inherited command and safety behavior.
