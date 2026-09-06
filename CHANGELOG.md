# Changelog

This file records user-visible changes to ChorusDraft.

## 0.51.3 — Unreleased

### Added

- A desktop GUI launcher for Ruby and Elixir, with Bluesky and Mastodon choices.
- Buttons for setup, configuration, drafting, review, monitoring, search, and manual posts.
- Embedded activity output, interactive review responses, and a Stop control.
- Double-click launchers for macOS and Windows.
- Combined platform packages containing both implementations and their source.
- Elixir support for the short commands introduced in Ruby 0.51.2.

### Compatibility

- Existing Ruby commands and both implementations' flags remain supported.
- Configuration and state remain separate for each implementation and platform.
- AI-generated content continues to require individual approval before publication.

## 0.51.2 — 2026-09-06

### Changed

- Raised the minimum Ruby version from 3.2 to 4.0. Tested with Ruby 4.0.6.
- Added short commands for setup, drafting, review, posts, replies, quotes,
  search, discovery, account monitoring, and deletion.
- Added `bot` launchers for Linux and macOS with automatic rbenv detection,
  and `bot.bat` launchers for Windows.
- Added `bot setup` to create missing configuration files without credentials
  or network access. Existing configuration files are preserved.

### Compatibility

- Existing command-line flags and package `run.sh`/`run.bat` launchers remain
  supported.
- Configuration and state formats are unchanged. Existing drafts, opt-outs,
  and interaction history are preserved when the `data` directory is retained.
- AI-generated content continues to require individual review before publication.

## 0.51.1 — 2026-09-05

### Fixed

- All opt-out requests in the fetched notification batch are recorded before
  generating replies, including those after the five-reply limit or a failed AI request.
- Opt-out and harassment screening recognize curly apostrophes, full-width text,
  and inserted invisible formatting characters without rewriting approved text.
- Do-not-contact checks cover explicit mentions in generated, manual, and queued
  text and content warnings. Platform-specific mention boundaries are used, and
  Mastodon local handles match their fully qualified equivalents on the configured instance.
- Adding new opt-outs no longer removes older entries from the block list.
- Mastodon content warnings receive length, control-character, and harassment
  screening before staging, review, and publication. Invalid warnings cannot be
  published behind a sanitized or truncated preview.

## 0.51 — 2026-09-05

### Changed

- Original Bluesky and Mastodon drafts now request dry wit, playful exaggeration,
  absurd comparisons, and varied punchlines about programming and open source.
- Replies build on the conversation with gentle humor. Target and discovery
  commentary can satirize products, claims, and situations without belittling
  their authors.
- Shared AI instructions include comic style examples and discourage generic
  praise, lectures, repeated joke structures, and explanations of punchlines.
- Serious help requests, grief, and distress call for sincere responses. Comic
  exaggeration must be clearly fanciful; fabricated allegations, personal attacks,
  and requests to harass someone remain prohibited.

### Compatibility

- The comic voice applies to new AI drafts with both local AI and Gemini. Existing
  queued drafts and manually supplied text are not rewritten.
- Configuration and account state are compatible with 0.50. Preserve the `data`
  directory when upgrading to retain pending drafts, opt-outs, and interaction history.
- Every AI draft still needs interactive approval. Output screening, privacy
  controls, do-not-contact enforcement, interaction limits, and Gemini safety
  settings remain in place.

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
