#!/bin/sh
set -eu
umask 077
if [ "$#" -ne 1 ]; then
  echo 'Usage: ./install.sh NEW_DIRECTORY (must not exist)' >&2
  exit 1
fi
src=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
dest=$1
case "$dest" in /*) ;; *) dest=$PWD/$dest ;; esac
if [ -e "$dest" ] || [ -L "$dest" ]; then
  echo 'Destination already exists; install into a new version directory.' >&2
  exit 1
fi
(cd "$src" && sha256sum --check --quiet MANIFEST.sha256)
mkdir -m 700 -- "$dest"
for item in chorusdraft run.sh setup.sh install.sh .env.example config source README.md RELEASE_NOTES.md SECURITY.md PARITY.md LICENSE NOTICE THIRD_PARTY_NOTICES.md VERSION MANIFEST.sha256; do
  cp -R -- "$src/$item" "$dest/$item"
done
(cd "$dest" && sha256sum --check --quiet MANIFEST.sha256)
"$dest/setup.sh"
echo "Installed in $dest. Edit its .env before use. See README.md for state import."
