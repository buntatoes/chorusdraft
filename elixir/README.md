# ChorusDraft 0.52 Elixir testing

This directory contains the separate Linux Elixir rewrite of BlueBot for Bluesky
and Mastobot for Mastodon. It is under active testing on the
`0.52-elixir-testing` branch. It does not replace or modify the published 0.51
release.

Both products write comic social drafts using a local OpenAI-compatible/Ollama
model or Gemini. The style favors dry wit, light sarcasm, playful exaggeration,
and absurd comparisons. Serious or sensitive posts receive a sincere response.
Every AI draft must be reviewed interactively before publication.

## Requirements

- Linux with Erlang/OTP 25 or later to run the current escript
- Elixir 1.14 or later and Mix to build or test
- A Bluesky app password or Mastodon access token
- A local AI endpoint or Gemini API key and model

## Build and configure

From this `elixir` directory:

```sh
mix deps.get
MIX_ENV=prod mix escript.build
elixir setup.exs bluesky
elixir setup.exs mastodon
```

Edit `bluesky/.env` and/or `mastodon/.env`. The setup script creates private files
only when they do not already exist. It never starts a service or overwrites an
existing configuration.

Show the commands for either product:

```sh
./chorusdraft bluesky --help
./chorusdraft mastodon --help
```

## Common workflows

```sh
# Stage one AI draft. This cannot publish directly.
./chorusdraft bluesky --post-only

# Fetch public mentions and stage up to five eligible replies.
./chorusdraft mastodon --replies-only

# Review pending drafts in an interactive terminal.
./chorusdraft bluesky --process-queue

# Stage manual text, or explicitly publish manual text.
./chorusdraft mastodon --text "The server has entered its artisanal latency era."
./chorusdraft mastodon --text "Maintenance is complete." --publish

# Inspect public posts without generating or publishing anything.
./chorusdraft bluesky --search "elixir linux"
```

Additional commands cover target commentary, discovery, public-post inspection,
interactive deletion, active hours, polling, and daemon operation. AI-generated
text always stays in the queue regardless of compatibility flags or environment
values.

## State and safeguards

State is stored under each product's `data/` directory and separated again by
platform, service origin, and account. Credentials never enter state. Preserve the
entire directory when moving an installation, and run only one process per account.

Add handles to `config/do_not_contact.txt` to refuse all supplied interaction
paths for those accounts. Clear public requests to stop contact are also recorded
before reply generation. `config/target_accounts.txt` is empty by default.
Unsolicited target and discovery drafts are capped at five per rolling 24 hours and
one per author every 30 days.

Mastobot processes only public and unlisted source statuses; restricted bodies are
discarded immediately. BlueBot supports public feed posts only. Automatic likes,
favourites, boosts, and reposts are not implemented.

If a publication request has an ambiguous result, the draft is marked `uncertain`.
Inspect the account manually before doing anything else with it. The program will
not retry that draft automatically.

## Tests and local packages

```sh
mix format --check-formatted
mix test --warnings-as-errors
MIX_ENV=prod mix run scripts/build_linux_release.exs
```

The package script writes only to `elixir/dist/`. It creates separate BlueBot and
Mastobot Linux archives, checksums, source, tests, GPL text, and third-party notices.
Generated configuration, credentials, logs, and state are excluded.

Read [CHANGELOG.md](CHANGELOG.md) for the actual ported features,
[SECURITY.md](SECURITY.md) for enforced boundaries and known limits, and
[RELEASE_NOTES.md](RELEASE_NOTES.md) before testing an archive.
