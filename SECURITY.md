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
older pending drafts. Automatic output is screened again for the baseline content
rules plus harassment, pile-ons, model-added mentions, links, and common email,
phone, and street-address patterns. A held draft remains pending for review.

Before an automatic reply is claimed, the source is re-fetched from the platform
API. Its ID, text, content warning, handle, immutable author identity, and public
visibility must still match the context used for generation. Prompt-injection,
opt-out, and do-not-contact checks run again. Public opt-outs record both handle
and immutable identity aliases.

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
API with an authorization header, bounded output, and `store: false`. Review
provider terms and account data controls before enabling a remote provider.

Remote social, Gemini, and OpenAI endpoints require HTTPS. When `AI_PROVIDER`
is `local` or `ollama`, `LOCAL_LLM_URL` must use a loopback host (`localhost`,
`127.0.0.1`, or `::1`) over HTTP or HTTPS — remote HTTPS hosts are rejected for
local AI. Redirects and automatic retries are disabled, request times and
response sizes are bounded, and remote bodies or credential-bearing details are
omitted from errors. Publication requests are never automatically retried.

Ambiguous publication results become `uncertain`. Inspect the account manually,
then reject a pending or uncertain draft with `reject ID` / `--reject ID` when it
should not publish. Rejection clears the automatic-mode freeze without
republishing; do not replay or force an uncertain draft back to pending until
the outcome is known.

## Personal information

AI context is screened and matching personal information is replaced with
`[REDACTED]` before any local or remote model request. Screening recognizes
ordinary and common obfuscated email addresses, Unicode numeric contact details,
long numeric identifiers, street/PO-box addresses, labeled identity details,
precise coordinate pairs, and common credential formats.

AI output is rejected if these patterns are detected, including in review mode.
Saved AI drafts and content warnings are checked again before publication.
The bot does not silently edit reviewed text. Public social mentions remain
supported, and explicitly owner-written manual text remains under owner control.

This is conservative pattern matching: it can hold harmless numbers and cannot
identify every name, address, identifier, language, or obfuscation. Public source
posts can still contain personal information that these rules miss. Human review
remains necessary for sensitive material; this feature does not promise anonymity.

## State and process safety

State is separated by platform, service origin, and account. Native locks
serialize writers and release after crashes. Unix files use private modes;
Windows uses protected ACLs. State replacement is atomic, symlinks and special
files are refused, and malformed state fails closed.

Run only one daemon per account. State import accepts compatible data only into
an empty account store, adds new state fields conservatively, converts imported
in-flight publications to `uncertain`, and never alters the source file.

## Jetstream

Jetstream starts automatically for Bluesky `listen` and daemon workflows and
cannot be disabled in those modes. `--jetstream` remains a compatibility no-op.
Streamed bodies do not enter AI context, terminal output, or state. Matching
events only wake the canonical notification fetch, where opt-out,
deduplication, safety, and publication policy still apply.

Frame size, handshake headers, fragment counts, receive deadlines, heartbeats,
and reconnect backoff are bounded. Invalid handshakes and unsolicited
compression are refused. Periodic API checks reduce missed notifications after
disconnects but cannot guarantee complete delivery. Mastodon uses polling.

## Known limits

Inbound prompt-injection screening and the stricter automatic-output gates are
best-effort, deterministic regex checks on normalized text (NFKC and
format-character stripping, matching opt-out and harassment). They can still miss
novel phrasing or hold benign text; interactive review before publish remains the
primary control outside explicit automatic mode.

Live Bluesky, Mastodon, and AI-provider acceptance and a sustained daemon soak
remain operator checks. Use disposable accounts first and exercise login,
read-only search, staging, exact review, automatic publication, deletion,
opt-outs, and network reconnection before production use.

