# ChorusDraft 0.51.2 release notes

Released September 6, 2026.
This release supports Bluesky and Mastodon on Linux, macOS, and Windows.
Download the platform archives and `SHA256SUMS` from the
[0.51.2 release](https://github.com/buntatoes/chorusdraft/releases/tag/v0.51.2).

## Ruby

Ruby 4.0 or newer is now required. This release is tested with Ruby
4.0.6. The bot uses Ruby's standard libraries without additional runtime gems.

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

## Upgrading

Stop the old bot, extract the new archive into a new directory, and copy your
`.env`, configured target/do-not-contact files, and complete `data` directory.
State and configuration formats are unchanged from 0.51.1. Run only one
installation per account.

## Platform support

Packages are available for both bots on Linux, macOS, and Windows. Each download
includes setup, launchers, and usage documentation. Install Ruby 4.0+ separately
and verify the archive against the release's `SHA256SUMS` before extraction.

The release passed source and package tests on Ubuntu 24.04, Windows Server
2025, and macOS 15 on Apple Silicon and Intel with Ruby 4.0.6. Automated tests
use simulated API responses; live service integration is not covered.
