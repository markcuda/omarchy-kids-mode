#!/bin/bash
# Tests bin/omarchy-kids-notify — the parent's enable/disable/status and the
# delegation to the device registry (SPEC.md R-NOTIFY-1/3). A stub `id` (uid 0)
# stands in for root; the registry, the relay tree and the published file live
# under a scratch root, so nothing here reads the machine's real state. The
# certificate mints only where python-cryptography is present (those checks skip
# otherwise).
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
DEV="$TMP/tree/bin/omarchy-kids-devices"
kids_id_stub "$STUBS" root 0

# A systemctl stub so disable's stop is owned by the test (AGENTS.md shape 1).
SYSTEMCTL_LOG="$TMP/systemctl.log"
cat >"$STUBS/systemctl" <<'EOF'
#!/bin/bash
printf 'systemctl %s\n' "$*" >>"$SYSTEMCTL_LOG"
EOF
chmod +x "$STUBS/systemctl"
export SYSTEMCTL_LOG

export PATH="$STUBS:$PATH"
kids_set_const "$BIN" ETC "$ETC"
kids_set_const "$DEV" ETC "$ETC"
kids_set_const "$DEV" SYSROOT "$SYSROOT"
CERT="$ETC/relay/cert.pem"
RKEY="$ETC/relay/key.pem"
KEY="AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
CONF="$ETC/devices/d1.conf"

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

# --- enable / status / rekey / disable (needs cryptography) -----------------
if python3 -c "import cryptography" >/dev/null 2>&1; then
  "$DEV" add --id d1 --name Phone --platform android --sign-pub "$KEY" --box-pub "$KEY" --apply >/dev/null

  out="$("$BIN" enable --apply 2>&1)"
  check_eq "$?" "0" "enable --apply mints the certificate"
  [[ -f "$CERT" && -f "$RKEY" ]] && pass "enable writes cert.pem and key.pem" ||
    fail "enable: certificate or key missing"
  check_eq "$(kids_file_mode "$CERT")" "644" "the certificate is 0644"
  check_eq "$(kids_file_mode "$RKEY")" "640" "the private key is 0640"

  # The printed fingerprint must be the SPKI hash of what was written (the
  # device pins exactly this; lib/cert.py:makes the same choice).
  printed="$(printf '%s\n' "$out" | awk '/fingerprint:/{print $2}')"
  recomputed="$(
    python3 - "$CERT" <<'PY'
import sys, hashlib
from cryptography import x509
from cryptography.hazmat.primitives import serialization
cert = x509.load_pem_x509_certificate(open(sys.argv[1], "rb").read())
spki = cert.public_key().public_bytes(
    serialization.Encoding.DER, serialization.PublicFormat.SubjectPublicKeyInfo
)
print(hashlib.sha256(spki).hexdigest())
PY
  )"
  check_eq "$printed" "$recomputed" "the printed fingerprint is the certificate's SPKI hash"

  # enable is idempotent: the key does not change, and the fingerprint is printed.
  before="$(cksum <"$RKEY")"
  out2="$("$BIN" enable --apply 2>&1)"
  check_eq "$?" "0" "enable is idempotent"
  check_eq "$(cksum <"$RKEY")" "$before" "enable again does not re-key"
  check_contains "$out2" "$recomputed" "enable again prints the existing fingerprint"

  # re-key mints a new key and unpairs every device.
  "$BIN" enable --rekey --apply >/dev/null 2>&1
  check_eq "$?" "0" "enable --rekey succeeds"
  [[ ! -f "$CONF" ]] && pass "re-key unpairs every device" || fail "re-key left a paired device"

  # pair again, then disable revokes it, removes the cert and stops the relay.
  "$DEV" add --id d1 --name Phone --platform android --sign-pub "$KEY" --box-pub "$KEY" --apply >/dev/null
  check_contains "$("$BIN" status)" "notifications: on" "status reports on after enable"
  "$BIN" disable --apply >/dev/null 2>&1
  check_eq "$?" "0" "disable --apply succeeds"
  [[ ! -e "$CERT" && ! -e "$RKEY" ]] && pass "disable removes the certificate and key" ||
    fail "disable left the certificate behind"
  [[ ! -f "$CONF" ]] && pass "disable revokes every paired device" || fail "disable left a paired device"
  check_contains "$(cat "$SYSTEMCTL_LOG")" "stop omarchy-kids-relayd.service" \
    "disable stops the relay so no listener is left (R-NOTIFY-1)"
  check_contains "$("$BIN" status)" "notifications: off" "status reports off after disable"
else
  echo "SKIP notify-test.sh: python-cryptography not installed — the minting checks did not run"
fi

echo "notify-test RESULT: $([[ $rc == 0 ]] && echo PASS || echo FAIL)"
exit $rc
