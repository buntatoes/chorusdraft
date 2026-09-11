# Guard verifying keys

Every `*.pub` file here is an ed25519 public key that this build trusts to
vouch for the compiled Guard modules. The files are read at compile time and
carried inside the built bot, so an installed ChorusDraft reads no key material
from disk at runtime.

Format, one key per file:

```
# who holds the private half, and where
ed25519 <base64 of the 32-byte public key>
```

Blank lines and `#` comments are ignored.

The matching private keys are never stored here and are never committed. A
release key is generated with `mix guard.keygen`, kept offline by whoever cuts
releases, and used through `CHORUSDRAFT_GUARD_SIGNING_KEY` when the release is
built. See the Guard section of `../README.md`.

`development.pub` is written by `mix guard.sign --development` for unofficial
builds. It is ignored by git, and `mix guard.sign` refuses to sign with a
release key while it exists.
