#!/bin/sh
# SYNCRO tests/test_network.sh — validation + wireless setup with mocked adb.
# Run: sh tests/test_network.sh

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
. "$ROOT/lib/network.sh"

TDIR="$(mktemp -d /tmp/syncro-net.XXXXXX)"
MOCK_STATE="$TDIR/state"
MOCK_BIN="$TDIR/bin"
mkdir -p "$MOCK_STATE" "$MOCK_BIN"
export MOCK_STATE
: > "$MOCK_STATE/log"
make_mock_bin "$MOCK_BIN" || exit 1
export PATH="$MOCK_BIN:$PATH"
export ADB_BIN="adb"
export SYNCRO_CONFIG_DIR="$TDIR/config" SYNCRO_STATE_DIR="$TDIR/state2"
SYNCRO_KNOWN_DEVICES_FILE="$SYNCRO_CONFIG_DIR/known_devices"
export SYNCRO_KNOWN_DEVICES_FILE
mkdir -p "$SYNCRO_CONFIG_DIR" "$SYNCRO_STATE_DIR"
: > "$SYNCRO_KNOWN_DEVICES_FILE"

printf '== test_network ==\n'

# --- validation ---
network_valid_ipv4 "192.168.1.42"; assert_ok "valid ipv4" "$?"
network_valid_ipv4 "999.1.1.1" >/dev/null 2>&1; assert_fail "octet >255 rejected" "$?"
network_valid_ipv4 "abc.def.ghi.jkl" >/dev/null 2>&1; assert_fail "non-numeric rejected" "$?"
network_valid_ipv4 "192.168.1" >/dev/null 2>&1; assert_fail "3-octet rejected" "$?"
network_valid_ipv4 "" >/dev/null 2>&1; assert_fail "empty rejected" "$?"
network_valid_address "192.168.1.42:5555"; assert_ok "valid addr" "$?"
network_valid_address "192.168.1.42"; assert_ok "bare ip valid" "$?"
network_valid_address "999.1.1.1:5555" >/dev/null 2>&1; assert_fail "bad ip rejected" "$?"
network_valid_address "192.168.1.42:99999" >/dev/null 2>&1; assert_fail "bad port rejected" "$?"
network_valid_address "not-an-address" >/dev/null 2>&1; assert_fail "garbage rejected" "$?"
assert_eq "normalize bare ip" "192.168.1.10:5555" "$(network_normalize_address "192.168.1.10")"
assert_eq "normalize keeps port" "192.168.1.10:7777" "$(network_normalize_address "192.168.1.10:7777")"
network_normalize_address "garbage" >/dev/null 2>&1; assert_fail "normalize garbage fails" "$?"

# --- valid wireless setup from USB ---
printf 'USB001\tdevice\n' > "$MOCK_STATE/devices"
unset MOCK_TCPIP_FAIL MOCK_CONNECT_FAIL MOCK_NO_IP
addr="$(network_setup_wireless_from_usb "USB001" 5555 2>/dev/null)"; rc=$?
assert_ok "wireless setup succeeds" "$rc"
assert_eq "wireless addr" "192.168.1.42:5555" "$addr"
assert_contains "tcpip was invoked" "$(cat "$MOCK_STATE/log")" "tcpip"
assert_contains "connect was invoked" "$(cat "$MOCK_STATE/log")" "connect"

# --- failed tcpip ---
: > "$MOCK_STATE/log"
printf 'USB002\tdevice\n' > "$MOCK_STATE/devices"
MOCK_TCPIP_FAIL=1; export MOCK_TCPIP_FAIL
network_setup_wireless_from_usb "USB002" 5555 >/dev/null 2>&1; assert_fail "tcpip failure propagates" "$?"
unset MOCK_TCPIP_FAIL

# --- unreachable device (connect fails) ---
: > "$MOCK_STATE/log"
printf 'USB003\tdevice\n' > "$MOCK_STATE/devices"
MOCK_CONNECT_FAIL=1; export MOCK_CONNECT_FAIL
network_setup_wireless_from_usb "USB003" 5555 >/dev/null 2>&1; assert_fail "connect failure propagates" "$?"
unset MOCK_CONNECT_FAIL

# --- no IP available ---
: > "$MOCK_STATE/log"
printf 'USB004\tdevice\n' > "$MOCK_STATE/devices"
MOCK_NO_IP=1; export MOCK_NO_IP
network_setup_wireless_from_usb "USB004" 5555 >/dev/null 2>&1; assert_fail "missing IP fails gracefully" "$?"
unset MOCK_NO_IP

# --- dual-transport: cellular + Wi-Fi must prefer Wi-Fi ---
: > "$MOCK_STATE/log"
printf 'USB005\tdevice\n' > "$MOCK_STATE/devices"
MOCK_ROUTE_DUAL=1; export MOCK_ROUTE_DUAL
dual_ip="$(adb_get_ip "USB005" 2>/dev/null)"; rc=$?
assert_ok "dual-transport get_ip succeeds" "$rc"
assert_eq "dual-transport prefers wlan0" "192.168.19.195" "$dual_ip"
dual_addr="$(network_setup_wireless_from_usb "USB005" 5555 2>/dev/null)"; rc=$?
assert_ok "dual-transport wireless setup succeeds" "$rc"
assert_eq "dual-transport wireless addr" "192.168.19.195:5555" "$dual_addr"
unset MOCK_ROUTE_DUAL

# --- malformed address connect ---
adb_connect "not-an-address" >/dev/null 2>&1
# mock stub would "connect" to anything; guard is validation layer:
network_valid_address "not-an-address" >/dev/null 2>&1; assert_fail "malformed addr rejected by validator" "$?"

# --- known-device reconnect ---
printf 'OLD123|192.168.1.77:5555|Old Phone\n' > "$SYNCRO_KNOWN_DEVICES_FILE"
: > "$MOCK_STATE/devices"
unset MOCK_CONNECT_FAIL
addr2="$(network_try_known_reconnect 2>/dev/null)"; rc=$?
assert_ok "known reconnect succeeds" "$rc"
assert_eq "known reconnect addr" "192.168.1.77:5555" "$addr2"

# known reconnect with unreachable host
MOCK_CONNECT_FAIL=1; export MOCK_CONNECT_FAIL
: > "$MOCK_STATE/devices"
network_try_known_reconnect >/dev/null 2>&1; assert_fail "known reconnect failure propagates" "$?"
unset MOCK_CONNECT_FAIL

rm -rf "$TDIR"
test_summary "test_network"
