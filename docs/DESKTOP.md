# Desktop guide

Launch ChorusDraft, configure credentials, review drafts, and recall local history.

## Requirements

Desktop downloads include the GUI and terminal bridge runtimes. The bot requires
Erlang/OTP 25 or later. Linux also needs util-linux (`flock`); macOS and Windows
need Python 3 for account-state locking. Windows launchers use PowerShell.
Building the bot from source requires Elixir 1.15+ and Mix.

Connect with a Bluesky app password or Mastodon access token. AI drafting needs
a local Ollama/OpenAI-compatible endpoint, Gemini, or ChatGPT/OpenAI API key and model.

## Download and launch

Development desktop packages are available as artifacts from successful
[desktop checks](https://github.com/buntatoes/chorusdraft/actions/workflows/bot-testing.yml).
Choose your operating system and processor architecture, then extract the download.
Each package contains the Elixir bot, both social platforms, the desktop launcher,
corresponding source, a SHA-256 sidecar, and a file checksum manifest.

| Operating system | Open the launcher |
| --- | --- |
| Linux | Open a terminal in the extracted folder and run `./bot` |
| macOS | Double-click `bot.command`, or run `./bot` in Terminal |
| Windows | Double-click `bot.bat`, or run `.\bot.bat` in PowerShell |

On Ubuntu 24.04 and other systems that restrict user namespaces, run
`sudo python3 launcher-source/linux_sandbox.py` once from the extracted folder
before opening the GUI. This enables Electron's sandbox for that download's exact
path. Run `./bot` as your normal user afterward. Repeat setup if you move the folder;
use the same script with `--remove` before removing an old download.

Choose Bluesky or Mastodon, click **Set up**, then click **Open configuration** to enter your
account and AI settings. Click **Create a draft** to draft a post and
**Open review** to approve or reject it. During review, use **Publish this draft**
or **Reject draft**. You can also send `y`, `d`, or `q` through the response field.
Review mode requires individual approval. **Start automatic mode** explicitly
permits only newly generated originals and eligible incoming mention replies,
after source, privacy, harassment, opt-out, and publication-budget checks.
Manual posts, existing drafts, quotes, targets and discovery still require review.

Use **Start monitoring** for continuous drafting and **Stop session** to end a
running session. Closing the window asks before stopping an active bot.

## Account credentials

Settings provides masked fields for your Bluesky app password, Mastodon access
token, Gemini API key, and OpenAI API key. Saved secrets are not shown again in the form.
**Save securely** encrypts settings using your operating system's protected
storage. On Linux, a supported unlocked system keyring is required. If protected
storage is unavailable, **Use for this session** keeps newly entered settings
in memory until ChorusDraft closes; the app does not fall back to saving plaintext.

These settings apply to bots launched through the GUI. Secure saving removes only
the fields managed by the form from the selected bot's existing `.env`; advanced
settings remain there. Session-only use leaves an existing `.env` unchanged.
**Forget saved settings** removes the desktop's saved settings; it does not revoke
credentials at the service or remove copies you maintain elsewhere.

Advanced command-line use still supports environment variables and each platform's
`.env`. Credentials supplied through those files are plaintext and must be kept
private. GUI settings are not automatically available to separately launched CLI
processes. See [Elixir configuration](../elixir/README.md) for command-line setup.

## Local history

Open **History** to search **Published posts** and **Bot activity** for the selected
platform. Published posts show text, account, time, and content warning where
present; **Copy post** recalls the text for reuse. Only successful publications
recorded by ChorusDraft appear here; it does not download your account's full
posting history.

Post history is retained for up to 10 days after publication. Completed published
and rejected draft records are then removed from the local account store.
Activity from GUI sessions expires 10 days after each event. Events are grouped
in hourly files, and the oldest files may be removed sooner to keep activity
storage within 50 MB. Cleanup runs while the app is open and at its next launch.
The app cannot remove files while it is closed or the computer is off; storage or
runtime errors may require attention before cleanup can finish.

Pending drafts, uncertain publications, do-not-contact entries, and duplicate and
interaction safety records are retained separately. Expiring local history does
not delete posts from Bluesky or Mastodon.

ChorusDraft does not upload history or activity logs. Account state stays in
`elixir/bluesky/data/` or `elixir/mastodon/data/` inside your installation. Desktop
credentials and activity use the following local application directory:

| Operating system | Desktop data directory |
| --- | --- |
| Linux | `$XDG_STATE_HOME/chorusdraft`, or `~/.local/state/chorusdraft` |
| macOS | `~/Library/Application Support/ChorusDraft` |
| Windows | `%LOCALAPPDATA%\ChorusDraft` |

Operating-system backups, synced installation folders, and logs captured by a
terminal or service manager are outside ChorusDraft's retention controls. Normal
posting and AI requests still send the information needed by the selected service.

## Direct commands

Use the launcher with arguments to run commands directly. `./bot menu`
(or `.\bot.bat menu`) opens an optional terminal menu:

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
| `listen` | Keep checking mentions |
| `delete ID` | Delete your own post after confirmation |
| `history` | Show locally recorded published posts from the last 10 days |
| `status` | Show account state and unresolved drafts |
| `import FILE` | Import compatible state into an empty account store |
| `reject ID` | Reject a pending draft |
| `help` / `version` | Show command help or the build version |

Existing Elixir flags and the `./bot elixir PLATFORM COMMAND` form remain supported.
The launcher now uses Elixir for `./bot PLATFORM COMMAND`; Ruby is no longer
included in desktop packages. See [Elixir usage and Jetstream](../elixir/README.md) for
additional options.

## Configuration and upgrades

Each platform uses its own configuration and account state under `elixir/bluesky/`
or `elixir/mastodon/`. Setup preserves existing files. Stop the old bot before
upgrading and install into a new directory. Retain the complete account state so
pending drafts, opt-outs, and uncertain publications survive the move. If you make
a backup, protect it and manage its retention separately.

When migrating from the Ruby release, follow the
[state import instructions](../elixir/README.md#upgrade-or-import-legacy-state).
Run only one bot per social account. The desktop does not automatically migrate
an older installation's state.

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

On Windows, set `$env:MIX_ENV = 'prod'`, run `mix escript.build`, then return to
the root directory and open `.\bot.bat`.

To build a desktop package, run `MIX_ENV=prod mix run scripts/build_release.exs`
from `elixir/`. From the root, run `npm ci --prefix desktop`,
`python -m pip install -r launcher/requirements-build.txt`,
`python scripts/build_gui.py`, and `python scripts/build_bundle.py`.
Build tools include Node.js 24, Python 3, and `zip`. macOS downloads distinguish
Apple Silicon (`arm64`) from Intel (`x64`); Linux and Windows builds target `x64`.

## Privacy and security

AI-generated content requires review unless automatic mode is explicitly started.
Do-not-contact lists, public opt-outs,
visibility checks, and interaction limits apply to both platforms.
Ambiguous publication failures are not retried automatically.
See [SECURITY.md](../SECURITY.md) for safeguards and vulnerability reporting.

## License

ChorusDraft is licensed under the [GNU General Public License v3.0](../LICENSE).
See [NOTICE](../NOTICE) and [Elixir third-party notices](../elixir/THIRD_PARTY_NOTICES.md)
for attribution and dependency licenses.
