#!/bin/sh

set -eu

script_dir="$(cd -- "$(dirname -- "$0")" && pwd)"
exec "$script_dir/kebab-folders" "$@"
