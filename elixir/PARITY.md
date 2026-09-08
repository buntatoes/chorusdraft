# Ruby → Elixir parity

The Elixir implementation inherits the command workflows and safety controls of
ChorusDraft's historical Ruby 0.51.1 reference commit
`68b83694ec34b1161839b5ff62a857a774415ece`. Ruby is no longer part of the active
0.51.3 application. Compatible legacy JSON state remains importable.

Version 0.51.3 adds short commands, the React desktop interface, protected GUI
credential entry, and local history retention. The table below describes the
inherited behavioral baseline.

| Inherited behavior | Elixir implementation | Verification |
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
| Account-scoped atomic state and idempotency | Native kernel locks, private modes/Windows ACLs, stable IDs/record keys, uncertain outcomes | Concurrency, crash recovery, native CI and transport tests |
| Existing state and configuration | Read-only import into an empty account store; non-overwriting setup | Legacy migration fixtures |
| Linux, macOS, and Windows packaging and install/upgrade | One native archive per OS with both platform modes, source/dependency source, manifest, and new-directory installer | Native CI extraction, installation, overwrite refusal and offline rebuild |
| Jetstream | Optional Bluesky notification wake-up with periodic API catch-up and bounded passive reception | Protocol, reconnect, coalescing, oversized/fragmented message, handshake, heartbeat, and timeout tests |

The bot requires Erlang/OTP; desktop downloads include the GUI runtime. Upgrade installation always
uses a new directory; state is copied explicitly after stopping the old process.
HTTP redirects and automatic retries are disabled, including 503 Retry-After.
The existing disabled likes/reposts/favourites remain disabled.

Jetstream provides live notification acceleration with the same finite
notification window as polling; it does not provide historical replay.
Completed post records now expire after 10 days, while pending drafts, uncertain
publications, and account safety state remain separately retained. Desktop
credential storage applies to GUI launches; advanced CLI configuration remains
available through the environment and `.env`.
