# Security policy for the Elixir experiment

This is an unreleased separate implementation on the `elixir-experimental`
branch. The supported release is Ruby 0.51.1 from `main-ruby`; future Ruby maintenance work is isolated
on `ruby-testing`. Report vulnerabilities using GitHub private
vulnerability reporting when available, or contact the maintainer privately
through the GitHub profile. Never include credentials, private posts, or exploit
details in a public issue.

The Elixir port enforces these boundaries:

- AI output enters a review queue and requires explicit approval for the exact
  queued text. The `--publish` option applies only to manually supplied text.
- Mastodon private, direct, and unknown-visibility bodies are discarded before
  they can enter AI context, state, or terminal output.
- Do-not-contact requests and configured entries block replies, quotes, target
  commentary, manual interactions, explicit mentions, and queued publication.
- Output screening rejects direct self-harm encouragement, threats, doxxing,
  pile-on requests, common personal attacks, control characters, and over-limit
  text. Mastodon content warnings receive the same validation.
- Prompt-like instructions in public source posts are excluded from AI workflows.
  Source content is serialized as untrusted data under a separate system prompt.
- Unsolicited target and discovery drafts are limited to five per rolling day and
  one per author every 30 days. Automatic likes, favourites, boosts, and reposts
  are absent.
- Remote endpoints require HTTPS and credential-bearing redirects are not
  followed. Mint HTTP/1 connections issue one request without automatic retries,
  including on 503 responses. Loopback HTTP is permitted only for a local AI
  service. Streaming response size/header limits and generic errors reduce accidental disclosure.
- State is isolated by platform and account, stored with private permissions, and
  replaced atomically. A Linux kernel flock prevents concurrent writers and
  releases on process exit. Corrupt state fails closed. Publishing requests are not automatically retried; uncertain
  results require manual account inspection.
- Import reads the old state without modifying it, requires an empty destination,
  and preserves publication IDs and interaction history. Interrupted publications
  become uncertain; import never makes them eligible for automatic replay.

The block list tracks handles rather than permanent identities across handle
changes. Update configured entries after a rename. Only fetched notifications can
be checked for new opt-outs. Keyword and pattern matching cannot understand every
form of harassment or prompt injection. Human review remains required for context,
accuracy, platform rules, and applicable law.

## Jetstream boundary

The optional Bluesky Jetstream client connects with TLS certificate and hostname
verification. It sends no Bluesky app password, session token, or AI credentials.
The current JSON subprotocol is required. Post bodies are decoded only to
identify relevant activity. Passive reads check declared frame lengths before
reading payloads: complete and fragmented messages are limited to 1 MiB, with
at most 1,024 fragments. Each handshake header line and the aggregate header
fields are limited to 16 KiB. Handshakes and individual frame reads have a
10-second deadline; assembling a fragmented message has a 90-second deadline.
Unrequested compression and malformed handshakes are refused. These limits bound
application message assembly; they are not an operating-system memory quota.

Stream content is an untrusted signal to fetch the account's notifications, never
a direct source of AI context or publication. A single coalesced wake-up prevents
network bursts from filling the consumer's mailbox. Startup, reconnect and
periodic notification checks remain active, subject to the existing fetch window.
Jetstream cursors and historical replay are not implemented, so outages or heavy
notification traffic can still cause missed events. A complete live audit remains
unfinished.

## Privacy review — 2026-09-06

A targeted review scanned all four branch tips, branch/tag commit history,
published Ruby 0.50, 0.51, and 0.51.1 archives, local Ruby 0.51.2 archives,
and the successful Elixir CI package. Gitleaks 8.30.1 was combined with checks
for personal paths, email addresses, phone/identity-number patterns, runtime
configuration/state, and decoded executable metadata.

No confirmed credentials or unintended personal data were found in that scope.
Secret-scanner findings were reviewed as synthetic post-record identifiers in
Ruby/Elixir test fixtures. Example identities and public attribution are retained.
Commit emails use GitHub noreply addresses. Elixir executable metadata contains
generic CI runner build paths, not a developer's personal home directory.

Private local build caches can contain machine paths; they are ignored and are
not in the inspected branch/tag history or release packages. This targeted review
is not an independent security audit or a guarantee that every possible secret
or form of personal data can be detected. Live-account acceptance remains a
separate check. Existing published tags and assets were not modified.
