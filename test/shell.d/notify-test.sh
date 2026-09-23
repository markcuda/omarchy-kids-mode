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

# A qrencode stub so pair's QR is owned by the test.
QR_LOG="$TMP/qrencode.log"
cat >"$STUBS/qrencode" <<'EOF'
#!/bin/bash
cat >>"$QR_LOG"
EOF
chmod +x "$STUBS/qrencode"
export QR_LOG

# An `ip` stub so pairing's address enumeration is owned by the test (N-10):
# a LAN address and a tailnet (CGNAT) address.
cat >"$STUBS/ip" <<'EOF'
#!/bin/bash
printf '2: eth0    inet 10.0.0.9/24 brd 10.0.0.255 scope global eth0\n'
printf '3: tailscale0    inet 100.64.0.7/32 scope global tailscale0\n'
EOF
chmod +x "$STUBS/ip"

# A tailscale stub so the away-on branch is owned by the test too.
cat >"$STUBS/tailscale" <<'EOF'
#!/bin/bash
[[ "${1:-}" == "ip" ]] && printf '100.64.0.7\n'
exit 0
EOF
chmod +x "$STUBS/tailscale"

export PATH="$STUBS:$PATH"
kids_set_const "$BIN" ETC "$ETC"
kids_set_const "$BIN" SYSROOT "$SYSROOT"
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

PAIR_DIR="$SYSROOT/run/omarchy-kids/pairing"
"$BIN" pair --apply >/dev/null 2>&1
check_eq "$?" "2" "pair refuses while notifications are off"
[[ -z "$(ls -A "$PAIR_DIR" 2>/dev/null)" ]] && pass "pair writes no record while off" ||
  fail "pair wrote a record while notifications are off"

