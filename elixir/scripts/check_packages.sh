#!/bin/sh
set -eu
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT HUP INT TERM
set -- dist/ChorusDraft-elixir-*-linux.tar.gz
if [ "$#" -ne 1 ] || [ ! -f "$1" ]; then
  echo 'Expected exactly one ChorusDraft Linux archive.' >&2
  exit 1
fi
archive=$1
(cd dist && sha256sum --check "$(basename "$archive").sha256")
tar -xzf "$archive" -C "$work"
name=$(basename "$archive" .tar.gz)
package=$work/$name
(cd "$package" && sha256sum --check --quiet MANIFEST.sha256)
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
printf '%s\n' 'SENTINEL=$(do-not-execute)' > "$installed/bluesky/.env"
"$installed/setup.sh"
test "$(cat "$installed/bluesky/.env")" = 'SENTINEL=$(do-not-execute)'
test "$(stat -c %a "$installed/bluesky/.env")" = 600
if "$package/install.sh" "$installed"; then
  echo 'Installer overwrote an existing directory' >&2
  exit 1
fi
(cd "$package/source" && HEX_OFFLINE=1 MIX_ENV=prod mix escript.build && ./chorusdraft bluesky --help && ./chorusdraft mastodon --help)
