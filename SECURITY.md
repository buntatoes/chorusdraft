# Security

## Supported versions

| Version | Runtime | Support |
|---|---|---|
| 0.51.6 | Elixir | Current |
| 0.51.5 and earlier | Earlier releases | Unsupported |

Report vulnerabilities through GitHub private reporting when it is available,
or contact the maintainer privately. Do not put credentials, private posts,
tokens, personal information, or exploit details in a public issue.

## Publication

Review is the default. `start`, one-shot AI commands, manual text, quotes,
target commentary, discovery commentary, and existing queue items cannot
auto-publish. Owner text needs `--publish` or it goes to the queue.

`automatic` may publish only the original or eligible public-mention reply
created in that daemon cycle. It does not sweep older drafts. Automatic output
is screened again for harassment, pile-ons, mixed-script words, model-added
mentions, links, and common email, phone, and street-address patterns. Held
drafts stay pending.

Before an automatic reply is claimed, the source is fetched again. ID, text,
content warning, handle, author identity, and public visibility must still
match. Injection, opt-out, and do-not-contact run again. Public opt-outs store
handle and identity aliases.

The lock reserves that draft and one of five automatic attempts per rolling
24 hours per account. Failures and ambiguous outcomes count. One automatic
publish in flight. `publishing` or `uncertain` blocks later claims. A
publishing claim older than five minutes becomes `uncertain` and is never
retried automatically.

`edit ID` and review `e` replace pending text after the same screens, then
leave the draft pending. They cannot publish. `--edit` cannot be combined with
`--publish`, reply, quote, or queue flags. Desktop review Edit prefills the
current text, keeps line breaks, and disables the response field until the
replacement is saved and review asks again.

`--random-reply` picks the target; it cannot be combined with `--publish`.

Review indents draft text. The desktop recognises the approval prompt and the
draft header only at the start of a line, so draft content cannot pose as
either.

These are regex checks. They miss some bad text and block some fine text.
Do not loosen them to chase people.

Public stop-contact requests are handled before reply generation. Do-not-contact
covers source handles, IDs, and mentioned accounts. Harassment, threats,
doxxing, pile-ons, self-harm encouragement, and common personal attacks are
rejected before staging and checked again before publish.

Mastodon private, direct, and unknown-visibility bodies are dropped before AI,
logs, or state. No automatic likes, favourites, boosts, or reposts.

## Credentials and network

Credentials live in local `.env` or the process environment. Setup never
overwrites an existing `.env`, executes it, starts a service, or contacts a
provider. Release packages exclude `.env`, state, logs, and build caches.

Local/Ollama stays on the configured loopback endpoint. Gemini and OpenAI
receive the drafting task and selected cleaned public context. OpenAI uses the
Responses API, an authorization header, bounded output, and `store: false`.
Read the provider's terms before using a remote model.

Remote social, Gemini, and OpenAI URLs must be HTTPS. For `local` / `ollama`,
`LOCAL_LLM_URL` must be loopback (`localhost`, `127.0.0.1`, `::1`) over HTTP or
HTTPS. No redirects, no automatic retries, bounded time and size. Errors omit
remote bodies and credentials. Publication is never retried automatically.

Ambiguous publishes become `uncertain`. Inspect the account, then `reject ID`
if it should not go out. That clears the automatic freeze. Do not replay an
uncertain draft until you know what happened.

## Personal information

Matching personal information in AI context is replaced with `[REDACTED]`
before the model request: ordinary and obfuscated emails, Unicode numeric
contact details, long numeric IDs, street/PO-box addresses, labeled identity
details, coordinate pairs, and common credential formats including Bluesky app
passwords, Google, GitHub, OpenAI, Stripe, and AWS keys, JWTs, and PEM
private-key headers.

AI output with those patterns is rejected, including in review mode. Saved AI
drafts and content warnings are checked again before publish. Reviewed text is
not silently edited. Public @mentions are allowed. Owner-written manual text
stays under owner control.

This is pattern matching. It can hold harmless numbers and will miss some
names, addresses, languages, and obfuscation. Human review is still required
for sensitive material.

## State

Split by platform, service origin, and account. Native locks serialize writers
and release after crashes. Unix files use private modes; Windows uses protected
ACLs. Replaces are atomic. Symlinks and special files are refused. Corrupt or
unexpected state is rejected.

One daemon per account. Import only into an empty account store. Unknown fields
are ignored or rejected. In-flight imports become `uncertain`. The source file
is not modified.

## Jetstream

Always on for Bluesky `listen` and daemon. `--jetstream` is a no-op. Stream
bodies never enter AI, the terminal, or state. Matches wake the normal
notification fetch.

Jetstream frames, handshakes, and reconnects have hard size and time limits.
Invalid handshakes and unsolicited compression are refused. Periodic API checks
help after disconnects; they do not guarantee delivery. Mastodon polls.

## Limits

Injection and automatic-output screens are regex on NFKC-normalized text with
format characters stripped. They can miss novel phrasing or hold benign text.

Try a disposable account first: login, search, staging, review, automatic
publish, delete, opt-outs, and reconnect.
