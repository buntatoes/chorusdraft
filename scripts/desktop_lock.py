#!/usr/bin/env python3
"""Fail if another open PR already changes the desktop hot path."""
import json
import os
import subprocess
import sys

HOT = {
    "desktop/src/main.jsx",
    "desktop/electron/main.cjs",
    "launcher/bridge.py",
}


def gh(*args):
    return subprocess.check_output(["gh", *args], text=True)


def filenames(repo, number):
    listed = gh(
        "api",
        f"repos/{repo}/pulls/{number}/files",
        "--paginate",
        "--jq",
        ".[].filename",
    )
    return {line for line in listed.splitlines() if line}


def main():
    repo = os.environ.get("GITHUB_REPOSITORY", "").strip()
    current = os.environ.get("PR_NUMBER", "").strip()
    if not repo or not current.isdigit():
        raise SystemExit("GITHUB_REPOSITORY and PR_NUMBER are required.")
    current = int(current)
    open_prs = json.loads(
        gh(
            "pr",
            "list",
            "--repo",
            repo,
            "--state",
            "open",
            "--json",
            "number",
            "--limit",
            "50",
        )
    )
    blockers = []
    for item in open_prs:
        number = item["number"]
        if number == current:
            continue
        hit = sorted(filenames(repo, number) & HOT)
        if hit:
            blockers.append((number, hit))
    if not blockers:
        return
    print("Another open pull request already changes the desktop lock files.")
    print("Merge or close it before opening a second PR against:")
    for path in sorted(HOT):
        print(f"  {path}")
    for number, hit in blockers:
        print(f"#{number}: {', '.join(hit)}")
    raise SystemExit(1)


if __name__ == "__main__":
    main()
