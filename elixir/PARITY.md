# Ruby → Elixir parity

The Elixir and Ruby 0.51.3 implementations are both supported releases. CI uses
the Ruby source from the same commit as the Elixir build when verifying state
compatibility. Elixir packages combine both social platforms; Ruby packages
ship Bluesky and Mastodon separately.

| Ruby behavior | Elixir implementation | Verification |
|---|---|---|
| Bluesky and Mastodon login, feed, search, replies, quotes and deletion | Platform clients in one ChorusDraft escript | Client fixtures; live credentials still needed |
| Original comic drafts, contextual replies, target and discovery commentary | Shared runner; continues past seen/ineligible candidates | Runner and parity tests |
| Local OpenAI, Ollama and Gemini | Shared AI adapter; provider credentials stay out of errors | AI adapter fixtures |
| Manual staging and explicit manual publication | `--text`, `--publish`, reply/quote/CW options | Runner and client tests |
| Exact interactive approval; rejection; no automatic AI posting | `--process-queue`; `--reject`; claim before publish | Approval, concurrency and failure tests |
| Search, timeline inspection and random reply targets | `--search`, `--random-post [QUERY]`, `--random-reply QUERY` | CLI/runner implementation; parser tests |
| Short commands and compatibility aliases | `draft`, `review`, `start`, `post`, `reply`, `quote`, `search`, other short commands, legacy flags and CID arguments | Parity tests; translation never adds `--publish`; supplied CIDs are re-fetched |
| Polling, daemon, local active hours and jitter | Foreground loops, monotonic scheduling and isolated job failures | Schedule and HTTP-error regression tests |
| Privacy exclusions, opt-outs and interaction budgets | Restricted bodies discarded; persistent blocks; daily/author limits | Safety, client, runner and store tests |
| Account-scoped atomic state and idempotency | Native kernel locks, private modes/Windows ACLs, stable IDs/record keys, uncertain outcomes | Concurrency, crash recovery, native CI and transport tests |
| Existing state and configuration | Read-only import into an empty account store; non-overwriting setup | Migration tests, including Ruby-generated state in CI |
| Linux, macOS, and Windows packaging and install/upgrade | One native archive per OS with both platform modes, source/dependency source, manifest, and new-directory installer | Native CI extraction, installation, overwrite refusal and offline rebuild |
| Jetstream | Optional Bluesky notification wake-up with periodic API catch-up and bounded passive reception | Protocol, reconnect, coalescing, oversized/fragmented message, handshake, heartbeat, and timeout tests |

Intentional differences: Elixir uses Erlang/OTP while the Ruby packages require
Ruby 4.0 or newer. Upgrade installation always
uses a new directory; state is copied explicitly after stopping the old process.
HTTP redirects and automatic retries are disabled, including 503 Retry-After.
The existing disabled likes/reposts/favourites remain disabled.

Implementation and offline parity do not establish live service acceptance.
Before operating an account, verify login, public/private filtering, AI generation,
interactive posting/reply/quote and deletion using a disposable test account;
then run the listener/daemon through a network outage and reconnect. Jetstream is
live-tail acceleration, with the same finite notification window as polling.
