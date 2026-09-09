#!/bin/sh
set -eu
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT HUP INT TERM
case $(uname -s) in
  Darwin) package_os=macos ;;
  Linux) package_os=linux ;;
  *) echo 'Use check_packages.ps1 on Windows.' >&2; exit 1 ;;
esac
set -- dist/ChorusDraft-elixir-*-$package_os.tar.gz
if [ "$#" -ne 1 ] || [ ! -f "$1" ]; then
  echo "Expected exactly one ChorusDraft $package_os archive." >&2
  exit 1
fi
archive=$1
verify() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum --check "$1"
  else
    shasum -a 256 --check "$1"
  fi
}
(cd dist && verify "$(basename "$archive").sha256")
tar -xzf "$archive" -C "$work"
name=$(basename "$archive" .tar.gz)
package=$work/$name
(cd "$package" && verify MANIFEST.sha256 >/dev/null)
for dep in mint websockex jason telemetry hpax; do
  find "$package/source/deps/$dep" -type f | grep -Ei '/(license|copying)(\.[^/]*)?$' >/dev/null
done
if tar -tzf "$archive" | grep -E '(^|/)(\.env|data|logs|_build|\.git)(/|$)'; then
  echo 'Runtime data leaked into package' >&2
  exit 1
fi
"$package/run.sh" bluesky --help
"$package/run.sh" mastodon --help
"$package/install.sh" "$work/installed-$name"
installed=$work/installed-$name
auto_home=$work/auto-home
mkdir -p "$auto_home"
auto_out=$(HOME="$auto_home" "$package/install.sh")
echo "$auto_out" | grep -q 'Installed ChorusDraft in '
auto_installed=$(echo "$auto_out" | sed -n 's/^Installed ChorusDraft in \(.*\)\. Edit.*/\1/p')
test -n "$auto_installed"
test -d "$auto_installed"
test -x "$auto_installed/run.sh"
printf '%s\n' 'SENTINEL=$(do-not-execute)' > "$installed/bluesky/.env"
"$installed/setup.sh"
test "$(cat "$installed/bluesky/.env")" = 'SENTINEL=$(do-not-execute)'
if [ "$package_os" = macos ]; then
  permissions=$(stat -f %Lp "$installed/bluesky/.env")
else
  permissions=$(stat -c %a "$installed/bluesky/.env")
fi
test "$permissions" = 600
if "$package/install.sh" "$installed"; then
  echo 'Installer overwrote an existing directory' >&2
  exit 1
fi
(cd "$package/source" && HEX_OFFLINE=1 MIX_ENV=prod mix escript.build && ./chorusdraft bluesky --help && ./chorusdraft mastodon --help)
