# ChorusDraft

Elixir app for Linux, macOS, and Windows. One executable, Bluesky and Mastodon
modes. Version 0.54.0. See [CHANGELOG.md](CHANGELOG.md).

Review is the default. `automatic` may publish new originals and eligible
public-mention replies after screening and a source recheck.

## Requirements

- Linux, macOS, or Windows with Erlang/OTP 25+
- Elixir 1.15+, Mix, and Erlang development headers to build or test
- Linux: `tar` and `sha256sum` to verify packages
- macOS: `tar` and `shasum`
- Windows: Python 3 and PowerShell
- A Bluesky app password or Mastodon access token
- A local AI endpoint, Gemini credentials, or OpenAI API credentials and model

## Build

```sh
mix deps.get
MIX_ENV=prod mix escript.build
./chorusdraft bluesky --help
./chorusdraft mastodon --help
./chorusdraft bluesky --setup
```

On Windows, from a source checkout: `escript .\chorusdraft ...`. Edit
`bluesky/.env` and/or `mastodon/.env`. Setup does not start a service or
overwrite existing config. Run one daemon per account.

## Guard signing

Guard is proprietary and is verified before it screens anything. `mix
guard.sign` digests the compiled Guard modules, signs the digests with an
ed25519 key, and compiles the signed manifest, the signature, and the public
keys in [guard/keys](guard/keys) into the build. At startup the bot digests the
Guard code as it exists on disk and refuses to run unless it matches.

`mix test` and `mix escript.build` sign first, so a source checkout needs no
extra step. With no release key configured they use a development key kept in
`_build/`, trusted through `guard/keys/development.pub`, which git ignores. A
development key makes a build run; it says nothing about a downloaded release.

Generate the release key once, keep the private half offline, and commit only
the public half. `mix guard.keygen` writes the private file owner-readable
only, the same private-file treatment as credentials:

```sh
mix guard.keygen --out /secure/path/chorusdraft-guard-release.key
cp /secure/path/chorusdraft-guard-release.key.pub guard/keys/release.pub
```

Then build a release with it:

```sh
rm -f guard/keys/development.pub
CHORUSDRAFT_GUARD_SIGNING_KEY=/secure/path/chorusdraft-guard-release.key \
  MIX_ENV=prod mix run scripts/build_release.exs
```

The private key is read from that path and never enters the repository or the
package; `guard/keys` may hold only public keys, and the build stops if it does
not. Signing refuses to run while `guard/keys/development.pub` exists, so a
release cannot ship trusting a development key. `./scripts/check_packages.sh`
runs the packaged bot, which verifies Guard before anything else, so a package
whose Guard does not verify fails the check.

## Workflows

```sh
./chorusdraft bluesky draft
./chorusdraft bluesky review
./chorusdraft bluesky review DRAFT_ID
./chorusdraft bluesky edit DRAFT_ID "replacement text"
./chorusdraft bluesky status
./chorusdraft bluesky start
./chorusdraft bluesky automatic
./chorusdraft mastodon reply STATUS_ID "Thanks for the context."
./chorusdraft mastodon search "open source"
```

`review` and `--process-queue` walk every pending draft. With an id they
open that one pending draft only. Missing, rejected, publishing, and
uncertain ids fail with `Draft is unavailable or not pending.` They do not
publish. `--publish` is refused.

`start` is review-first. Only `automatic` (`--daemon --automatic`) may
auto-publish AI output. Manual text, quotes, target/discovery commentary,
held drafts, and items already in the queue stay review-only.

```sh
./chorusdraft bluesky --post-only
./chorusdraft mastodon --replies-only
./chorusdraft bluesky --process-queue
./chorusdraft bluesky --process-queue DRAFT_ID
./chorusdraft mastodon --text "Maintenance is complete." --publish
```

## Configuration

Per-platform files under `bluesky/` or `mastodon/` (or `--base`):

| File | Purpose |
|---|---|
| `.env` | Credentials and knobs. Setup copies `.env.example` once; it never overwrites. |
| `config/target_accounts.txt` | Handles for `targets` (one per line; `#` is a comment) |
| `config/do_not_contact.txt` | Never reply, quote, or target. Loaded at start. |

| Key | Constraint |
|---|---|
| `ACTIVE_HOURS` | Local `HH:MM-HH:MM`. Blank or equal endpoints keep the bot always active. Overnight ranges work (`22:00-08:00`). Minutes are optional (`9-17`). |
| `DISCOVERY_KEYWORDS` | Comma-separated. `discover` without a query picks one at random. Falls back to `DISCOVERY_TAGS`, then `opensource`. |
| `STATUS_VISIBILITY` | Mastodon originals and quotes (default `public`). Replies to others are `unlisted`. Bluesky is always `public`. Desktop Settings allows `public` or `unlisted`. |
| `STATUS_LANGUAGE` | Draft language tag (default `en`). |

