# ChorusDraft Guard

Proprietary screening module for ChorusDraft. This directory is **not**
Apache 2.0. See [LICENSE](LICENSE).

Guard implements publication screening: opt-outs, prompt-injection, harassment,
automatic-mode extra checks, and personal-information / credential patterns.
The Apache-licensed bot talks to it through `ChorusDraft.Safety` and
`ChorusDraft.PII`. If Guard is missing or is not a licensed implementation,
the bot refuses to continue.

Official source trees and release packages include this directory. Do not
replace it with a stub that skips screening.

## Signature

The compiled Guard modules are signed with an ed25519 key. `mix guard.sign`
records a digest of each one in `guard.manifest`, signs it, and compiles the
signed manifest, the signature, and the public keys in [keys](keys) into the
build. Before Guard screens anything, ChorusDraft digests the Guard code as it
exists on disk, checks it against that signature, and confirms the running code
is that code. A Guard file that was swapped or patched is refused even when it
exports every function with the right names.

The private signing key is never stored here. Release signing and the
development key that unofficial builds use are described in the Guard signing
section of [../README.md](../README.md).
