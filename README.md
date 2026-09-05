# ChorusDraft

ChorusDraft is an AI-assisted command-line publishing tool for Bluesky and
Mastodon. It can draft posts, prepare replies, monitor mentions, search public
posts, and build commentary from configured accounts. AI-generated content is
always placed in a review queue so the account owner can inspect the exact text
before it is published.

Version 0.50 uses one shared Ruby codebase on Linux, macOS, and Windows.

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

- Ruby 3.2 or later for syntax compatibility. Use a currently supported,
  security-patched Ruby release in production.
- A Bluesky app password or a Mastodon access token.
- A local Ollama/OpenAI-compatible endpoint or a Google Gemini API key and model.

The release contains no third-party Ruby gems and does not require a Go or Rust
toolchain. Setup does not download software, install services, or start a bot.

## Download and install

Download the archive for the bot and operating system from the GitHub release:

| Product | Linux | macOS | Windows |
| --- | --- | --- | --- |
| ChorusDraft for Bluesky | `chorusdraft-bluesky-v0.50-linux.tar.gz` | `chorusdraft-bluesky-v0.50-macos.tar.gz` | `chorusdraft-bluesky-v0.50-windows.zip` |
| ChorusDraft for Mastodon | `chorusdraft-mastodon-v0.50-linux.tar.gz` | `chorusdraft-mastodon-v0.50-macos.tar.gz` | `chorusdraft-mastodon-v0.50-windows.zip` |

On Linux or macOS:

```sh
tar -xzf chorusdraft-bluesky-v0.50-linux.tar.gz
cd chorusdraft-bluesky-v0.50-linux
ruby setup.rb
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
ruby setup.rb
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

Run `ruby chorusdraft.rb` inside an extracted package. The platform launchers forward the
same arguments:

```sh
./run.sh --help
```

```powershell
run.bat --help
```

### Draft and publish

```sh
ruby chorusdraft.rb --post-only
ruby chorusdraft.rb --process-queue
```

Each draft displays its exact text, visibility, reply or quote target, and content
warning. Enter `y` to publish that draft, `d` to reject it, or `q` to stop reviewing.
Review requires an interactive terminal.

Stage a post you wrote, or publish that supplied text explicitly:

```sh
ruby chorusdraft.rb --text "Hello from ChorusDraft"
ruby chorusdraft.rb --text "Hello from ChorusDraft" --publish
```

`--publish` applies only to text supplied with `--text`. AI-generated content has
no direct-publish option.

### Replies and quotes

```sh
ruby chorusdraft.rb --replies-only
ruby chorusdraft.rb --text "Thanks for the details" --reply-to POST_ID
ruby chorusdraft.rb --text "Useful context" --quote-uri POST_ID
```

For Bluesky, `POST_ID` is an `at://.../app.bsky.feed.post/...` URI and
`--reply-uri` is an alias. For Mastodon, it is a numeric status ID. The Bluesky
integration creates a native quote embed after fetching the current record. The
Mastodon integration adds the public source URL to the commentary. `--reply-cid`
and `--quote-cid` are accepted for compatibility, but supplied CIDs are not trusted.

Add a Mastodon content warning:

```sh
ruby chorusdraft.rb --text "Post body" --cw "Topic warning"
```

### Search, discovery, and targets

```sh
ruby chorusdraft.rb --search "ruby programming" --limit 5
ruby chorusdraft.rb --random-post "open source"
ruby chorusdraft.rb --text "Manual response" --random-reply "open source"
ruby chorusdraft.rb --discover --query "ruby"
ruby chorusdraft.rb --targets-only
ruby chorusdraft.rb --targets-only --target account.example
```

Search and random-post commands only display public content. Discovery and
target modes create respectful drafts for review. Unsolicited drafts are
limited to five per rolling 24 hours and one per author every 30 days. The bot
refuses to draft or publish interactions with accounts in do-not-contact state.

### Foreground monitoring

```sh
ruby chorusdraft.rb --listen --poll-interval 60
ruby chorusdraft.rb --daemon --interval 120
ruby chorusdraft.rb --daemon --active-hours 08:30-22:00 --jitter 10
```

`--listen` checks mentions. `--daemon` checks mentions and periodically prepares
original and target drafts. Both run in the foreground and stop with Ctrl+C. They
do not install or detach a background service.

- Poll intervals must be 10–3600 seconds.
- Draft intervals must be 1–1440 minutes.
- Jitter must be 0–60 minutes.
- `--ignore-active-hours` bypasses the configured window.

### Delete a post

```sh
ruby chorusdraft.rb --delete POST_ID
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
  AI processing, logging, or storage. Version 0.50 does not reply to restricted
  Mastodon messages.
- Source visibility is checked again immediately before publishing a reply or quote.
- Suspected prompt-injection posts are skipped.
- Dedicated critical targeting is not supported. Target and discovery prompts
  must address topics without insulting, judging, or provoking their authors.
- Clear public opt-out requests are honored permanently in local state. A
  configurable do-not-contact list also blocks queued and manual interactions.
- Unsolicited interaction is limited to five drafts per day and one draft per
  author every 30 days.
- Output screening rejects threats, doxxing, pile-on requests, self-harm
  encouragement, and common direct personal attacks.
- Automatic likes, favourites, boosts, and reposts are disabled.
- API keys are sent in headers and remote error bodies are omitted from logs.
- Redirects are not followed with credentials and publishing requests are not
  automatically retried.

Human review remains responsible for factual accuracy, tone, and suitability.
See [SECURITY.md](SECURITY.md) for supported versions, vulnerability reporting,
and enforced safety boundaries.

## Migrating to 0.50

Install 0.50 in a new directory. Copy only the credentials and target handles you
intend to keep. Earlier queue and interaction files are not imported automatically.
Stop old listeners, scheduled tasks, launch agents, or services before starting
the new foreground clients.

The public product name and release filenames are now ChorusDraft. The
platform names remain Bluesky and Mastodon in configuration variables and API terms.

## Development

From the source repository:

```sh
ruby bluesky/chorusdraft.rb --help
ruby mastodon/chorusdraft.rb --help
ruby test/safety_test.rb
ruby scripts/build_release.rb
```

The release builder produces six platform archives and `SHA256SUMS` under `dist/`.
Tests use local fakes and do not log in, call an AI provider, or publish posts.

## License and acknowledgements

ChorusDraft is distributed under the GNU General Public License v3.0.
See [LICENSE](LICENSE). [NOTICE](NOTICE) records the original projects,
modification date, scope of the version 0.50 rewrite, and third-party names.

Version 0.50 is based on the feature sets of Bluesky Bot 1.0.3 and Mastodon Bot
1.0.2 by Buntatoes. It begins a new shared Ruby release line under the
ChorusDraft name.
