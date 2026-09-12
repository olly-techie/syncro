#!/bin/sh
# Shared test helpers for SYNCRO mock-based tests (no physical device).
# Sourced by tests/test_*.sh. POSIX sh.
# Provides: assert_eq, assert_ok, assert_fail, make_mock_bin, cleanup.

TEST_PASS=0
TEST_FAIL=0

assert_eq() {
    # $1=label $2=expected $3=actual
    if [ "$2" = "$3" ]; then
        TEST_PASS=$((TEST_PASS + 1))
        printf '  ok: %s\n' "$1"
    else
        TEST_FAIL=$((TEST_FAIL + 1))
        printf '  FAIL: %s\n    expected: [%s]\n    actual:   [%s]\n' "$1" "$2" "$3"
    fi
}

assert_ok() {
    # $1=label $2...=command (run with eval-free "$@"? caller passes rc instead)
    # Usage: some_cmd; assert_ok "label" $?
    _alabel="$1"
    _arc="$2"
    if [ "$_arc" -eq 0 ]; then
        TEST_PASS=$((TEST_PASS + 1))
        printf '  ok: %s\n' "$_alabel"
    else
        TEST_FAIL=$((TEST_FAIL + 1))
        printf '  FAIL: %s (exit %s, want 0)\n' "$_alabel" "$_arc"
    fi
    unset _alabel _arc
}

assert_fail() {
    # $1=label $2=rc (expect non-zero)
    if [ "$2" -ne 0 ]; then
        TEST_PASS=$((TEST_PASS + 1))
        printf '  ok: %s\n' "$1"
    else
        TEST_FAIL=$((TEST_FAIL + 1))
        printf '  FAIL: %s (exit 0, want non-zero)\n' "$1"
    fi
}

assert_contains() {
    # $1=label $2=haystack $3=needle
    case "$2" in
        *"$3"*)
            TEST_PASS=$((TEST_PASS + 1))
            printf '  ok: %s\n' "$1"
            ;;
        *)
            TEST_FAIL=$((TEST_FAIL + 1))
            printf '  FAIL: %s\n    haystack: [%s]\n    missing:  [%s]\n' "$1" "$2" "$3"
            ;;
    esac
}

# make_mock_bin DIR
# Creates DIR/adb + DIR/scrcpy stubs driven by env files:
#   $MOCK_STATE/devices      — lines "SERIAL STATUS" (e.g. "ABC123 device")
#   $MOCK_STATE/model_SERIAL — model string (optional, default TestPhone)
#   $MOCK_STATE/log          — appended call log
#   Flags: MOCK_TCPIP_FAIL=1, MOCK_CONNECT_FAIL=1, MOCK_NO_IP=1
make_mock_bin() {
    _mmd="${1:-}"
    mkdir -p "$_mmd" || return 1
    cat > "$_mmd/adb" <<'STUB'
#!/bin/sh
# Mock adb for syncro tests.
MS="${MOCK_STATE:-/tmp/syncro-mock}"
LOG="$MS/log"
DEVF="$MS/devices"
serial=""
mode="devices"
prev=""
for a in "$@"; do
    if [ "$prev" = "-s" ]; then serial="$a"; prev=""; continue; fi
    case "$a" in
        -s) prev="-s" ;;
        devices|connect|tcpip|disconnect|shell|version|wait-for-device|reconnect) mode="$a" ;;
    esac
done
last="${*: -1:$#}"
log() { printf '%s\n' "$*" >> "$LOG" 2>/dev/null || true; }
case "$mode" in
    version) printf 'Android Debug Bridge version 1.0.41-mock\n'; exit 0 ;;
    devices)
        printf 'List of devices attached\n'
        if [ -f "$DEVF" ]; then cat "$DEVF"; fi
        exit 0 ;;
    shell)
        log "shell $serial $*"
        case "$*" in
            *getprop*)
                mf="$MS/model_$serial"
                if [ -f "$mf" ]; then cat "$mf"; else printf 'TestPhone\n'; fi
                exit 0 ;;
            *"ip route"*)
                if [ "${MOCK_NO_IP:-0}" = "1" ]; then printf '\n'; exit 0; fi
                printf 'default via 192.168.1.1 dev wlan0 proto dhcp src 192.168.1.42 metric 300\n'
                exit 0 ;;
            *"addr show"*)
                if [ "${MOCK_NO_IP:-0}" = "1" ]; then printf '\n'; exit 0; fi
                printf '3: wlan0: <UP> mtu 1500\n    inet 192.168.1.42/24 brd 192.168.1.255 scope global wlan0\n'
                exit 0 ;;
            *) printf '\n'; exit 0 ;;
        esac ;;
    tcpip)
        log "tcpip $serial $*"
        if [ "${MOCK_TCPIP_FAIL:-0}" = "1" ]; then printf 'error\n' >&2; exit 1; fi
        # Simulate device switching to TCP: append wireless entry for its IP.
        printf 'restarting in TCP mode port: %s\n' "$last"
        # If devices file lacks wireless entry, add it (mirrors real adb behavior).
        if [ -f "$DEVF" ]; then
            if ! grep -q '^192\.168\.1\.42:5555' "$DEVF" 2>/dev/null; then
                printf '192.168.1.42:5555\tdevice\n' >> "$DEVF"
            fi
        fi
        exit 0 ;;
    connect)
        log "connect $*"
        if [ "${MOCK_CONNECT_FAIL:-0}" = "1" ]; then printf 'failed to connect to %s\n' "$last"; exit 0; fi
        printf 'connected to %s\n' "$last"
        # Ensure devices file contains the address as device (so verify passes).
        if [ -f "$DEVF" ]; then
            if ! grep -q "^$last" "$DEVF" 2>/dev/null; then
                printf '%s\tdevice\n' "$last" >> "$DEVF"
            fi
        fi
        exit 0 ;;
    disconnect) log "disconnect $*"; printf 'disconnected %s\n' "$last"; exit 0 ;;
    *) printf '\n'; exit 0 ;;
esac
STUB
    chmod +x "$_mmd/adb" || return 1
    cat > "$_mmd/scrcpy" <<'STUB2'
#!/bin/sh
MS="${MOCK_STATE:-/tmp/syncro-mock}"
printf 'scrcpy %s\n' "$*" >> "$MS/log" 2>/dev/null || true
printf 'MOCK scrcpy %s\n' "$*"
exit "${MOCK_SCRCPY_RC:-0}"
STUB2
    chmod +x "$_mmd/scrcpy" || return 1
    unset _mmd
    return 0
}

test_summary() {
    # $1 = suite name
    printf '\n%s: %s passed, %s failed\n' "${1:-suite}" "$TEST_PASS" "$TEST_FAIL"
    if [ "$TEST_FAIL" -ne 0 ]; then
        return 1
    fi
    return 0
}
