# ChorusDraft 0.51.2 release candidate

Unreleased Ruby maintenance update for Bluesky and Mastodon on Linux, macOS,
and Windows. No GitHub release or tag has been published by this work.

## Ruby

Ruby 4.0 or newer is now required. Development is pinned to and tested on Ruby
4.0.6 in `.ruby-version`. The bot uses Ruby's bundled libraries without external
runtime gems. Tests require Minitest.

Linux/macOS launchers use rbenv when available, including `~/.rbenv` when shell
initialization has not run; otherwise they use Ruby on PATH. Extracted packages
use your selected Ruby 4.0+ rather than pinning one patch release. Windows uses
Ruby on PATH. Launchers do not install Ruby or change global Ruby settings.

## Short commands

In the extracted folder, run:

```sh
./bot setup
# Edit .env with your account and AI settings.
./bot draft
./bot review
./bot start
```

On Windows use `.\bot.bat` in place of `./bot`. In a source checkout, first enter
`bluesky` or `mastodon`, or use `./bot bluesky COMMAND` from the root.

`post "TEXT"`, `reply ID "TEXT"`, `quote ID "TEXT"`, `search "QUERY"`, `random`,
`discover`, `targets`, `replies`, `listen`, and `delete ID` are also available.
Run `./bot help` for the quick guide or `./bot --help` for advanced options.
Existing flags and package `run.sh`/`run.bat` launchers remain supported.

AI drafts still require explicit review. `start` prepares drafts in the
foreground; Ctrl+C stops it. Setup preserves existing configuration files.

## Upgrade and packaging

Stop the old bot, extract the new archive into a new directory, and copy your
`.env`, configured target/do-not-contact files, and complete `data` directory.
State and configuration formats are unchanged from 0.51.1. Run only one
installation per account.

Build with `rbenv exec ruby scripts/build_release.rb` (or Ruby 4.0+ on PATH).
The builder writes six archives and `SHA256SUMS` under `dist/`. Runtime secrets,
state, logs, and the experimental Elixir project are excluded.

## Native release validation

The `Ruby release checks` workflow tests Ruby 4.0.6 on Ubuntu 24.04, Windows
2025, macOS 15 Apple Silicon, and macOS 15 Intel. It builds archives once and
runs both bots' extracted packages on their native operating systems, including
`bot.bat` and `run.bat` through Windows cmd.exe. Checks cover the full safety
and command suites, checksums, paths with spaces, setup preservation, argument
forwarding, and draft queue behavior without live API calls. All native jobs
must pass before treating a candidate as validated for release.
