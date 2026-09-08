# Changelog

Newest first. Also: [GitHub Releases](https://github.com/buntatoes/chorusdraft/releases).

## Unreleased

- README banner uses the desktop speech-bubble and voices mark.

## 0.51.4 — 2026-09-08

### License and desktop

- Apache License 2.0.
- Desktop launcher with ChatGPT credentials, automatic mode, and ten-day
  local history. Windows console detection is verified in the terminal
  launcher before enabling queue review.
- Replace the README project image with a high-contrast ChorusDraft banner.

### Privacy and screening

- Screen inherited content warnings before automatic publication and honor
  opt-outs in source text and content warnings.
- Expand automatic screening for direct threats, self-harm encouragement,
  coordinated harassment, Unicode domains, and normalized injection patterns.
- Redact recognized personal information from AI context before provider
  requests.
- Reject detected personal information and common credential formats in AI
  output and recheck saved AI drafts and content warnings before publication.
- Expand automatic link screening beyond a small list of domain suffixes.
- Add a verified email-history cleanup utility for authenticated local use.

### Automatic mode

- Explicit `automatic` command (`--daemon --automatic`). `start` and every
  other command stay review-first.
- Auto-publish only a newly generated original or eligible public-mention
  reply. Older queue items, owner text, quotes, and target/discovery commentary
  stay review-only.
- Stricter automatic-output screening: harassment, pile-ons, model-added
  mentions, links, and common contact patterns.
- Re-fetch the source and recheck content, content warning, handle, author,
  visibility, injection, opt-out, and do-not-contact.
- Five-attempt rolling 24-hour budget, single-flight claims, lockout, and
  stale claims to `uncertain`.
- `reject ID` / `--reject ID` clears a pending or uncertain draft without
  republishing.
- Empty or nil local/Gemini answers raise a clean error, matching OpenAI.

### Providers and Bluesky

- ChatGPT through the OpenAI Responses API (`chatgpt` / `openai`), bounded
  output, sanitized errors, `store: false`.
- Jetstream is the wake-up transport for Bluesky listen and daemon.
  `--jetstream` is a no-op.
- Canonical notification fetches and periodic catch-up kept. Streamed post
  bodies stay out of AI, output, and state.

## 0.51.3 — 2026-09-06

### Elixir runtime

- Elixir is the supported implementation.
- Bluesky and Mastodon in one executable.
- Short commands plus the full option interface. Command translation cannot
  add `--publish`.
- Import compatible older state into an empty account store.

### Platforms and packaging

- `.tar.gz` for Linux and macOS, `.zip` for Windows. Both social modes in
  every package.
- Unix and PowerShell setup, install, run, and verification scripts.
- Private Unix modes and Windows ACLs for config and state. Native locks and
  atomic state replacement.
- Application source, pinned dependency source and licenses, manifests, and
  SHA-256 sidecars. No credentials, state, logs, or build caches.
- CI on Ubuntu 22.04, macOS 14, and Windows Server 2022.

### Bluesky Jetstream

- Optional Jetstream wake-ups for Bluesky listeners and daemons, with
  periodic notification catch-up.
- Bounded frames, fragments, handshake headers, deadlines, reconnect backoff,
  and heartbeats.
- Streamed post bodies stay out of AI, the terminal, and state. Stream events
  cannot generate or publish.

### Safety

- Interactive review for AI drafts. Owner text publishes only with an explicit
  flag.
- Privacy filtering, opt-outs, do-not-contact, harassment screening,
  interaction budgets, ownership checks. No automatic likes/boosts/reposts.
- Crash-released locks, strict state validation, idempotent publication IDs,
  `uncertain` without automatic retries.
- No HTTP redirects or automatic retries. Request timeouts and streaming
  limits.

## 0.51.2 — 2026-09-06

- Earlier implementation required Ruby 4.0.
- Short commands and cross-platform launchers.
- Credential-free setup that leaves existing config alone.
- Full option interface and state format kept.

## 0.51.1 — 2026-09-05

- Record fetched public opt-outs before reply generation or batch limits.
- Broader normalization for opt-out and harassment screening.
- Do-not-contact covers generated, manual, and queued mentions and Mastodon
  content warnings.
- New opt-outs no longer replace earlier block-list entries.
- Full validation of Mastodon content warnings.

## 0.51 — 2026-09-05

- Dry comic voice; sincere on serious subjects.
- Varied originals and topic-focused reply, target, and discovery prompts.
- Review, privacy, interaction limits, and provider safety kept.

## 0.50 — 2026-09-05

- First ChorusDraft release: Bluesky and Mastodon drafting, interactive
  review, local AI and Gemini, scheduling, account-scoped state, opt-outs,
  privacy filtering, and cross-platform packages.
