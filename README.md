# ChorusDraft — separate Elixir version

This branch, `elixir-experimental`, contains the Linux Elixir implementation of
BlueBot for Bluesky and Mastobot for Mastodon. The Ruby builds remain on
`main-ruby` and `ruby-testing`; their source here is a read-only parity reference.

The Elixir version includes the Ruby command workflows, local AI/Gemini adapters,
human-reviewed drafting, optional Bluesky Jetstream, state import and separate
Linux packages. Its internal version is `0.52.0-testing`; no official Ruby release
or version is replaced. Live account acceptance remains to be performed.

- [Build, install, configure and run](elixir/README.md)
- [Feature parity and verification scope](elixir/PARITY.md)
- [Implementation notes](elixir/RELEASE_NOTES.md)
- [Safeguards and known limits](elixir/SECURITY.md)

```sh
cd elixir
mix deps.get
MIX_ENV=prod mix escript.build
./chorusdraft bluesky --help
./chorusdraft mastodon --help
```

Building requires Linux, Elixir 1.15+, Erlang/OTP 25+ and util-linux. Packages need
Erlang/OTP and util-linux to run. AI output always requires interactive approval;
`--publish` applies only to manually supplied text.

ChorusDraft is GPLv3; see [LICENSE](LICENSE) and the
[dependency notices](elixir/THIRD_PARTY_NOTICES.md).
