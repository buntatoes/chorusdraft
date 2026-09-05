# Security audit — BlueBot and Mastobot 0.50

Audit date: 2026-09-05 (UTC). Scope: shared Ruby source, both entry points,
configuration/setup, release builder, and all six generated platform packages.
This was a source review and offline adversarial test pass, not an independent
penetration test or a certification of the machine running the bots.

## Confirmed findings fixed

| Severity | Finding | Resolution |
| --- | --- | --- |
| High | Mastodon numeric account IDs are instance-local. Identical IDs on different servers could share a queue, and a draft could pass the account check on the wrong server. | Both the queue namespace and draft ownership now include the configured HTTPS origin and account identity. Bluesky uses the same origin binding. |
| Medium | Review displayed a snapshot, but publishing claimed the latest stored draft. An edit between display and confirmation could change the approved text. | The locked claim compares the complete stored draft with the reviewed snapshot and rejects any change before making a publishing request. |
| High, conditional | Rebuilding into an existing package directory could archive an unexpected leftover file, including a credential backup whose name was not exactly `.env`. Symlinks could also redirect builder writes. | The builder rejects unexpected files and symlinks in a package tree before populating it. Only enumerated release files are allowed. |

Existing privacy/publication controls were rechecked: restricted Mastodon bodies
are discarded; private replies and quotes are refused; source visibility is
rechecked at publication; AI output has no unattended publishing path; no automatic
likes/favourites exist; per-draft terminal approval is required; ambiguous writes
are not retried; Gemini keys are header-only; redirects and raw transport errors
do not expose credentials. Read-only staging requests may authenticate to the
social service; staging does not publish or like content.

## Validation

- 33 regression tests, 137 assertions: passed on the local Linux Ruby 3.2.3 runtime.
- Added reproductions for cross-instance account collision and review/edit races.
- Existing tests cover private/injection inputs, context filtering, manual versus
  AI publication, terminal-only review, concurrent queue updates, corrupt state,
  cooldown/queue limits, credential redaction, redirects, and Bluesky record APIs.
- Release-builder contamination checks cover an unexpected credential-backup
  filename and a symlink; both must stop the build before packaging.
- Each final archive is extracted and checked against source and documentation;
  its bundled tests and version command are run offline. SHA-256 checksums are
  regenerated after these audit fixes.

## Remaining deployment requirements and limits

- **Runtime upgrade remains necessary for an upstream-supported deployment.**
  The test host has Ruby 3.2.3; Ruby 3.2 is upstream end-of-life. Syntax compatibility
  with 3.2 is not a security endorsement. Deploy with a currently supported Ruby
  branch and current security patches, or verify your OS vendor's backport support.
  Runtime/OS upgrades were not performed. Sources:
  [Ruby maintenance branches](https://www.ruby-lang.org/en/downloads/branches/)
  and [Ruby security advisories](https://www.ruby-lang.org/en/security/).
- Native Windows/macOS execution, real API interoperability, TLS interception
  tests, and provider/account permissions have not been tested with live accounts.
- Local state/configuration are trusted files. Keep the entire installation in a
  private user-owned directory with appropriate Windows ACLs. This audit does not
  claim protection against another process running as the same OS user.
- Human review is still needed for inaccurate or manipulated AI output. Selecting
  Gemini deliberately sends eligible public content to that provider. No prompt
  filter can establish that a generated claim is true or appropriate.
- Old releases and running old services are outside the rewritten release and
  retain their old behavior. Stop them before migrating. Pre-audit 0.50 draft state
  uses the old account namespace and is deliberately not automatically imported.
- Checksums detect accidental change when compared with a trusted copy; they are
  not signed release provenance. No independent supply-chain attestation was made.
