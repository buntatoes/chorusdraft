# Ruby → Elixir parity

Elixir matches the Ruby 0.51.1 workflows and safety rules (commit
`68b83694ec34b1161839b5ff62a857a774415ece`). Ruby is not in 0.51.3+.
Old JSON state still imports.

0.51.5 adds Queue, pending-draft edit, and automatic budget in `status`.
0.51.6 is fixes only; see CHANGELOG.

| From Ruby 0.51.1 | Elixir | Tests |
|---|---|---|
| Bluesky and Mastodon login, feed, search, replies, quotes, deletion | Platform clients in one escript | Client fixtures; live credentials still needed |
| Original comic drafts, contextual replies, target and discovery commentary | Shared runner; skips seen or ineligible candidates | Runner and parity tests |
| Local OpenAI, Ollama, and Gemini | Shared AI adapter; credentials stay out of errors | AI adapter fixtures |
| Manual staging and explicit manual publication | `--text`, `--publish`, reply/quote/CW options | Runner and client tests |
| Interactive approval and rejection; review is the default | `--process-queue`; `--edit`; `--reject`; claim before publish. Opt-in `automatic` can post a new original or eligible mention reply | Approval, concurrency, and failure tests |
| Search, timeline inspection, random reply targets | `--search`, `--random-post [QUERY]`, `--random-reply QUERY` | CLI/runner; parser tests |
| CLI compatibility aliases | `--reply-uri`, `--quote-only`, `--staging`, `--poll`, CID arguments | Parity tests; supplied CIDs are re-fetched |
| Polling, daemon, local active hours, jitter | Foreground loops; one failed job does not kill the loop | Schedule and HTTP-error tests |
| Privacy exclusions, opt-outs, interaction budgets | Restricted bodies discarded; persistent blocks; daily/author limits | Safety, client, runner, and store tests |
| Account-scoped atomic state and idempotency | Native locks, private modes/Windows ACLs, stable IDs, `uncertain` outcomes | Concurrency, crash recovery, native CI, transport tests |
| Existing state and configuration | Read-only import into an empty account store; setup never overwrites | Legacy migration fixtures |
| Linux, macOS, and Windows packaging | One archive per OS with both modes, source, manifest, new-directory installer | Native CI extraction, install, overwrite refusal, offline rebuild |
| Jetstream | Bluesky notification wake-up only; periodic API catch-up; no history replay | Protocol, reconnect, coalescing, oversized/fragment, handshake, heartbeat, timeout tests |

The bot needs Erlang/OTP. Desktop downloads include the GUI runtime. Install
into a new directory; copy state after stopping the old process. HTTP
redirects and automatic retries are off, including 503 Retry-After. Still no
auto likes, boosts, or reposts.

Published post records expire after 10 days. Pending drafts, uncertain
publications, and account safety state stay. Desktop credential storage
applies to GUI launches; CLI still uses the environment and `.env`.
