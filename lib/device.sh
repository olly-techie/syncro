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

device_canonical_id() {
    # $1 = serial → canonical physical-device id.
    # Wi-Fi entries map back to their USB serial via known_devices; USB
    # entries map to themselves. Lets USB+Wi-Fi rows for one phone collapse.
    _ci_s="${1:-}"
    if [ -z "$_ci_s" ]; then
        unset _ci_s
        return 1
    fi
    case "$(adb_transport_of "$_ci_s")" in
        wifi)
            _ci_usb="$(known_device_lookup_address "$_ci_s" 2>/dev/null || true)"
            if [ -n "$_ci_usb" ]; then
                printf '%s' "$_ci_usb"
            else
                printf '%s' "$_ci_s"
            fi
            unset _ci_s _ci_usb
            return 0
            ;;
        *)
            printf '%s' "$_ci_s"
            unset _ci_s
            return 0
            ;;
    esac
}

device_wifi_for_usb() {
    # $1 = USB serial → Wi-Fi address currently in `adb devices`, if any.
    # Prefers known_devices mapping, falls back to matching the USB device's
    # Wi-Fi IP against attached Wi-Fi entries (works before first save).
    _wu_usb="${1:-}"
    [ -n "$_wu_usb" ] || { unset _wu_usb; return 1; }
    _wu_known="$(known_device_lookup_serial "$_wu_usb" 2>/dev/null || true)"
    if [ -n "$_wu_known" ]; then
        if adb_status_of "$_wu_known" >/dev/null 2>&1; then
            printf '%s' "$_wu_known"
            unset _wu_usb _wu_known
            return 0
        fi
    fi
    _wu_ip="$(adb_get_ip "$_wu_usb" 2>/dev/null || true)"
    if [ -n "$_wu_ip" ]; then
        for _wu_cand in $(adb_list 2>/dev/null | awk '{print $1}'); do
            case "$(adb_transport_of "$_wu_cand")" in
                wifi)
                    _wu_cip="$(printf '%s' "$_wu_cand" | cut -d: -f1)"
                    if [ "$_wu_cip" = "$_wu_ip" ]; then
                        if adb_is_connected "$_wu_cand" 2>/dev/null; then
                            printf '%s' "$_wu_cand"
                            unset _wu_usb _wu_known _wu_ip _wu_cand _wu_cip
                            return 0
                        fi
                    fi
                    unset _wu_cip
                    ;;
            esac
        done
        unset _wu_cand
    fi
    unset _wu_usb _wu_known _wu_ip
    return 1
}

device_physical_count() {
    # Number of distinct physical devices (USB+Wi-Fi aliases merged).
    _pc_list="$(adb_list 2>/dev/null || true)"
    if [ -z "$_pc_list" ]; then
        printf '0'
        unset _pc_list
        return 0
    fi
    _pc_n=0
    _pc_seen=""
    for _pc_s in $(printf '%s\n' "$_pc_list" | awk '{print $1}'); do
        _pc_c="$(device_canonical_id "$_pc_s" 2>/dev/null || printf '%s' "$_pc_s")"
        # IP fallback: USB whose Wi-Fi alias is attached shares canonical id.
        if [ "$(adb_transport_of "$_pc_s")" = "usb" ]; then
            _pc_w="$(device_wifi_for_usb "$_pc_s" 2>/dev/null || true)"
            if [ -n "$_pc_w" ]; then
                _pc_c="$_pc_s"
            fi
        fi
        case " $_pc_seen " in
            *" $_pc_c "*) ;;
            *) _pc_seen="$_pc_seen $_pc_c"; _pc_n=$((_pc_n + 1)) ;;
        esac
        # Mark Wi-Fi alias as seen so it doesn't double-count.
        if [ "$(adb_transport_of "$_pc_s")" = "usb" ]; then
            _pc_w2="$(device_wifi_for_usb "$_pc_s" 2>/dev/null || true)"
            if [ -n "$_pc_w2" ]; then
                case " $_pc_seen " in
                    *" $_pc_w2 "*) ;;
                    *) _pc_seen="$_pc_seen $_pc_w2" ;;
                esac
            fi
            unset _pc_w2
        fi
        unset _pc_s _pc_c _pc_w
    done
    printf '%s' "$_pc_n"
    unset _pc_list _pc_n _pc_seen
    return 0
}

device_preferred_serial() {
    # When all attached rows belong to one physical phone, prints the serial
    # to use (Wi-Fi address when connected, else the sole entry). Fails when
    # there are 0 or 2+ physical devices.
    if [ "$(device_physical_count)" != "1" ]; then
        return 1
    fi
    _ps_list="$(adb_list 2>/dev/null || true)"
    # Prefer a connected Wi-Fi entry (wireless mirroring, no prompt).
    _ps_wifi="$(printf '%s\n' "$_ps_list" | awk '$2=="device"{print $1}' | while read -r _w; do
        [ -n "$_w" ] || continue
        if [ "$(adb_transport_of "$_w")" = "wifi" ]; then printf '%s\n' "$_w"; break; fi
    done)"
    if [ -n "$_ps_wifi" ] && adb_is_connected "$_ps_wifi" 2>/dev/null; then
        printf '%s' "$_ps_wifi"
        unset _ps_list _ps_wifi
        return 0
    fi
    # Single USB row (or non-device state): return first row.
    _ps_first="$(printf '%s\n' "$_ps_list" | awk '{print $1; exit}')"
    if [ -n "$_ps_first" ]; then
        printf '%s' "$_ps_first"
        unset _ps_list _ps_wifi _ps_first
        return 0
    fi
    unset _ps_list _ps_wifi _ps_first
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

