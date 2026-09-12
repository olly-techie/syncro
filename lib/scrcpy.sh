#!/bin/sh
# SYNCRO lib/scrcpy.sh — scrcpy detection, command construction, launch.
# POSIX sh. scrcpy binary overridable via SCRCPY_BIN.

if [ "${SYNCRO_SCRCPY_LOADED:-}" = "1" ]; then
    return 0 2>/dev/null || exit 0
fi
SYNCRO_SCRCPY_LOADED=1

: "${SCRCPY_BIN:=scrcpy}"

scrcpy_found() {
    command -v "$SCRCPY_BIN" >/dev/null 2>&1
}

scrcpy_print_missing_help() {
    _s_os=""
    if [ -f /etc/os-release ]; then
        _s_os="$(grep '^ID=' /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"' | tr '[:upper:]' '[:lower:]')"
    fi
    printf 'Missing dependency: scrcpy (screen mirroring engine)\n' >&2
    printf '  Why: performs the actual video mirroring.\n' >&2
    case "$_s_os" in
        fedora*|rhel*|centos*|rocky*|alma*)
            printf '  Install: sudo dnf install scrcpy\n' >&2
            ;;
        ubuntu*|debian*|linuxmint*|pop*)
            printf '  Install: sudo apt update && sudo apt install scrcpy\n' >&2
            ;;
        arch*|manjaro*|endeavour*)
            printf '  Install: sudo pacman -S scrcpy\n' >&2
            ;;
        opensuse*)
            printf '  Install: sudo zypper install scrcpy\n' >&2
            ;;
        *)
            printf '  Install (Fedora): sudo dnf install scrcpy\n' >&2
            printf '  Install (Debian/Ubuntu): sudo apt update && sudo apt install scrcpy\n' >&2
            printf '  Install (Arch): sudo pacman -S scrcpy\n' >&2
            ;;
    esac
    printf '  Then re-run: syncro\n' >&2
    unset _s_os
}

scrcpy_quality_args() {
    # $1 = low|balanced|high → prints scrcpy sizing/bitrate args.
    case "${1:-balanced}" in
        low) printf '%s' "--max-size 1280 --video-bit-rate 4M" ;;
        balanced) printf '%s' "--max-size 1920 --video-bit-rate 8M" ;;
        high) printf '%s' "--max-size 1920 --video-bit-rate 12M" ;;
        *) return 1 ;;
    esac
    return 0
}

scrcpy_default_fps() {
    # $1 = quality → 30|60.
    case "${1:-balanced}" in
        low) printf '30' ;;
        balanced) printf '30' ;;
        high) printf '60' ;;
        *) printf '30'; return 1 ;;
    esac
    return 0
}

scrcpy_build_cmd() {
    # $1=serial $2=quality $3=fps $4=fullscreen(0|1) → prints full command string.
    _bc_serial="${1:-}"
    _bc_quality="${2:-balanced}"
    _bc_fps="${3:-30}"
    _bc_fs="${4:-0}"
    _bc_qargs="$(scrcpy_quality_args "$_bc_quality" || printf '%s' "--max-size 1920 --video-bit-rate 8M")"
    _bc_cmd="$SCRCPY_BIN"
    if [ -n "$_bc_serial" ]; then
        _bc_cmd="$_bc_cmd --serial $_bc_serial"
    fi
    _bc_cmd="$_bc_cmd $_bc_qargs --max-fps $_bc_fps"
    if [ "$_bc_fs" = "1" ]; then
        _bc_cmd="$_bc_cmd --fullscreen"
    fi
    printf '%s' "$_bc_cmd"
    unset _bc_serial _bc_quality _bc_fps _bc_fs _bc_qargs _bc_cmd
    return 0
}

scrcpy_launch() {
    # $1=serial $2=quality $3=fps $4=fullscreen → execs scrcpy (no return on success).
    _sl_serial="${1:-}"
    _sl_quality="${2:-balanced}"
    _sl_fps="${3:-30}"
    _sl_fs="${4:-0}"
    case "$_sl_quality" in
        low) set -- --max-size 1280 --video-bit-rate 4M ;;
        high) set -- --max-size 1920 --video-bit-rate 12M ;;
        *) set -- --max-size 1920 --video-bit-rate 8M ;;
    esac
    # Prepend serial / append fps + fullscreen in a shellcheck-clean way.
    if [ -n "$_sl_serial" ]; then
        set -- --serial "$_sl_serial" "$@"
    fi
    set -- "$@" --max-fps "$_sl_fps"
    if [ "$_sl_fs" = "1" ]; then
        set -- "$@" --fullscreen
    fi
    # shellcheck disable=SC2271
    exec "$SCRCPY_BIN" "$@"
    # exec failed
    unset _sl_serial _sl_quality _sl_fps _sl_fs
    return 127
}
