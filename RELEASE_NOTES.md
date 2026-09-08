# ChorusDraft 0.51.4 release notes

Release notes, downloads, and upgrade guidance are published in
[GitHub Releases](https://github.com/buntatoes/chorusdraft/releases).

Version 0.51.4 adds an explicit safeguarded automatic mode, makes Bluesky
Jetstream the default listener transport, and adds ChatGPT through the OpenAI
Responses API. Review-first behavior remains the default.

## Highlights

The current main branch also includes unreleased privacy and automatic-screening
fixes described in CHANGELOG.md. These fixes are not in the v0.51.4 downloads.

- Run `chorusdraft PLATFORM automatic` to opt into automatic publication for
  newly generated originals and eligible public-mention replies.
- Reject pending or uncertain drafts with `reject ID` so automatic mode can
  resume without a blind republish.
- Keep `start`, `draft`, `replies`, manual posts, quotes, target commentary,
  discovery commentary, and existing queued items under the established review
  or explicit-owner-publication rules.
- Use `AI_PROVIDER=chatgpt` (or `openai`) with `OPENAI_API_KEY` and
  `OPENAI_MODEL`. Local/Ollama and Gemini providers remain supported.
- Bluesky `listen` and `start` now use Jetstream automatically.
  `--jetstream` is retained as a compatibility no-op, and
  `--no-jetstream` is rejected.
- All platform API calls, AI calls, and publication calls retain bounded
  responses, sanitized errors, and no automatic retry behavior.

## Automatic-publication boundary

Automatic mode does not approve a queue. It may claim only the exact draft just
created by that daemon cycle, and only when it is an original or a reply to an
eligible incoming public mention.

Before an automatic reply is claimed, ChorusDraft re-fetches the source through
the canonical service API. The ID, text, content warning, handle, immutable
author identity, and visibility must match the generation context. Injection,
opt-out, and do-not-contact checks run again. Generated output receives an
additional deterministic screen that holds model-added mentions, links, common
contact-information patterns, harassment, and pile-on language for review.

Each account receives at most five automatic publication attempts per rolling
24 hours. The attempt is reserved atomically before the network call and counts
even if the outcome is ambiguous. Only one automatic publication may be in
flight, and any `publishing` or `uncertain` item blocks later automatic
claims. A crash-stranded publishing claim ages into `uncertain`; no
publication is retried automatically. After inspecting the account, operators can
reject a pending or uncertain draft with `reject ID` / `--reject ID` to clear the
automatic-mode freeze without republishing it.

These controls reduce risk but cannot understand every context. Screening remains
best-effort and deterministic. Operators remain responsible for account behavior,
and review mode provides the strongest human control.

## Jetstream behavior

Jetstream is always active for Bluesky listener and daemon workflows. It remains
a bounded wake-up channel, not an AI data source: raw stream bodies never enter
AI context, terminal output, or persistent state. Matching events trigger the
ordinary notification path, which re-fetches canonical public content and
applies opt-out, deduplication, safety, schedule, queue, and publication-policy
checks. Periodic notification checks remain active for catch-up. Mastodon
continues to use polling.

## ChatGPT and data handling

Set `AI_PROVIDER=chatgpt`, `OPENAI_API_KEY`, and `OPENAI_MODEL` in the
selected platform's private `.env`. The `openai` provider name is an alias.
ChorusDraft sends the drafting task and selected cleaned public context to the
OpenAI Responses API, requests a bounded text response, and sets `store` to
`false`. The API key is sent only in the authorization header; remote response
details are omitted from local errors.

Using a remote provider changes the privacy boundary. Review the provider's
terms and data controls before sending public conversation context. Credentials,
local state, logs, and runtime configuration remain excluded from release
packages.

## Packages

- `ChorusDraft-elixir-0.51.4-linux.tar.gz`
- `ChorusDraft-elixir-0.51.4-macos.tar.gz`
- `ChorusDraft-elixir-0.51.4-windows.zip`

Every archive includes its executable, native setup/install/verification
scripts, configuration examples, documentation, GPL source, pinned dependency
source and licenses, and a complete manifest. Each archive has a SHA-256
sidecar. Install into a new directory and import compatible state explicitly
after stopping the old process.
