# Ruby → Elixir parity

Read-only baseline: the historical Ruby 0.51.1 reference commit
`68b83694ec34b1161839b5ff62a857a774415ece`. This commit remains pinned in CI.
Ruby 0.51.2 source is now merged into `main-ruby`, and `ruby-testing` is
synchronized with that merge. Its Ruby 4.0 requirement and short commands are
outside this parity baseline; no Elixir implementation or reference pin changed.
The rewrite targets Linux. It does not replace the Windows/macOS Ruby builds.

| Ruby behavior | Elixir implementation | Verification |
|---|---|---|
| Bluesky and Mastodon login, feed, search, replies, quotes and deletion | Platform clients in one ChorusDraft escript | Client fixtures; live credentials still needed |
| Original comic drafts, contextual replies, target and discovery commentary | Shared runner; continues past seen/ineligible candidates | Runner and parity tests |
| Local OpenAI, Ollama and Gemini | Shared AI adapter; provider credentials stay out of errors | AI adapter fixtures |
| Manual staging and explicit manual publication | `--text`, `--publish`, reply/quote/CW options | Runner and client tests |
| Exact interactive approval; rejection; no automatic AI posting | `--process-queue`; `--reject`; claim before publish | Approval, concurrency and failure tests |
| Search, timeline inspection and random reply targets | `--search`, `--random-post [QUERY]`, `--random-reply QUERY` | CLI/runner implementation; parser tests |
| CLI compatibility aliases | `--reply-uri`, `--quote-only`, `--staging`, `--poll`, CID arguments | Parity tests; supplied CIDs are deliberately re-fetched |
| Polling, daemon, local active hours and jitter | Foreground loops, monotonic scheduling and isolated job failures | Schedule and HTTP-error regression tests |
| Privacy exclusions, opt-outs and interaction budgets | Restricted bodies discarded; persistent blocks; daily/author limits | Safety, client, runner and store tests |
| Account-scoped atomic state and idempotency | Kernel flock, private files, stable IDs/record keys, uncertain outcomes | Concurrency, crash recovery and transport tests |
| Existing state and configuration | Read-only import into an empty account store; non-overwriting setup | Migration tests, including Ruby-generated state in CI |
| Linux packaging and install/upgrade | One ChorusDraft archive with both platform modes, source/dependency source, manifest, and new-directory installer | CI extraction, installation, overwrite refusal and offline rebuild |
| Jetstream | Optional Bluesky notification wake-up with periodic API catch-up and bounded passive reception | Protocol, reconnect, coalescing, oversized/fragmented message, handshake, heartbeat, and timeout tests |

Intentional differences: Elixir uses no Ruby runtime. Packaging requires Erlang
rather than bundling an operating-system runtime. Upgrade installation always
uses a new directory; state is copied explicitly after stopping the old process.
HTTP redirects and automatic retries are disabled, including 503 Retry-After.
The existing disabled likes/reposts/favourites remain disabled.

Implementation and offline parity do not establish live service acceptance.
Before operating an account, verify login, public/private filtering, AI generation,
interactive posting/reply/quote and deletion using a disposable test account;
then run the listener/daemon through a network outage and reconnect. Jetstream is
live-tail acceleration, with the same finite notification window as polling.
