#!/bin/bash
# Tests bin/omarchy-kids-devices — the root-owned paired-device registry
# (SPEC.md R-NOTIFY-3). A stub `id` (uid 0) stands in for root; the registry
# tree and the published file both live under a scratch root.
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=test/shell.d/lib.sh
source "$DIR/test/shell.d/lib.sh"
# shellcheck source=test/shell.d/tree.sh
source "$DIR/test/shell.d/tree.sh"

pass() { echo "PASS  $*"; }
fail() {
  echo "FAIL  $*"
  rc=1
}
rc=0
check_eq() { # got want label
  if [[ "$1" == "$2" ]]; then pass "$3"; else fail "$3 (want '$2', got '$1')"; fi
}
check_contains() { # haystack needle label
  if [[ "$1" == *"$2"* ]]; then pass "$3"; else fail "$3 (want '$2' in '$1')"; fi
}

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
STUBS="$TMP/stubs"
ETC="$TMP/etc"
SYSROOT="$TMP/sysroot"
mkdir -p "$STUBS" "$ETC" "$SYSROOT"

kids_tree "$TMP/tree" "$DIR"
BIN="$TMP/tree/bin/omarchy-kids-devices"
kids_id_stub "$STUBS" root 0
export PATH="$STUBS:$PATH"
kids_set_const "$BIN" ETC "$ETC"
kids_set_const "$BIN" SYSROOT "$SYSROOT"

KEY="AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
DEV="$ETC/devices/d1.conf"
PUB="$SYSROOT/run/omarchy-kids/devices.json"

# --- root only -------------------------------------------------------------
KIDS_TEST_UID=1000 "$BIN" list >/dev/null 2>&1
check_eq "$?" "2" "a non-root caller is refused (registry is root-owned)"
KIDS_TEST_UID=1000 "$BIN" --help >/dev/null 2>&1
check_eq "$?" "0" "--help works for a non-root caller (AGENTS.md)"
export KIDS_TEST_UID=0

# --- DRY_RUN is the default ------------------------------------------------
out="$("$BIN" add --id d1 --name Phone --platform android --sign-pub "$KEY" --box-pub "$KEY" 2>&1)"
check_eq "$?" "0" "add: previews without --apply"
check_contains "$out" "[dry-run]" "add: prints the plan"
[[ -e "$DEV" ]] && fail "add (dry-run): must not write the device file" || pass "add (dry-run): writes nothing"

# --- add --apply -----------------------------------------------------------
"$BIN" add --id d1 --name Phone --platform android --sign-pub "$KEY" --box-pub "$KEY" --apply >/dev/null
check_eq "$?" "0" "add --apply succeeds"
[[ -f "$DEV" ]] && pass "add: writes <id>.conf" || fail "add: no device file"
check_eq "$(kids_file_mode "$DEV")" "600" "device conf is 0600 root (R-NOTIFY-3)"
check_contains "$(cat "$DEV")" "name=Phone" "device conf carries the name"
check_contains "$(cat "$DEV")" "scopes=decide,act" "device conf carries the default scopes"
[[ -f "$PUB" ]] && pass "add: publishes the relay copy" || fail "add: no published devices.json"
check_contains "$(cat "$PUB")" '"id": "d1"' "published record names the device"
check_contains "$(cat "$PUB")" '"sign_pub": ' "published record carries the public key"

# --- a second add of the same id is refused --------------------------------
"$BIN" add --id d1 --name Phone2 --platform ios --sign-pub "$KEY" --box-pub "$KEY" --apply >/dev/null 2>&1
check_eq "$?" "2" "add: an already-paired id is refused"

# --- validation ------------------------------------------------------------
for bad in \
  "--id ../../etc --name X --platform ios --sign-pub $KEY --box-pub $KEY" \
  "--id d2 --name X --platform ios --sign-pub short --box-pub $KEY" \
  "--id d2 --name X --platform ios --sign-pub $KEY --box-pub $KEY --scopes root"; do
  # shellcheck disable=SC2086
  "$BIN" add $bad --apply >/dev/null 2>&1
  check_eq "$?" "2" "add refuses: $bad"
done
# A newline in --scopes must not inject a second field; a trailing comma must
# not publish an empty scope; a control character in the name must not land.
"$BIN" add --id d3 --name X --platform ios --sign-pub "$KEY" --box-pub "$KEY" \
  --scopes "$(printf 'decide\nsign_pub=EVIL')" --apply >/dev/null 2>&1
check_eq "$?" "2" "add refuses scopes with an embedded newline"
"$BIN" add --id d3 --name X --platform ios --sign-pub "$KEY" --box-pub "$KEY" --scopes "decide," --apply >/dev/null 2>&1
check_eq "$?" "2" "add refuses a trailing-comma scope list"
"$BIN" add --id d3 --name "$(printf 'Phone\033[2J')" --platform ios --sign-pub "$KEY" --box-pub "$KEY" --apply >/dev/null 2>&1
check_eq "$?" "2" "add refuses a control character in the name"

# --- list ------------------------------------------------------------------
check_contains "$("$BIN" list)" "d1" "list shows the device"
check_contains "$("$BIN" list --json)" '"platform": "android"' "list --json is machine-readable"

# --- scopes / rename / revoke ----------------------------------------------
"$BIN" scopes d1 decide --apply >/dev/null
check_contains "$(cat "$DEV")" "scopes=decide" "scopes --apply rewrites the scopes"
"$BIN" rename d1 "Ada's phone" --apply >/dev/null
check_contains "$(cat "$DEV")" "name=Ada's phone" "rename --apply rewrites the name"
"$BIN" rename d1 'A|B&C\D' --apply >/dev/null
check_contains "$(cat "$DEV")" 'name=A|B&C\D' "rename stores a name with |, & and \ verbatim (no sed injection)"
"$BIN" revoke d1 --apply >/dev/null
[[ -f "$DEV.revoked" ]] && pass "revoke renames the conf to .revoked" || fail "revoke did not rename"
[[ -f "$DEV" ]] && fail "revoke must remove the live conf" || pass "revoke removes the live conf"
check_contains "$("$BIN" list)" "no devices paired" "revoked device is not listed"

# --- publish is idempotent and public-only ---------------------------------
"$BIN" publish --apply >/dev/null
check_eq "$?" "0" "publish succeeds with no live devices"
check_eq "$(cat "$PUB")" "[]" "publish writes an empty array when nothing is paired"

echo "devices-test RESULT: $([[ $rc == 0 ]] && echo PASS || echo FAIL)"
exit $rc
