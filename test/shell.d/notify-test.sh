#!/bin/bash
# Tests bin/omarchy-kids-notify — the parent's enable/disable/status and the
# delegation to the device registry (SPEC.md R-NOTIFY-1/3). A stub `id` (uid 0)
# stands in for root; the certificate mints only where python-cryptography is
# present (the minting checks skip otherwise).
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
BIN="$TMP/tree/bin/omarchy-kids-notify"
kids_id_stub "$STUBS" root 0
export PATH="$STUBS:$PATH"
kids_set_const "$BIN" ETC "$ETC"
kids_set_const "$BIN" SYSROOT "$SYSROOT"
CERT="$ETC/relay/cert.pem"
KEY="$ETC/relay/key.pem"

# --- root only -------------------------------------------------------------
KIDS_TEST_UID=1000 "$BIN" status >/dev/null 2>&1
check_eq "$?" "2" "a non-root caller is refused (relay cert and registry are root-owned)"
KIDS_TEST_UID=1000 "$BIN" --help >/dev/null 2>&1
check_eq "$?" "0" "--help works for a non-root caller"
export KIDS_TEST_UID=0

# --- status before enable --------------------------------------------------
check_contains "$("$BIN" status)" "notifications: off" "status reports off before enable"

# --- enable previews by default --------------------------------------------
out="$("$BIN" enable 2>&1)"
check_eq "$?" "0" "enable previews without --apply"
check_contains "$out" "[dry-run]" "enable prints the plan"
[[ -e "$CERT" ]] && fail "enable (dry-run): must not mint a certificate" ||
  pass "enable (dry-run): mints nothing"

# --- delegation ------------------------------------------------------------
"$BIN" devices --json >/dev/null 2>&1
check_eq "$?" "0" "devices delegates to omarchy-kids-devices"

# --- enable / status / disable (needs cryptography) ------------------------
if python3 -c "import cryptography" >/dev/null 2>&1; then
  "$BIN" enable --apply >/dev/null 2>&1
  check_eq "$?" "0" "enable --apply mints the certificate"
  [[ -f "$CERT" && -f "$KEY" ]] && pass "enable writes cert.pem and key.pem" ||
    fail "enable: certificate or key missing"
  check_eq "$(kids_file_mode "$CERT")" "644" "the certificate is 0644"
  check_eq "$(kids_file_mode "$KEY")" "640" "the private key is 0640"
  check_contains "$("$BIN" status)" "notifications: on" "status reports on after enable"
  "$BIN" enable --apply >/dev/null 2>&1
  check_eq "$?" "0" "enable is idempotent"
  "$BIN" disable --apply >/dev/null 2>&1
  [[ ! -e "$CERT" && ! -e "$KEY" ]] && pass "disable removes the certificate and key" ||
    fail "disable left the certificate behind"
  check_contains "$("$BIN" status)" "notifications: off" "status reports off after disable"
else
  echo "SKIP notify-test.sh: python-cryptography not installed — the minting checks did not run"
fi

echo "notify-test RESULT: $([[ $rc == 0 ]] && echo PASS || echo FAIL)"
exit $rc
