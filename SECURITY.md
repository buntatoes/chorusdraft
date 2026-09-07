# Security policy

## Supported version

The latest stable release is
[0.51.2](https://github.com/buntatoes/chorusdraft/releases/tag/v0.51.2).
Version 0.51.3 is an Elixir desktop preview. Use a supported, security-patched
Erlang/OTP runtime that meets its minimum requirements. See
[Elixir security](elixir/SECURITY.md) for transport, state, and platform safeguards.

## Reporting a vulnerability

Use GitHub's private vulnerability reporting feature when it is available for
this repository. Otherwise, contact the maintainer privately through the GitHub
profile. Do not put credentials, tokens, private messages, or exploit details in
a public issue.

Include the affected product, operating system, exact version, reproduction
steps, and the security impact. Revoke any credential that may have been exposed.

## Desktop credentials

The desktop encrypts saved account and AI settings with Electron's `safeStorage`,
backed by operating-system protected storage. Linux requires a supported system
keyring; the plaintext fallback backend is refused. When protected storage is
unavailable, users can choose session-only settings. Newly entered session
credentials are not written to disk, though existing configuration files remain
unchanged.

Password and token fields are masked. Saved secrets are not returned to the
settings form. Settings use a restricted desktop bridge and are supplied to the
selected local bot process for its session. Known configured secrets are redacted
from GUI activity before display and storage. Credentials still exist in process
memory while in use; operating-system protection does not protect against a
compromised user account, malware, or an administrator inspecting that process.

Secure saving removes only fields managed by the form from the selected platform's
`.env`. Advanced `.env` settings and separately launched command-line environment
variables remain supported and are the user's responsibility. Saved GUI settings
are not automatically passed to separately launched CLI processes. Forgetting
settings does not revoke credentials or erase external copies.

The renderer runs with context isolation and sandboxing, without Node.js access.
Navigation and new windows are blocked. The bridge permits specific bot operations
and validates platform selection and input; it does not accept arbitrary shell
commands.

## Local history and retention

ChorusDraft stores account state and desktop activity on the user's computer and
does not upload history or activity logs. Publishing and configured AI requests
still send their necessary content to the selected service. Local history can
contain post text and account identifiers; treat it as private account data.

Published and rejected draft records expire after 10 days from completion, or
creation for legacy records without a completion time. Desktop activity is grouped
into hourly files; each event expires 10 days after its timestamp. Oldest activity
files may be removed sooner to keep storage within 50 MB. The desktop also removes
expired bot log files under the installation's `logs/` directories.

Cleanup runs while the app is open and at its next launch. CLI state access also
prunes completed records. Cleanup requires the bot runtime and writable storage;
errors are reported in the GUI. The application cannot remove files while it is
closed or the computer is off. Operating-system backups, synced folders, user
exports, and external terminal or service-manager logs remain outside its control.
Deletion is ordinary file removal, not forensic secure erasure.

Pending drafts, uncertain publications, do-not-contact entries, duplicate
identifiers, and interaction safety records remain retained separately. These
records prevent lost work, duplicate publication, and renewed unwanted contact.
Local expiry does not delete posts from social services. Storage locations are
listed in the [README](docs/DESKTOP.md#local-history).

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
- Credentials come from protected GUI settings or the command-line environment
  and `.env`. Runtime credentials are excluded from release packages, sent only
  to validated endpoints, and omitted from network errors.
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
