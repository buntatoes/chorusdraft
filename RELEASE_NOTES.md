# BlueBot and Mastobot 0.50

BlueBot and Mastobot 0.50 are AI-assisted command-line clients for Bluesky and
Mastodon. This release introduces a shared Ruby implementation for Linux, macOS,
and Windows, with a human review queue for every AI-generated post.

## Highlights

- Draft original posts, replies, quotes, discovery commentary, and target commentary.
- Monitor mentions or prepare periodic drafts in a foreground process.
- Use a local Ollama/OpenAI-compatible model or Google Gemini.
- Review the exact text and publication metadata before any AI draft is posted.
- Keep private Mastodon messages out of AI requests, logs, and local state.
- Use per-account locked state, duplicate prevention, cooldowns, and conservative
  handling of uncertain network results.
- Run the same Ruby source on Linux, macOS, and Windows without third-party gems.

## Release files

| Product | Linux | macOS | Windows |
| --- | --- | --- | --- |
| BlueBot | `bluebot-v0.50-linux.tar.gz` | `bluebot-v0.50-macos.tar.gz` | `bluebot-v0.50-windows.zip` |
| Mastobot | `mastobot-v0.50-linux.tar.gz` | `mastobot-v0.50-macos.tar.gz` | `mastobot-v0.50-windows.zip` |

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

Run `ruby setup.rb`, edit `.env`, and use `ruby bot.rb --help` to see every command.

## Compatibility notes

- Version 0.50 begins a new release line under the BlueBot and Mastobot names.
- Earlier queue and interaction files are not imported automatically.
- AI drafts cannot be published without interactive review.
- Automatic likes, favourites, boosts, and reposts are disabled.
- Restricted Mastodon messages are not processed or answered.
- BlueBot feed posts are public and do not support Mastodon content warnings.

See `README.md` for installation, configuration, command examples, and state
handling. See `CHANGELOG.md` for the complete feature and behavior list and
`SECURITY_AUDIT.md` for the audit scope and deployment limitations.
