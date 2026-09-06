# Security policy

## Supported version

The latest supported release is 0.51.1 from `main-ruby`. The controls below
describe that release. Use a currently supported, security-patched Ruby runtime.

## Reporting a vulnerability

Use GitHub's private vulnerability reporting feature when it is available for
this repository. Otherwise, contact the maintainer privately through the GitHub
profile. Do not put credentials, tokens, private messages, or exploit details in
a public issue.

Include the affected product, operating system, exact version, reproduction
steps, and the security impact. Revoke any credential that may have been exposed.

## Enforced safety boundaries

- Every AI-generated post enters an interactive review queue. AI output has no
  unattended publishing path.
- The built-in critical-targeting mode has been removed. Target and discovery
  drafts are limited to five per rolling 24 hours and may
  involve a given author at most once every 30 days.
- AI instructions allow satire of software, products, public claims, and situations
  while prohibiting personal humiliation, threats, private-information disclosure,
  and harassment. These are model instructions, not a guarantee about generated
  text. Comic framing does not bypass screening or publication review.
- Public requests such as “stop replying to me” permanently add that account to
  local do-not-contact state. Operators can preconfigure additional accounts in
  `config/do_not_contact.txt`. Queued and manual interactions with those accounts
  are refused.
- The fetched notification batch is checked for opt-outs before reply generation
  or limits. Older opt-outs are retained when new ones are added. Do-not-contact
  checks include explicit mentions in draft text and content warnings, with
  Mastodon local-handle aliases on the configured instance recognized.
- Output screening rejects direct self-harm encouragement, threats, doxxing,
  pile-on requests, and common direct personal attacks. Human review remains
  responsible for context, factual accuracy, and language that filters cannot
  reliably classify.
- Mastodon content warnings are screened before staging, review, and publication;
  the reviewer sees the same accepted text that will be sent. Unicode normalization
  is used only for matching opt-out and abuse patterns, never to rewrite a draft.
- Mastodon private, direct, and unknown-visibility message bodies are discarded
  before AI processing, logging, or state storage.
- Credentials are read from the environment or `.env`, excluded from release
  packages, sent only to validated endpoints, and omitted from errors.
- Publishing requests are not automatically retried. An ambiguous result is
  marked `uncertain` for manual account inspection.

These controls cover the supplied AI workflows. An operator remains responsible
for manually written posts, account configuration, platform rules, and applicable
law.

The block list tracks handles, not a permanent identity across handle changes.
Update configured entries after a rename. Only the fetched notification batch can
be checked for new opt-outs; unavailable or older notifications may not be observed.
Keyword matching cannot classify all harassment or prompt injection. Human review
remains required, including for drafts that pass automated checks.

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
