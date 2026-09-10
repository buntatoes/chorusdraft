# Third-party notices

Linux, macOS, and Windows builds use:

- [Jason](https://github.com/michalmuskala/jason) 1.4.5, JSON, copyright (c)
  2016 Michał Muskała, Apache License 2.0.
- [WebSockex](https://github.com/dominicletz/websockex) 0.5.1, WebSocket
  transport, MIT License.
- [Telemetry](https://github.com/beam-telemetry/telemetry), WebSockex runtime
  dependency, Apache License 2.0. Version pinned in `mix.lock`.
- [Mint](https://github.com/elixir-mint/mint) 1.10.0, HTTP, Apache License 2.0.
- [HPAX](https://github.com/elixir-mint/hpax), Mint dependency, Apache License
  2.0. Version pinned in `mix.lock`. ChorusDraft uses HTTP/1 only.

Packages include each dependency's source and license files under
`source/deps/`. ChorusDraft application code is Apache 2.0 except ChorusDraft
Guard (`guard/`), which is proprietary. Dependencies keep their own licenses.
Erlang/OTP is a separate runtime.
