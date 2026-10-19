#!/bin/sh
# SYNCRO tests/test_config.sh — first run, existing, malformed, known, missing dir.
# Run: sh tests/test_config.sh

set -u

HERE="$(CDPATH= cd -- "$(dirname -- "$0")" 2>/dev/null && pwd)"
ROOT="$(CDPATH= cd -- "$HERE/.." 2>/dev/null && pwd)"
# shellcheck disable=SC1091
. "$HERE/helpers.sh"

printf '== test_config ==\n'

TDIR="$(mktemp -d /tmp/syncro-cfg.XXXXXX)"
export SYNCRO_CONFIG_DIR="$TDIR/config" SYNCRO_STATE_DIR="$TDIR/state"
# shellcheck disable=SC1091
. "$ROOT/lib/config.sh"

# first run: dirs + file created
rm -rf "$TDIR/config" "$TDIR/state"
config_init; assert_ok "first-run config_init" "$?"
[ -d "$TDIR/config" ]; assert_ok "config dir exists" "$?"
[ -f "$TDIR/config/known_devices" ]; assert_ok "known_devices created" "$?"

# quality / fps validation
config_validate_quality "low" >/dev/null; assert_ok "quality low ok" "$?"
config_validate_quality "balanced" >/dev/null; assert_ok "quality balanced ok" "$?"
config_validate_quality "high" >/dev/null; assert_ok "quality high ok" "$?"
config_validate_quality "ultra" >/dev/null 2>&1; assert_fail "quality ultra rejected" "$?"
config_validate_fps "30" >/dev/null; assert_ok "fps 30 ok" "$?"
config_validate_fps "60" >/dev/null; assert_ok "fps 60 ok" "$?"
config_validate_fps "120" >/dev/null 2>&1; assert_fail "fps 120 rejected" "$?"
config_validate_fps "abc" >/dev/null 2>&1; assert_fail "fps abc rejected" "$?"

# known device save + lookup
known_device_save "ABC123" "192.168.1.42:5555" "Pixel 8"; assert_ok "known save" "$?"
assert_eq "lookup serial→addr" "192.168.1.42:5555" "$(known_device_lookup_serial "ABC123")"
assert_eq "lookup addr→serial" "ABC123" "$(known_device_lookup_address "192.168.1.42:5555")"
known_device_list >/dev/null; assert_ok "known list non-empty" "$?"

# overwrite same serial with new address (no duplicates)
known_device_save "ABC123" "192.168.1.50:5555" "Pixel 8"; assert_ok "known re-save" "$?"
assert_eq "lookup updated addr" "192.168.1.50:5555" "$(known_device_lookup_serial "ABC123")"
lines="$(known_device_list | grep -c '^ABC123|' || true)"
assert_eq "no duplicate serial rows" "1" "$lines"

# regex metacharacters in serial/address must not act as wildcards.
# Previously `grep "^AB.1|"` also matched ABX1, and saving "AB.1" deleted
# the unrelated ABX1 row entirely. Operates on a scratch file so the
# surrounding cases keep their fixtures.
KD_SCRATCH="$TDIR/known_scratch"
cp "$TDIR/config/known_devices" "$KD_SCRATCH"
: > "$TDIR/config/known_devices"
known_device_save "ABX1" "192.168.1.9:5555" "Other"
known_device_save "AB.1" "192.168.1.5:5555" "Dotted"
assert_eq "dot serial lookup" "192.168.1.5:5555" "$(known_device_lookup_serial "AB.1")"
assert_eq "dot-free serial survives" "192.168.1.9:5555" "$(known_device_lookup_serial "ABX1")"
assert_eq "dot address lookup" "AB.1" "$(known_device_lookup_address "192.168.1.5:5555")"
known_device_lookup_address "192.168.1.9:5555" >/dev/null; assert_ok "unrelated addr still resolves" "$?"
assert_eq "no collateral row deletion" "2" "$(known_device_list | grep -c '|' || true)"
cp "$KD_SCRATCH" "$TDIR/config/known_devices"

# malformed config: blank lines, comments, garbage — list must skip blanks/comments, lookups must not crash
printf '\n# comment line\nGARBAGE-NO-DELIM\nDEF456|192.168.1.60:5555|Phone X\n' >> "$TDIR/config/known_devices"
known_device_lookup_serial "DEF456" >/dev/null; assert_ok "lookup after malformed ok" "$?"
assert_eq "lookup valid row amid garbage" "192.168.1.60:5555" "$(known_device_lookup_serial "DEF456")"
known_device_lookup_serial "NOPE" >/dev/null 2>&1; assert_fail "lookup unknown fails" "$?"

# existing configuration preserved across re-init
config_init; assert_ok "re-init idempotent" "$?"
assert_eq "data survives re-init" "192.168.1.50:5555" "$(known_device_lookup_serial "ABC123")"

# missing configuration directory → re-created
rm -rf "$TDIR/config"
[ ! -f "$TDIR/config/known_devices" ]; assert_ok "config removed for test" "$?"
config_init; assert_ok "init recreates missing dir" "$?"
[ -f "$TDIR/config/known_devices" ]; assert_ok "known_devices recreated" "$?"

rm -rf "$TDIR"
test_summary "test_config"
