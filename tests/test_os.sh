#!/bin/sh
# SYNCRO tests/test_os.sh — distro detection + suitable setup commands.
# Run: sh tests/test_os.sh

set -u

HERE="$(CDPATH= cd -- "$(dirname -- "$0")" 2>/dev/null && pwd)"
ROOT="$(CDPATH= cd -- "$HERE/.." 2>/dev/null && pwd)"
# shellcheck disable=SC1091
. "$HERE/helpers.sh"
# shellcheck disable=SC1091
. "$ROOT/lib/os.sh"

printf '== test_os ==\n'

# --- families via SYNCRO_OS_ID override ---
SYNCRO_OS_ID=fedora; export SYNCRO_OS_ID
assert_eq "fedora family" "dnf" "$(os_family)"
assert_eq "fedora adb cmd" "sudo dnf install android-tools" "$(os_adb_install_cmd)"
assert_contains "fedora scrcpy via COPR" "$(os_scrcpy_install_cmd)" "copr enable zeno/scrcpy"
[ -n "$(os_scrcpy_note)" ]; assert_ok "fedora scrcpy note present" "$?"

SYNCRO_OS_ID=ubuntu; export SYNCRO_OS_ID
assert_eq "ubuntu family" "apt" "$(os_family)"
assert_contains "ubuntu adb cmd" "$(os_adb_install_cmd)" "apt install adb"
assert_contains "ubuntu scrcpy cmd" "$(os_scrcpy_install_cmd)" "apt install scrcpy"

SYNCRO_OS_ID=debian; export SYNCRO_OS_ID
assert_eq "debian family" "apt" "$(os_family)"

SYNCRO_OS_ID=arch; export SYNCRO_OS_ID
assert_eq "arch family" "pacman" "$(os_family)"
assert_contains "arch adb cmd" "$(os_adb_install_cmd)" "pacman -S android-tools"

SYNCRO_OS_ID=opensuse-leap; export SYNCRO_OS_ID
assert_eq "opensuse-leap family" "zypper" "$(os_family)"
assert_contains "opensuse adb cmd" "$(os_adb_install_cmd)" "zypper"

SYNCRO_OS_ID=almalinux; export SYNCRO_OS_ID
assert_eq "almalinux family" "dnf" "$(os_family)"

SYNCRO_OS_ID=gentoo; export SYNCRO_OS_ID
assert_eq "gentoo family" "emerge" "$(os_family)"

# --- ID_LIKE fallback via fake os-release (derivatives not listed by ID) ---
TDIR="$(mktemp -d /tmp/syncro-os.XXXXXX)"
printf 'ID=vanilla\nID_LIKE="debian ubuntu"\n' > "$TDIR/os-release"
unset SYNCRO_OS_ID
OS_RELEASE_FILE="$TDIR/os-release"; export OS_RELEASE_FILE
assert_eq "ID_LIKE debian→apt" "apt" "$(os_family)"
assert_eq "os_id reads file" "vanilla" "$(os_id)"

printf 'ID=mycorp\nID_LIKE="rhel centos fedora"\n' > "$TDIR/os-release"
assert_eq "ID_LIKE rhel→dnf" "dnf" "$(os_family)"

# --- unknown distro: commands fail, plan degrades to generic block ---
printf 'ID=mystery\n' > "$TDIR/os-release"
assert_eq "mystery family" "unknown" "$(os_family)"
os_adb_install_cmd >/dev/null 2>&1; assert_fail "mystery adb cmd unavailable" "$?"
os_scrcpy_install_cmd >/dev/null 2>&1; assert_fail "mystery scrcpy cmd unavailable" "$?"
assert_contains "mystery plan generic" "$(os_setup_plan)" "unknown distro"

# missing file entirely
OS_RELEASE_FILE="$TDIR/nope"; export OS_RELEASE_FILE
assert_eq "missing file→unknown" "unknown" "$(os_id)"

# --- setup plan on a known distro ---
SYNCRO_OS_ID=fedora; export SYNCRO_OS_ID
OS_RELEASE_FILE=/etc/os-release; export OS_RELEASE_FILE
assert_contains "plan names distro" "$(os_setup_plan)" "Detected distro: fedora"
assert_contains "plan adb line" "$(os_setup_plan)" "android-tools"
assert_contains "plan scrcpy COPR" "$(os_setup_plan)" "zeno/scrcpy"

# --- integration: missing-dep hints follow the detected distro ---
# shellcheck disable=SC1091
. "$ROOT/lib/adb.sh"
# shellcheck disable=SC1091
. "$ROOT/lib/scrcpy.sh"
SYNCRO_OS_ID=debian; export SYNCRO_OS_ID
assert_contains "adb hint follows debian" "$(adb_print_missing_help 2>&1)" "apt install adb"
SYNCRO_OS_ID=fedora; export SYNCRO_OS_ID
assert_contains "scrcpy hint follows fedora" "$(scrcpy_print_missing_help 2>&1)" "copr enable zeno/scrcpy"
SYNCRO_OS_ID=arch; export SYNCRO_OS_ID
assert_contains "scrcpy hint follows arch" "$(scrcpy_print_missing_help 2>&1)" "pacman -S scrcpy"

# --- integration: install.sh prints distro-aware setup when deps are missing ---
# Hermetic: hide adb/scrcpy behind a restricted PATH (they may be installed
# on the dev machine), keeping only the tools install.sh needs.
mkdir -p "$TDIR/hidebin"
for _t in sh dirname mkdir cp chmod grep cut tr head; do
    _tp="$(command -v "$_t" 2>/dev/null || true)"
    [ -n "$_tp" ] && ln -sf "$_tp" "$TDIR/hidebin/$_t"
done
unset _t _tp
out="$(PATH="$TDIR/hidebin" PREFIX="$TDIR/prefix" sh "$ROOT/install.sh" 2>&1)"; rc=$?
assert_ok "install.sh exits 0" "$rc"
assert_contains "install.sh setup mentions distro" "$out" "Detected distro:"
assert_contains "install.sh setup has scrcpy cmd" "$out" "scrcpy"

rm -rf "$TDIR"
test_summary "test_os"
