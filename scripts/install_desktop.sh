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

if [ "$(uname -s)" = Darwin ]; then
  apps_link="$HOME/Applications/ChorusDraft.app"
  if [ -e "$apps_link" ] && [ ! -L "$apps_link" ]; then
    echo "Cannot create $apps_link: a folder already exists there and is not a symlink." >&2
    echo 'Move it aside (for example, to the Trash), then run this installer again.' >&2
    exit 1
  fi
fi

verify() {
  manifest=$1
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum --check --quiet "$manifest"
  else
    shasum -a 256 --check "$manifest" >/dev/null
  fi
}

# Desktop-entry spec quoting for Exec/Path/Icon: double any %, escape
# " ` $ and \, and wrap in double quotes when the value contains a
# character (such as a space) that is unsafe unquoted.
desktop_quote() {
  quoted=$(printf '%s' "$1" | sed -e 's/%/%%/g' -e 's/["`$\\]/\\&/g')
  case $quoted in
    *[!A-Za-z0-9_+.,:/@%^=-]*) printf '"%s"' "$quoted" ;;
    *) printf '%s' "$quoted" ;;
  esac
}

register_application() {
  install_root=$1
  case $(uname -s) in
    Darwin)
      apps_dir="$HOME/Applications"
      mkdir -p "$apps_dir"
      apps_link="$apps_dir/ChorusDraft.app"
      rm -f "$apps_link"
      ln -s "$install_root/ChorusDraft.app" "$apps_link"
      ;;
    Linux)
      apps_dir="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
      mkdir -p "$apps_dir"
      exec_path="$install_root/launcher/ChorusDraft"
      if [ ! -x "$exec_path" ]; then
        exec_path="$install_root/bot"
      fi
      cat > "$apps_dir/chorusdraft.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=ChorusDraft
Comment=Bluesky and Mastodon drafting bot
Exec=$(desktop_quote "$exec_path")
Path=$(desktop_quote "$install_root")
Icon=$(desktop_quote "$install_root/chorusdraft.svg")
Terminal=false
Categories=Network;Chat;
StartupWMClass=ChorusDraft
EOF
      chmod 600 "$apps_dir/chorusdraft.desktop"
      if command -v update-desktop-database >/dev/null 2>&1; then
        update-desktop-database "$apps_dir" 2>/dev/null || true
      fi
      ;;
  esac
}

launch_gui() {
  install_root=$1
  if [ "${CI:-}" = true ]; then
    return 1
  fi
  case $(uname -s) in
    Darwin)
      open "$install_root/ChorusDraft.app" >/dev/null 2>&1 &
      ;;
    Linux)
      if [ -z "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]; then
        return 1
      fi
      "$install_root/bot" >/dev/null 2>&1 &
      ;;
  esac
}

(cd "$src" && verify MANIFEST.sha256)
mkdir -p "$(dirname "$dest")"
mkdir -m 700 "$dest"
for item in "$src"/*; do
  base=$(basename "$item")
  case "$base" in desktop-source|build-scripts) continue ;; esac
  cp -R "$item" "$dest/$base"
done
# Re-verify the installed copy; desktop-source/ and build-scripts/ are
# intentionally not copied, so check the manifest without their entries.
installed_manifest=$(mktemp "${TMPDIR:-/tmp}/chorusdraft-manifest.XXXXXX")
grep -vE '  (desktop-source|build-scripts)/' "$dest/MANIFEST.sha256" > "$installed_manifest"
(cd "$dest" && verify "$installed_manifest")
rm -f "$installed_manifest"
chmod 755 "$dest/bot" "$dest/install.sh" 2>/dev/null || true
chmod 755 "$dest/bot.command" 2>/dev/null || true
chmod 755 "$dest/launcher/ChorusDraft" 2>/dev/null || true
"$dest/elixir/setup.sh"
register_application "$dest"
if launch_gui "$dest"; then
  echo "Installed ChorusDraft in $dest and opened the desktop app."
else
  echo "Installed ChorusDraft in $dest."
  case $(uname -s) in
    Darwin) echo "Open ChorusDraft from Applications or run: $dest/bot" ;;
    *) echo "Open ChorusDraft from your applications menu or run: $dest/bot" ;;
  esac
fi
echo 'Edit elixir/bluesky/.env and/or elixir/mastodon/.env before use.'
