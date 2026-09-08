# Remove a personal email from Git history

The GitHub connector cannot rewrite commit identities or release tags. Run this
utility from a machine where Git already has push access to this repository.
It uses Git and Python 3 only and prepares a separate private mirror; it does
not modify your existing working directory.

First set the repository's identity for future local commits:

```sh
git config user.email '324143321+buntatoes@users.noreply.github.com'
```

In GitHub Settings → Emails, enable email privacy and blocking command-line
pushes that expose your personal email. Changing settings does not change
existing history.

Prepare and verify the rewrite, substituting your exposed address locally:

```sh
python3 scripts/rewrite_email.py --old-email 'YOUR_EXPOSED_EMAIL'
```

Apply it after inspecting the preparation result:

```sh
python3 scripts/rewrite_email.py --old-email 'YOUR_EXPOSED_EMAIL' --apply
```

The script replaces the exact email in author, committer, tagger, and message
metadata, preserving commit file trees and merge relationships. It verifies
branch/tag trees and rewritten metadata before an atomic push, with explicit
leases to refuse concurrent remote changes. Branch rules may reject rewriting.
It never deletes remote branches and never pushes GitHub-owned pull-request refs.

Rewritten commits and tags have new IDs. Their old signatures cannot authenticate
the new objects and are removed; re-sign releases separately if needed. Existing
release binaries are not rebuilt or scrubbed by this operation. Other local
clones should be re-cloned or carefully realigned so old history is not pushed back.

Old commits may remain accessible through GitHub pull requests, caches, forks,
and other people's clones. Contact GitHub Support about any remaining hosted
copies; ordinary force-push access cannot purge them. The private preparation
directory also contains old objects and must not be uploaded or shared.