_device_grouped_rows() {
    # Prints one line per physical device:
    #   preferred_serial|model|conn_display|human_status
    # USB+Wi-Fi aliases for one phone collapse to a single row preferring Wi-Fi.
    _gr_list="$(adb_list 2>/dev/null || true)"
    [ -n "$_gr_list" ] || { unset _gr_list; return 1; }
    _gr_consumed=" "
    for _gr_s in $(printf '%s\n' "$_gr_list" | awk '{print $1}'); do
        [ -n "$_gr_s" ] || continue
        [ "$(adb_transport_of "$_gr_s")" = "usb" ] || continue
        _gr_st="$(adb_status_of "$_gr_s" 2>/dev/null || printf '')"
        _gr_model="$(adb_get_model "$_gr_s" 2>/dev/null || printf 'unknown')"
        [ -n "$_gr_model" ] || _gr_model="unknown"
        _gr_w="$(device_wifi_for_usb "$_gr_s" 2>/dev/null || true)"
        if [ -n "$_gr_w" ]; then
            _gr_wst="$(adb_status_of "$_gr_w" 2>/dev/null || printf '')"
            _gr_wmodel="$(adb_get_model "$_gr_w" 2>/dev/null || true)"
            [ -n "$_gr_wmodel" ] || _gr_wmodel="$_gr_model"
            # Prefer Wi-Fi model name when USB model unknown.
            if [ "$_gr_model" = "unknown" ]; then _gr_model="$_gr_wmodel"; fi
            if [ "$_gr_wst" = "device" ]; then
                _gr_human="$(device_human_status device)"
                _gr_pref="$_gr_w"
            elif [ "$_gr_st" = "device" ]; then
                _gr_human="$(device_human_status device)"
                _gr_pref="$_gr_w"
            else
                _gr_human="$(device_human_status "$_gr_st")"
                _gr_pref="$_gr_w"
            fi
            printf '%s|%s|USB + Wi-Fi (%s)|%s\n' "$_gr_pref" "$_gr_model" "$_gr_w" "$_gr_human"
            _gr_consumed="$_gr_consumed$_gr_s $_gr_w "
        else
            _gr_human="$(device_human_status "$_gr_st")"
            printf '%s|%s|USB (%s)|%s\n' "$_gr_s" "$_gr_model" "$_gr_s" "$_gr_human"
            _gr_consumed="$_gr_consumed$_gr_s "
        fi
        unset _gr_s _gr_st _gr_model _gr_w _gr_wst _gr_wmodel _gr_human _gr_pref
    done
    # Orphan Wi-Fi rows (no USB owner attached).
    for _gr_s in $(printf '%s\n' "$_gr_list" | awk '{print $1}'); do
        [ -n "$_gr_s" ] || continue
        [ "$(adb_transport_of "$_gr_s")" = "wifi" ] || continue
        case "$_gr_consumed" in
            *" $_gr_s "*) continue ;;
        esac
        _gr_st="$(adb_status_of "$_gr_s" 2>/dev/null || printf '')"
        _gr_model="$(adb_get_model "$_gr_s" 2>/dev/null || printf 'unknown')"
        [ -n "$_gr_model" ] || _gr_model="unknown"
        _gr_human="$(device_human_status "$_gr_st")"
        printf '%s|%s|Wi-Fi (%s)|%s\n' "$_gr_s" "$_gr_model" "$_gr_s" "$_gr_human"
        unset _gr_s _gr_st _gr_model _gr_human
    done
    unset _gr_list _gr_consumed
    return 0
}

device_list_numbered() {
    # Human-readable numbered list, one row per physical phone.
    # Same phone via USB+Wi-Fi shows once as "USB + Wi-Fi (address)".
    _ln_rows="$(_device_grouped_rows 2>/dev/null || true)"
    if [ -z "$_ln_rows" ]; then
        if [ -z "$(adb_list 2>/dev/null || true)" ]; then
            printf 'No devices found.\n'
        else
            printf 'No devices found.\n'
        fi
        unset _ln_rows
        return 1
    fi
    _ln_i=0
    printf '%s\n' "$_ln_rows" | while IFS='|' read -r _ln_pref _ln_model _ln_conn _ln_human; do
        [ -n "$_ln_pref" ] || continue
        _ln_i=$((_ln_i + 1))
        printf '[%s] %s\n    %s\n    %s\n' "$_ln_i" "$_ln_model" "$_ln_conn" "$_ln_human"
    done
    # NOTE: pipeline subshell loses counter; exit status is what matters.
    unset _ln_rows _ln_i _ln_pref _ln_model _ln_conn _ln_human
    return 0
}

device_serial_at_index() {
    # $1 = 1-based physical index → preferred serial (Wi-Fi when paired).
    _si_idx="${1:-}"
    _si_row="$(_device_grouped_rows 2>/dev/null | awk -v n="$_si_idx" -F'|' 'NR==n{print $1}')"
    if [ -z "$_si_row" ]; then
        unset _si_idx _si_row
        return 1
    fi
    printf '%s' "$_si_row"
    unset _si_idx _si_row
    return 0
}

device_select_interactive() {
    # Prints chosen serial. Auto-resolves single physical phone (even when
    # adb shows USB+Wi-Fi rows). Prompts only for 2+ physical devices.
    _sel_count="$(device_physical_count)"
    if [ "$_sel_count" = "0" ]; then
        unset _sel_count
        return 1
    fi
    if [ "$_sel_count" = "1" ]; then
        device_preferred_serial
        _rc=$?
        unset _sel_count _rc
        return "${_rc:-0}"
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
