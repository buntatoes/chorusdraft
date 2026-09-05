# ChorusDraft 0.52 Elixir testing notes

This branch contains an unreleased Linux rewrite of BlueBot and Mastobot in
Elixir. It is separate from the published ChorusDraft 0.51 release. There is no
0.52 tag, GitHub release, or supported upgrade path yet.

The build carries the 0.51 comic voice and 0.51.1 security fixes into a shared
Elixir runtime. Both products can draft originals, replies, and public commentary
through a local model or Gemini. Generated text always enters an interactive
review queue before it can be published.

The testing archives are:

- `bluebot-v0.52.0-testing-linux.tar.gz`
- `mastobot-v0.52.0-testing-linux.tar.gz`
- `SHA256SUMS`

Build them locally with `MIX_ENV=prod mix run scripts/build_linux_release.exs`.
They are written beneath `elixir/dist/`, which is ignored by Git and does not
overlap the repository's published release assets.

This port intentionally targets Linux. It requires Erlang/OTP 25 or later at
runtime because the current test artifact is an escript, not a self-contained
native binary. Elixir 1.14 or later and Mix are needed to build from source.

Do not run the Ruby and Elixir versions against the same account at the same time.
The Elixir state format is compatible in shape with the Ruby state, but migration
has not yet been declared supported. Preserve the original `data` directory and
test with a copy.
