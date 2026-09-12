# Agent instructions

Follow [CONTRIBUTING.md](CONTRIBUTING.md).

Before you edit `desktop/src/main.jsx`, `desktop/electron/main.cjs`, or
`launcher/bridge.py`, list open pull requests. If another open PR already
changes any of those files, stop. Do not open a second PR. Do not stack a
branch on an unmerged desktop-lock PR.

Do not invent extra GitHub issues. Do not put checklists, plans, or
“as an agent” notes in issues or pull requests. Title, what changed,
`Fixes #N`.

Do not merge, close, or duplicate an open PR for the same work. Do not bump
`VERSION` or publish a GitHub Release unless the user asked.

Commit as Cursor Agent when that identity is configured. Leave git commit
signing on the environment default so GitHub can verify it.
