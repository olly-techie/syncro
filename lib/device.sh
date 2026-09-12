#!/bin/sh
# SYNCRO lib/device.sh — identification, selection, known-device handling.
# POSIX sh. Expects lib/adb.sh + lib/ui.sh + lib/config.sh sourced first
# (functions degrade gracefully if ui missing).

if [ "${SYNCRO_DEVICE_LOADED:-}" = "1" ]; then
    return 0 2>/dev/null || exit 0
fi
SYNCRO_DEVICE_LOADED=1

device_model() {
    # $1 = serial → model (or "unknown").
    adb_get_model "${1:-}" 2>/dev/null || printf 'unknown'
}

device_transport() {
    # $1 = serial → wifi|usb
    adb_transport_of "${1:-}"
}

device_status() {
    # $1 = serial → device|unauthorized|offline|"" (+rc).
    adb_status_of "${1:-}" || return 1
}

device_human_status() {
    # $1 = raw adb status → human string.
    case "${1:-}" in
        device) printf 'authorized' ;;
        unauthorized) printf 'unauthorized — check phone prompt' ;;
        offline) printf 'offline' ;;
        no-device|"") printf 'disconnected' ;;
        *) printf '%s' "$1" ;;
    esac
}

device_match() {
    # $1 = query (--device value); prints matching serial, rc 0/1.
    # Match order: exact serial → exact address → model substring (case-insensitive).
    _dm_q="${1:-}"
    if [ -z "$_dm_q" ]; then
        unset _dm_q
        return 1
    fi
    # Exact serial/address.
    _dm_hit="$(adb_list | awk -v q="$_dm_q" '$1==q{print $1; exit}')"
    if [ -n "$_dm_hit" ]; then
        printf '%s' "$_dm_hit"
        unset _dm_q _dm_hit
        return 0
    fi
    # Model substring: iterate serials, compare lowercase model.
    _dm_ql="$(printf '%s' "$_dm_q" | tr '[:upper:]' '[:lower:]')"
    _dm_serials="$(adb_list | awk '{print $1}')"
    for _dm_s in $_dm_serials; do
        _dm_m="$(adb_get_model "$_dm_s" 2>/dev/null | tr -d '\r' || printf 'unknown')"
        _dm_ml="$(printf '%s' "$_dm_m" | tr '[:upper:]' '[:lower:]')"
        case "$_dm_ml" in
            *"$_dm_ql"*)
                printf '%s' "$_dm_s"
                unset _dm_q _dm_hit _dm_ql _dm_serials _dm_s _dm_m _dm_ml
                return 0
                ;;
        esac
    done
    unset _dm_q _dm_hit _dm_ql _dm_serials _dm_s _dm_m _dm_ml
    return 1
}

device_count() {
    adb_count
}

device_print_table() {
    # Prints numbered device list to stdout (for --list and selection).
    _pt_i=0
    _pt_list="$(adb_list)"
    if [ -z "$_pt_list" ]; then
        unset _pt_i _pt_list
        return 1
    fi
    printf '%s\n' "$_pt_list" | while IFS="$(printf '\t')" read -r _pt_serial _pt_status; do
        [ -n "$_pt_serial" ] || continue
        _pt_i=$((_pt_i + 1))
        # NOTE: subshell loop — numbering restarts per line in POSIX sh pipeline.
        # We handle numbering in device_select_interactive / --list via awk instead.
        unset _pt_serial _pt_status
    done
    unset _pt_i _pt_list
    return 0
}

device_list_numbered() {
    # Human-readable numbered list: "[1] MODEL / serial / transport / status".
    _ln_i=0
    _ln_list="$(adb_list)"
    if [ -z "$_ln_list" ]; then
        printf 'No devices found.\n'
        unset _ln_i _ln_list
        return 1
    fi
    # Use temp file to avoid subshell counter issue.
    _ln_tmp="/tmp/syncro-devlist.$$"
    printf '%s\n' "$_ln_list" > "$_ln_tmp"
    while IFS="	" read -r _ln_serial _ln_status <&3; do
        [ -n "$_ln_serial" ] || continue
        _ln_i=$((_ln_i + 1))
        _ln_model="$(adb_get_model "$_ln_serial" 2>/dev/null || printf 'unknown')"
        _ln_trans="$(adb_transport_of "$_ln_serial")"
        _ln_human="$(device_human_status "$_ln_status")"
        if [ "$_ln_trans" = "wifi" ]; then
            _ln_conn="Wi-Fi ($_ln_serial)"
        else
            _ln_conn="USB ($_ln_serial)"
        fi
        printf '[%s] %s\n    %s\n    %s\n' "$_ln_i" "$_ln_model" "$_ln_conn" "$_ln_human"
    done 3< "$_ln_tmp"
    rm -f "$_ln_tmp" 2>/dev/null || true
    unset _ln_i _ln_list _ln_tmp _ln_serial _ln_status _ln_model _ln_trans _ln_human _ln_conn
    return 0
}

device_serial_at_index() {
    # $1 = 1-based index → serial.
    _si_idx="${1:-}"
    _si_hit="$(adb_list | awk -v n="$_si_idx" 'NR==n{print $1}')"
    if [ -z "$_si_hit" ]; then
        unset _si_idx _si_hit
        return 1
    fi
    printf '%s' "$_si_hit"
    unset _si_idx _si_hit
    return 0
}

device_select_interactive() {
    # Prints chosen serial. Fails if no devices or bad input or non-interactive.
    _sel_count="$(adb_count)"
    if [ "$_sel_count" = "0" ]; then
        unset _sel_count
        return 1
    fi
    if [ "$_sel_count" = "1" ]; then
        adb_list | awk '{print $1; exit}'
        unset _sel_count
        return 0
    fi
    # Multiple: require TTY or readable stdin.
    if [ ! -t 0 ] && [ -z "${SYNCRO_ALLOW_NON_TTY_SELECT:-}" ]; then
        unset _sel_count
        return 2
    fi
    device_list_numbered >&2
    # Single prompt (read from stdin so tests can pipe input).
    _sel_choice=""
    printf 'Select device: ' >&2
    if IFS= read -r _sel_choice; then
        _sel_choice="$(printf '%s' "$_sel_choice" | tr -d '[:space:]')"
        case "$_sel_choice" in
            ''|*[!0-9]*) unset _sel_count _sel_choice; return 1 ;;
        esac
        if [ "$_sel_choice" -ge 1 ] && [ "$_sel_choice" -le "$_sel_count" ]; then
            device_serial_at_index "$_sel_choice"
            _rc=$?
            unset _sel_count _sel_choice _rc
            return "${_rc:-0}"
        fi
    fi
    unset _sel_count _sel_choice
    return 1
}
