#!/bin/sh
base=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
exec "$base/bot" "$@"
