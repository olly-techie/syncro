#!/bin/sh
# SYNCRO install.sh — user-local, idempotent, no root, no shell-rc edits.
# Installs to: ~/.local/bin/syncro + ~/.local/share/syncro/
# Usage: sh install.sh [--prefix "$HOME/.local"] [--force]
# shellcheck-friendly, POSIX sh.

set -u

PREFIX="${PREFIX:-$HOME/.local}"
FORCE=0

for _a in "$@"; do
    case "$_a" in
        --prefix=*) PREFIX="${_a#--prefix=}" ;;
        --prefix) printf 'Error: --prefix requires =VALUE\n' >&2; exit 2 ;;
        --force) FORCE=1 ;;
        --help|-h) printf 'Usage: sh install.sh [--prefix=$HOME/.local] [--force]\n'; exit 0 ;;
        *) printf 'Error: unknown argument: %s\n' "$_a" >&2; exit 2 ;;
    esac
done
unset _a

SRC_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" 2>/dev/null && pwd)"
BIN_SRC="$SRC_DIR/bin/syncro"
LIB_SRC="$SRC_DIR/lib"
VER_SRC="$SRC_DIR/VERSION"

BIN_DST="$PREFIX/bin/syncro"
SHARE_DST="$PREFIX/share/syncro"
LIB_DST="$SHARE_DST/lib"

printf 'SYNCRO installer\n'
printf '  source: %s\n' "$SRC_DIR"
printf '  prefix: %s\n' "$PREFIX"

# Sanity checks.
if [ ! -f "$BIN_SRC" ]; then printf 'Error: missing %s\n' "$BIN_SRC" >&2; exit 1; fi
if [ ! -d "$LIB_SRC" ]; then printf 'Error: missing %s\n' "$LIB_SRC" >&2; exit 1; fi
if [ ! -f "$VER_SRC" ]; then printf 'Error: missing %s\n' "$VER_SRC" >&2; exit 1; fi

mkdir -p "$PREFIX/bin" || { printf 'Error: cannot create %s\n' "$PREFIX/bin" >&2; exit 1; }
mkdir -p "$LIB_DST" || { printf 'Error: cannot create %s\n' "$LIB_DST" >&2; exit 1; }

# Copy lib files (only known syncro modules — never wipe unrelated files).
for _f in ui.sh config.sh adb.sh device.sh network.sh scrcpy.sh; do
    if [ ! -f "$LIB_SRC/$_f" ]; then printf 'Error: missing lib/%s\n' "$_f" >&2; exit 1; fi
    cp -f "$LIB_SRC/$_f" "$LIB_DST/$_f" || { printf 'Error: copy failed for %s\n' "$_f" >&2; exit 1; }
    chmod 644 "$LIB_DST/$_f" || true
done
unset _f

cp -f "$VER_SRC" "$SHARE_DST/VERSION" || exit 1
cp -f "$BIN_SRC" "$BIN_DST" || exit 1
chmod 755 "$BIN_DST" || exit 1

# Patch installed launcher to prefer installed lib dir (bin/syncro already
# falls back to ~/.local/share/syncro/lib, so no patching needed).

printf 'Installed:\n'
printf '  %s\n' "$BIN_DST"
printf '  %s/ (lib + VERSION)\n' "$SHARE_DST"
printf 'Config:   ${XDG_CONFIG_HOME:-$HOME/.config}/syncro/\n'
printf 'State:    ${XDG_STATE_HOME:-$HOME/.local/state}/syncro/\n'

# Dependency notice (never auto-install).
if ! command -v adb >/dev/null 2>&1; then
    printf 'NOTE: adb not found — install it (Fedora: sudo dnf install android-tools).\n'
fi
if ! command -v scrcpy >/dev/null 2>&1; then
    printf 'NOTE: scrcpy not found — install it (Fedora: sudo dnf install scrcpy).\n'
fi

# PATH hint (do not modify rc files automatically).
case ":$PATH:" in
    *":$PREFIX/bin:"*) printf 'PATH: OK (%s/bin on PATH)\n' "$PREFIX" ;;
    *) printf 'PATH: add %s/bin to PATH to run `syncro` (we did not edit your shell rc).\n' "$PREFIX" >&2 ;;
esac

printf 'Done. Run: syncro --help\n'
