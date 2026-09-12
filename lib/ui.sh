#!/bin/sh
# SYNCRO lib/ui.sh — output, prompts, status indicators, errors, formatting.
# POSIX sh, shellcheck-friendly. No dependencies.

# Guard against double-sourcing.
# shellcheck disable=SC2034
if [ "${SYNCRO_UI_LOADED:-}" = "1" ]; then
    return 0 2>/dev/null || exit 0
fi
SYNCRO_UI_LOADED=1

# Colour setup: disabled when not a TTY, NO_COLOR set, or dumb terminal.
# NOTE: escape bytes must be REAL control characters, not backslash text —
# `printf '%s'` never interprets escapes in its arguments, so build them with
# `printf` octal escapes here (interpreted in the format string per POSIX).
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ] && [ "${TERM:-dumb}" != "dumb" ]; then
    _UI_ESC="$(printf '\033')"
    _C_RESET="$_UI_ESC[0m"
    _C_BOLD="$_UI_ESC[1m"
    _C_GREEN="$_UI_ESC[32m"
    _C_RED="$_UI_ESC[31m"
    _C_YELLOW="$_UI_ESC[33m"
    _C_BLUE="$_UI_ESC[34m"
    _C_CYAN="$_UI_ESC[36m"
else
    _C_RESET=''
    _C_BOLD=''
    _C_GREEN=''
    _C_RED=''
    _C_YELLOW=''
    _C_BLUE=''
    _C_CYAN=''
fi
unset _UI_ESC 2>/dev/null || true

# Status marks as real UTF-8 bytes (octal escapes work in dash too,
# unlike \xNN which only some shells interpret in format strings).
_M_OK="$(printf '\342\234\223')"
_M_FAIL="$(printf '\342\234\227')"
_M_ARROW="$(printf '\342\206\222')"

ui_header() {
    # $1 = title
    printf '%s%s%s\n' "${_C_BOLD}${_C_CYAN}" "${1:-SYNCRO}" "${_C_RESET}"
}

ui_subheader() {
    # $1 = text
    printf '\n%s%s%s\n' "${_C_BOLD}" "${1:-}" "${_C_RESET}"
}

ui_ok() {
    # $1 = message
    printf '%s%s%s %s\n' "${_C_GREEN}" "$_M_OK" "${_C_RESET}" "${1:-}"
}

ui_fail() {
    # $1 = message (stdout)
    printf '%s%s%s %s\n' "${_C_RED}" "$_M_FAIL" "${_C_RESET}" "${1:-}"
}

ui_warn() {
    # $1 = message (stderr)
    printf '%s!%s %s\n' "${_C_YELLOW}" "${_C_RESET}" "${1:-}" >&2
}

ui_info() {
    # $1 = message
    printf '  %s\n' "${1:-}"
}

ui_action() {
    # $1 = message (e.g. "→ connecting...")
    printf '%s%s%s %s\n' "${_C_BLUE}" "$_M_ARROW" "${_C_RESET}" "${1:-}"
}

ui_error() {
    # $1 = message, [$2 = hint]
    printf '%sError:%s %s\n' "${_C_RED}" "${_C_RESET}" "${1:-unknown error}" >&2
    if [ -n "${2:-}" ]; then
        printf '  Hint: %s\n' "$2" >&2
    fi
}

ui_hint() {
    # $1 = message (stderr)
    printf '  Hint: %s\n' "${1:-}" >&2
}

ui_prompt() {
    # $1 = prompt text; prints to stderr, reads reply from stdin.
    # Echoes reply to stdout. Returns 1 on EOF.
    _prompt_text="${1:-Continue?}"
    printf '%s [press Enter to continue, Ctrl-C to abort]: %s' "$_prompt_text" "" >&2
    _prompt_reply=""
    if IFS= read -r _prompt_reply; then
        printf '%s' "$_prompt_reply"
        unset _prompt_reply _prompt_text
        return 0
    fi
    unset _prompt_reply _prompt_text
    return 1
}

ui_ask_select() {
    # $1 = prompt, $2 = max index; prints selection to stdout.
    _ask_prompt="${1:-Select device:}"
    _ask_max="${2:-1}"
    printf '%s ' "$_ask_prompt" >&2
    _ask_reply=""
    if IFS= read -r _ask_reply; then
        # Trim whitespace
        _ask_reply="$(printf '%s' "$_ask_reply" | tr -d '[:space:]')"
        case "$_ask_reply" in
            ''|*[!0-9]*)
                unset _ask_prompt _ask_max _ask_reply
                return 1
                ;;
        esac
        if [ "$_ask_reply" -ge 1 ] && [ "$_ask_reply" -le "$_ask_max" ]; then
            printf '%s' "$_ask_reply"
            unset _ask_prompt _ask_max _ask_reply
            return 0
        fi
    fi
    unset _ask_prompt _ask_max _ask_reply
    return 1
}
