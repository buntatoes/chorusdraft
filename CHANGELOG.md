# Changelog

This file records user-visible changes to ChorusDraft.

## 0.50 — 2026-09-05

Version 0.50 begins the ChorusDraft release line. Its Bluesky and Mastodon
integrations share the same Ruby implementation and command-line interface on
Linux, macOS, and Windows.

### Bluesky integration

- Added original post drafting, mention replies, public search, random-post
  selection, account targets, discovery, and foreground
  monitoring for Bluesky.
- Added native Bluesky reply references and quote-post embeds using freshly fetched
  records.
- Added rich-text facets for HTTPS links, account mentions, and hashtags, including
  UTF-8 byte offsets for non-ASCII text.
- Added custom PDS support through `BLUESKY_PDS_URL`.
- Added deletion of posts owned by the authenticated account.

### Mastodon integration

- Added original post drafting, mention replies, public search, random-post
  selection, account targets, discovery, and foreground
  monitoring for Mastodon.
- Added public, unlisted, followers-only, and mentioned-users visibility options.
- Added content warnings, language selection, and link-based quote commentary.
- Added deletion of statuses owned by the authenticated account.
- Public replies to unlisted posts are automatically narrowed to unlisted.

### Shared features

- Added local Ollama and OpenAI-compatible AI support as the default provider.
- Added optional Google Gemini support with an explicitly configured model.
- Added recent-post context to original drafts to reduce repeated topics.
- Added eligible public thread context to reply drafts.
- Added an interactive queue showing the exact draft, visibility, reply or quote
  target, and content warning before publication.
- Added active-hour windows, overnight schedules, configurable poll and draft
  intervals, and randomized posting jitter.
- Added per-server/account state, duplicate history, a 100-draft queue limit, a
  five-per-day unsolicited draft limit, and a 30-day per-author cooldown.
- Added Linux/macOS shell launchers and a Windows batch launcher. All launchers
  forward command-line arguments and display help when run without arguments.
- Added a setup command that creates missing configuration files while preserving
  existing files.

### Privacy and security

- AI-generated content always enters the review queue. Direct publishing is
  available only for text explicitly supplied by the account owner.
- Private, direct, and unknown-visibility Mastodon message bodies are discarded
  before AI processing, logging, or state storage. Restricted-message replies are
  disabled in this release.
- Reply and quote visibility is checked again immediately before publication.
- Suspected prompt-injection posts are skipped rather than answered.
- Removed dedicated critical targeting. Target and discovery workflows request
  respectful topic-focused commentary without personal judgment or provocation.
- Added persistent do-not-contact state and a configurable do-not-contact file.
  Clear public requests to stop replying are honored automatically; blocked
  accounts cannot receive queued or manual replies, quotes, or target commentary.
- Expanded output screening for threats, doxxing, pile-on requests, self-harm
  encouragement, and common direct personal attacks.
- Automatic likes, favourites, boosts, and reposts are disabled.
- Gemini keys are sent in request headers. Remote error bodies and credential-bearing
  network details are excluded from logs.
- Publishing requests are not automatically retried. Ambiguous results are marked
  `uncertain` for manual account inspection.
- Queue updates are locked and atomically replaced. Corrupt state stops processing
  instead of silently resetting duplicate history.
- Draft ownership includes the server origin and account identity. A draft changed
  after display must be reviewed again.
- Release builds reject unexpected files and symbolic links before packaging.
- Added a GPLv3 modification and attribution notice. Replaced the dated audit
  report with a maintainable security policy and disclosure instructions.

### Compatibility and migration

- The project, commands, source namespace, and archive filenames use the
  ChorusDraft name.
- Ruby 3.2 or later is required for syntax compatibility; a currently supported,
  security-patched Ruby release is recommended for production.
- Earlier draft and interaction files are not imported automatically. Install into
  a new directory and stop previous listeners or scheduled services before use.
- `--reply-cid` and `--quote-cid` remain accepted for command compatibility, but
  the current Bluesky record is fetched instead of trusting a supplied CID.
- Bluesky feed posts are public and do not accept Mastodon visibility or content
  warning options.
