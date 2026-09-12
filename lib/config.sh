#!/bin/sh
# SYNCRO lib/config.sh — configuration, known devices, state, validation.
# POSIX sh. Depends on nothing (ui.sh optional for messages).
# Override dirs in tests via SYNCRO_CONFIG_DIR / SYNCRO_STATE_DIR env vars.

if [ "${SYNCRO_CONFIG_LOADED:-}" = "1" ]; then
    return 0 2>/dev/null || exit 0
fi
SYNCRO_CONFIG_LOADED=1

# XDG-compliant defaults.
: "${XDG_CONFIG_HOME:=$HOME/.config}"
: "${XDG_STATE_HOME:=$HOME/.local/state}"
: "${SYNCRO_CONFIG_DIR:=$XDG_CONFIG_HOME/syncro}"
: "${SYNCRO_STATE_DIR:=$XDG_STATE_HOME/syncro}"

SYNCRO_KNOWN_DEVICES_FILE="$SYNCRO_CONFIG_DIR/known_devices"
SYNCRO_LOG_FILE="$SYNCRO_STATE_DIR/syncro.log"

config_init() {
    # Create config + state dirs. Returns 0 on success.
    if ! mkdir -p "$SYNCRO_CONFIG_DIR" 2>/dev/null; then
        return 1
    fi
    if ! mkdir -p "$SYNCRO_STATE_DIR" 2>/dev/null; then
        return 1
    fi
    # Tighten config dir perms (best effort, ignore failure).
    chmod 700 "$SYNCRO_CONFIG_DIR" 2>/dev/null || true
    # Ensure known-devices file exists.
    if [ ! -f "$SYNCRO_KNOWN_DEVICES_FILE" ]; then
        : > "$SYNCRO_KNOWN_DEVICES_FILE" 2>/dev/null || return 1
    fi
    return 0
}

config_known_file() {
    printf '%s' "$SYNCRO_KNOWN_DEVICES_FILE"
}

config_validate_quality() {
    # $1 = value; echoes normalized value, returns 0/1.
    case "${1:-}" in
        low|balanced|high)
            printf '%s' "$1"
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

config_validate_fps() {
    # $1 = value; echoes normalized value, returns 0/1.
    case "${1:-}" in
        30|60)
            printf '%s' "$1"
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

known_device_save() {
    # $1 = usb-or-device serial, $2 = wireless address (IP:PORT), [$3 = model]
    _ks_serial="${1:-}"
    _ks_addr="${2:-}"
    _ks_model="${3:-unknown}"
    if [ -z "$_ks_serial" ] || [ -z "$_ks_addr" ]; then
        unset _ks_serial _ks_addr _ks_model
        return 1
    fi
    # Delimiter is '|'. Strip delimiters/newlines from fields.
    _ks_serial="$(printf '%s' "$_ks_serial" | tr -d '|[:cntrl:]')"
    _ks_addr="$(printf '%s' "$_ks_addr" | tr -d '|[:cntrl:]')"
    _ks_model="$(printf '%s' "$_ks_model" | tr -d '|[:cntrl:]')"
    [ -n "$_ks_serial" ] || { unset _ks_serial _ks_addr _ks_model; return 1; }
    [ -n "$_ks_addr" ] || { unset _ks_serial _ks_addr _ks_model; return 1; }

    if [ ! -f "$SYNCRO_KNOWN_DEVICES_FILE" ]; then
        : > "$SYNCRO_KNOWN_DEVICES_FILE" 2>/dev/null || { unset _ks_serial _ks_addr _ks_model; return 1; }
    fi
    # Remove any existing entry for this serial or address, then append.
    _ks_tmp="$SYNCRO_KNOWN_DEVICES_FILE.tmp.$$"
    grep -v "^${_ks_serial}|" "$SYNCRO_KNOWN_DEVICES_FILE" 2>/dev/null | grep -v "|${_ks_addr}|" > "$_ks_tmp" 2>/dev/null || true
    printf '%s|%s|%s\n' "$_ks_serial" "$_ks_addr" "$_ks_model" >> "$_ks_tmp"
    if mv "$_ks_tmp" "$SYNCRO_KNOWN_DEVICES_FILE" 2>/dev/null; then
        chmod 600 "$SYNCRO_KNOWN_DEVICES_FILE" 2>/dev/null || true
        unset _ks_serial _ks_addr _ks_model _ks_tmp
        return 0
    fi
    rm -f "$_ks_tmp" 2>/dev/null || true
    unset _ks_serial _ks_addr _ks_model _ks_tmp
    return 1
}

known_device_lookup_serial() {
    # $1 = serial; prints wireless address, returns 0 if found.
    _kl_serial="${1:-}"
    [ -n "$_kl_serial" ] || { unset _kl_serial; return 1; }
    if [ ! -f "$SYNCRO_KNOWN_DEVICES_FILE" ]; then
        unset _kl_serial
        return 1
    fi
    _kl_line="$(grep -m1 "^${_kl_serial}|" "$SYNCRO_KNOWN_DEVICES_FILE" 2>/dev/null || true)"
    if [ -z "$_kl_line" ]; then
        unset _kl_serial _kl_line
        return 1
    fi
    printf '%s' "$_kl_line" | cut -d'|' -f2
    unset _kl_serial _kl_line
    return 0
}

known_device_lookup_address() {
    # $1 = address; prints serial, returns 0 if found.
    _ka_addr="${1:-}"
    [ -n "$_ka_addr" ] || { unset _ka_addr; return 1; }
    if [ ! -f "$SYNCRO_KNOWN_DEVICES_FILE" ]; then
        unset _ka_addr
        return 1
    fi
    _ka_line="$(grep -m1 "|${_ka_addr}|" "$SYNCRO_KNOWN_DEVICES_FILE" 2>/dev/null || true)"
    if [ -z "$_ka_line" ]; then
        unset _ka_addr _ka_line
        return 1
    fi
    printf '%s' "$_ka_line" | cut -d'|' -f1
    unset _ka_addr _ka_line
    return 0
}

known_device_list() {
    # Prints all non-empty, non-comment lines.
    if [ ! -f "$SYNCRO_KNOWN_DEVICES_FILE" ]; then
        return 1
    fi
    grep -v '^[[:space:]]*#' "$SYNCRO_KNOWN_DEVICES_FILE" 2>/dev/null | grep -v '^[[:space:]]*$' || return 1
    return 0
}

config_log() {
    # $1 = message; best-effort append to state log.
    _log_msg="${1:-}"
    [ -n "$_log_msg" ] || { unset _log_msg; return 0; }
    mkdir -p "$SYNCRO_STATE_DIR" 2>/dev/null || { unset _log_msg; return 0; }
    printf '%s %s\n' "$(date '+%Y-%m-%dT%H:%M:%S' 2>/dev/null || printf 'unknown-time')" "$_log_msg" >> "$SYNCRO_LOG_FILE" 2>/dev/null || true
    unset _log_msg
    return 0
}
