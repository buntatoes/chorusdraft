# ChorusDraft Elixir experiment

This directory contains the separate Linux Elixir rewrite of BlueBot for Bluesky
and Mastobot for Mastodon. Development lives on the `elixir-experimental` branch.
It is an unfinished experiment and is not part of the official Ruby release line.
The supported Ruby release remains 0.51.1, with future Ruby work isolated on
`0.51.2-ruby-testing`.

The executable currently reports `0.52.0-testing` as a temporary internal build
identifier. That identifier is not a release, tag, compatibility promise, or the
official Ruby 0.52 version.

Both products write comic social drafts using a local OpenAI-compatible/Ollama
model or Gemini. The style favors dry wit, light sarcasm, playful exaggeration,
and absurd comparisons. Serious or sensitive posts receive a sincere response.
Every AI draft must be reviewed interactively before publication.

## Current status

- The shared Mix project compiles and produces a Linux escript.
- BlueBot and Mastobot API clients, local AI and Gemini support, draft storage,
  review workflows, and the primary 0.51.1 safeguards have initial Elixir ports.
- The offline suite currently contains 22 passing tests. These use fake clients
  and do not log in, contact an AI provider, or publish posts.
- Live platform compatibility, state migration, long-running daemon behavior,
  packaging, installation upgrades, and a complete security audit are unfinished.
- No Elixir archive, tag, GitHub release, or supported upgrade path exists.

## Requirements

- Linux with Erlang/OTP 25 or later to run the current escript
- Elixir 1.14 or later and Mix to build or test
- A Bluesky app password or Mastodon access token
- A local AI endpoint or Gemini API key and model

## Build and inspect

From this `elixir` directory:

```sh
mix deps.get
MIX_ENV=prod mix escript.build
```

Check the command interface before adding credentials:

```sh
./chorusdraft bluesky --help
./chorusdraft mastodon --help
```

To create local configuration files for hands-on testing:

```sh
elixir setup.exs bluesky
elixir setup.exs mastodon
```

Edit `bluesky/.env` and/or `mastodon/.env`. The setup script creates private files
only when they do not already exist. It never starts a service or overwrites an
existing configuration.

Use separate test credentials and state until live API behavior and migration are
fully audited. Do not point the Ruby and Elixir programs at the same account at
the same time.

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

Additional experimental commands cover target commentary, discovery, public-post
inspection, interactive deletion, active hours, polling, and daemon operation.
AI-generated text is designed to stay in the queue regardless of compatibility
flags or environment values, but the Elixir port is not release-qualified yet.

## State and safeguards

State is stored under each product's `data/` directory and separated again by
platform, service origin, and account. Credentials are not written to state. The
state format resembles the Ruby format, but migration has not been declared safe
or supported. Test with a copy and run only one process per account.

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

## Tests

```sh
mix format --check-formatted
mix test --warnings-as-errors
```

There is no packaging script yet. A future package must include the GPL source,
Jason's license and corresponding source, checksums, setup files, and separate
BlueBot and Mastobot launchers. It must exclude generated configuration,
credentials, logs, state, dependencies fetched outside the package, and stale
build output.

Read [CHANGELOG.md](CHANGELOG.md) for the porting checkpoint and
[SECURITY.md](SECURITY.md) for the intended boundaries and known limits. Both are
working documents until the experiment receives a complete release audit.
