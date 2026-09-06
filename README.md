# ChorusDraft

An AI-assisted writing and publishing tool for Bluesky and Mastodon.

ChorusDraft drafts posts, replies, and commentary with a dry comic voice. Search
public conversations, follow topics and accounts, and review drafts before
publishing. Every AI-generated post requires your approval.

**Version 0.51.2** · Linux, macOS, and Windows · Ruby 4.0+

[Download](https://github.com/buntatoes/chorusdraft/releases/tag/v0.51.2) ·
[Release notes](RELEASE_NOTES.md) · [Changelog](CHANGELOG.md)

## Requirements

- Ruby 4.0 or later; tested with Ruby 4.0.6.
- A Bluesky app password or Mastodon access token.
- For AI drafting, a local Ollama/OpenAI-compatible endpoint or a Google Gemini
  API key and model.

The bot uses Ruby's standard libraries and requires no additional runtime gems.

## Download and install

Download the archive for your bot and operating system from the
[0.51.2 release](https://github.com/buntatoes/chorusdraft/releases/tag/v0.51.2):

| Product | Linux | macOS | Windows |
| --- | --- | --- | --- |
| Bluesky | [Linux](https://github.com/buntatoes/chorusdraft/releases/download/v0.51.2/chorusdraft-bluesky-v0.51.2-linux.tar.gz) | [macOS](https://github.com/buntatoes/chorusdraft/releases/download/v0.51.2/chorusdraft-bluesky-v0.51.2-macos.tar.gz) | [Windows](https://github.com/buntatoes/chorusdraft/releases/download/v0.51.2/chorusdraft-bluesky-v0.51.2-windows.zip) |
| Mastodon | [Linux](https://github.com/buntatoes/chorusdraft/releases/download/v0.51.2/chorusdraft-mastodon-v0.51.2-linux.tar.gz) | [macOS](https://github.com/buntatoes/chorusdraft/releases/download/v0.51.2/chorusdraft-mastodon-v0.51.2-macos.tar.gz) | [Windows](https://github.com/buntatoes/chorusdraft/releases/download/v0.51.2/chorusdraft-mastodon-v0.51.2-windows.zip) |

Download [SHA256SUMS](https://github.com/buntatoes/chorusdraft/releases/download/v0.51.2/SHA256SUMS)
and verify your archive before extracting it. On Linux:

```sh
sha256sum --ignore-missing -c SHA256SUMS
```

On macOS, compute the checksum and compare it with the matching entry in
`SHA256SUMS`:

```sh
shasum -a 256 chorusdraft-bluesky-v0.51.2-macos.tar.gz
```

On Windows, use PowerShell's `Get-FileHash`:

```powershell
Get-FileHash .\chorusdraft-bluesky-v0.51.2-windows.zip -Algorithm SHA256
```

Extract the archive and run setup. For example, on Linux:

```sh
tar -xzf chorusdraft-bluesky-v0.51.2-linux.tar.gz
cd chorusdraft-bluesky-v0.51.2-linux
./bot setup
```

Substitute the Mastodon or macOS archive name as needed.

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

The launchers use your selected Ruby installation. Linux/macOS supports rbenv,
including installations under `~/.rbenv` or `RBENV_ROOT`; Windows uses Ruby on
PATH. Run `./bot help` for a command summary or `./bot --help` for all options.
Existing flags and package `run.sh`/`run.bat` launchers remain supported.

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

`--publish` applies only to text supplied with `post` (or `--text`). AI-generated
content requires review.

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
target modes create commentary for review. Unsolicited drafts are limited to
five per rolling 24 hours and one per author every 30 days. The bot
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

- AI drafts enter a review queue and require individual approval to publish.
- Restricted Mastodon messages are excluded from AI processing, logging, and
  storage. Reply and quote visibility is checked again before publication.
- Do-not-contact lists and public opt-out requests block further interactions.
- Unsolicited drafts are limited to five per day and one per author every 30 days.
- Content screening rejects common threats, harassment, and private-information
  disclosures. Human review remains necessary for context, accuracy, and tone.
- Credentials are excluded from release packages and omitted from error logs.
- Publishing requests are never retried automatically after an ambiguous failure.

See [SECURITY.md](SECURITY.md) for the security policy and reporting instructions.

## Upgrading to 0.51.2

Install Ruby 4.0+ and back up your configuration and `data` directory before
upgrading.

From ChorusDraft 0.50, 0.51, or 0.51.1, stop the existing listener or daemon, extract
0.51.2 into a new directory, and securely copy your `.env`, configured target and
do-not-contact files, and the entire `data` directory into it. State and
configuration formats are unchanged. Keeping `data` preserves queued drafts,
opt-outs, and duplicate and interaction history. Start only one installation for
each account.

Existing drafts are preserved and are not regenerated or republished during
the upgrade.

For the older Bluesky Bot and Mastodon Bot projects, install into a new directory
and copy only the credentials and target handles you intend to keep. Their queue
and interaction files are not imported automatically. Stop their listeners,
scheduled tasks, launch agents, or services before starting ChorusDraft.

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

AI drafts use dry wit, light sarcasm, and self-deprecation for software topics
and public commentary. Replies aim for gentle humor; serious requests call for
sincere responses. Style varies with the selected model. Previously queued drafts
and manually supplied text keep their original wording.

## Development

The source checkout selects Ruby 4.0.6 through `.ruby-version`. To run a bot from
the repository root, use `./bot bluesky COMMAND` or `./bot mastodon COMMAND`.
On Windows, enter the integration folder and use `.\bot.bat COMMAND`.

With the selected Ruby on PATH:

```sh
gem install minitest --version 6.0.0 --no-document
ruby test/safety_test.rb
ruby test/cli_test.rb
ruby scripts/build_release.rb
python scripts/verify_release.py
```

The builder creates six platform archives and `SHA256SUMS` in `dist/`. Python is
used only by the package verifier. Tests use simulated API responses and do not
require live accounts.

[Continuous integration](https://github.com/buntatoes/chorusdraft/actions/workflows/ruby-release.yml)
runs source and package tests on Linux, Windows, and macOS for Apple Silicon and
Intel. The local verifier checks packages for the current operating system.

## License

ChorusDraft is licensed under the [GNU General Public License v3.0](LICENSE).
It is based on Bluesky Bot 1.0.3 and Mastodon Bot 1.0.2 by Buntatoes.
See [NOTICE](NOTICE) for attribution and modification notices.
