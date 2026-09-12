# Contributing

One human, often several agents. The product is one `main`. The failure
mode is several changes to the same desktop files at once.

## Desktop lock

These files are one lock. At most one open pull request may change them:

- `desktop/src/main.jsx`
- `desktop/electron/main.cjs`
- `launcher/bridge.py`

If an open PR already touches any of those, merge or close it before starting
another. Do not open a second PR “based on” the first while both stay open.
Elixir, Guard, packaging, and docs can proceed in parallel with each other,
not with a desktop-lock PR.

CI rejects a second open PR that edits the lock files.

## Pull requests

One issue, one PR, then merge to `main` before the next related change.
Split work is sequential, not parallel.

- Short title. Short body. `Fixes #N` when there is an issue.
- No checklists, agent logs, or process notes in the body.
- Do not open a replacement PR for the same issue while one is still open.
- Do not merge, close, or rebase other people’s PRs unless asked.
- At most two open PRs, and at most one of those is desktop-lock.

`main` is the product. Feature work does not bump `VERSION` or cut a GitHub
Release unless that is the task.

## Issues

A ticket is a few sentences: what is wrong or wanted, and how you will know
it is done. No design essays, no agent checklists. Do not file extra issues
while doing the work unless a real separate bug shows up.

Use [private reporting](https://github.com/buntatoes/chorusdraft/security/advisories/new)
for vulnerabilities. Public issues stay free of tokens, private posts, and
personal information.

## Commits

Sign commits when the environment can. Do not switch signing off, and do not
point `user.signingkey` at a key GitHub will not verify.

## Releases

Tag from `main` after checks are green. Do not mix a feature PR with a
version bump and packages unless the task says to.
