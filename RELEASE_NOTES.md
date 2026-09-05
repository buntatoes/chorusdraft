# ChorusDraft 0.50

ChorusDraft 0.50 is an AI-assisted command-line publishing tool for Bluesky and
Mastodon. This release introduces a shared Ruby implementation for Linux, macOS,
and Windows, with a human review queue for every AI-generated post.

## Highlights

- Draft original posts, replies, quotes, discovery commentary, and target commentary.
- Monitor mentions or prepare periodic drafts in a foreground process.
- Use a local Ollama/OpenAI-compatible model or Google Gemini.
- Review the exact text and publication metadata before any AI draft is posted.
- Keep private Mastodon messages out of AI requests, logs, and local state.
- Use per-account locked state, duplicate prevention, do-not-contact controls,
  conservative interaction limits, and safe handling of uncertain network results.
- Run the same Ruby source on Linux, macOS, and Windows without third-party gems.

## Release files

| Product | Linux | macOS | Windows |
| --- | --- | --- | --- |
| ChorusDraft for Bluesky | `chorusdraft-bluesky-v0.50-linux.tar.gz` | `chorusdraft-bluesky-v0.50-macos.tar.gz` | `chorusdraft-bluesky-v0.50-windows.zip` |
| ChorusDraft for Mastodon | `chorusdraft-mastodon-v0.50-linux.tar.gz` | `chorusdraft-mastodon-v0.50-macos.tar.gz` | `chorusdraft-mastodon-v0.50-windows.zip` |

Download `SHA256SUMS` with the selected archive. On Linux, verify with:

```sh
sha256sum --ignore-missing -c SHA256SUMS
```

On macOS:

```sh
shasum -a 256 -c SHA256SUMS
```

## Requirements

- Ruby 3.2 or later for syntax compatibility; use a currently supported,
  security-patched Ruby release in production.
- A Bluesky app password or Mastodon access token.
- A configured local AI model or Gemini API key and model.

Run `ruby setup.rb`, edit `.env`, and use `ruby chorusdraft.rb --help` to see every command.

## Compatibility notes

- Version 0.50 begins a new release line under the ChorusDraft name.
- Earlier queue and interaction files are not imported automatically.
- AI drafts cannot be published without interactive review.
- Automatic likes, favourites, boosts, and reposts are disabled.
- Restricted Mastodon messages are not processed or answered.
- Dedicated critical targeting is not included. Unsolicited target and discovery
  drafts are limited to five per day and one per author every 30 days.
- Clear requests to stop replying and configured do-not-contact entries block all
  supplied reply, quote, target, and queued publication paths for that account.
- Bluesky feed posts are public and do not support Mastodon content warnings.

See `README.md` for installation, configuration, command examples, and state
handling. See `CHANGELOG.md` for the complete feature and behavior list and
`SECURITY.md` for vulnerability reporting and the enforced safety boundaries.
