# Third-party notices

The Linux, macOS, and Windows Elixir builds use:

- [Jason](https://github.com/michalmuskala/jason) 1.4.5 for JSON encoding and
  decoding, copyright (c) 2016 Michał Muskała, Apache License 2.0.
- [WebSockex](https://github.com/dominicletz/websockex) 0.5.1 for WebSocket
  transport, MIT License.
- [Telemetry](https://github.com/beam-telemetry/telemetry), a WebSockex runtime
  dependency, Apache License 2.0. The resolved version is pinned in `mix.lock`.
- [Mint](https://github.com/elixir-mint/mint) 1.10.0 for bounded HTTP transport,
  Apache License 2.0.
- [HPAX](https://github.com/elixir-mint/hpax), a Mint dependency, Apache License 2.0.
  Its resolved version is pinned in `mix.lock` (ChorusDraft selects HTTP/1 only).

Packages include each resolved dependency's corresponding source and original
license/notice files under `source/deps/`. The application is GPLv3; dependencies
retain their own licenses. Erlang/OTP is a separately installed runtime.
