# Security policy

## Supported versions

| Version | Runtime | Security support |
|---|---|---|
| 0.51.3 | Elixir | Current |
| 0.51.2 and earlier | Earlier runtimes | Unsupported; upgrade recommended |

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

Remote social and Gemini endpoints require HTTPS. When `AI_PROVIDER` is `local`
or `ollama`, `LOCAL_LLM_URL` must use a loopback host (`localhost`, `127.0.0.1`,
or `::1`) over HTTP or HTTPS — remote HTTPS hosts are rejected for local AI.
Redirects and automatic retries are disabled, request times and response sizes
are bounded, and remote bodies or credential-bearing details are omitted from
errors. Publication requests are never automatically retried.

Ambiguous publication results become `uncertain`. Inspect the account manually;
do not replay the draft until the outcome is known.

## State and process safety

State is separated by platform, service origin, and account. Native locks
serialize writers and release after crashes. Unix files use private modes;
Windows uses protected ACLs. State replacement is atomic, symlinks and special
files are refused, and malformed state fails closed.

Run only one daemon per account. State import accepts compatible data only into
an empty account store and never alters the source file.

## Jetstream

Jetstream is an optional wake-up signal for the Bluesky notification workflow.
Streamed bodies do not enter AI context, terminal output, or state. Frame size,
handshake headers, fragment counts, receive deadlines, heartbeats, and reconnect
backoff are bounded. Invalid handshakes and unsolicited compression are refused.
Periodic API checks reduce missed notifications after disconnects but cannot
guarantee complete delivery.

## Verification and known limits

The 0.51.3 suite contains 65 offline regressions and package checks on Linux,
macOS, and Windows. Tests use synthetic fixtures and loopback servers without
credentials or publication. Package checks cover checksums, installation,
private configuration, runtime-data exclusion, both platform modes, and an
offline rebuild from shipped source.

Inbound prompt-injection screening is a best-effort regex on normalized text
(NFKC and format-character stripping, matching opt-out and harassment). It can
still miss novel phrasing; interactive review before publish remains the
primary control.

Live Bluesky, Mastodon, and AI-provider acceptance and a sustained daemon soak
remain operator checks. Use disposable accounts first and exercise login,
read-only search, staging, exact review, publication, deletion, opt-outs, and
network reconnection before production use.
