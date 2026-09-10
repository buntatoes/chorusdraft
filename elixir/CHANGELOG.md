# Changelog

Newest first. Also: [GitHub Releases](https://github.com/buntatoes/chorusdraft/releases).

## 0.53.0 — 2026-09-10

Current published GitHub Release. Earlier GitHub Releases and tags
(v0.50 through v0.52.1) were withdrawn and are not downloadable.

Publication screening is now a proprietary module. Opt-out, injection,
harassment, automatic-output, and personal-information checks moved out of the
Apache-licensed Elixir tree into ChorusDraft Guard (`elixir/guard/`). The
public `ChorusDraft.Safety` and `ChorusDraft.PII` APIs remain, and call Guard.

Official source trees and release packages include Guard (`GUARD_LICENSE` in
the archive). If Guard is missing or replaced with an unlicensed stub, the bot
refuses to draft or publish instead of running without screens.

Desktop `./install.sh` and `install.ps1` install ChorusDraft into a versioned
folder under your user data directory, register an application entry
(applications menu on Linux, Applications on macOS, Start menu on Windows),
run setup, and open the desktop app. With no argument the default locations
are `~/.local/share/chorusdraft-0.53.0` on Linux, `~/Library/Application
Support/chorusdraft-0.53.0` on macOS, and `%LOCALAPPDATA%\ChorusDraft-0.53.0`
on Windows. You can still pass a path when you want a custom location. CLI-only
packages use the same scripts for the bot; they do not launch a GUI.

Anyone who still has an older ChorusDraft copy retains that copy's original
Apache 2.0 license, including screening code those versions shipped.

## 0.52.1 — 2026-09-08

Desktop `./install.sh` and `install.ps1` install ChorusDraft into a versioned
folder under your user data directory, register an application entry
(applications menu on Linux, Applications on macOS, Start menu on Windows),
run setup, and open the desktop app. With no argument the default locations
are `~/.local/share/chorusdraft-0.52.1` on Linux, `~/Library/Application
Support/chorusdraft-0.52.1` on macOS, and `%LOCALAPPDATA%\ChorusDraft-0.52.1`
on Windows. You can still pass a path when you want a custom location. CLI-only
packages use the same scripts for the bot; they do not launch a GUI.

## 0.52 — 2026-09-08

Desktop review talks to the bot over JSON. Mastodon listen/start uses the user
streaming API as a wake-up, like Bluesky Jetstream. `service install` writes a
user unit; it does not start it.

### Desktop

- GUI sessions no longer wrap the bot in a PTY. The bot prints JSON events;
  the activity log is still the human lines.
- Approve, reject, quit, skip, and edit are JSON commands. Edit is one round
  trip and keeps line breaks. The publish buttons follow a `review` event, not
  a scraped prompt.
- Typing `e` in the response field opens the editor. Save sends the replacement
  once.

### Mastodon streaming

- `listen`, `start`, and `automatic` open `GET /api/v1/streaming/user` (or
  `MASTODON_STREAMING_URL`). The access token is an Authorization header, never
  a query string.
- Stream bodies never go to the model, the terminal, or state. A `notification`
  event wakes the normal mention fetch. Polling catch-up stays.
- HTTPS only. Size, idle, and reconnect limits match Jetstream.

### Service

- `chorusdraft PLATFORM service install` writes a systemd user unit, LaunchAgent,
  or Windows task that runs `start`. Add `--automatic` to run automatic mode.
  `print` shows the file. `uninstall` removes it.
- Setup still does not start a service. Enable the unit yourself.

## 0.51.6 — 2026-09-08

Bug-fix and security release. No new features.

### Fixed

- `chorusdraft PLATFORM automatic` and the desktop **Start automatic mode**
  button had exited with "Unknown command" since 0.51.4. `--daemon --automatic`
  was unaffected. The tests that should have caught this were checking an
  unused parser; that parser is gone and the tests now run against the real
  one.
- Long edits from the desktop were cut at 4095 bytes on Linux and 1024 on
  macOS by the terminal line discipline, then rejected as invalid. The bot
  terminal now reads lines whole.
- Editing a reply or mention draft during review no longer times out on the
  store lock. A nested store transaction fails at once with a clear message
  instead of waiting five seconds and reporting "busy".
- Help lists `import FILE` and `--history`, and the `--edit` line names every
  option it refuses.

### Security

- Review indents the draft body, and the desktop only recognises the approval
  prompt and draft header at the start of a line. Text inside a draft can no
  longer light up the publish button early or point Edit at a different draft.
- Desktop responses reject every control character except tab, so a response
  cannot send the bot EOF, suspend, or line-erase keys. Requests to the bot
  service are capped at its 64 KiB line limit.
- The obfuscated-email screen was quadratic on runs of whitespace (3 s on 32k
  spaces). It is linear now.
- Automatic mode holds output that splices Cyrillic, Greek, or Armenian
  letters into a Latin word, which is how "kill" got past the word list.
- C1 control characters (U+0080–U+009F) are rejected in drafts like C0.
- Bluesky app passwords, AWS access keys, Stripe keys, and PEM private-key
  headers are redacted from AI context and refused in AI output.
- Status IDs, at:// URIs, model names, and store keys are checked against the
  whole value, so a trailing newline no longer passes. Draft identifier fields
  reject whitespace.
- `--publish` is refused with `--random-reply`. The target is chosen at random,
  so the reply is staged for review instead of posted unseen.
- Jetstream treats a session that drops right after the handshake as a failed
  attempt, so a server that accepts and closes cannot hold the client in a
  one-second reconnect loop.
- History and Queue refuse state or activity files over 50 MB before reading
  them. `build_bundle.py` raises instead of using `assert` for its integrity
  checks. Both workflows pin the same `upload-artifact` release.

### Docs

- `docs/DESKTOP.md` lists `automatic`. Both READMEs say `run.sh` is the
  package launcher and use `chorusdraft` from a source checkout. The supported
  versions table covers 0.51.5.

## 0.51.5 — 2026-09-08

### Queue and review

- Desktop Queue lists pending, publishing, and uncertain drafts from the
  account store last used on the selected platform, with remaining automatic
  attempts and freeze state.
- `edit ID TEXT` replaces pending draft text. The new text is screened, then
  stays pending for review. `--publish` cannot be combined with `--edit`, and
  `--edit` cannot be combined with reply, quote, or queue options.
- Interactive review accepts `e` to replace the current draft, then asks again
  before publish. Desktop review Edit prefills the current text after it is
  loaded, keeps line breaks, and disables the response field so `y` cannot
  publish the original while a replacement is being entered.
- `status` prints the automatic attempt budget and whether automatic mode is
  frozen.
- Queue stays on the Queue page after edit or reject, and expired publication
  leases display as uncertain so Reject is available.
- Editing a pending reply or mention no longer times out on the store lock.
  Queue Save ignores a second click, and a failed review Save does not leave
  the response field disabled.

### Packaging

- CI artifact paths are taken from `VERSION`, so a testing suffix cannot fail
  the upload step after tests pass.
- Elixir checks can be started by hand and cancel overlapping runs on the same
  branch.
- README uses the desktop banner.

## 0.51.4 — 2026-09-08

### License and desktop

- Apache License 2.0.
- Desktop launcher with ChatGPT credentials, automatic mode, and ten-day
  local history. Windows console detection is verified in the terminal
  launcher before enabling queue review.
- Swap README image for the ChorusDraft banner.

### Privacy and screening

- Screen inherited content warnings before automatic publication and honor
  opt-outs in source text and content warnings.
- Screen threats, self-harm encouragement, pile-ons, Unicode domains, and
  injection-shaped text.
- Redact PII in model context; reject PII and obvious credentials in drafts;
  widen link checks.
- Add local `scripts/rewrite_email.py` for rewriting a personal email out of
  git history.

### Automatic mode

- Explicit `automatic` command (`--daemon --automatic`). `start` and every
  other command stay review-first.
- Auto-publish only a newly generated original or eligible public-mention
  reply. Older queue items, owner text, quotes, and target/discovery commentary
  stay review-only.
- Re-fetch the source and recheck content, content warning, handle, author,
  visibility, injection, opt-out, and do-not-contact.
- Five-attempt rolling 24-hour budget, single-flight claims, lockout, and
  stale claims to `uncertain`.
- `reject ID` / `--reject ID` clears a pending or uncertain draft without
  republishing.
- Empty or nil local/Gemini answers raise a clean error, matching OpenAI.

### Providers and Bluesky

- ChatGPT through the OpenAI Responses API (`chatgpt` / `openai`), bounded
  output, sanitized errors, `store: false`.
- Jetstream is the wake-up transport for Bluesky listen and daemon.
  `--jetstream` is a no-op.
- Still fetch notifications the normal way, with periodic catch-up. Streamed
  post bodies stay out of AI, output, and state.

## 0.51.3 — 2026-09-06

### Elixir runtime

- Elixir is the supported implementation.
- Bluesky and Mastodon in one executable.
- Short commands plus the full option interface. Command translation cannot
  add `--publish`.
- Import older state into an empty account store.

### Platforms and packaging

- `.tar.gz` for Linux and macOS, `.zip` for Windows. Both social modes in
  every package.
- Unix and PowerShell setup, install, run, and verification scripts.
- Private Unix modes and Windows ACLs for config and state. Native locks and
  atomic state replacement.
- Application source, pinned dependency source and licenses, manifests, and
  SHA-256 sidecars. No credentials, state, logs, or build caches.
- CI on Ubuntu 22.04, macOS 14, and Windows Server 2022.

### Bluesky Jetstream

- Optional Jetstream wake-ups for Bluesky listeners and daemons, with
  periodic notification catch-up.
- Bounded frames, fragments, handshake headers, deadlines, reconnect backoff,
  and heartbeats.
- Streamed post bodies stay out of AI, the terminal, and state. Stream events
  cannot generate or publish.

### Safety

- Interactive review for AI drafts. Owner text publishes only with an explicit
  flag.
- Privacy filtering, opt-outs, do-not-contact, harassment screening,
  interaction budgets, ownership checks. No automatic likes/boosts/reposts.
- Crash-released locks, strict state validation, idempotent publication IDs,
  `uncertain` without automatic retries.
- No HTTP redirects or automatic retries. Request timeouts and streaming
  limits.

## 0.51.2 — 2026-09-06

- Earlier implementation required Ruby 4.0.
- Short commands and cross-platform launchers.
- Setup creates missing files only; never overwrites.
- Full option interface and state format kept.

## 0.51.1 — 2026-09-05

- Record fetched public opt-outs before reply generation or batch limits.
- Broader normalization for opt-out and harassment screening.
- Do-not-contact covers generated, manual, and queued mentions and Mastodon
  content warnings.
- New opt-outs no longer replace earlier block-list entries.
- Full validation of Mastodon content warnings.

## 0.51 — 2026-09-05

- Dry comic voice; sincere on serious subjects.
- Varied originals and topic-focused reply, target, and discovery prompts.
- Review, privacy, interaction limits, and provider safety kept.

## 0.50 — 2026-09-05

- First ChorusDraft release: Bluesky and Mastodon drafting, interactive
  review, local AI and Gemini, scheduling, account-scoped state, opt-outs,
  privacy filtering, and cross-platform packages.
