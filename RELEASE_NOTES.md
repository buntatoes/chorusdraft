# ChorusDraft 0.51.3 release notes

These notes are retained for reference. Future release notes, downloads, and
upgrade instructions are published in [GitHub Releases](https://github.com/buntatoes/chorusdraft/releases).

Version 0.51.3 establishes the Elixir implementation as the supported
ChorusDraft release for Linux, macOS, and Windows. One application supports both
Bluesky and Mastodon.

## Highlights

- Provides Bluesky and Mastodon clients, AI adapters, review queues, scheduling,
  account-scoped storage, and safeguards in one Elixir application.
- Adds native Linux, macOS, and Windows release packages containing both social
  platform modes.
- Includes short commands and a complete advanced option interface. Short
  commands never enable direct publication.
- Adds optional Bluesky Jetstream wake-ups with bounded WebSocket messages,
  reconnect handling, and periodic API catch-up.
- Supports explicit import of compatible older ChorusDraft state into an empty,
  account-scoped store.

## Safety and privacy

AI-generated text always enters the review queue. Each draft is validated before
staging and immediately before publication. Opt-outs and do-not-contact entries
block replies, quotes, mentions, and unsolicited commentary. Harassment,
threats, doxxing, coordinated pile-ons, self-harm encouragement, and common
direct personal attacks are rejected.

Mastodon private and direct message bodies are discarded before AI processing,
logging, or state storage. Automatic likes, boosts, favourites, and reposts are
disabled. Publication calls are not automatically retried; ambiguous outcomes
are marked `uncertain` for manual inspection.

Credentials remain in local `.env` files and are excluded from packages. Network
errors omit remote bodies and credential-bearing details.

## Packages

- `ChorusDraft-elixir-0.51.3-linux.tar.gz`
- `ChorusDraft-elixir-0.51.3-macos.tar.gz`
- `ChorusDraft-elixir-0.51.3-windows.zip`

Every archive includes its executable, native setup/install/verification
scripts, configuration examples, documentation, GPL source, pinned dependency
source and licenses, and a complete manifest. Each archive is published with a
SHA-256 sidecar. Runtime credentials, state, logs, and build caches are excluded.

## Verification status

The automated suite contains 65 offline regressions and runs natively on Ubuntu
22.04, macOS 14, and Windows Server 2022. It verifies the executable, archive
integrity, installation, private configuration, both platform modes, overwrite
refusal, compatibility-state import, and rebuilding from shipped dependency
source.

Automated fixtures do not establish live-service acceptance. Operators should
test login, read-only search, staging, review, publication, deletion, opt-outs,
and reconnect behavior with disposable accounts before production use.