Desktop Settings can edit the same hours, keywords, visibility, language, and
list files for GUI launches. Form values other than the two lists stay in the
desktop vault or session memory. Only the list files are written under
`config/`. CLI still reads `.env` and `config/` from disk.

## Automatic mode

```sh
./chorusdraft bluesky automatic --active-hours 08:30-22:00
./chorusdraft mastodon --daemon --automatic --poll-interval 60
```

Only the original or eligible public-mention reply created in that cycle can
be claimed. Before an automatic reply, the source is fetched again; ID, text,
content warning, handle, author identity, and public visibility must match.
Injection, opt-out, and do-not-contact run again. Output with extra mentions,
links, contact patterns, pile-ons, or harassment is held for review.

Five automatic attempts per account per rolling 24 hours. Failures count. One
in flight. `publishing` or `uncertain` blocks later claims. A stranded claim
ages to `uncertain` and is not retried. `reject ID` clears it after you inspect
the account.

## Live streams

On for Bluesky and Mastodon `listen` and daemon. `--jetstream` does nothing;
`--no-jetstream` is rejected. Stream bodies never go to AI, the terminal, or
state. A match wakes the normal notification fetch.

Bluesky default: `wss://jetstream.us-east.bsky.network`. Override with
`BLUESKY_JETSTREAM_URL`.

Mastodon uses `GET /api/v1/streaming/user` on the instance. Override with
`MASTODON_STREAMING_URL`. The access token is an Authorization header, not a
query string.

Bounds: [SECURITY.md](SECURITY.md).

## Service

```sh
./chorusdraft bluesky service print
./chorusdraft bluesky service install
./chorusdraft mastodon service install --automatic
./chorusdraft bluesky service uninstall
```

Writes a user-level systemd unit, LaunchAgent, or Windows scheduled-task XML.
It does not start the process, enable linger, or put credentials in the file.
`.env` stays beside the bot. Setup still does not start a service.

Default mode is `start` (review-first). `--automatic` writes `automatic`.
`--base` is the platform directory the daemon should use (`bluesky/` or
`mastodon/` in the install). Run install from that package so the unit points
at its `run.sh` / `run.ps1`. A source checkout without those launchers uses
`escript` and the built `chorusdraft`.

| OS | Unit | Enable | Disable |
|---|---|---|---|
| Linux | `~/.config/systemd/user/chorusdraft-PLATFORM.service` (`$XDG_CONFIG_HOME` if set) | `systemctl --user enable --now chorusdraft-PLATFORM.service` | `systemctl --user disable --now chorusdraft-PLATFORM.service` |
| macOS | `~/Library/LaunchAgents/org.chorusdraft.PLATFORM.plist` | `launchctl load PATH` | `launchctl unload PATH` |
| Windows | `%APPDATA%\ChorusDraft\chorusdraft-PLATFORM.xml` | `schtasks /Create /TN "ChorusDraft PLATFORM" /XML PATH` | `schtasks /Delete /TN "ChorusDraft PLATFORM" /F` |

`print` shows the file and the enable line. Linux linger is optional and
separate: `loginctl enable-linger $USER`. The systemd unit restarts on
failure after 15 seconds. macOS `RunAtLoad` is false; load the agent when
you want it. `KeepAlive` restarts it after load. A registered Windows task
starts at logon and retries a failed start three times. Override the unit
directory with `CHORUSDRAFT_SERVICE_HOME`.

One unit name per platform per user. One daemon per account. Reinstall after
moving the package so the command path stays valid.

## State

Per platform `data/` directory, split by platform, origin, and account.
Writers take a loopback lock in the bot process; another run of the same
account store is refused until it is released. Do-not-contact and public
opt-outs apply. Ambiguous publishes become `uncertain`. Screens are regex.
They miss things. Review is what matters.

## Providers

| Value | Settings | Destination |
|---|---|---|
| `local` or `ollama` | `LOCAL_LLM_URL`, `LOCAL_LLM_MODEL` | Loopback endpoint |
| `gemini` | `GEMINI_API_KEY`, `GEMINI_MODEL` | Google Gemini |
| `chatgpt` or `openai` | `OPENAI_API_KEY`, `OPENAI_MODEL` | OpenAI Responses API |

Local AI URLs must be loopback. Remote endpoints need HTTPS. OpenAI uses bearer
auth, bounded output, and `store: false`.

## Packages

