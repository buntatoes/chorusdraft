# ChorusDraft

An AI-assisted writing and publishing tool for Bluesky and Mastodon.

Draft posts, replies, and commentary, then review each draft before publishing.
Choose Ruby or Elixir from one desktop window, with the same core commands in both.

**0.51.3 preview** · Linux, macOS, and Windows

[Latest stable release: 0.51.2](https://github.com/buntatoes/chorusdraft/releases/tag/v0.51.2) ·
[Changelog](CHANGELOG.md) · [Release notes](RELEASE_NOTES.md)

## Requirements

The combined download includes the desktop GUI runtime. Install the runtime for
the bot implementation you want to use:

| Implementation | Requirements |
| --- | --- |
| Ruby | Ruby 4.0+; tested with 4.0.6 |
| Elixir | Erlang/OTP 25+; Linux also needs `flock`, macOS and Windows need Python 3 |
| Build Elixir from source | Elixir 1.15+, Mix, and Erlang/OTP 25+ |

Windows launchers use PowerShell. The packaged Elixir executable does not require
Ruby or an Elixir installation. Using Ruby does not require Erlang or Elixir.
AI drafting needs a local Ollama/OpenAI-compatible endpoint or a Gemini API key
and model. Connect with a Bluesky app password or Mastodon access token.

## Download and launch

The 0.51.3 preview packages are available as artifacts from successful
[Combined bot checks](https://github.com/buntatoes/chorusdraft/actions/workflows/bot-testing.yml)
runs. Choose your operating system and processor architecture, then extract the download. Each package
contains both implementations and both social platforms, with a SHA-256 sidecar
and a file checksum manifest.

| Operating system | Open the launcher |
| --- | --- |
| Linux | Open a terminal in the extracted folder and run `./bot` |
| macOS | Double-click `bot.command`, or run `./bot` in Terminal |
| Windows | Double-click `bot.bat`, or run `.\bot.bat` in PowerShell |

Choose an implementation and platform in the desktop window. Click **Set up**,
then **Open configuration** to add your account and AI settings. Click
**Create a draft** to create a draft and **Open review** to approve or reject it.

Activity and review prompts appear in the window. Type your response in the
**Response** field and click **Send**. During review, use **Publish this draft** or **Reject draft**. You can also send
`y` to publish, `d` to reject, or `q` to finish review.

Use **Start monitoring** for continuous drafting and **Stop session** to end a running
session. Select another bot after the session ends. Closing the window asks
before stopping an active bot. AI-generated posts always need individual approval.

## Direct commands

Use the same launcher with arguments to run commands directly. `./bot menu`
(or `.\bot.bat menu`) opens an optional terminal menu:

```sh
./bot ruby bluesky setup
./bot ruby bluesky draft
./bot ruby bluesky review
./bot elixir mastodon setup
./bot elixir mastodon draft
./bot elixir mastodon review
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
| `help` / `version` | Show command help or the build version |

Existing flags remain supported. The older `./bot bluesky COMMAND` and
`./bot mastodon COMMAND` forms continue to select Ruby. Elixir additionally
supports `status`, `import FILE`, `reject ID`, and Bluesky Jetstream monitoring.

## Configuration and upgrades

Each bot has its own configuration and account state:

| Bot | Configuration folder |
| --- | --- |
| Ruby / Bluesky | `bluesky/` |
| Ruby / Mastodon | `mastodon/` |
| Elixir / Bluesky | `elixir/bluesky/` |
| Elixir / Mastodon | `elixir/mastodon/` |

Setup preserves existing files. Stop the old bot and back up its configuration
and complete `data` directory before upgrading. Keep each implementation's state
separate and run only one bot per social account at a time. Switching the bot
selection does not migrate credentials or state.

See [Ruby usage and configuration](RUBY.md) or
[Elixir usage, Jetstream, and state import](elixir/README.md) for details.

## Build from source

The source GUI uses React and Electron. Development requires Node.js 24 and
Python 3.12+; Windows also requires `pywinpty`. From `desktop/`, run `npm ci`
and `npm start`. The combined downloads include the GUI and bridge runtimes. Ruby is ready to use after
installing its runtime. To build the Elixir executable:

```sh
cd elixir
mix deps.get
MIX_ENV=prod mix escript.build
cd ..
./bot
```

On Windows, set `$env:MIX_ENV = 'prod'`, run `mix escript.build`, then return to
the root directory and open `.\bot.bat`.

To build a combined package, first run `ruby scripts/build_release.rb` from the
root and `MIX_ENV=prod mix run scripts/build_release.exs` from `elixir/`. Then run
`python -m pip install -r launcher/requirements-build.txt`,
`python scripts/build_gui.py`, and `python scripts/build_bundle.py` from the root.
Run `npm ci --prefix desktop` before building. Build tools include Node.js 24,
Python 3, and `zip`. macOS downloads distinguish Apple Silicon (`arm64`) from
Intel (`x64`); Linux and Windows builds target `x64`.

## Privacy and security

AI-generated content requires review. Do-not-contact lists, public opt-outs,
visibility checks, and interaction limits apply in both implementations.
Ambiguous publication failures are not retried automatically.
See [SECURITY.md](SECURITY.md) for safeguards and vulnerability reporting.

## License

ChorusDraft is licensed under the [GNU General Public License v3.0](LICENSE).
See [NOTICE](NOTICE) and [Elixir third-party notices](elixir/THIRD_PARTY_NOTICES.md)
for attribution and dependency licenses.
