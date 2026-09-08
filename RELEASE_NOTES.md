# ChorusDraft 0.52

Downloads: [GitHub Releases](https://github.com/buntatoes/chorusdraft/releases).

The desktop talks to the bot over JSON instead of a fake terminal. Mastodon
listen/start uses the user streaming API as a wake-up. `service install`
writes a user unit; it does not start it.

## Desktop

GUI sessions set `CHORUSDRAFT_CONTROL=1` and run the bot on ordinary pipes.
Log lines still fill the activity pane. Review sends `approve`, `reject`,
`quit`, `skip`, or `edit` as JSON. Edit is one command and keeps line breaks.
The publish buttons follow a `review` event, not the prompt string.

CLI review is unchanged: type `y`, `e`, `d`, or `q`.

## Mastodon streaming

`listen`, `start`, and `automatic` open `GET /api/v1/streaming/user` on the
instance, or `MASTODON_STREAMING_URL` if you set one. The token goes in the
Authorization header. Stream bodies never go to the model, the terminal, or
state. A `notification` event wakes the same mention fetch as polling. Catch-up
polls still run.

Bluesky Jetstream is the same idea as before.

## Service

```sh
./run.sh bluesky service print
./run.sh bluesky service install
./run.sh mastodon service install --automatic
```

That writes a systemd user unit, LaunchAgent, or Windows task. Enable it
yourself. Setup still does not start a service. Credentials stay in `.env`.

Details: [CHANGELOG.md](CHANGELOG.md). GUI: [docs/DESKTOP.md](docs/DESKTOP.md).

## Packages

CLI:

- `ChorusDraft-elixir-0.52-linux.tar.gz`
- `ChorusDraft-elixir-0.52-macos.tar.gz`
- `ChorusDraft-elixir-0.52-windows.zip`

Desktop (`chorusdraft-v0.52-<os>-<arch>`, `.tar.gz` on Unix, `.zip` on
Windows) includes the Elixir bot and the launcher.

Each archive has the executable, setup/install/verify scripts, config
examples, docs, application source, pinned dependency source and licenses, a
manifest, and a SHA-256 sidecar. Stop the old process, then import state if
you need it.
