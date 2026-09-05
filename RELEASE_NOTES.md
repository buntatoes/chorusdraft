# ChorusDraft 0.51.1 release notes

ChorusDraft 0.51.1 is a security update for the Ruby releases on Linux, macOS,
and Windows. It retains the comic voice introduced in 0.51 and the requirement
that every AI-generated draft receive interactive review.

## Security changes

- All fetched opt-out requests are recorded before reply limits or AI failures can
  interrupt notification processing.
- Unicode-aware matching recognizes common curly-apostrophe, full-width, and
  invisible-formatting variations without rewriting the text being reviewed.
- Do-not-contact checks cover explicit mentions in generated, manual, and queued
  text and Mastodon content warnings. Local Mastodon handles match their fully
  qualified form on the configured instance.
- New opt-outs no longer evict older entries from local state.
- Mastodon content warnings receive length, control-character, harassment, and
  do-not-contact validation before staging, display, and publication.

## Comic drafting

ChorusDraft 0.51 gives Bluesky and Mastodon drafts a clearer comic voice: dry wit,
light sarcasm, absurd comparisons, and playful commentary on software and everyday
internet situations. Every AI-generated post still goes through human review.

## What's new

- Original drafts request concrete setups and unexpected turns, with varied topics
  and joke structures.
- Replies share gentle humor about the conversation. Target and discovery drafts
  can satirize products, claims, and situations without humiliating their authors.
- Shared instructions discourage generic praise and explanations of punchlines.
  Serious help requests, grief, and distress call for sincere responses.
- Local AI and Gemini receive the same comic brief. Output quality varies by model.

The review queue, output screening, private-message exclusions, do-not-contact
controls, interaction limits, and protection against duplicate publishing remain
in place. The update changes newly generated drafts; existing queued drafts and
manually supplied text keep their wording.

## Release files

| Product | Linux | macOS | Windows |
| --- | --- | --- | --- |
| ChorusDraft for Bluesky | `chorusdraft-bluesky-v0.51.1-linux.tar.gz` | `chorusdraft-bluesky-v0.51.1-macos.tar.gz` | `chorusdraft-bluesky-v0.51.1-windows.zip` |
| ChorusDraft for Mastodon | `chorusdraft-mastodon-v0.51.1-linux.tar.gz` | `chorusdraft-mastodon-v0.51.1-macos.tar.gz` | `chorusdraft-mastodon-v0.51.1-windows.zip` |

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

- State and configuration are compatible with ChorusDraft 0.50 and 0.51. Stop the old
  instance and securely copy `.env`, configured target and do-not-contact files,
  and the entire `data` directory into the new installation. Run only one instance
  per account; preserve `data` to retain drafts, opt-outs, and interaction history.
- Queue and interaction files from the older Bluesky Bot and Mastodon Bot projects
  are not imported automatically.
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
