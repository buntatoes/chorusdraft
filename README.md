# ChorusDraft

ChorusDraft is a social drafting assistant for Bluesky and Mastodon. It helps
account owners write original posts, replies, and commentary while keeping
AI-generated content in a local review queue until they approve it.

Its writing style favors dry wit and playful observations, with a sincere tone
for serious topics. You can use a local AI model or a supported hosted provider
and choose what reaches your account.

## What it does

- Drafts original posts, replies, and commentary for Bluesky and Mastodon.
- Supports owner-written posts and public-post search.
- Provides a shared workflow for drafting, reviewing, and publishing.
- Keeps queues and account state locally, separated by account and platform.
- Applies opt-outs, do-not-contact lists, and interaction limits.

## How it works

1. Connect your social account and configure an AI provider.
2. Create a draft or collect eligible public mentions for replies.
3. Review the text and its context before approving publication.

AI-generated drafts require individual approval. You remain responsible for the
content you publish and how your account interacts with others.

## Get started

Visit [GitHub Releases](https://github.com/buntatoes/chorusdraft/releases) for
downloads, installation requirements, upgrade instructions, and release notes.
Use the documentation included with your chosen release for its supported
features and commands.

The [application documentation](elixir/README.md) covers the source checkout,
configuration, and command workflows. Read the [security policy](SECURITY.md)
for credential handling, safeguards, and vulnerability reporting.

## License

ChorusDraft is licensed under the GNU General Public License, version 3. See
[LICENSE](LICENSE), [NOTICE](NOTICE), and
[third-party notices](elixir/THIRD_PARTY_NOTICES.md).
