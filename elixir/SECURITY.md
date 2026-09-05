# Security policy for the 0.52 Elixir test build

Version 0.52 is unreleased test software on the `0.52-elixir-testing` branch. The
published 0.51 release remains the latest release. Report vulnerabilities using
GitHub private vulnerability reporting when available, or contact the maintainer
privately through the GitHub profile. Never include credentials, private posts,
or exploit details in a public issue.

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
  followed. Loopback HTTP is permitted only for a local AI service. Response size
  limits and generic errors reduce accidental disclosure.
- State is isolated by platform and account, stored with private permissions, and
  replaced atomically. A Linux process lock prevents concurrent writers. Corrupt
  state fails closed. Publishing requests are not automatically retried; uncertain
  results require manual account inspection.

The block list tracks handles rather than permanent identities across handle
changes. Update configured entries after a rename. Only fetched notifications can
be checked for new opt-outs. Keyword and pattern matching cannot understand every
form of harassment or prompt injection. Human review remains required for context,
accuracy, platform rules, and applicable law.
