#!/bin/sh
# SYNCRO lib/network.sh — network info, wireless logic, validation.
# POSIX sh. No arbitrary network scanning (only device-provided addresses).

if [ "${SYNCRO_NETWORK_LOADED:-}" = "1" ]; then
    return 0 2>/dev/null || exit 0
fi
SYNCRO_NETWORK_LOADED=1

: "${ADB_DEFAULT_PORT:=5555}"

network_valid_ipv4() {
    # $1 = dotted quad; strict octet 0-255 check.
    _v4="${1:-}"
    case "$_v4" in
        *.*.*.*) ;;
        *) unset _v4; return 1 ;;
    esac
    # Reject non-numeric/chars.
    case "$_v4" in
        *[!0-9.]*) unset _v4; return 1 ;;
    esac
    _v4_o1="$(printf '%s' "$_v4" | cut -d. -f1)"
    _v4_o2="$(printf '%s' "$_v4" | cut -d. -f2)"
    _v4_o3="$(printf '%s' "$_v4" | cut -d. -f3)"
    _v4_o4="$(printf '%s' "$_v4" | cut -d. -f4)"
    _v4_extra="$(printf '%s' "$_v4" | cut -d. -f5)"
    if [ -n "$_v4_extra" ]; then unset _v4 _v4_o1 _v4_o2 _v4_o3 _v4_o4 _v4_extra; return 1; fi
    for _v4_o in "$_v4_o1" "$_v4_o2" "$_v4_o3" "$_v4_o4"; do
        [ -n "$_v4_o" ] || { unset _v4 _v4_o1 _v4_o2 _v4_o3 _v4_o4 _v4_extra _v4_o; return 1; }
        # No leading-zero octal confusion: force decimal, range check.
        case "$_v4_o" in ''|*[!0-9]*) unset _v4 _v4_o1 _v4_o2 _v4_o3 _v4_o4 _v4_extra _v4_o; return 1 ;; esac
        if [ "$_v4_o" -lt 0 ] || [ "$_v4_o" -gt 255 ]; then
            unset _v4 _v4_o1 _v4_o2 _v4_o3 _v4_o4 _v4_extra _v4_o
            return 1
        fi
    done
    unset _v4 _v4_o1 _v4_o2 _v4_o3 _v4_o4 _v4_extra _v4_o
    return 0
}

network_valid_port() {
    # $1 = port 1-65535.
    case "${1:-}" in
        ''|*[!0-9]*) return 1 ;;
    esac
    if [ "$1" -ge 1 ] && [ "$1" -le 65535 ]; then
        return 0
    fi
    return 1
}

network_valid_address() {
    # $1 = IP or IP:PORT.
    _va="${1:-}"
    case "$_va" in
        *:*)
            _va_ip="$(printf '%s' "$_va" | cut -d: -f1)"
            _va_port="$(printf '%s' "$_va" | cut -d: -f2)"
            _va_extra="$(printf '%s' "$_va" | cut -d: -f3)"
            [ -z "$_va_extra" ] || { unset _va _va_ip _va_port _va_extra; return 1; }
            if network_valid_ipv4 "$_va_ip" && network_valid_port "$_va_port"; then
                unset _va _va_ip _va_port _va_extra
                return 0
            fi
            unset _va _va_ip _va_port _va_extra
            return 1
            ;;
        *)
            if network_valid_ipv4 "$_va"; then
                unset _va
                return 0
            fi
            unset _va
            return 1
            ;;
    esac
}

network_normalize_address() {
    # $1 = IP or IP:PORT → prints IP:PORT (default port 5555).
    _na="${1:-}"
    case "$_na" in
        *:*)
            if network_valid_address "$_na"; then
                printf '%s' "$_na"
                unset _na
                return 0
            fi
            unset _na
            return 1
            ;;
        *)
            if network_valid_ipv4 "$_na"; then
                printf '%s:%s' "$_na" "$ADB_DEFAULT_PORT"
                unset _na
                return 0
            fi
            unset _na
            return 1
            ;;
    esac
}

network_setup_wireless_from_usb() {
    # $1 = usb serial, [$2 = port]. Prints wireless address on success.
    # Steps: get IP → tcpip → connect → verify.
    _sw_serial="${1:-}"
    _sw_port="${2:-$ADB_DEFAULT_PORT}"
    if [ -z "$_sw_serial" ]; then
        unset _sw_serial _sw_port
        return 1
    fi
    if ! network_valid_port "$_sw_port"; then
        unset _sw_serial _sw_port
        return 1
    fi
    _sw_ip="$(adb_get_ip "$_sw_serial" || true)"
    if [ -z "$_sw_ip" ]; then
        unset _sw_serial _sw_port _sw_ip
        return 2
    fi
    if ! network_valid_ipv4 "$_sw_ip"; then
        unset _sw_serial _sw_port _sw_ip
        return 2
    fi
    if ! adb_tcpip_enable "$_sw_serial" "$_sw_port"; then
        unset _sw_serial _sw_port _sw_ip
        return 3
    fi
    # Give adbd a moment to restart in tcp mode.
    sleep 2
    _sw_addr="${_sw_ip}:${_sw_port}"
    if adb_connect "$_sw_addr"; then
        # Verify it shows up as device.
        sleep 1
        if adb_is_connected "$_sw_addr"; then
            printf '%s' "$_sw_addr"
            unset _sw_serial _sw_port _sw_ip _sw_addr
            return 0
        fi
    fi
    unset _sw_serial _sw_port _sw_ip _sw_addr
    return 4
}

network_try_known_reconnect() {
    # Tries each known_devices entry via `adb connect`. Prints address on first success.
    if [ ! -f "${SYNCRO_KNOWN_DEVICES_FILE:-}" ]; then
        return 1
    fi
    _kr_tmp="/tmp/syncro-known.$$"
    known_device_list > "$_kr_tmp" 2>/dev/null || { rm -f "$_kr_tmp" 2>/dev/null || true; unset _kr_tmp; return 1; }
    while IFS='|' read -r _kr_serial _kr_addr _kr_model; do
        [ -n "$_kr_addr" ] || continue
        if network_valid_address "$_kr_addr" || network_valid_address "$(network_normalize_address "$_kr_addr" 2>/dev/null || true)"; then
            _kr_norm="$(network_normalize_address "$_kr_addr" 2>/dev/null || printf '%s' "$_kr_addr")"
            if adb_connect "$_kr_norm"; then
                sleep 1
                if adb_is_connected "$_kr_norm" || adb_is_connected "$_kr_serial"; then
                    printf '%s' "$_kr_norm"
                    rm -f "$_kr_tmp" 2>/dev/null || true
                    unset _kr_tmp _kr_serial _kr_addr _kr_model _kr_norm
                    return 0
                fi
            fi
        fi
    done < "$_kr_tmp"
    rm -f "$_kr_tmp" 2>/dev/null || true
    unset _kr_tmp _kr_serial _kr_addr _kr_model _kr_norm
    return 1
}