Downloads: [GitHub Releases](https://github.com/buntatoes/chorusdraft/releases)
(0.54.0 is the current published release; v0.50 through v0.53.1 were withdrawn;
0.53.2 remains available).

CLI only (no GUI):

- `ChorusDraft-elixir-0.54.0-linux.tar.gz`
- `ChorusDraft-elixir-0.54.0-macos.tar.gz`
- `ChorusDraft-elixir-0.54.0-windows.zip`

These archives are the bot and terminal launchers only. They do not include
the desktop app. For the GUI, download `chorusdraft-v0.54.0-<os>-<arch>` and
follow [docs/DESKTOP.md](../docs/DESKTOP.md): `./install.sh`, macOS
`Install ChorusDraft.command`, or Windows `install.cmd`. Desktop install uses
a stable folder and can be run again to update.

CLI: extract the archive, then run `./install.sh` (or `install.ps1` on
Windows). With no arguments it installs into a versioned folder under your
user data directory and runs setup. Pass a path when you want a custom
location. The CLI installer refuses a destination that already exists.

Build: `MIX_ENV=prod mix run scripts/build_release.exs`  
Verify: `./scripts/check_packages.sh` or `.\scripts\check_packages.ps1`  
Release builds set `CHORUSDRAFT_GUARD_SIGNING_KEY` first: [Guard signing](#guard-signing).

## Upgrade

CLI install writes a new versioned folder and refuses a destination that
already exists. Desktop install updates the existing folder in place and
keeps `.env`, queues, and block lists. Stop the old process first. For a
CLI move, install into a new directory, then copy `.env` and config:

```sh
./chorusdraft bluesky import /absolute/path/to/old/data/ACCOUNT_HASH/state.json
./chorusdraft bluesky status
```

Inside a release package use `./run.sh` (or `run.ps1`) in place of
`./chorusdraft`.

`reject ID` drops a pending or uncertain draft and unfreezes automatic mode.
Check the live account first. Do not force uncertain back to pending.

## Troubleshooting

| Symptom | What to do |
|---|---|
| `ChorusDraft Guard is required` | Official source includes `guard/`. Do not delete or replace it. |
| `ChorusDraft Guard failed signature verification` | The Guard code is not what this build signed. Reinstall from an official package. From source, run `mix guard.sign --development` after changing Guard. |
| `automatic frozen` in `status` | A `publishing` or `uncertain` draft is blocking claims. Inspect the live account, then `reject ID`. |
| `Draft is unavailable or not pending` | `review ID` and `edit ID` accept a current pending draft only. Use `status` for ids. `reject ID` for uncertain. |
| `State is busy` / lock timed out | Another process holds the account store. Stop the extra daemon or the other run. |
| `no loopback lock address was free` | Locking binds a loopback address. Allow local sockets on `127.0.0.1` for the bot. |
| `State is already locked by this process` | Nested store write. Retry the edit after the outer command finishes. |
| `Import requires empty destination state` | Import only into a new account store. Source must match platform and account. |
| `Jetstream cannot be disabled` | `--no-jetstream` is rejected. Bluesky listen/start always stream. |
| Mastodon streaming handshake / URL error | `MASTODON_STREAMING_URL` must be an HTTPS origin or `/api/v1/streaming` path. No credentials, query, or fragment. The token is an Authorization header. |
| `LOCAL_LLM_URL` rejected | Local/Ollama must be loopback (`localhost`, `127.0.0.1`, `::1`) and include an API path such as `/v1/chat/completions` or `/api/generate`. |
| Bluesky draft/automatic HTTP 404 | 0.53.2 sends `app.bsky.*` to the AppView and `com.atproto.*` to the account PDS. If the error names a local/Gemini/OpenAI model, pull or correct that model instead. |
| `--publish` refused | Not valid with `--edit`, `--queue`, or `--random-reply`. Owner text only. |
| `Choose one command at a time` | One short command or option group per invocation. |
| Desktop install did not open the GUI | Headless Linux (no `DISPLAY` / `WAYLAND_DISPLAY`) skips launch. Open `./bot` later. Ubuntu 24.04 sandbox: `sudo python3 launcher-source/linux_sandbox.py` from the **installed** folder. |
| Linux **Save securely** fails | Unlock a supported system keyring, or use **Use for this session**. The GUI does not save plaintext. |

`status` prints queue counts, unresolved IDs, remaining automatic attempts,
and freeze. Details: [SECURITY.md](SECURITY.md). Desktop JSON control is in
the source-tree desktop guide (`docs/DESKTOP.md`).

## License

Application code is Apache 2.0 except ChorusDraft Guard (`guard/`), which is
proprietary. Official builds require Guard, verify its signature, and refuse to
run without it. See
LICENSE, [guard/LICENSE](guard/LICENSE), [NOTICE](NOTICE), and
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
