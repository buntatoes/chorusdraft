# ChorusDraft 0.51.4

Downloads: [GitHub Releases](https://github.com/buntatoes/chorusdraft/releases).

0.51.4 adds opt-in automatic mode, makes Jetstream the Bluesky listener
transport, and adds ChatGPT via the OpenAI Responses API. Review stays the
default. This version also includes the desktop launcher, Apache License 2.0,
and later privacy and screening checks.

## Highlights

- Desktop launcher with encrypted account settings, ten-day local history, and
  verified Windows console detection. See [docs/DESKTOP.md](docs/DESKTOP.md).
- `chorusdraft PLATFORM automatic` may auto-post new originals and eligible
  public-mention replies.
- `reject ID` drops a pending or uncertain draft so automatic mode can resume.
- `start`, `draft`, `replies`, manual posts, quotes, target/discovery
  commentary, and existing queue items stay review-only (or explicit
  `--publish` for owner text).
- `AI_PROVIDER=chatgpt` (or `openai`) with `OPENAI_API_KEY` and `OPENAI_MODEL`.
  Local/Ollama and Gemini still work.
- Bluesky `listen` and `start` use Jetstream. `--jetstream` is a no-op;
  `--no-jetstream` is rejected.
- Recognized personal information is redacted from AI context and rejected in
  drafts. Inherited content warnings and CW opt-outs are screened on automatic
  replies.

## Automatic mode

It does not drain the queue. It may claim only the draft just created in that
cycle, and only if it is an original or a reply to an eligible public mention.

Before claiming an automatic reply, the source is fetched again. ID, text,
content warning, handle, author identity, and visibility must match. Injection,
opt-out, and do-not-contact run again. Extra mentions, links, contact patterns,
harassment, and pile-on language are held for review.

Five attempts per account per rolling 24 hours, reserved before the network
call, counted even when the outcome is unclear. One in flight.
`publishing` or `uncertain` blocks later claims. A stranded publishing claim
becomes `uncertain` and is not retried. `reject ID` clears the freeze after
you inspect the account.

Limits: [SECURITY.md](SECURITY.md).

## Jetstream

Always on for Bluesky listen and daemon. Wake-up only: stream bodies never
enter AI, the terminal, or state. Matches run the ordinary notification path.
Periodic catch-up stays. Mastodon polls.

## ChatGPT

Set `AI_PROVIDER=chatgpt`, `OPENAI_API_KEY`, and `OPENAI_MODEL` in that
platform's `.env`. `openai` is an alias. ChorusDraft sends the drafting task
and selected cleaned public context to the Responses API, asks for bounded
text, and sets `store` to `false`. The key is only in the authorization
header.

A remote provider changes the privacy boundary. Credentials, state, logs, and
runtime config are not in release packages.

## Packages

CLI:

- `ChorusDraft-elixir-0.51.4-linux.tar.gz`
- `ChorusDraft-elixir-0.51.4-macos.tar.gz`
- `ChorusDraft-elixir-0.51.4-windows.zip`

Desktop (`chorusdraft-v0.51.4-<os>-<arch>`, `.tar.gz` on Unix, `.zip` on
Windows) includes the Elixir bot and the launcher.

Each archive has the executable, setup/install/verify scripts, config
examples, docs, application source, pinned dependency source and licenses, a
manifest, and a SHA-256 sidecar. Install into a new directory. Import
compatible state explicitly after stopping the old process.
