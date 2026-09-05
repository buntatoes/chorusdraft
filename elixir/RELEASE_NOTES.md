# ChorusDraft Elixir experimental notes

This is an unfinished Linux rewrite of BlueBot and Mastobot on the
`elixir-experimental` branch. It is separate from the supported Ruby 0.51.1
release on `main-ruby` and the future Ruby work on `ruby-testing`.

The Mix project currently reports `0.52.0-testing` as a temporary internal build
identifier. It is not the official Ruby 0.52 version and has no associated tag,
GitHub release, download archive, or compatibility promise.

The checkpoint includes initial ports of Bluesky and Mastodon clients, local AI
and Gemini support, comic drafting, interactive review, per-account state,
opt-outs, do-not-contact checks, visibility filtering, interaction limits, and
ambiguous-publication handling. The 22-test offline suite uses fakes and performs
no network calls or publication.

Live platform compatibility, long-running daemon behavior, state migration,
installation upgrades, packaging, and a complete release security audit remain
unfinished. There is no packaging script yet.

The experiment targets Linux. The current escript requires Erlang/OTP 25 or later
at runtime; Elixir 1.14 or later and Mix are needed to build from source.

Do not run the Ruby and Elixir implementations against the same account at the
same time. Use separate test credentials and a copy of any state until migration
and live behavior have been audited.
