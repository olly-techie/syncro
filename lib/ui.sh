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
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ] && [ "${TERM:-dumb}" != "dumb" ]; then
    _C_RESET='\033[0m'
    _C_BOLD='\033[1m'
    _C_GREEN='\033[32m'
    _C_RED='\033[31m'
    _C_YELLOW='\033[33m'
    _C_BLUE='\033[34m'
    _C_CYAN='\033[36m'
else
    _C_RESET=''
    _C_BOLD=''
    _C_GREEN=''
    _C_RED=''
    _C_YELLOW=''
    _C_BLUE=''
    _C_CYAN=''
fi

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
    printf '%s\xe2\x9c\x93%s %s\n' "${_C_GREEN}" "${_C_RESET}" "${1:-}"
}

ui_fail() {
    # $1 = message (stdout)
    printf '%s\xe2\x9c\x97%s %s\n' "${_C_RED}" "${_C_RESET}" "${1:-}"
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
    printf '%s\xe2\x86\x92%s %s\n' "${_C_BLUE}" "${_C_RESET}" "${1:-}"
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
