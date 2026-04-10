#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
tool="$repo_root/kebab-folders"

cleanup_dirs=()
cleanup() {
    for d in "${cleanup_dirs[@]:-}"; do
        rm -rf "$d" || true
    done
}
trap cleanup EXIT

mktemp_dir() {
    local d=""
    if d="$(mktemp -d 2>/dev/null)"; then
        printf '%s\n' "$d"
        return 0
    fi
    d="$(mktemp -d -t kebab-folders 2>/dev/null)"
    printf '%s\n' "$d"
}

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

assert_dir() {
    [[ -d "$1" ]] || fail "expected directory to exist: $1"
}

assert_not_dir() {
    [[ ! -d "$1" ]] || fail "expected directory to not exist: $1"
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    printf '%s' "$haystack" | rg -q --fixed-strings -- "$needle" || fail "expected output to contain: $needle"
}

if ! command -v rg >/dev/null 2>&1; then
    fail "ripgrep (rg) is required to run tests"
fi

tmp="$(mktemp_dir)"
cleanup_dirs+=("$tmp")

mkdir -p "$tmp/My Folder" "$tmp/Nested Folder/Child Dir" "$tmp/Already-kebab"

out="$("$tool" "$tmp")"
assert_dir "$tmp/My Folder"
assert_dir "$tmp/Nested Folder/Child Dir"
assert_contains "$out" "My\\ Folder"
assert_contains "$out" "my-folder"

"$tool" --execute "$tmp" >/dev/null
assert_dir "$tmp/my-folder"
assert_dir "$tmp/nested-folder/child-dir"
assert_dir "$tmp/already-kebab"
assert_not_dir "$tmp/My Folder"
assert_not_dir "$tmp/Nested Folder"

tmp2="$(mktemp_dir)"
cleanup_dirs+=("$tmp2")
mkdir -p "$tmp2"$'/Line\nBreak'
"$tool" --execute "$tmp2" >/dev/null
assert_dir "$tmp2/line-break"

tmp3="$(mktemp_dir)"
cleanup_dirs+=("$tmp3")
mkdir -p "$tmp3/a b" "$tmp3/a-b"
set +e
out3="$("$tool" --execute "$tmp3" 2>&1)"
status3=$?
set -e
[[ $status3 -ne 0 ]] || fail "expected nonzero exit status on conflict"
assert_contains "$out3" "CONFLICT:"
assert_dir "$tmp3/a b"
assert_dir "$tmp3/a-b"

echo "OK"
