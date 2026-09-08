# ChorusDraft 0.51.6

Downloads: [GitHub Releases](https://github.com/buntatoes/chorusdraft/releases).

Bug-fix and security release. No new features. Upgrade if you use
`automatic`, edit drafts from the desktop, or run automatic mode on a public
account.

## Fixed

- `chorusdraft PLATFORM automatic` and the desktop **Start automatic mode**
  button failed with "Unknown command" since 0.51.4. `--daemon --automatic`
  still worked, so the bug hid behind the long form.
- Desktop edits longer than 4095 bytes (1024 on macOS) were silently cut by
  the terminal and then rejected. Long replacements now arrive whole.
- Editing a reply or mention during review no longer stalls on the store lock.
- Help text matches the parser: `import FILE`, `--history`, and the full list
  of options `--edit` refuses.

## Security

Findings from an audit of the bot, desktop, launcher, and CI. None were
known to be exploited.

- Draft text shown during review is indented, and the desktop only accepts
  the approval prompt at the start of a line. A draft containing the prompt
  string cannot enable the publish button early.
- Desktop responses reject control characters other than tab. Requests to the
  bot service are size-capped.
- The obfuscated-email screen no longer takes seconds on long whitespace runs.
- Automatic mode holds words that mix Latin with Cyrillic, Greek, or Armenian
  letters, which defeated the harassment word list.
- C1 control characters are rejected in drafts.
- Bluesky app passwords, AWS keys, Stripe keys, and private-key headers are
  redacted from AI context and refused in AI output.
- Identifier checks cover the whole value; a trailing newline no longer
  passes. `--publish` is refused with `--random-reply`.
- Jetstream backs off from a server that accepts and immediately closes.
- History and Queue refuse oversized state files. The bundle script's
  integrity checks no longer depend on `assert`.

Details: [CHANGELOG.md](CHANGELOG.md). GUI: [docs/DESKTOP.md](docs/DESKTOP.md).

## Packages

CLI:

- `ChorusDraft-elixir-0.51.6-linux.tar.gz`
- `ChorusDraft-elixir-0.51.6-macos.tar.gz`
- `ChorusDraft-elixir-0.51.6-windows.zip`

Desktop (`chorusdraft-v0.51.6-<os>-<arch>`, `.tar.gz` on Unix, `.zip` on
Windows) includes the Elixir bot and the launcher.

Each archive has the executable, setup/install/verify scripts, config
examples, docs, application source, pinned dependency source and licenses, a
manifest, and a SHA-256 sidecar. Stop the old process, then import state if
you need it.
