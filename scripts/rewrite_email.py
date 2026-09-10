#!/usr/bin/env python3
"""Prepare or apply an email-only history rewrite in a fresh, private mirror.

Requires Python 3, Git, and existing GitHub authentication. No tokens are read
or managed by this script. GitHub pull refs and cached commits need separate
cleanup; neither is writable by an ordinary force push.
"""
import argparse
from pathlib import Path
import subprocess
import tempfile


def run(*args, cwd=None, data=None):
    return subprocess.check_output(args, cwd=cwd, input=data)


def rewrite(repository, old_email, new_email, apply=False):
    if not old_email or old_email == new_email:
        raise ValueError("Provide distinct old and new email addresses.")
    if any(c in "\r\n<>" or c.isspace() or ord(c) < 0x20 or ord(c) == 0x7f
           for c in old_email + new_email):
        raise ValueError("Invalid email address.")
    directory = Path(tempfile.mkdtemp(prefix="chorusdraft-email-"))
    mirror = directory / "mirror.git"
    run("git", "clone", "--mirror", "--", repository, str(mirror))

    def git(*args, data=None):
        return run("git", *args, cwd=mirror, data=data)

    refs = dict(line.split(" ", 1)[::-1] for line in git(
        "for-each-ref", "--format=%(objectname) %(refname)", "refs/heads", "refs/tags"
    ).decode().splitlines())
    if not refs:
        raise ValueError("Repository has no branch or release tag refs.")
    before_trees = {ref: git("rev-parse", ref + "^{tree}").strip() for ref in refs}
    old, new = old_email.encode(), new_email.encode()
    replacements = {}

    def object_data(sha):
        kind = git("cat-file", "-t", sha).strip().decode()
        return kind, git("cat-file", kind, sha)

    def write_object(kind, data):
        return git("hash-object", "-t", kind, "-w", "--stdin", data=data).strip().decode()

    def headers(raw):
        head, body = raw.split(b"\n\n", 1)
        groups = []
        for line in head.split(b"\n"):
            if line.startswith(b" "):
                groups[-1] += b"\n" + line
            else:
                groups.append(line)
        return groups, body

    def rewrite_object(sha):
        if sha in replacements:
            return replacements[sha]
        kind, raw = object_data(sha)
        if kind not in ("commit", "tag"):
            raise ValueError("Only commits and annotated release tags are supported.")
        groups, body = headers(raw)
        revised = []
        for group in groups:
            key, value = group.split(b" ", 1)
            if key in (b"parent", b"object"):
                group = key + b" " + rewrite_object(value.decode()).encode()
            elif key in (b"author", b"committer", b"tagger"):
                group = group.replace(b"<" + old + b">", b"<" + new + b">")
            revised.append(group)
        body = body.replace(old, new)
        updated = b"\n".join(revised) + b"\n\n" + body
        if updated != raw:
            # Signatures over the original object cannot authenticate rewritten data.
            revised = [g for g in revised if g.split(b" ", 1)[0] not in
                       (b"gpgsig", b"gpgsig-sha256", b"mergetag")]
            if kind == "tag":
                for marker in (b"-----BEGIN PGP SIGNATURE-----", b"-----BEGIN SSH SIGNATURE-----"):
                    body = body.split(marker, 1)[0]
            updated = b"\n".join(revised) + b"\n\n" + body
        replacements[sha] = sha if updated == raw else write_object(kind, updated)
        return replacements[sha]

    # Parent-first iteration avoids recursion proportional to history length.
    commits = git("rev-list", "--reverse", "--topo-order", *refs).decode().splitlines()
    for sha in commits:
        rewrite_object(sha)
    changed = {ref: rewrite_object(sha) for ref, sha in refs.items()}
    for ref, sha in changed.items():
        git("update-ref", ref, sha, refs[ref])
        if git("rev-parse", ref + "^{tree}").strip() != before_trees[ref]:
            raise RuntimeError("Verification failed: a branch or tag file tree changed.")
    for sha in replacements.values():
        kind, raw = object_data(sha)
        if old in raw:
            raise RuntimeError("Old email remains in rewritten metadata; refusing to push.")
    git("fsck", "--no-reflogs", "--no-dangling")
    changes = [(ref, sha) for ref, sha in changed.items() if sha != refs[ref]]
    print(f"Verified {len(commits)} commits; {len(changes)} refs change; file trees preserved.")
    print(f"Private preparation directory: {directory}")
    if apply and changes:
        # Atomic update plus an explicit lease for every ref rejects concurrent edits.
        args = ["push", "--atomic"]
        args.extend(f"--force-with-lease={ref}:{refs[ref]}" for ref, _ in changes)
        args.append(repository)
        args.extend(f"{sha}:{ref}" for ref, sha in changes)
        git(*args)
        remote = dict(line.split("\t", 1)[::-1] for line in git(
            "ls-remote", "--refs", repository, "refs/heads/*", "refs/tags/*"
        ).decode().splitlines())
        if any(remote.get(ref) != sha for ref, sha in changes):
            raise RuntimeError("Remote verification failed; inspect before retrying.")
        print("Rewritten branches and tags verified on remote.")
    elif not apply:
        print("Preparation only. Run again with --apply to update remote branches and tags.")
    print("GitHub PR refs, cached commits and existing clones can retain the original email.")
    return mirror


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", default="https://github.com/buntatoes/chorusdraft.git")
    parser.add_argument("--old-email", required=True)
    parser.add_argument("--new-email", default="324143321+buntatoes@users.noreply.github.com")
    parser.add_argument("--apply", action="store_true", help="atomically push verified rewrites")
    args = parser.parse_args()
    rewrite(args.repo, args.old_email, args.new_email, args.apply)
