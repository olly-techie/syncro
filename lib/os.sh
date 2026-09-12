#!/bin/sh
# SYNCRO lib/os.sh — distro detection + suitable setup commands.
# POSIX sh. Single source of truth for "which commands install adb/scrcpy
# on this distro". Used by lib/adb.sh, lib/scrcpy.sh, install.sh.
#
# Test hooks (env overrides):
#   SYNCRO_OS_ID       — pretend to be this distro ID (e.g. fedora, ubuntu)
#   OS_RELEASE_FILE    — read os-release data from this file instead of /etc/os-release

if [ "${SYNCRO_OS_LOADED:-}" = "1" ]; then
    return 0 2>/dev/null || exit 0
fi
SYNCRO_OS_LOADED=1

: "${OS_RELEASE_FILE:=/etc/os-release}"

_os_field() {
    # $1 = FIELD name (ID or ID_LIKE); prints lowercased, unquoted value.
    _of_file="${OS_RELEASE_FILE:-/etc/os-release}"
    if [ -n "${SYNCRO_OS_ID:-}" ] && [ "$1" = "ID" ]; then
        printf '%s' "$SYNCRO_OS_ID" | tr '[:upper:]' '[:lower:]'
        unset _of_file
        return 0
    fi
    if [ -f "$_of_file" ]; then
        grep "^$1=" "$_of_file" 2>/dev/null | head -n1 | cut -d= -f2- | tr -d '"' | tr '[:upper:]' '[:lower:]'
        unset _of_file
        return 0
    fi
    unset _of_file
    return 1
}

os_id() {
    # Prints distro ID (e.g. fedora, ubuntu, arch) or "unknown".
    _oid="$(_os_field ID || true)"
    if [ -z "$_oid" ]; then
        printf 'unknown'
    else
        printf '%s' "$_oid"
    fi
    unset _oid
    return 0
}

os_family() {
    # Prints package-manager family: dnf|apt|pacman|zypper|emerge|apk|unknown.
    # Matches ID first, then ID_LIKE (covers derivatives like Mint, Pop, Nobara).
    _fam_id="$(_os_field ID || true)"
    _fam_like="$(_os_field ID_LIKE || true)"
    _fam_all=" $_fam_id $_fam_like "
    case "$_fam_all" in
        *" fedora "*|*" rhel "*|*" centos "*|*" rocky "*|*" alma"*|*" nobara "*|*" ultramarine "*)
            printf 'dnf' ;;
        *" debian "*|*" ubuntu "*|*" linuxmint "*|*" pop "*|*" zorin "*|*" elementary "*|*" raspbian "*|*" kali "*|*" tuxedo "*)
            printf 'apt' ;;
        *" arch "*|*" manjaro "*|*" endeavour "*|*" cachyos "*|*" garuda "*)
            printf 'pacman' ;;
        *" opensuse"*|*" suse"*|*" sles"*)
            printf 'zypper' ;;
        *" gentoo "*)
            printf 'emerge' ;;
        *" alpine "*)
            printf 'apk' ;;
        *)
            printf 'unknown' ;;
    esac
    unset _fam_id _fam_like _fam_all
    return 0
}

os_adb_install_cmd() {
    # Prints the suitable adb install command for this distro. rc 1 if unknown.
    case "$(os_family)" in
        dnf) printf 'sudo dnf install android-tools' ;;
        apt) printf 'sudo apt update && sudo apt install adb' ;;
        pacman) printf 'sudo pacman -S android-tools' ;;
        zypper) printf 'sudo zypper install android-tools' ;;
        emerge) printf 'sudo emerge -av dev-util/android-tools' ;;
        apk) printf 'sudo apk add android-tools' ;;
        *) return 1 ;;
    esac
    return 0
}

os_scrcpy_install_cmd() {
    # Prints the suitable scrcpy install command for this distro. rc 1 if unknown.
    case "$(os_family)" in
        dnf) printf 'sudo dnf copr enable zeno/scrcpy && sudo dnf install scrcpy' ;;
        apt) printf 'sudo apt update && sudo apt install scrcpy' ;;
        pacman) printf 'sudo pacman -S scrcpy' ;;
        zypper) printf 'sudo zypper install scrcpy' ;;
        emerge) printf 'sudo emerge -av media-video/scrcpy' ;;
        *) return 1 ;;
    esac
    return 0
}

os_scrcpy_note() {
    # Prints an extra caveat for this distro, if any (empty otherwise).
    case "$(os_family)" in
        dnf) printf 'scrcpy is not in the default Fedora repos; zeno/scrcpy is the upstream-documented COPR' ;;
        *) printf '' ;;
    esac
    return 0
}

os_setup_plan() {
    # Prints a copy-paste setup block for both dependencies. Always succeeds.
    _sp_id="$(os_id)"
    _sp_adb="$(os_adb_install_cmd 2>/dev/null || true)"
    _sp_scrcpy="$(os_scrcpy_install_cmd 2>/dev/null || true)"
    _sp_note="$(os_scrcpy_note 2>/dev/null || true)"
    printf 'Detected distro: %s\n' "$_sp_id"
    if [ -n "$_sp_adb" ]; then
        printf '  adb:    %s\n' "$_sp_adb"
    else
        printf '  adb:    (unknown distro — Fedora: sudo dnf install android-tools; Debian/Ubuntu: sudo apt update && sudo apt install adb; Arch: sudo pacman -S android-tools)\n'
    fi
    if [ -n "$_sp_scrcpy" ]; then
        printf '  scrcpy: %s\n' "$_sp_scrcpy"
    else
        printf '  scrcpy: (unknown distro — Fedora: sudo dnf copr enable zeno/scrcpy && sudo dnf install scrcpy; Debian/Ubuntu: sudo apt update && sudo apt install scrcpy; Arch: sudo pacman -S scrcpy)\n'
    fi
    if [ -n "$_sp_note" ]; then
        printf '  Note: %s\n' "$_sp_note"
    fi
    unset _sp_id _sp_adb _sp_scrcpy _sp_note
    return 0
}
