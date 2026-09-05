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

The optional BlueBot stream connects with TLS certificate and hostname
verification. It sends no Bluesky app password, session token, or AI credentials.
The current JSON subprotocol is required. Post bodies are decoded only to
identify relevant activity; complete messages over 1 MiB are ignored. This is an
application decoding limit, not a transport-level bound on fragmented frames.

Stream content is an untrusted signal to fetch the account's notifications, never
a direct source of AI context or publication. A single coalesced wake-up prevents
network bursts from filling the consumer's mailbox. Startup, reconnect and
periodic notification checks remain active, subject to the existing fetch window.
Jetstream cursors and historical replay are not implemented, so outages or heavy
notification traffic can still cause missed events. A complete live audit remains
unfinished.
