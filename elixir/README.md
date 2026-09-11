# ChorusDraft

Elixir app for Linux, macOS, and Windows. One executable, Bluesky and Mastodon
modes. Version 0.54.0. See [CHANGELOG.md](CHANGELOG.md).

Review is the default. `automatic` may publish new originals and eligible
public-mention replies after screening and a source recheck.

## Requirements

- Linux, macOS, or Windows with Erlang/OTP 25+
- Elixir 1.15+, Mix, and Erlang development headers to build or test
- Linux: util-linux (`flock`); `tar` and `sha256sum` to verify packages
- macOS: Python 3; `tar` and `shasum`
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

## Workflows

```sh
./chorusdraft bluesky draft
./chorusdraft bluesky review
./chorusdraft bluesky edit DRAFT_ID "replacement text"
./chorusdraft bluesky status
./chorusdraft bluesky start
./chorusdraft bluesky automatic
./chorusdraft mastodon reply STATUS_ID "Thanks for the context."
./chorusdraft mastodon search "open source"
```

`start` is review-first. Only `automatic` (`--daemon --automatic`) may
auto-publish AI output. Manual text, quotes, target/discovery commentary,
held drafts, and items already in the queue stay review-only.

```sh
./chorusdraft bluesky --post-only
./chorusdraft mastodon --replies-only
./chorusdraft bluesky --process-queue
./chorusdraft mastodon --text "Maintenance is complete." --publish
```

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
Do-not-contact and public opt-outs apply. Ambiguous publishes become
`uncertain`. Screens are regex. They miss things. Review is what matters.

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

## Upgrade

Stop the old process, install into a new directory, copy `.env` and config:

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
| `automatic frozen` in `status` | A `publishing` or `uncertain` draft is blocking claims. Inspect the live account, then `reject ID`. |
| `State is busy` / lock timed out | Another process holds the account store. Stop the extra daemon. Linux needs `flock` (`util-linux`). |
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
proprietary. Official builds require Guard and refuse to run without it. See
LICENSE, [guard/LICENSE](guard/LICENSE), [NOTICE](NOTICE), and
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
