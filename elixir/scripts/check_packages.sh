#!/bin/sh
set -eu
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT HUP INT TERM
for archive in dist/*.tar.gz; do
  (cd dist && sha256sum --check "$(basename "$archive").sha256")
  tar -xzf "$archive" -C "$work"
  name=$(basename "$archive" .tar.gz)
  package=$work/$name
  (cd "$package" && sha256sum --check --quiet MANIFEST.sha256)
  test -f "$package/source/deps/mint/LICENSE"
  test -f "$package/source/deps/websockex/LICENSE"
  if tar -tzf "$archive" | rg '(^|/)(\.env|data|logs|_build|\.git)(/|$)'; then
    echo 'Runtime data leaked into package' >&2
    exit 1
  fi
  "$package/run.sh" --help
  "$package/install.sh" "$work/installed-$name"
  installed=$work/installed-$name
  printf '%s\n' 'SENTINEL=$(do-not-execute)' > "$installed/.env"
  "$installed/setup.sh"
  test "$(cat "$installed/.env")" = 'SENTINEL=$(do-not-execute)'
  test "$(stat -c %a "$installed/.env")" = 600
  if "$package/install.sh" "$installed"; then
    echo 'Installer overwrote an existing directory' >&2
    exit 1
  fi
  # Rebuild using only the dependency sources shipped inside the archive.
  (cd "$package/source" && HEX_OFFLINE=1 MIX_ENV=prod mix escript.build && ./chorusdraft bluesky --help)
done
