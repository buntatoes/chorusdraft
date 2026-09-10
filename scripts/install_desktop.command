#!/bin/sh
set -eu
cd "$(CDPATH= cd "$(dirname "$0")" && pwd)"
set +e
./install.sh
status=$?
set -e
echo
if [ "$status" -eq 0 ]; then
  echo 'You can close this window.'
else
  echo 'Install did not finish. The message above explains why.'
  printf 'Press Return to close...'
  read -r _ || true
fi
exit "$status"
