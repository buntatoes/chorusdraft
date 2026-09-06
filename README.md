# ChorusDraft

> **ChorusDraft 0.51.2 — Ruby 4.0 and simpler commands.**
> Released September 6, 2026 for Linux, Windows, and macOS.
> [Download 0.51.2](https://github.com/buntatoes/chorusdraft/releases/tag/v0.51.2).
> Native validation uses Ruby 4.0.6 on Linux, Windows, and Apple Silicon/Intel macOS.

ChorusDraft is an AI-assisted comedy drafting and publishing tool for Bluesky and
Mastodon. It drafts dry observations about software, playful replies, and satirical
commentary on public posts. It can also monitor mentions, search public posts,
and prepare commentary from configured accounts. AI-generated content is
always placed in a review queue so the account owner can inspect the exact text
before it is published.

Version 0.51.2 uses the shared Ruby codebase on Linux, macOS, and Windows. The comic voice introduced in 0.51 is retained.

## Release and development branches

- `main-ruby` is the default and sole maintained Ruby branch, containing the
  tested 0.51.2 source.
- `elixir-experimental` is an independent implementation with its own development
  and release status.
- Create a short-lived branch from `main-ruby` when changes need isolation, open
  a pull request back to main, and delete the branch after integration. Temporary
  `codex/ruby-release-*` branches may be used for native validation when needed.

Release downloads are identified by their tags. The instructions below describe
0.51.2; older 0.51.1 downloads require Ruby 3.2+ and use flag-based commands.

## What's new in 0.51.2

- Ruby 4.0 or newer is required; source development selects Ruby 4.0.6 using
  `.ruby-version`.
- Short commands: `./bot setup`, `./bot draft`, `./bot review`, and `./bot start`.
- Plain commands for manual posts, replies, quotes, search, and discovery.
- Linux/macOS launchers find rbenv even if shell initialization has not run.
- Windows packages include `bot.bat`. Existing flags and `run.sh`/`run.bat`
  remain available.

See [CHANGELOG.md](CHANGELOG.md) for the complete version history and
[RELEASE_NOTES.md](RELEASE_NOTES.md) for installation and compatibility details.

## Comic voice

New AI drafts aim for dry wit, light sarcasm, absurd comparisons, and
self-deprecation. The joke should grow from the topic or conversation: a stubborn
build, an overcomplicated app, or a corporate claim with more adjectives than evidence.
Replies joke alongside people and avoid turning the author into the punchline.
Serious help requests, grief, and distress call for sincere responses.

Illustrative style examples, not captured model outputs:

- “Our deployment has achieved sentience. Its first act was requesting a rollback.”
- “This app has three settings: on, off, and consulting a forum from 2011.”

The same voice is requested from local AI and Gemini for original drafts, replies,
target commentary, and discovery. Results depend on the selected model and context;
every AI draft still needs your review. Threats, personal attacks, invented
allegations, and harassment are outside the comic brief. Manually supplied text
and previously queued drafts keep their original wording.

## Features

| Feature | Bluesky | Mastodon |
| --- | --- | --- |
| AI-assisted original drafts | Yes | Yes |
| Manual posts | Yes | Yes |
| Replies and mention monitoring | Yes | Yes |
| Quote posts | Native record embed | Commentary with source link |
| Public post search | Yes | Yes |
| Random post selection | Yes | Yes |
| Account target monitoring | Yes | Yes |
| Public discovery and commentary | Yes | Yes |
| Links, mentions, and hashtag metadata | Rich-text facets | Native Mastodon parsing |
| Content warnings | No | Yes |
| Status visibility selection | Public feed posts | Public, unlisted, followers, or mentioned users |
| Active-hour schedules and jitter | Yes | Yes |
| Local AI and Gemini | Yes | Yes |
| Interactive draft review | Yes | Yes |
| Delete your own posts | Yes | Yes |

Original AI drafts include recent eligible account posts as context to reduce
repeated topics. Replies can include a short public thread history. Restricted
Mastodon posts are excluded from AI input.

## Requirements

- Ruby 4.0 or later. This release is tested with Ruby 4.0.6.
- A Bluesky app password or a Mastodon access token.
- A local Ollama/OpenAI-compatible endpoint or a Google Gemini API key and model.

The release contains no third-party Ruby gems and does not require a Go or Rust
toolchain. Setup does not download software, install services, or start a bot.

## Download and install

Download the archive for your bot and operating system from the
[0.51.2 release](https://github.com/buntatoes/chorusdraft/releases/tag/v0.51.2):

| Product | Linux | macOS | Windows |
| --- | --- | --- | --- |
| Bluesky | [Linux](https://github.com/buntatoes/chorusdraft/releases/download/v0.51.2/chorusdraft-bluesky-v0.51.2-linux.tar.gz) | [macOS](https://github.com/buntatoes/chorusdraft/releases/download/v0.51.2/chorusdraft-bluesky-v0.51.2-macos.tar.gz) | [Windows](https://github.com/buntatoes/chorusdraft/releases/download/v0.51.2/chorusdraft-bluesky-v0.51.2-windows.zip) |
| Mastodon | [Linux](https://github.com/buntatoes/chorusdraft/releases/download/v0.51.2/chorusdraft-mastodon-v0.51.2-linux.tar.gz) | [macOS](https://github.com/buntatoes/chorusdraft/releases/download/v0.51.2/chorusdraft-mastodon-v0.51.2-macos.tar.gz) | [Windows](https://github.com/buntatoes/chorusdraft/releases/download/v0.51.2/chorusdraft-mastodon-v0.51.2-windows.zip) |

Download [SHA256SUMS](https://github.com/buntatoes/chorusdraft/releases/download/v0.51.2/SHA256SUMS) alongside your archive
to verify its checksum. Ruby 4.0+ must be installed separately.

On Linux or macOS:

```sh
tar -xzf chorusdraft-bluesky-v0.51.2-linux.tar.gz
cd chorusdraft-bluesky-v0.51.2-linux
./bot setup
```

Substitute the Mastodon or macOS archive name as needed.

Verify a downloaded archive against `SHA256SUMS` before extracting it. On Linux:

```sh
sha256sum --ignore-missing -c SHA256SUMS
```

On macOS:

```sh
shasum -a 256 -c SHA256SUMS
```

On Windows, extract the ZIP, open a terminal in the extracted folder, and run:

```powershell
.\bot.bat setup
```

Setup creates `.env`, `config/target_accounts.txt`, and
`config/do_not_contact.txt` when they do not already exist. Existing files are
preserved.

## Configuration

Edit `.env` after setup.

### AI provider

Local AI is the default:

```dotenv
AI_PROVIDER=local
LOCAL_LLM_URL=http://localhost:11434/v1/chat/completions
LOCAL_LLM_MODEL=llama3.2:3b
```

The local URL may use HTTP only for `localhost`, `127.0.0.1`, or `::1`. Remote
endpoints must use HTTPS.

To use Gemini:

```dotenv
AI_PROVIDER=gemini
GEMINI_API_KEY=replace_with_your_key
GEMINI_MODEL=replace_with_an_available_model
```

Gemini receives eligible public post text and public thread context used to build
a draft. There is no automatic fallback between local AI and Gemini.

### Bluesky

```dotenv
BLUESKY_PDS_URL=https://bsky.social
BLUESKY_HANDLE=your-handle.bsky.social
BLUESKY_APP_PASSWORD=xxxx-xxxx-xxxx-xxxx
```

Use a Bluesky app password rather than the primary account password. Change
`BLUESKY_PDS_URL` only when the account uses another HTTPS personal data server.

### Mastodon

```dotenv
MASTODON_API_BASE_URL=https://mastodon.social
MASTODON_ACCESS_TOKEN=replace_with_your_token
STATUS_VISIBILITY=public
STATUS_LANGUAGE=en
```

The access token must have the read or write permissions required by the commands
you use. Valid Mastodon visibility values are `public`, `unlisted`, `private`, and
`direct`. Replies generated from public mentions use unlisted visibility; a reply
to an unlisted post cannot be widened to public.

### Optional scheduling and discovery

```dotenv
ACTIVE_HOURS=08:30-22:00
DISCOVERY_KEYWORDS=opensource,ruby,linux
```

`DISCOVERY_TAGS` is also accepted for compatibility. Active hours use local time
and may cross midnight.

Add target handles, one per line, to `config/target_accounts.txt`. Target
commentary is subject to the unsolicited-interaction limits described below.

Add accounts that must never receive replies, quotes, or target commentary to
`config/do_not_contact.txt`. A leading `@` is optional and matching is
case-insensitive. Public mentions containing a clear request such as “stop
replying to me” also add the author to local do-not-contact state.

Blank lines and lines beginning with `#` are ignored.

## Usage

Inside an extracted package, use `./bot` on Linux/macOS or `.\bot.bat` in
Windows PowerShell. Run it without arguments for a short command guide.

From this source checkout, choose your bot once:

```sh
cd bluesky             # or: cd mastodon
./bot setup            # first time only; then edit .env
./bot draft            # create an AI draft
./bot review           # choose which drafts to publish
./bot start            # keep preparing drafts; stop with Ctrl+C
```

You can also stay in the repository root and run `./bot bluesky draft` or
`./bot mastodon review`. On Windows, enter the integration folder and use
`.\bot.bat setup`, `.\bot.bat draft`, and `.\bot.bat review`.

The Linux/macOS launcher uses rbenv when available, including an installation
under `~/.rbenv` or `RBENV_ROOT`, and otherwise uses `ruby` from PATH. In the
source checkout, `.ruby-version` selects 4.0.6; extracted packages use your
selected Ruby and require 4.0+. No system Ruby or global settings are changed.

Existing `ruby chorusdraft.rb --...`, `./run.sh`, and `.\run.bat` commands still
work with Ruby 4.0+. Use `./bot --help` for all advanced options.

### Draft and publish

```sh
./bot draft
./bot review
```

Each draft displays its exact text, visibility, reply or quote target, and content
warning. Enter `y` to publish that draft, `d` to reject it, or `q` to stop reviewing.
Review requires an interactive terminal.

Stage a post you wrote, or publish that supplied text explicitly:

```sh
./bot post "Hello from ChorusDraft"
./bot post "Hello from ChorusDraft" --publish
```

`--publish` applies only to text supplied with `post` (or `--text`). AI-generated content has
no direct-publish option.

### Replies and quotes

```sh
./bot replies
./bot reply POST_ID "Thanks for the details"
./bot quote POST_ID "Useful context"
```

For Bluesky, `POST_ID` is an `at://.../app.bsky.feed.post/...` URI and
`--reply-uri` is an alias. For Mastodon, it is a numeric status ID. The Bluesky
integration creates a native quote embed after fetching the current record. The
Mastodon integration adds the public source URL to the commentary. `--reply-cid`
and `--quote-cid` are accepted for compatibility, but supplied CIDs are not trusted.

Add a Mastodon content warning:

```sh
./bot post "Post body" --cw "Topic warning"
```

### Search, discovery, and targets

```sh
./bot search "ruby programming" --limit 5
./bot random "open source"
./bot post "Manual response" --random-reply "open source"
./bot discover "ruby"
./bot targets
./bot targets account.example
```

Search and random-post commands only display public content. Discovery and
target modes create witty commentary on topics and situations for review. Unsolicited drafts are
limited to five per rolling 24 hours and one per author every 30 days. The bot
refuses to draft or publish interactions with accounts in do-not-contact state.

### Foreground monitoring

```sh
./bot listen --poll-interval 60
./bot start --interval 120
./bot start --active-hours 08:30-22:00 --jitter 10
```

`listen` checks mentions. `start` checks mentions and periodically prepares
original and target drafts. Both run in the foreground and stop with Ctrl+C. They
do not install or detach a background service.

- Poll intervals must be 10–3600 seconds.
- Draft intervals must be 1–1440 minutes.
- Jitter must be 0–60 minutes.
- `--ignore-active-hours` bypasses the configured window.

### Delete a post

```sh
./bot delete POST_ID
```

Deletion is limited to the authenticated account and requires typing `delete` in
an interactive terminal. The Bluesky integration accepts your post's full AT URI
or record key.

## Review queue and state

Runtime data is stored under `data/<account-hash>/state.json`. The server origin
and account identity are both included in the account hash, keeping installations
for different servers separate. State updates use a file lock and atomic replace.

The queue holds at most 100 pending, publishing, or uncertain drafts. A draft is
claimed before publication and must still match the exact version shown during
review. An ambiguous network failure marks it `uncertain` and is never retried
automatically. Check the social account before recreating an uncertain draft.

Keep the `data` directory when moving an active installation. Removing it also
removes duplicate-prevention and interaction history.

## Privacy and safety

- AI-generated content always requires per-draft approval.
- Bluesky feed posts are public. Private visibility and content warnings are
  rejected because Bluesky feed posts do not support them.
- ChorusDraft discards private, direct, and unknown-visibility Mastodon message bodies before
  AI processing, logging, or storage. ChorusDraft does not reply to restricted
  Mastodon messages.
- Source visibility is checked again immediately before publishing a reply or quote.
- Suspected prompt-injection posts are skipped.
- Dedicated critical targeting is not supported. Target and discovery prompts
  request satire about topics and situations without insulting or baiting their authors.
- Clear public opt-out requests are honored permanently in local state. A
  configurable do-not-contact list also blocks queued and manual interactions.
  In 0.51.1, all fetched opt-outs are recorded before generating replies,
  and explicit mentions in draft text and content warnings are checked as well.
  Mastodon local and fully qualified handles on the configured instance are matched.
  Blocks follow recorded handles; update the list when an account changes its handle.
- Unsolicited interaction is limited to five drafts per day and one draft per
  author every 30 days.
- Output screening rejects threats, doxxing, pile-on requests, self-harm
  encouragement, and common direct personal attacks.
  Version 0.51.1 screens Mastodon content warnings before queueing or displaying
  them and rejects hidden control characters instead of showing a sanitized preview
  of different text. Common Unicode variations are normalized only for screening;
  the approved text itself is not rewritten.
- Automatic likes, favourites, boosts, and reposts are disabled.
- API keys are sent in headers and remote error bodies are omitted from logs.
- Redirects are not followed with credentials and publishing requests are not
  automatically retried.

Human review remains responsible for factual accuracy, tone, and suitability.
See [SECURITY.md](SECURITY.md) for supported versions, vulnerability reporting,
and enforced safety boundaries.

## Upgrading to 0.51.2

Version 0.51.2 requires Ruby 4.0+ and uses the same configuration and state
formats as 0.51 and 0.51.1. Keep a
backup of your `data` directory before upgrading.

From ChorusDraft 0.50, 0.51, or 0.51.1, stop the existing listener or daemon, extract
0.51.2 into a new directory, and securely copy your `.env`, configured target and
do-not-contact files, and the entire `data` directory into it. State and
configuration formats are unchanged. Keeping `data` preserves queued drafts,
opt-outs, and duplicate and interaction history. Start only one installation for
each account.

The new voice applies only to drafts generated after the upgrade. Review existing
pending drafts normally; the upgrade does not regenerate or republish them.

For the older Bluesky Bot and Mastodon Bot projects, install into a new directory
and copy only the credentials and target handles you intend to keep. Their queue
and interaction files are not imported automatically. Stop their listeners,
scheduled tasks, launch agents, or services before starting ChorusDraft.

## Development

From the source repository:

```sh
./bot bluesky help
./bot mastodon help
rbenv exec ruby test/safety_test.rb
rbenv exec ruby test/cli_test.rb
rbenv exec ruby scripts/build_release.rb
```

Tests require the development gem `minitest` (`gem install minitest` if absent);
the bot itself has no third-party gem dependencies. If Ruby 4.0+ is already
on PATH without rbenv, omit `rbenv exec` in the commands above.

The release builder produces six platform archives and `SHA256SUMS` under `dist/`.
Start future Ruby changes from `main-ruby` and merge them back after review and
passing native checks. Remove temporary branches once their work is integrated.
Tagging and publishing tested archives remain separate release steps.
Tests use local fakes and do not log in, call an AI provider, or publish posts.

The `Ruby release checks` GitHub Actions workflow builds the six archives once,
then tests those same artifacts on Ubuntu, Windows, macOS Apple Silicon, and
macOS Intel with Ruby 4.0.6. [Native verification](https://github.com/buntatoes/chorusdraft/actions/runs/34014831624)
passed all four native jobs: 55 source tests plus both packaged suites and
launcher/setup/queue checks on each OS. These checks used fakes, without live
account login, AI-provider calls, or social publication. Archive checks also
verify SHA-256 hashes and launchers from extracted paths containing spaces.

To repeat archive checks locally after building (with Ruby 4.0+ on PATH):

```sh
python scripts/verify_release.py
```

The verifier runs only the current operating system's archives; full release
validation requires all four native CI jobs to pass. Workflow artifacts retain
the exact tested archives and checksums for 14 days.

## License and acknowledgements

ChorusDraft is distributed under the GNU General Public License v3.0.
See [LICENSE](LICENSE). [NOTICE](NOTICE) records the original projects,
modification date, scope of the version 0.50 rewrite, the 0.51 comic update, the
0.51.1 security update, 0.51.2 runtime and command update, and third-party names.

Version 0.50 is based on the feature sets of Bluesky Bot 1.0.3 and Mastodon Bot
1.0.2 by Buntatoes. It begins a new shared Ruby release line under the
ChorusDraft name.

## Privacy review

The 2026-09-06 branch, history, and release-artifact review found no confirmed
credentials or unintended personal data. Synthetic test fixtures and public
attribution were reviewed separately. See [SECURITY.md](SECURITY.md) for the
scope and limits; this is not a guarantee or a full independent security audit.
