# Remove a personal email from Git history

Run this from a machine that can push to the repository. Python 3 and Git.
It prepares a private mirror; it does not change your working tree.

Set the repo identity for later commits:

```sh
git config user.email '324143321+buntatoes@users.noreply.github.com'
```

In GitHub Settings → Emails, enable email privacy and block command-line
pushes that expose your personal email. That does not rewrite history.

Prepare:

```sh
python3 scripts/rewrite_email.py --old-email 'YOUR_EXPOSED_EMAIL'
```

Apply after you inspect the result:

```sh
python3 scripts/rewrite_email.py --old-email 'YOUR_EXPOSED_EMAIL' --apply
```

The script replaces that exact address in author, committer, tagger, and
message metadata. Trees and merge structure stay. It checks trees and
metadata, then pushes atomically with leases. It does not delete branches or
push GitHub pull-request refs.

New commits have new IDs. Old signatures are dropped. Re-sign tags if you
need signatures. Other clones should be re-cloned so they do not push old
history back.

Pull requests, caches, forks, and other clones can still hold the old
commits. Ask GitHub Support to purge hosted copies. Do not upload the
preparation directory.
