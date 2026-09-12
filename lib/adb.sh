#!/bin/sh
# SYNCRO lib/adb.sh — ADB detection, commands, listing, connection, status.
# POSIX sh. ADB binary overridable via ADB_BIN (used by tests for mocks).

if [ "${SYNCRO_ADB_LOADED:-}" = "1" ]; then
    return 0 2>/dev/null || exit 0
fi
SYNCRO_ADB_LOADED=1

: "${ADB_BIN:=adb}"
: "${ADB_DEFAULT_PORT:=5555}"

adb_found() {
    command -v "$ADB_BIN" >/dev/null 2>&1
}

adb_version() {
    "$ADB_BIN" version 2>/dev/null | head -n 1
}

adb_print_missing_help() {
    # Prints distro-specific install guidance to stderr. No auto-install.
    _os_id=""
    if [ -f /etc/os-release ]; then
        # shellcheck disable=SC1091
        _os_id="$(grep '^ID=' /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"' | tr '[:upper:]' '[:lower:]')"
    fi
    printf 'Missing dependency: adb (Android Platform Tools)\n' >&2
    printf '  Why: required to detect and connect to your Android device.\n' >&2
    case "$_os_id" in
        fedora*|rhel*|centos*|rocky*|alma*)
            printf '  Install: sudo dnf install android-tools\n' >&2
            ;;
        ubuntu*|debian*|linuxmint*|pop*)
            printf '  Install: sudo apt update && sudo apt install adb\n' >&2
            ;;
        arch*|manjaro*|endeavour*)
            printf '  Install: sudo pacman -S android-tools\n' >&2
            ;;
        opensuse*)
            printf '  Install: sudo zypper install android-tools\n' >&2
            ;;
        *)
            printf '  Install (Fedora): sudo dnf install android-tools\n' >&2
            printf '  Install (Debian/Ubuntu): sudo apt update && sudo apt install adb\n' >&2
            printf '  Install (Arch): sudo pacman -S android-tools\n' >&2
            ;;
    esac
    printf '  Then re-run: syncro\n' >&2
    unset _os_id
}

adb_devices_raw() {
    # Raw `adb devices` output minus header. Never fails hard (empty on error).
    "$ADB_BIN" devices 2>/dev/null | tail -n +2 | grep -v '^[[:space:]]*$' || true
}

adb_list() {
    # Prints "serial<TAB>status" per attached device (status: device|unauthorized|offline|...).
    adb_devices_raw | awk '{print $1 "\t" $2}' | grep -v '^[[:space:]]*$' || true
}

adb_count() {
    _c="$(adb_list | wc -l | tr -d ' ')"
    printf '%s' "${_c:-0}"
    unset _c
}

adb_status_of() {
    # $1 = serial; prints status or empty + return 1 if not found.
    _so_serial="${1:-}"
    if [ -z "$_so_serial" ]; then
        unset _so_serial
        return 1
    fi
    _so_status="$(adb_list | awk -v s="$_so_serial" '$1==s{print $2; exit}')"
    if [ -z "$_so_status" ]; then
        unset _so_serial _so_status
        return 1
    fi
    printf '%s' "$_so_status"
    unset _so_serial _so_status
    return 0
}

adb_transport_of() {
    # $1 = serial; prints "wifi" or "usb" (heuristic: network serials contain : or .).
    case "${1:-}" in
        *:*|*.*) printf 'wifi' ;;
        *) printf 'usb' ;;
    esac
}

adb_get_model() {
    # $1 = serial; prints model or "unknown". Strips CR.
    _gm_serial="${1:-}"
    if [ -z "$_gm_serial" ]; then
        printf 'unknown'
        unset _gm_serial
        return 1
    fi
    _gm_model="$("$ADB_BIN" -s "$_gm_serial" shell getprop ro.product.model 2>/dev/null | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    if [ -z "$_gm_model" ]; then
        printf 'unknown'
        unset _gm_serial _gm_model
        return 1
    fi
    printf '%s' "$_gm_model"
    unset _gm_serial _gm_model
    return 0
}

adb_get_ip() {
    # $1 = serial; prints first valid IPv4 found via device, return 0/1.
    _gi_serial="${1:-}"
    if [ -z "$_gi_serial" ]; then
        unset _gi_serial
        return 1
    fi
    # Strategy 1: `ip route` → look for "src <ip>".
    _gi_route="$("$ADB_BIN" -s "$_gi_serial" shell ip route 2>/dev/null | tr -d '\r' || true)"
    _gi_ip="$(printf '%s' "$_gi_route" | grep -o 'src [0-9][0-9.]*' 2>/dev/null | head -n1 | awk '{print $2}')"
    if [ -n "$_gi_ip" ]; then
        case "$_gi_ip" in
            127.*) _gi_ip="" ;;
            *) printf '%s' "$_gi_ip"; unset _gi_serial _gi_route _gi_ip; return 0 ;;
        esac
    fi
    # Strategy 2: wlan0 address.
    _gi_wlan="$("$ADB_BIN" -s "$_gi_serial" shell ip -f inet addr show wlan0 2>/dev/null | tr -d '\r' || true)"
    _gi_ip2="$(printf '%s' "$_gi_wlan" | grep -o 'inet [0-9][0-9./]*' 2>/dev/null | head -n1 | awk '{print $2}' | cut -d/ -f1)"
    if [ -n "$_gi_ip2" ]; then
        case "$_gi_ip2" in
            127.*) ;;
            *) printf '%s' "$_gi_ip2"; unset _gi_serial _gi_route _gi_ip _gi_wlan _gi_ip2; return 0 ;;
        esac
    fi
    unset _gi_serial _gi_route _gi_ip _gi_wlan _gi_ip2
    return 1
}

adb_tcpip_enable() {
    # $1 = serial, [$2 = port]; runs `adb -s S tcpip P`.
    _te_serial="${1:-}"
    _te_port="${2:-$ADB_DEFAULT_PORT}"
    if [ -z "$_te_serial" ]; then
        unset _te_serial _te_port
        return 1
    fi
    if "$ADB_BIN" -s "$_te_serial" tcpip "$_te_port" >/dev/null 2>&1; then
        unset _te_serial _te_port
        return 0
    fi
    unset _te_serial _te_port
    return 1
}

adb_connect() {
    # $1 = address (IP:PORT); returns 0 if output contains "connected".
    _cn_addr="${1:-}"
    if [ -z "$_cn_addr" ]; then
        unset _cn_addr
        return 1
    fi
    _cn_out="$("$ADB_BIN" connect "$_cn_addr" 2>&1 || true)"
    case "$_cn_out" in
        *connected*)
            unset _cn_addr _cn_out
            return 0
            ;;
        *)
            unset _cn_addr _cn_out
            return 1
            ;;
    esac
}

adb_disconnect() {
    # $1 = address; best effort.
    _dc_addr="${1:-}"
    [ -n "$_dc_addr" ] || { unset _dc_addr; return 1; }
    "$ADB_BIN" disconnect "$_dc_addr" >/dev/null 2>&1 || true
    unset _dc_addr
    return 0
}

adb_is_connected() {
    # $1 = serial-or-address; true if listed with status "device".
    _ic_s="${1:-}"
    [ -n "$_ic_s" ] || { unset _ic_s; return 1; }
    _ic_st="$(adb_status_of "$_ic_s" || true)"
    if [ "$_ic_st" = "device" ]; then
        unset _ic_s _ic_st
        return 0
    fi
    unset _ic_s _ic_st
    return 1
}
