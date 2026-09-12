#!/bin/sh
# SYNCRO uninstall.sh — removes ONLY files owned by SYNCRO.
# Default: removes ~/.local/bin/syncro + ~/.local/share/syncro, keeps config/state.
#   sh uninstall.sh --purge   also removes config + state.
# POSIX sh.

set -u

PREFIX="${PREFIX:-$HOME/.local}"
PURGE=0

for _a in "$@"; do
    case "$_a" in
        --prefix=*) PREFIX="${_a#--prefix=}" ;;
        --purge) PURGE=1 ;;
        --help|-h) printf 'Usage: sh uninstall.sh [--prefix=$HOME/.local] [--purge]\n'; exit 0 ;;
        *) printf 'Error: unknown argument: %s\n' "$_a" >&2; exit 2 ;;
    esac
done
unset _a

: "${XDG_CONFIG_HOME:=$HOME/.config}"
: "${XDG_STATE_HOME:=$HOME/.local/state}"

BIN_F="$PREFIX/bin/syncro"
SHARE_D="$PREFIX/share/syncro"

printf 'SYNCRO uninstaller (prefix: %s)\n' "$PREFIX"

# Only remove our launcher: verify marker before deleting.
if [ -f "$BIN_F" ]; then
    if grep -q 'SYNCRO' "$BIN_F" 2>/dev/null; then
        rm -f "$BIN_F" && printf 'Removed: %s\n' "$BIN_F"
    else
        printf 'Skipped (not owned by syncro): %s\n' "$BIN_F" >&2
    fi
else
    printf 'Not present: %s\n' "$BIN_F"
fi

# Only remove our share dir: verify it looks like a syncro install.
if [ -d "$SHARE_D" ]; then
    if [ -f "$SHARE_D/lib/ui.sh" ] && [ -f "$SHARE_D/VERSION" ]; then
        rm -rf "$SHARE_D" && printf 'Removed: %s/\n' "$SHARE_D"
    else
        printf 'Skipped (not a syncro install): %s/\n' "$SHARE_D" >&2
    fi
else
    printf 'Not present: %s/\n' "$SHARE_D"
fi

if [ "$PURGE" = "1" ]; then
    for _d in "$XDG_CONFIG_HOME/syncro" "$XDG_STATE_HOME/syncro"; do
        if [ -e "$_d" ]; then
            rm -rf "$_d" && printf 'Purged: %s\n' "$_d"
        else
            printf 'Not present: %s\n' "$_d"
        fi
    done
    unset _d
else
    printf 'Kept (use --purge to remove): %s/syncro %s/syncro\n' "$XDG_CONFIG_HOME" "$XDG_STATE_HOME"
fi

printf 'Done.\n'
