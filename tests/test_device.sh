#!/bin/sh
# SYNCRO tests/test_device.sh — device states via mocked adb.
# Run: sh tests/test_device.sh

set -u

HERE="$(CDPATH= cd -- "$(dirname -- "$0")" 2>/dev/null && pwd)"
ROOT="$(CDPATH= cd -- "$HERE/.." 2>/dev/null && pwd)"
# shellcheck disable=SC1091
. "$HERE/helpers.sh"
# shellcheck disable=SC1091
. "$ROOT/lib/adb.sh"
# shellcheck disable=SC1091
. "$ROOT/lib/config.sh"
# shellcheck disable=SC1091
. "$ROOT/lib/device.sh"

TDIR="$(mktemp -d /tmp/syncro-dev.XXXXXX)"
MOCK_STATE="$TDIR/state"
MOCK_BIN="$TDIR/bin"
mkdir -p "$MOCK_STATE" "$MOCK_BIN"
export MOCK_STATE
: > "$MOCK_STATE/log"
make_mock_bin "$MOCK_BIN" || exit 1
export PATH="$MOCK_BIN:$PATH"
export ADB_BIN="adb"
export SYNCRO_CONFIG_DIR="$TDIR/cfg" SYNCRO_STATE_DIR="$TDIR/st"
SYNCRO_KNOWN_DEVICES_FILE="$SYNCRO_CONFIG_DIR/known_devices"
export SYNCRO_KNOWN_DEVICES_FILE
mkdir -p "$SYNCRO_CONFIG_DIR" "$SYNCRO_STATE_DIR"
: > "$SYNCRO_KNOWN_DEVICES_FILE"

printf '== test_device ==\n'

set_devices() {
    # $1 = content with \n escapes interpreted via printf
    printf '%b' "${1:-}" > "$MOCK_STATE/devices"
}

# no device
set_devices ""
assert_eq "no device count=0" "0" "$(adb_count)"
adb_status_of "ANY" >/dev/null 2>&1; assert_fail "no device status lookup fails" "$?"

# authorized USB device
set_devices "ABC123\tdevice\n"
printf 'TECNO KM4' > "$MOCK_STATE/model_ABC123"
assert_eq "usb count=1" "1" "$(adb_count)"
assert_eq "usb status=device" "device" "$(adb_status_of "ABC123")"
assert_eq "usb transport=usb" "usb" "$(adb_transport_of "ABC123")"
assert_eq "usb model" "TECNO KM4" "$(adb_get_model "ABC123")"
assert_eq "usb human status" "authorized" "$(device_human_status "device")"
assert_eq "usb match exact" "ABC123" "$(device_match "ABC123")"
assert_eq "usb match model substring" "ABC123" "$(device_match "tecno")"

# authorized Wi-Fi device
set_devices "192.168.1.42:5555\tdevice\n"
printf 'Pixel 8' > "$MOCK_STATE/model_192.168.1.42:5555"
assert_eq "wifi transport=wifi" "wifi" "$(adb_transport_of "192.168.1.42:5555")"
assert_eq "wifi status=device" "device" "$(adb_status_of "192.168.1.42:5555")"
assert_eq "wifi match address" "192.168.1.42:5555" "$(device_match "192.168.1.42:5555")"

# unauthorized device
set_devices "XYZ999\tunauthorized\n"
assert_eq "unauthorized status" "unauthorized" "$(adb_status_of "XYZ999")"
assert_contains "unauthorized human" "$(device_human_status "unauthorized")" "unauthorized"

# offline device
set_devices "OFF123\toffline\n"
assert_eq "offline status" "offline" "$(adb_status_of "OFF123")"

# multiple devices
set_devices "AAA111\tdevice\nBBB222\tdevice\n"
printf 'Phone A' > "$MOCK_STATE/model_AAA111"
printf 'Phone B' > "$MOCK_STATE/model_BBB222"
assert_eq "multiple count=2" "2" "$(adb_count)"
assert_eq "index 1" "AAA111" "$(device_serial_at_index 1)"
assert_eq "index 2" "BBB222" "$(device_serial_at_index 2)"
device_serial_at_index 3 >/dev/null 2>&1; assert_fail "index 3 fails" "$?"
# interactive select with piped input (SYNCRO_ALLOW_NON_TTY_SELECT bypasses TTY check)
out="$(printf '2\n' | SYNCRO_ALLOW_NON_TTY_SELECT=1 device_select_interactive 2>/dev/null)"; rc=$?
assert_ok "interactive select rc" "$rc"
assert_eq "interactive select picks 2" "BBB222" "$out"
# bad input
printf '9\n' | SYNCRO_ALLOW_NON_TTY_SELECT=1 device_select_interactive >/dev/null 2>&1; assert_fail "select out-of-range fails" "$?"
printf 'abc\n' | SYNCRO_ALLOW_NON_TTY_SELECT=1 device_select_interactive >/dev/null 2>&1; assert_fail "select non-numeric fails" "$?"

# unknown device query
device_match "NOPE-NOT-HERE" >/dev/null 2>&1; assert_fail "match unknown fails" "$?"

# same phone via USB + Wi-Fi collapses to one (known mapping)
set_devices "USB001\tdevice\n192.168.19.195:5555\tdevice\n"
printf 'MyPhone' > "$MOCK_STATE/model_USB001"
printf 'MyPhone' > "$MOCK_STATE/model_192.168.19.195:5555"
printf 'USB001|192.168.19.195:5555|MyPhone\n' > "$SYNCRO_KNOWN_DEVICES_FILE"
assert_eq "dual physical count=1" "1" "$(device_physical_count)"
assert_eq "dual prefers wifi" "192.168.19.195:5555" "$(device_preferred_serial)"
assert_eq "dual index maps to wifi" "192.168.19.195:5555" "$(device_serial_at_index 1)"
assert_contains "dual list merged" "$(device_list_numbered)" "USB + Wi-Fi"
out="$(device_select_interactive 2>/dev/null)"; rc=$?
assert_ok "dual auto-select rc" "$rc"
assert_eq "dual auto-select picks wifi, no prompt" "192.168.19.195:5555" "$out"

# same phone via USB + Wi-Fi without known file (IP fallback)
: > "$SYNCRO_KNOWN_DEVICES_FILE"
MOCK_ROUTE_DUAL=1; export MOCK_ROUTE_DUAL
assert_eq "ip-fallback physical count=1" "1" "$(device_physical_count)"
assert_eq "ip-fallback prefers wifi" "192.168.19.195:5555" "$(device_preferred_serial)"
unset MOCK_ROUTE_DUAL

# two distinct phones stay separate
: > "$SYNCRO_KNOWN_DEVICES_FILE"
set_devices "AAA111\tdevice\nBBB222\tdevice\n"
assert_eq "distinct physical count=2" "2" "$(device_physical_count)"
assert_eq "distinct index 1" "AAA111" "$(device_serial_at_index 1)"
assert_eq "distinct index 2" "BBB222" "$(device_serial_at_index 2)"

rm -rf "$TDIR"
test_summary "test_device"
