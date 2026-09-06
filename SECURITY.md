# Security policy for the Elixir experiment

The supported Ruby release is ChorusDraft 0.51.1 from `main-ruby`. The Linux
Elixir version of ChorusDraft on `elixir-experimental` is unreleased. Its offline regression, state-import, and
package checks have passed; live platform verification, a sustained daemon soak,
and an independent release security audit remain outstanding.

The latest targeted review hardened optional Jetstream reception: frames and
fragmented messages have limits checked before payload reads, and handshake
headers, fragment counts, and receive times are bounded. Socket-level regression
tests cover these boundaries alongside the existing publication safeguards.

Report vulnerabilities using GitHub private vulnerability reporting when
available, or contact the maintainer privately through the GitHub profile. Do not
put credentials, private posts, tokens, or exploit details in a public issue.

The implemented Elixir safeguards and current limitations are documented in
[`elixir/SECURITY.md`](elixir/SECURITY.md). Treat those controls as an
implementation checkpoint rather than a completed security guarantee.