# --- enable / status / rekey / disable (needs cryptography) -----------------
if python3 -c "import cryptography" >/dev/null 2>&1; then
  "$DEV" add --id d1 --name Phone --platform android --sign-pub "$KEY" --box-pub "$KEY" --apply >/dev/null
  check_eq "$?" "0" "the fixture device pairs"
  [[ -f "$CONF" ]] && pass "the fixture device file exists" || fail "the fixture device file is missing"

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

  # pair: previews, then writes a single-use record, shows the URI+QR and the fingerprint.
  check_contains "$("$BIN" pair 2>&1)" "would write a pairing record" "pair previews without --apply"
  [[ -z "$(ls -A "$PAIR_DIR" 2>/dev/null)" ]] && pass "pair preview writes no record" ||
    fail "pair preview wrote a record"
  : >"$QR_LOG"
  out3="$("$BIN" pair --apply 2>&1)"
  check_eq "$?" "0" "pair --apply starts a pairing window"
  check_contains "$out3" "omarchy-kids://pair" "pair prints the URI the device scans"
  check_contains "$out3" "addr=10.0.0.9" "pair passes the box's own address (N-10)"
  [[ "$out3" != *"100.64.0.7"* ]] && pass "the CGNAT address is left out while away is off (N-10)" ||
    fail "the CGNAT address rode the URI with away off"
  check_contains "$out3" "fingerprint: $recomputed" "pair prints the SPKI fingerprint to check on the device"
  check_contains "$(cat "$QR_LOG")" "omarchy-kids://pair" "pair renders the URI as a QR (qrencode, on stdin)"
  ls "$PAIR_DIR"/* >/dev/null 2>&1 && pass "pair wrote a single-use pairing record" ||
    fail "pair wrote no pairing record"

  # enable is idempotent: the key does not change, and the fingerprint is printed.
  before="$(cksum <"$RKEY")"
  out2="$("$BIN" enable --apply 2>&1)"
  check_eq "$?" "0" "enable is idempotent"
  check_eq "$(cksum <"$RKEY")" "$before" "enable again does not re-key"
  check_contains "$out2" "$recomputed" "enable again prints the existing fingerprint"

  # re-key mints a new key, unpairs every device and stops the old listener.
  check_contains "$("$BIN" enable --rekey 2>&1)" "would unpair every device" \
    "enable --rekey previews the unpair (label claims)"
  : >"$SYSTEMCTL_LOG"
  "$BIN" enable --rekey --apply >/dev/null 2>&1
  check_eq "$?" "0" "enable --rekey succeeds"
  [[ -f "$CONF" ]] && fail "re-key left a paired device" || pass "re-key unpairs every device"
  check_contains "$(cat "$SYSTEMCTL_LOG")" "stop omarchy-kids-relayd.service" \
    "re-key stops the relay so no old-cert listener is left"

  # pair again, then disable revokes it, removes the cert and stops the relay.
  : >"$SYSTEMCTL_LOG"
  "$DEV" add --id d1 --name Phone --platform android --sign-pub "$KEY" --box-pub "$KEY" --apply >/dev/null
  check_eq "$?" "0" "the fixture device pairs again"
  [[ -f "$CONF" ]] && pass "the fixture device file exists again" || fail "the second fixture device is missing"
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

# --- away from home: the tailnet drop-in (N-10) ---------------------------
AWAY_FILE="$SYSROOT/etc/systemd/system/omarchy-kids-relayd.service.d/away.conf"
check_eq "$("$BIN" away-status)" "off" "away-status: off by default"
out="$("$BIN" away tailnet 2>&1)"
check_eq "$?" 0 "away tailnet previews without --apply"
check_contains "$out" "[dry-run]" "away tailnet prints the plan"
[[ -e "$AWAY_FILE" ]] && fail "away tailnet preview must not write the drop-in" ||
  pass "away tailnet preview writes nothing"

: >"$SYSTEMCTL_LOG"
out="$("$BIN" away tailnet --apply 2>&1)"
check_eq "$?" 0 "away tailnet --apply succeeds"
check_contains "$(cat "$AWAY_FILE")" "100.64.0.0/10" "the drop-in allows the tailnet's CGNAT range"
check_contains "$(cat "$AWAY_FILE")" "192.168.0.0/16" "the drop-in keeps the LAN ranges"
check_contains "$(cat "$SYSTEMCTL_LOG")" "daemon-reload" "away reloads systemd"
check_eq "$("$BIN" away-status)" "tailnet" "away-status: tailnet after apply"
if python3 -c "import cryptography" >/dev/null 2>&1; then
  "$BIN" enable --apply >/dev/null 2>&1
  out="$("$BIN" pair --apply 2>&1)"
  check_contains "$out" "100.64.0.7" "pair offers the tailnet address once away is on (N-10)"
fi

out="$("$BIN" away off --apply 2>&1)"
check_eq "$?" 0 "away off --apply succeeds"
[[ ! -e "$AWAY_FILE" ]] && pass "away off removes the drop-in" || fail "away off left the drop-in"
check_eq "$("$BIN" away-status)" "off" "away-status: off after away off"

out="$("$BIN" away bogus --apply 2>&1)"
check_eq "$?" 2 "an unknown away mode is refused"

# --- the away mailbox: the courier's one server (N-11) ---------------------
COURIER_CONF="$ETC/courier.conf"
check_eq "$("$BIN" mailbox-status)" "off" "mailbox-status: off by default"
out="$("$BIN" mailbox ntfy --url https://ntfy.example --topic kid 2>&1)"
check_eq "$?" 0 "mailbox ntfy previews without --apply"
check_contains "$out" "[dry-run]" "mailbox prints the plan"
[[ -e "$COURIER_CONF" ]] && fail "mailbox preview must not write the config" ||
  pass "mailbox preview writes nothing"

out="$("$BIN" mailbox ntfy --url https://ntfy.example --topic kid --reply-topic kid-replies --apply 2>&1)"
check_eq "$?" 0 "mailbox ntfy --apply succeeds"
check_contains "$(cat "$COURIER_CONF")" "transport=ntfy" "the config names the transport"
check_contains "$(cat "$COURIER_CONF")" "url=https://ntfy.example" "the config names the server"
check_contains "$(cat "$COURIER_CONF")" "reply_topic=kid-replies" "the config names the reply topic"
check_eq "$("$BIN" mailbox-status)" "ntfy" "mailbox-status: ntfy after apply"

"$BIN" mailbox ntfy --url http://insecure.example --topic kid --apply >/dev/null 2>&1
check_eq "$?" 2 "mailbox refuses a non-https url"
"$BIN" mailbox ntfy --url https://ntfy.example --topic kid --token leaked --apply >/dev/null 2>&1
check_eq "$?" 2 "--token is not an option (a secret must not be on argv)"
printf '\n' | "$BIN" mailbox gotify --url https://gotify.example --topic kid --apply >/dev/null 2>&1
check_eq "$?" 2 "gotify needs a token on stdin"
printf 'tok-secret\n' | "$BIN" mailbox gotify --url https://gotify.example --topic kid --apply >/dev/null 2>&1
check_eq "$?" 0 "gotify --apply with a token on stdin succeeds"
check_contains "$(cat "$COURIER_CONF")" "token=tok-secret" "the token is written from stdin"

out="$("$BIN" mailbox off --apply 2>&1)"
check_eq "$?" 0 "mailbox off succeeds"
[[ ! -e "$COURIER_CONF" ]] && pass "mailbox off removes the config" || fail "mailbox off left the config"
check_eq "$("$BIN" mailbox-status)" "off" "mailbox-status: off after mailbox off"

echo "notify-test RESULT: $([[ $rc == 0 ]] && echo PASS || echo FAIL)"
exit $rc
