#!/bin/sh
set -eu
umask 077
src=$(CDPATH= cd "$(dirname "$0")" && pwd)

default_dest() {
  case $(uname -s) in
    Darwin) printf '%s/Library/Application Support/chorusdraft-app' "$HOME" ;;
    *) printf '%s/chorusdraft' "${XDG_DATA_HOME:-$HOME/.local/share}" ;;
  esac
}

chorusdraft_install() {
  [ -f "$1/VERSION" ] && [ -f "$1/elixir/chorusdraft" ]
}

if [ "$#" -eq 0 ]; then
  dest=$(default_dest)
elif [ "$#" -eq 1 ]; then
  dest=$1
  case "$dest" in /*) ;; *) dest=$PWD/$dest ;; esac
else
  echo 'Usage: ./install.sh [DIRECTORY]' >&2
  echo '  With no argument, installs to a per-user ChorusDraft folder and opens the app.' >&2
  echo '  Run again to update that folder. Account data and .env files are kept.' >&2
  exit 1
fi

if [ -e "$dest" ] || [ -L "$dest" ]; then
  if [ -L "$dest" ] || [ ! -d "$dest" ] || ! chorusdraft_install "$dest"; then
    echo "Destination already exists and is not a ChorusDraft install: $dest" >&2
    echo 'Choose another directory or remove that path first.' >&2
    exit 1
  fi
  upgrade=1
else
  upgrade=0
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

copy_account_state() {
  from=$1
  to=$2
  for platform in bluesky mastodon; do
    mkdir -p "$to/elixir/$platform/config"
    if [ -f "$from/elixir/$platform/.env" ]; then
      cp "$from/elixir/$platform/.env" "$to/elixir/$platform/.env"
    fi
    if [ -d "$from/elixir/$platform/data" ]; then
      rm -rf "$to/elixir/$platform/data"
      cp -R "$from/elixir/$platform/data" "$to/elixir/$platform/data"
    fi
    if [ -d "$from/elixir/$platform/logs" ]; then
      rm -rf "$to/elixir/$platform/logs"
      cp -R "$from/elixir/$platform/logs" "$to/elixir/$platform/logs"
    fi
    for file in do_not_contact.txt target_accounts.txt; do
      if [ -f "$from/elixir/$platform/config/$file" ]; then
        cp "$from/elixir/$platform/config/$file" "$to/elixir/$platform/config/$file"
      fi
    done
  done
}

(cd "$src" && verify MANIFEST.sha256)
mkdir -p "$(dirname "$dest")"
staging=$(mktemp -d "$(dirname "$dest")/chorusdraft-staging.XXXXXX")
cleanup() {
  if [ ! -d "$staging" ]; then
    return
  fi
  # If an upgrade already moved the old folder aside, keep the staged copy.
  if [ "$upgrade" -eq 1 ] && [ ! -e "$dest" ]; then
    return
  fi
  rm -rf "$staging"
}
trap cleanup EXIT HUP INT TERM

for item in "$src"/*; do
  base=$(basename "$item")
  cp -R "$item" "$staging/$base"
done
(cd "$staging" && verify MANIFEST.sha256)
chmod 755 "$staging/bot" "$staging/install.sh" 2>/dev/null || true
chmod 755 "$staging/bot.command" 2>/dev/null || true
chmod 755 "$staging/Install ChorusDraft.command" 2>/dev/null || true
chmod 755 "$staging/launcher/ChorusDraft" 2>/dev/null || true

if [ "$upgrade" -eq 1 ]; then
  copy_account_state "$dest" "$staging"
fi

"$staging/elixir/setup.sh"

if [ "$upgrade" -eq 1 ]; then
  backup="${dest}.replacing"
  rm -rf "$backup"
  mv "$dest" "$backup"
  if mv "$staging" "$dest"; then
    rm -rf "$backup"
  else
    mv "$backup" "$dest"
    exit 1
  fi
else
  mv "$staging" "$dest"
fi

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
echo 'Use Open configuration in the app to add your account and AI provider.'
