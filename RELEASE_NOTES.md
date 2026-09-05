# Elixir experimental branch notes

This is the `elixir-experimental` branch. It contains an unfinished Linux Elixir
rewrite of BlueBot and Mastobot and is separate from the supported Ruby release
line.

The current supported release is
[ChorusDraft 0.51.1](https://github.com/buntatoes/chorusdraft/releases/tag/v0.51.1),
whose source lives on `main-ruby`. Unreleased Ruby maintenance work lives on
`ruby-testing`.

The Elixir executable currently reports `0.52.0-testing` as a temporary internal
identifier. There is no Elixir tag, GitHub release, archive, or supported upgrade
path. Packaging, live API verification, state migration, daemon testing, and a
complete security audit are unfinished.

See [`elixir/RELEASE_NOTES.md`](elixir/RELEASE_NOTES.md) for the detailed
experimental status and [`elixir/README.md`](elixir/README.md) for build and test
instructions.
