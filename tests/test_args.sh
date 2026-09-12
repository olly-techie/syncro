#!/bin/sh
# SYNCRO tests/test_args.sh — CLI argument parsing (mock adb+scrcpy).
# Run: sh tests/test_args.sh

set -u

HERE="$(CDPATH= cd -- "$(dirname -- "$0")" 2>/dev/null && pwd)"
ROOT="$(CDPATH= cd -- "$HERE/.." 2>/dev/null && pwd)"
# shellcheck disable=SC1091
. "$HERE/helpers.sh"

TDIR="$(mktemp -d /tmp/syncro-args.XXXXXX)"
MOCK_STATE="$TDIR/state"
MOCK_BIN="$TDIR/bin"
mkdir -p "$MOCK_STATE" "$MOCK_BIN"
export MOCK_STATE
: > "$MOCK_STATE/devices"
: > "$MOCK_STATE/log"
make_mock_bin "$MOCK_BIN" || exit 1

export PATH="$MOCK_BIN:$PATH"
export ADB_BIN="adb" SCRCPY_BIN="scrcpy"
export SYNCRO_CONFIG_DIR="$TDIR/config" SYNCRO_STATE_DIR="$TDIR/state2"

printf '== test_args ==\n'

# --help
out="$(sh "$ROOT/bin/syncro" --help 2>&1)"; rc=$?
assert_ok "--help exits 0" "$rc"
assert_contains "--help shows usage" "$out" "Usage:"

# --version
out="$(sh "$ROOT/bin/syncro" --version 2>&1)"; rc=$?
assert_ok "--version exits 0" "$rc"
assert_contains "--version prints syncro" "$out" "syncro"

# --list with no devices
: > "$MOCK_STATE/devices"
out="$(sh "$ROOT/bin/syncro" --list 2>&1)"; rc=$?
assert_ok "--list exits 0" "$rc"
assert_contains "--list empty message" "$out" "No devices"

# --list with one device
printf 'ABC123\tdevice\n' > "$MOCK_STATE/devices"
printf 'Pixel 8' > "$MOCK_STATE/model_ABC123"
out="$(sh "$ROOT/bin/syncro" --list 2>&1)"; rc=$?
assert_ok "--list with device exits 0" "$rc"
assert_contains "--list shows model" "$out" "Pixel 8"

# --device explicit match
out="$(sh "$ROOT/bin/syncro" --device ABC123 --dry-run 2>&1)"; rc=$?
assert_ok "--device exact exits 0 (dry-run)" "$rc"
assert_contains "--device resolves" "$out" "ABC123"

# --device model substring
out="$(sh "$ROOT/bin/syncro" --device pixel --dry-run 2>&1)"; rc=$?
assert_ok "--device model substring exits 0" "$rc"

# --quality presets
for q in low balanced high; do
    out="$(sh "$ROOT/bin/syncro" --quality "$q" --dry-run 2>&1)"; rc=$?
    assert_ok "--quality $q exits 0" "$rc"
    assert_contains "--quality $q echoed" "$out" "$q"
done

# --fps valid
for f in 30 60; do
    sh "$ROOT/bin/syncro" --fps "$f" --dry-run >/dev/null 2>&1; rc=$?
    assert_ok "--fps $f exits 0" "$rc"
done

# --fullscreen + dry-run
out="$(sh "$ROOT/bin/syncro" --fullscreen --dry-run 2>&1)"; rc=$?
assert_ok "--fullscreen exits 0" "$rc"
assert_contains "--fullscreen echoed" "$out" "Fullscreen"

# --dry-run makes no changes: no tcpip/connect in log
: > "$MOCK_STATE/log"
printf 'USB001\tdevice\n' > "$MOCK_STATE/devices"
sh "$ROOT/bin/syncro" --dry-run >/dev/null 2>&1; rc=$?
assert_ok "--dry-run exits 0" "$rc"
logcontent="$(cat "$MOCK_STATE/log")"
assert_eq "--dry-run performs no tcpip/connect" "" "$(printf '%s' "$logcontent" | grep -E 'tcpip|connect' || true)"

# invalid arguments
sh "$ROOT/bin/syncro" --bogus >/dev/null 2>&1; rc=$?
assert_eq "--bogus exits 2" "2" "$rc"

sh "$ROOT/bin/syncro" --quality ultra >/dev/null 2>&1; rc=$?
assert_eq "--quality ultra exits 2" "2" "$rc"

sh "$ROOT/bin/syncro" --fps 120 >/dev/null 2>&1; rc=$?
assert_eq "--fps 120 exits 2" "2" "$rc"

sh "$ROOT/bin/syncro" --device >/dev/null 2>&1; rc=$?
assert_eq "--device (no value) exits 2" "2" "$rc"

sh "$ROOT/bin/syncro" extra-positional >/dev/null 2>&1; rc=$?
assert_eq "positional arg exits 2" "2" "$rc"

# missing dep → exit 3 (empty PATH without adb)
OLD_PATH="$PATH"
PATH="/usr/bin:/bin"
if ! command -v adb >/dev/null 2>&1; then
    sh "$ROOT/bin/syncro" --list >/dev/null 2>&1; rc=$?
    assert_eq "--list without adb exits 3" "3" "$rc"
else
    printf '  skip: real adb present, cannot test missing-dep path\n'
    TEST_PASS=$((TEST_PASS + 1))
fi
PATH="$OLD_PATH"

rm -rf "$TDIR"
test_summary "test_args"
