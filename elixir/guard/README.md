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
