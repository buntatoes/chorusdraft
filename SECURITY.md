# Security policy for the Elixir experiment

The supported Ruby release is ChorusDraft 0.51.1 from `main-ruby`. The Linux
Elixir version of ChorusDraft on `elixir-experimental` is unreleased. Its offline regression, state-import, and
package checks have passed; live platform verification, a sustained daemon soak,
and an independent release security audit remain outstanding.

The latest targeted review hardened optional Jetstream reception: frames and
fragmented messages have limits checked before payload reads, and handshake
headers, fragment counts, and receive times are bounded. Socket-level regression
tests cover these boundaries alongside the existing publication safeguards.

Report vulnerabilities using GitHub private vulnerability reporting when
available, or contact the maintainer privately through the GitHub profile. Do not
put credentials, private posts, tokens, or exploit details in a public issue.

The implemented Elixir safeguards and current limitations are documented in
[`elixir/SECURITY.md`](elixir/SECURITY.md). Treat those controls as an
implementation checkpoint rather than a completed security guarantee.

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
