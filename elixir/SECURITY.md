# Security policy

## Supported versions

| Version | Runtime | Security support |
|---|---|---|
| 0.51.3 | Ruby and Elixir | Current |
| 0.51.2 and earlier | Ruby | Upgrade recommended |

Report vulnerabilities through GitHub private vulnerability reporting when
available, or contact the maintainer privately through the GitHub profile. Do
not put credentials, private posts, tokens, personal information, or exploit
details in a public issue.

## Security boundaries

ChorusDraft reduces accidental or abusive publication but cannot determine that
every draft is appropriate. The account owner must review the exact text,
visibility, reply or quote target, and content warning before approval.

AI-generated text cannot use the direct-publication path. Short commands do not
add publication permission. Owner-written text requires an explicit `--publish`
flag for direct publication; otherwise it enters the same queue.

Clear public requests to stop contact are recorded before reply generation.
Do-not-contact checks cover source authors and mentioned accounts. Harassment,
threats, doxxing, coordinated pile-ons, self-harm encouragement, and common
direct personal attacks are rejected before staging and checked again before
publication. Operators must not weaken these controls to target people.

Mastodon private, direct, and unknown-visibility bodies are discarded before
AI, logging, or persistent state. Automatic likes, favourites, boosts, and
reposts are disabled.

## Credentials and network behavior

Credentials belong only in local `.env` files or process environment variables.
Setup never overwrites an existing `.env`, executes its contents, starts a
service, or contacts a provider. Release packages exclude `.env`, state, logs,
and build caches.

Remote endpoints require HTTPS. Plain HTTP is allowed only for loopback local AI
servers. Redirects and automatic retries are disabled, request times and response
sizes are bounded, and remote bodies or credential-bearing details are omitted
from errors. Publication requests are never automatically retried.

Ambiguous publication results become `uncertain`. Inspect the account manually;
do not replay the draft until the outcome is known.

## State and process safety

State is separated by platform, service origin, and account. Both implementations
serialize writers, create private files where the runtime supports Unix modes,
replace state atomically, and fail closed on malformed state. Elixir additionally
applies protected Windows ACLs and explicitly refuses symlinks and special files.

Run only one daemon per account. Do not operate Ruby and Elixir against the same
account simultaneously or share a live state directory. Elixir import accepts
compatible state only into an empty account store and never alters the source.

## Elixir Jetstream

Jetstream is an optional wake-up signal for the Elixir Bluesky notification
workflow. Streamed bodies do not enter AI context, terminal output, or state.
Frame size, handshake headers, fragment counts, receive deadlines, heartbeats,
and reconnect backoff are bounded. Invalid handshakes and unsolicited
compression are refused. Periodic API checks reduce missed notifications after
disconnects but cannot guarantee complete delivery.

## Verification and known limits

The Elixir 0.51.3 suite contains 65 offline regressions and package checks on
Linux, macOS, and Windows. Ruby CI builds all six release archives and runs
source safety, command, archive, native launcher, setup, queue, and package tests
on Linux, Windows, Intel macOS, and ARM macOS. Tests use synthetic fixtures and
loopback servers without credentials or publication.

Live Bluesky, Mastodon, and AI-provider acceptance and a sustained daemon soak
remain operator checks. Use disposable accounts first and exercise login,
read-only search, staging, exact review, publication, deletion, opt-outs, and
network reconnection before production use.

## Privacy and secret review — 2026-09-06

A read-only pattern scan covered current branches and tags, reachable history,
local Git objects, the working tree, published release assets, retained CI
artifacts, and release descriptions. No live credential, private key, personal
email, phone number, personal path, or public IP address was found in published
GitHub content. Test values are synthetic, commit emails use GitHub noreply, and
dependency contacts are public upstream attribution.

Ignored local compiler outputs and unreachable local BEAM objects can retain a
developer workstation path. They are not part of current branches, tags, release
packages, or retained CI artifacts. Build only from a clean checkout. Pattern
scanning cannot prove the absence of every possible secret or form of personal
data. GitHub native secret scanning was disabled when this review ran.
