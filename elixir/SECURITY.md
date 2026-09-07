# Security policy for the Elixir bot

This policy covers the Elixir implementation in the ChorusDraft 0.51.3 preview.
Report vulnerabilities using GitHub private
vulnerability reporting when available, or contact the maintainer privately
through the GitHub profile. Never include credentials, private posts, or exploit
details in a public issue.

The Elixir implementation enforces these boundaries:

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
- State is isolated by platform and account, stored with private permissions,
  and replaced atomically. Linux uses a kernel `flock`; macOS uses `fcntl`, and
  Windows uses `msvcrt` plus atomic Python `os.replace`. The helper locks release
  when their owning VM exits. Windows configuration and state use ACLs
  limited to the current user and SYSTEM. Corrupt state fails closed. Publishing
  requests are not automatically retried; uncertain results require manual
  account inspection.
- Import reads the old state without modifying it, requires an empty destination,
  and preserves publication IDs and interaction history. Interrupted publications
  become uncertain; import never makes them eligible for automatic replay.

The block list tracks handles rather than permanent identities across handle
changes. Update configured entries after a rename. Only fetched notifications can
be checked for new opt-outs. Keyword and pattern matching cannot understand every
form of harassment or prompt injection. Human review remains required for context,
accuracy, platform rules, and applicable law.

## Credentials and local retention

GUI launches receive account settings through the desktop's restricted bridge.
Persistent settings use operating-system protected storage; session-only use is
available when secure storage cannot be used. Secure saving removes only the
form's managed fields from that platform's `.env`. Separate CLI launches still
read the environment and `.env`; plaintext files must be kept private.
See the [desktop security policy](https://github.com/buntatoes/chorusdraft/blob/bot-testing/SECURITY.md#desktop-credentials).

The account store keeps successful post text for up to 10 days. Completed
published and rejected records are pruned during state access and desktop
maintenance; legacy records without a completion time use their creation time.
Pending drafts, uncertain publications, opt-outs, duplicate identifiers, and
interaction safety records remain separately retained. History expiry never
resets an uncertain draft for publication.

The desktop records local GUI activity for up to 10 days, with a 50 MB limit that
can remove older activity sooner. Hourly files expire from the beginning of their
hour. Desktop maintenance also removes expired bot log files in the installation.
The bot does not create a separate persistent terminal-output archive; logs captured
by external launchers or service managers require their own retention policy.

History and activity are not uploaded by ChorusDraft. Normal posting and AI calls
still send necessary content to the selected provider. Cleanup runs while the app
is open and at its next launch; it cannot run on a powered-off computer and depends
on writable storage and an available runtime. Backups, sync software, exports, and
external log capture are outside these controls. Local expiry does not delete
remote posts or provide forensic secure erasure.

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
notification traffic can still cause missed events.
