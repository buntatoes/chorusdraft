#!/bin/sh
set -eu
umask 077
src=$(CDPATH= cd "$(dirname "$0")" && pwd)

default_dest() {
  version=$(tr -d '[:space:]' < "$src/VERSION")
  case $(uname -s) in
    Darwin) root="$HOME/Library/Application Support" ;;
    *) root="${XDG_DATA_HOME:-$HOME/.local/share}" ;;
  esac
  printf '%s/chorusdraft-%s' "$root" "$version"
}

if [ "$#" -eq 0 ]; then
  dest=$(default_dest)
elif [ "$#" -eq 1 ]; then
  dest=$1
  case "$dest" in /*) ;; *) dest=$PWD/$dest ;; esac
else
  echo 'Usage: ./install.sh [NEW_DIRECTORY]' >&2
  echo '  With no argument, installs to a versioned folder under your user data directory.' >&2
  exit 1
fi

if [ -e "$dest" ] || [ -L "$dest" ]; then
  echo "Destination already exists: $dest" >&2
  echo 'Choose another directory or remove the old install first.' >&2
  exit 1
fi

verify() {
  manifest=$1
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum --check --quiet "$manifest"
  else
    shasum -a 256 --check "$manifest" >/dev/null
  fi
}

(cd "$src" && verify MANIFEST.sha256)
mkdir -m 700 "$dest"
for item in chorusdraft run.sh setup.sh install.sh bluesky mastodon source README.md RELEASE_NOTES.md CHANGELOG.md SECURITY.md LICENSE NOTICE THIRD_PARTY_NOTICES.md VERSION MANIFEST.sha256; do
  cp -R "$src/$item" "$dest/$item"
done
(cd "$dest" && verify MANIFEST.sha256)
"$dest/setup.sh"
echo "Installed ChorusDraft in $dest. Edit bluesky/.env and/or mastodon/.env before use."
