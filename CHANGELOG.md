# Changelog

This file records user-visible changes to BlueBot and Mastobot.

## 0.50 — 2026-09-04

Version 0.50 begins the BlueBot and Mastobot release line. Both clients now share
the same Ruby implementation and command-line interface on Linux, macOS, and Windows.

### BlueBot

- Added original post drafting, mention replies, public search, random-post
  selection, account targets, discovery, critical commentary, and foreground
  monitoring for Bluesky.
- Added native Bluesky reply references and quote-post embeds using freshly fetched
  records.
- Added rich-text facets for HTTPS links, account mentions, and hashtags, including
  UTF-8 byte offsets for non-ASCII text.
- Added custom PDS support through `BLUESKY_PDS_URL`.
- Added deletion of posts owned by the authenticated account.

### Mastobot

- Added original post drafting, mention replies, public search, random-post
  selection, account targets, discovery, critical commentary, and foreground
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
  15-per-day unsolicited draft limit, and a 24-hour per-author cooldown.
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

### Compatibility and migration

- Product names and archive filenames changed to BlueBot and Mastobot.
- Ruby 3.2 or later is required for syntax compatibility; a currently supported,
  security-patched Ruby release is recommended for production.
- Earlier draft and interaction files are not imported automatically. Install into
  a new directory and stop previous listeners or scheduled services before use.
- `--reply-cid` and `--quote-cid` remain accepted for command compatibility, but
  the current Bluesky record is fetched instead of trusting a supplied CID.
- BlueBot feed posts are public and do not accept Mastodon visibility or content
  warning options.
