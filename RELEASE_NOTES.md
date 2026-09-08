# ChorusDraft 0.51.5

Downloads: [GitHub Releases](https://github.com/buntatoes/chorusdraft/releases).

Queue UI, pending-draft edit, and automatic budget in `status`. Edit never
publishes. Review is still the default.

- Desktop **Queue** lists pending, publishing, and uncertain drafts from the
  account store last used on the selected platform. Remaining automatic
  attempts and freeze state are shown there.
- `chorusdraft PLATFORM edit ID TEXT` replaces pending draft text after the
  same screens used at review. The draft stays pending. `--publish` is
  rejected with `--edit`. `--edit` cannot take reply, quote, or queue flags.
- Interactive review accepts `e`, then replacement text, then asks again
  before publish. Empty replacement cancels the edit. Desktop review Edit
  prefills the current text, keeps line breaks, and disables the response
  field so `y` cannot publish the original.
- `status` includes `automatic: remaining/limit` and a freeze line when
  needed.
- CI artifact names are read from `VERSION`.

GUI: [docs/DESKTOP.md](docs/DESKTOP.md).

## Packages

CLI:

- `ChorusDraft-elixir-0.51.5-linux.tar.gz`
- `ChorusDraft-elixir-0.51.5-macos.tar.gz`
- `ChorusDraft-elixir-0.51.5-windows.zip`

Desktop (`chorusdraft-v0.51.5-<os>-<arch>`, `.tar.gz` on Unix, `.zip` on
Windows) includes the Elixir bot and the launcher.

Each archive has the executable, setup/install/verify scripts, config
examples, docs, application source, pinned dependency source and licenses, a
manifest, and a SHA-256 sidecar. Stop the old process, then import state if
you need it.
