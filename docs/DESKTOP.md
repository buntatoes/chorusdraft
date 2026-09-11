# Desktop guide

## Requirements

Desktop downloads include the GUI and terminal bridge. The bot needs
Erlang/OTP 25 or later. Linux also needs util-linux (`flock`); macOS and
Windows need Python 3 for account-state locking. Windows launchers use
PowerShell. Building the bot from source requires Elixir 1.15+ and Mix.

Connect with a Bluesky app password or Mastodon access token. AI drafting
needs a local Ollama/OpenAI-compatible endpoint, Gemini, or ChatGPT/OpenAI
API key and model.

## Download and launch

Packages are on
[GitHub Releases](https://github.com/buntatoes/chorusdraft/releases) and as
artifacts from
[desktop checks](https://github.com/buntatoes/chorusdraft/actions/workflows/bot-testing.yml).
Download `chorusdraft-v0.53.2-<os>-<arch>` (Desktop). The
`ChorusDraft-elixir-*` files on the same page are **CLI only (no GUI)**.
Each desktop archive has the Elixir bot, both social platforms, the desktop
launcher, licenses, a SHA-256 sidecar, and a checksum manifest.

**Install (recommended):** extract the archive, then run `./install.sh`,
double-click `Install ChorusDraft.command` on macOS, or `install.cmd` on
Windows. No path is required. ChorusDraft installs into a stable per-user
folder, adds an application entry (Applications on macOS, your applications
menu on Linux, Start menu on Windows), runs setup, and opens the desktop app.
Run the installer again to update; account `.env` files, queues, and block
lists are kept. Default locations:

- Linux: `~/.local/share/chorusdraft`
- macOS: `~/Library/Application Support/chorusdraft-app`
- Windows: `%LOCALAPPDATA%\Programs\ChorusDraft`

Pass a path when you want a custom install directory.

| Operating system | Open the launcher |
| --- | --- |
| Linux | Run `./install.sh`, or open ChorusDraft from your applications menu |
| macOS | Double-click `Install ChorusDraft.command`, or open ChorusDraft from Applications |
| Windows | Double-click `install.cmd`, or open ChorusDraft from the Start menu |

You can still run `./bot` (or `bot.bat` / `bot.command`) directly from the
extracted folder without installing.

The installer updates an existing ChorusDraft folder in place. 0.52 through
0.53.1 used a versioned folder (`chorusdraft-0.53.1`, `ChorusDraft-0.53.1`,
and the like). Pass that old path to the installer to update it, or install
to the new default and copy `.env` plus `data/`. To move to a new location,
stop the old bot, install into the new folder, then copy `.env` and import
state. On Linux without `DISPLAY` or `WAYLAND_DISPLAY`, install still copies
files and registers the menu entry; it does not open the GUI.

On Ubuntu 24.04 and other systems that restrict user namespaces, run
`sudo python3 launcher-source/linux_sandbox.py` once from the **installed**
folder (or the extracted folder if you did not install) before opening the GUI.
That enables Electron's sandbox for that download's exact path. Run `./bot` as
your normal user afterward. Repeat if you move the install; use the same script
with `--remove` before removing an old copy.

Choose Bluesky or Mastodon, click **Set up**, then **Open configuration**.
**Create a draft** stages a post. **Write a post**, **Write a reply**, and
**Write a quote** open compose. Body text shows a live count against 300
characters on Bluesky and 500 on Mastodon. Mastodon compose includes a
content warning (`--cw`, at most 500 characters); Bluesky rejects content
warnings. Reply id (`reply ID TEXT` / `--reply-to`) is an at:// URI on Bluesky
or a numeric status id on Mastodon. Quote id (`quote ID TEXT` / `--quote-uri`)
uses the same id formats. Compose previews visibility before submit: Bluesky
`public`; Mastodon originals and quotes use **Default visibility** from
Settings (`STATUS_VISIBILITY`); Mastodon replies to others stage as `unlisted`.
Compose queues for review. It does not publish.

**Open review** approves, edits, or rejects it. The desktop talks to the bot
over JSON; publish buttons follow a review event, not a scraped prompt.
**Queue** lists pending and uncertain drafts from the account store last used
on the selected platform. Cards show reply and quote targets when the draft
has them. **Review this draft** starts `review ID` for that pending item;
publish buttons still follow a review event. Remaining automatic attempts and
freeze state are shown for Bluesky and Mastodon side by side. Edit from Queue
or during review; the replacement is screened and still needs approval.
During review, **Edit text** prefills the current draft and keeps line
breaks. The response field is disabled while the edit form is open so `y`
cannot publish the original. After you save, review asks again. You can also
send `y`, `e`, `d`, or `q` through the response field when those buttons are
showing.

**Start automatic mode** can post only a new original or an eligible public
mention reply from that run. Manual posts, existing drafts, quotes, targets,
and discovery still need review.

**Start monitoring** keeps drafting. **Stop session** ends a running session.
Closing the window asks before stopping an active bot.

## Account credentials

Settings provides masked fields for your Bluesky app password, Mastodon access
token, Gemini API key, and OpenAI API key. Saved secrets are not shown again
in the form. **Save securely** encrypts settings using the operating system's
protected storage. On Linux, a supported unlocked system keyring is required.
If protected storage is unavailable, **Use for this session** keeps newly
entered settings in memory until ChorusDraft closes. The app does not fall
back to saving plaintext.

The form also has `ACTIVE_HOURS` (`HH:MM-HH:MM`; blank or equal start and end
means always active) and `DISCOVERY_KEYWORDS` (comma-separated). Target
accounts and Do not contact edit `config/target_accounts.txt` and
`config/do_not_contact.txt` in the selected platform directory (one handle
per line). Saving Settings writes those two files; the bot reads them from
disk.

These settings apply to bots launched through the GUI. Secure saving removes
only the fields managed by the form from the selected bot's existing `.env`;
advanced settings remain there. Session-only use leaves an existing `.env`
unchanged. **Forget saved settings** removes the desktop's saved settings. It
does not revoke credentials at the service or remove copies you keep elsewhere.

Command-line `.env` files and environment variables are still plaintext.
GUI settings are not available to separately launched CLI processes. See
[Elixir configuration](../elixir/README.md) for command-line setup.

## Local history

**History** searches **Published posts** and **Bot activity** for the selected
platform. Published posts show text, account, time, and content warning where
present. **Copy post** recalls the text. Only successful publications
recorded by ChorusDraft appear here; it does not download your full posting
history.

Post history is kept for up to 10 days after publication. Completed published
and rejected draft records are then removed from the local account store.
Activity from GUI sessions expires 10 days after each event. Events are
grouped in hourly files, and the oldest files may be removed sooner to keep
activity storage within 50 MB. Cleanup runs while the app is open and at its
next launch.

Pending drafts, uncertain publications, do-not-contact entries, and duplicate
and interaction safety records are retained separately. Expiring local history
does not delete posts from Bluesky or Mastodon.

ChorusDraft does not upload history or activity logs. Account state stays in
`elixir/bluesky/data/` or `elixir/mastodon/data/` inside your installation.
Desktop credentials and activity use:

| Operating system | Desktop data directory |
| --- | --- |
| Linux | `$XDG_STATE_HOME/chorusdraft`, or `~/.local/state/chorusdraft` |
| macOS | `~/Library/Application Support/ChorusDraft` |
| Windows | `%LOCALAPPDATA%\ChorusDraft` |

Backups and terminal logs are outside this retention. Posts and AI calls still
go to Bluesky/Mastodon and your chosen model provider.

## Direct commands

`./bot menu` (or `.\bot.bat menu`) opens an optional terminal menu:

```sh
./bot bluesky setup
./bot bluesky draft
./bot bluesky review
./bot mastodon post "A post to review."
./bot mastodon history
```

On Windows, replace `./bot` with `.\bot.bat`.

| Command | Action |
| --- | --- |
| `setup` | Create missing configuration files |
| `draft` | Create an AI draft |
| `review` | Review and publish selected drafts |
| `post "TEXT"` | Queue a post you wrote |
| `reply ID "TEXT"` | Queue a reply |
| `quote ID "TEXT"` | Queue a quote or commentary |
| `replies` | Draft replies to public mentions |
| `search "QUERY"` | Find public posts |
| `random ["QUERY"]` | Show a random public post |
| `discover ["QUERY"]` | Draft commentary on a public post |
| `targets [HANDLE]` | Draft commentary from selected accounts |
| `start` | Keep drafting posts and checking mentions |
| `automatic` | Like `start`, but may publish new originals and eligible mention replies |
| `listen` | Keep checking mentions |
| `delete ID` | Delete your own post after confirmation |
| `history` | Show locally recorded published posts from the last 10 days |
| `status` | Show queue counts, unresolved drafts, automatic budget, and freeze |
| `import FILE` | Import compatible state into an empty account store |
| `reject ID` | Reject a pending or uncertain draft |
| `edit ID "TEXT"` | Replace pending draft text; review still required |
| `service install` | Write a user service that runs `start` (CLI; add `--automatic` for automatic) |
| `help` / `version` | Show command help or the build version |

Existing Elixir flags and `./bot elixir PLATFORM COMMAND` still work.
Desktop packages use Elixir for `./bot PLATFORM COMMAND`; Ruby is not
included. `service install` is CLI-only; enable the unit yourself. See
[Elixir service and troubleshooting](../elixir/README.md#service).

## Desktop JSON control

GUI sessions set `CHORUSDRAFT_CONTROL=1` and talk to the bot over JSON lines
on stdio (binary, not a PTY). The activity log still shows the human `log`
lines. Publish buttons follow a `review` event, not scraped prompt text.

Bot events, one JSON object per line on stdout:

```json
{"event":"log","value":"message\n"}
{"event":"review","draft":{"id":"draft-id","action":"ai_generated","visibility":"public","text":"Exact draft text","cw":null,"reply_to":null,"quote_to":null,"status":"pending"}}
```

Commands, one JSON object per line on stdin:

```json
{"action":"approve"}
{"action":"reject"}
{"action":"skip"}
{"action":"quit"}
{"action":"edit","text":"replacement\nkeeps line breaks"}
```

`edit` text must be non-empty after trim, at most 10,000 characters, and
cannot contain NUL or C0 controls other than tab and newline. EOF or a read
error is `quit`. The desktop rejects a bot line larger than 64 KiB.

There is no `publish` action. Approval is `approve` after a `review` event.
CLI review without this environment still uses the `[y/N/e/d/q]` prompt.

## Configuration and upgrades

Each platform uses its own configuration and account state under
`elixir/bluesky/` or `elixir/mastodon/`. Setup preserves existing files. Stop
the old bot before upgrading and install into a new directory. Keep the
complete account state so pending drafts, opt-outs, and uncertain publications
survive the move. Backups can hold secrets; treat them like credentials.

When migrating from the Ruby release, follow the
[state import instructions](../elixir/README.md#upgrade).
Run only one bot per social account. The desktop does not migrate an older
installation's state automatically.

## Build from source

The source GUI uses React and Electron. Development requires Node.js 24 and
Python 3.12+; Windows also requires `pywinpty`. From `desktop/`, run `npm ci`
and `npm start`. Build the Elixir executable first:

```sh
cd elixir
mix deps.get
MIX_ENV=prod mix escript.build
cd ..
./bot
```

On Windows, set `$env:MIX_ENV = 'prod'`, run `mix escript.build`, then return
to the root directory and open `.\bot.bat`.

To build a desktop package, run `MIX_ENV=prod mix run scripts/build_release.exs`
from `elixir/`. From the root, run `npm ci --prefix desktop`,
`python -m pip install -r launcher/requirements-build.txt`,
`python scripts/build_gui.py`, and `python scripts/build_bundle.py`.
Build tools include Node.js 24, Python 3, and `zip`. macOS downloads distinguish
Apple Silicon (`arm64`) from Intel (`x64`); Linux and Windows builds target `x64`.

## Privacy and security

AI-generated content needs review unless you start automatic mode. Do-not-contact
lists, public opt-outs, visibility checks, and interaction limits apply to both
platforms. Ambiguous publication failures are not retried automatically.
See [SECURITY.md](../SECURITY.md) for limits and how to report issues.

## License

ChorusDraft application code is licensed under the [Apache License 2.0](../LICENSE),
except ChorusDraft Guard (`elixir/guard/`), which is
[proprietary](../elixir/guard/LICENSE). Official builds require Guard.
See [NOTICE](../NOTICE) and [Elixir third-party notices](../elixir/THIRD_PARTY_NOTICES.md)
for attribution and dependency licenses.
