# ChorusDraft 0.51.5

Downloads: [GitHub Releases](https://github.com/buntatoes/chorusdraft/releases).

0.51.5 adds a desktop queue, pending-draft editing, and automatic-budget
visibility. Review stays the default. Automatic mode is unchanged: it still
cannot publish edited, manual, or previously queued drafts.

## Highlights

- Desktop **Queue** lists pending, publishing, and uncertain drafts for the
  selected platform. It shows remaining automatic attempts and whether a
  publishing or uncertain draft has frozen automatic mode.
- `chorusdraft PLATFORM edit ID TEXT` replaces pending draft text after the
  same screens used at review. The draft stays pending. `--publish` is
  rejected with `--edit`.
- Interactive review accepts `e`, then replacement text, then asks again
  before publish. Empty replacement cancels the edit.
- `status` includes `automatic: remaining/limit` and a freeze line when
  needed.
- CI artifact names are read from `VERSION`.

See [docs/DESKTOP.md](docs/DESKTOP.md) for the GUI. 0.51.4 notes for
automatic mode, Jetstream, ChatGPT, and privacy still apply.

## Packages

CLI:

- `ChorusDraft-elixir-0.51.5-linux.tar.gz`
- `ChorusDraft-elixir-0.51.5-macos.tar.gz`
- `ChorusDraft-elixir-0.51.5-windows.zip`

Desktop (`chorusdraft-v0.51.5-<os>-<arch>`, `.tar.gz` on Unix, `.zip` on
Windows) includes the Elixir bot and the launcher.

Each archive has the executable, setup/install/verify scripts, config
examples, docs, application source, pinned dependency source and licenses, a
manifest, and a SHA-256 sidecar. Install into a new directory. Import
compatible state explicitly after stopping the old process.
