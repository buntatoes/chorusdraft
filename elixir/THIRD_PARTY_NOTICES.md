# Third-party notices

The Linux Elixir build uses:

- [Jason](https://github.com/michalmuskala/jason) 1.4.5 for JSON encoding and
  decoding, copyright (c) 2016 Michał Muskała, Apache License 2.0.
- [WebSockex](https://github.com/dominicletz/websockex) 0.5.1 for WebSocket
  transport, MIT License.
- [Telemetry](https://github.com/beam-telemetry/telemetry), a WebSockex runtime
  dependency, Apache License 2.0. The resolved version is pinned in `mix.lock`.

No package archive exists yet. Future packages must include the corresponding
dependency source and original license/notice files. Running Mix downloads these
dependencies for local builds; it does not create a distributable source bundle.
