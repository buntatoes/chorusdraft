# Security policy

## Supported versions

| Version | Runtime | Security support |
|---|---|---|
| 0.51.4 | Elixir | Current |
| 0.51.3 and earlier | Earlier releases | Unsupported; upgrade recommended |

Report vulnerabilities through GitHub private vulnerability reporting when
available, or contact the maintainer privately through the GitHub profile. Do
not put credentials, private posts, tokens, personal information, or exploit
details in a public issue.

## Publication boundary

Review-first behavior is the default. `start`, one-shot AI commands, manual
text, quotes, target commentary, discovery commentary, and existing queue items
cannot acquire automatic AI publication permission. Owner-written text requires
an explicit `--publish`; otherwise it enters the queue.

The explicit `automatic` command may publish only the exact original or eligible
incoming public-mention reply generated in that daemon cycle. It cannot sweep
older pending drafts. Generated text and any content warning are screened again
for the baseline content rules plus expanded harassment, pile-ons, normalized
prompt-injection patterns, account mentions, links, and common email, phone, and
street-address patterns. A held draft remains pending for review.

Before an automatic reply is claimed, the source is re-fetched from the platform
API. Its ID, text, content warning, handle, and immutable author identity must
still match the context used for generation, and the source must retain supported
public visibility. Prompt-injection, opt-out, and do-not-contact checks run
again, including opt-outs in source text or its content warning. Public opt-outs
record both handle and immutable identity aliases.

The state lock atomically reserves both the exact draft and one of five automatic
attempts allowed per rolling 24 hours per account. Failed and ambiguous attempts
count. Only one automatic publication may be in flight. Any `publishing` or
`uncertain` draft blocks later automatic claims. A publishing claim older than
five minutes becomes `uncertain`; it is never retried automatically.

These controls reduce risk but are deterministic and can miss harmful context or
hold benign text. Review mode provides the strongest operator control. Operators
must not weaken safeguards to target people.

Clear public requests to stop contact are also processed before reply generation.
Do-not-contact checks cover source handles, immutable IDs, and mentioned
accounts. Baseline harassment, threats, doxxing, coordinated pile-ons, self-harm
encouragement, and common direct personal attacks are rejected before staging
and checked before publication.

Mastodon private, direct, and unknown-visibility bodies are discarded before AI,
logging, or persistent state. Automatic likes, favourites, boosts, and reposts
are disabled.

## Credentials, providers, and network behavior

Credentials belong only in local `.env` files or process environment variables.
Setup never overwrites an existing `.env`, executes its contents, starts a
service, or contacts a provider. Release packages exclude `.env`, state, logs,
and build caches.

Local/Ollama uses the configured loopback endpoint. Gemini and ChatGPT/OpenAI
are remote privacy boundaries: the drafting task and selected cleaned public
context are sent to the chosen provider. The OpenAI adapter uses the Responses
API with a bearer authorization header and `store: false`; it rejects failed,
incomplete, malformed, and empty responses before applying platform-length and
content safeguards. OpenAI generation is capped at 256 output tokens.
`store: false` disables storage for later API retrieval but does not itself claim
zero data retention. Review [OpenAI's current data controls](https://developers.openai.com/api/docs/guides/your-data)
before enabling a remote provider.

Remote endpoints require HTTPS. Plain HTTP is allowed only for loopback local AI
servers. Redirects and automatic retries are disabled, request times and response
sizes are bounded, and remote bodies or credential-bearing details are omitted
from errors. Publication requests are never automatically retried.

Ambiguous publication results become `uncertain`. Inspect the account manually;
do not replay the draft until the outcome is known.

## State and process safety

State is separated by platform, service origin, and account. Native locks
serialize writers and release after crashes. Unix files use private modes;
Windows uses protected ACLs. State replacement is atomic, symlinks and special
files are refused, and malformed state fails closed.

Run only one daemon per account. State import accepts compatible data only into
an empty account store, adds new state fields conservatively, converts imported
in-flight publications to `uncertain`, and never alters the source file.

## Jetstream

Jetstream is required and starts automatically for Bluesky `listen` and daemon
workflows, including `start` and `automatic`. It cannot be disabled in those
modes; `--jetstream` remains a compatibility no-op.
Streamed bodies do not enter AI context, terminal output, or state. Matching
events only wake the canonical notification fetch, where opt-out,
deduplication, safety, and publication policy still apply.

Frame size, handshake headers, fragment counts, receive deadlines, heartbeats,
and reconnect backoff are bounded. Invalid handshakes and unsolicited
compression are refused. Periodic API checks reduce missed notifications after
disconnects but cannot guarantee complete delivery. Mastodon uses polling.

## Verification and known limits

The 0.51.4 suite contains 80 offline regressions and package checks for Linux,
macOS, and Windows. Tests use synthetic fixtures and loopback servers without
credentials or live publication. Coverage includes review and automatic mode,
source-edit and opt-out revalidation, publication budgets and interlocks,
ambiguous outcomes, state migration, provider errors, HTTP/WebSocket bounds,
checksums, installation, private configuration, runtime-data exclusion, and an
offline rebuild from shipped source.

Live Bluesky, Mastodon, and AI-provider acceptance and a sustained daemon soak
remain operator checks. Use disposable accounts first and exercise login,
read-only search, staging, exact review, automatic publication, deletion,
opt-outs, and network reconnection before production use.
