#!/bin/bash
# Tests bin/omarchy-kids-authd and bin/omarchy-kids-parent-auth (R-SEC-1,
# R-SEC-2) plus the GRANT path the "Ask a grown-up" modal now goes through
# (review S1/S2/S3) and the socket-redirection hardening (review S4).
#
# Everything that does not need a working crypt(3) runs everywhere,
# including this repo's macOS dev box: the review's own complaint was that
# the *security* tests were the ones that skipped. Only the live-daemon
# password checks are conditional on libcrypt.
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
AUTHD="$DIR/bin/omarchy-kids-authd"
CLIENT="$DIR/bin/omarchy-kids-parent-auth"

fail=0
check() { # got want label
  if [[ "$1" == "$2" ]]; then echo "ok   $3"; else
    echo "FAIL $3 (want '$2', got '$1')"
    fail=1
  fi
}
ok() { echo "ok   $1"; }
bad() {
  echo "FAIL $1"
  fail=1
}

# Who may present a DECIDE (R-NOTIFY-4): the relay or root, nothing else. The
# away courier runs as root and carries the app's signed decision, so root must
# be accepted; a pure function makes that testable without a root daemon.
python3 - "$AUTHD" <<'PY' || fail=1
import importlib.machinery, importlib.util, sys
loader = importlib.machinery.SourceFileLoader("kids_authd", sys.argv[1])
spec = importlib.util.spec_from_loader("kids_authd", loader)
authd = importlib.util.module_from_spec(spec)
loader.exec_module(authd)
fails = []


def check(cond, label):
    print(("ok   " if cond else "FAIL ") + label)
    if not cond:
        fails.append(label)


check(authd.may_present_decide(1000, 1000), "DECIDE: the relay uid may present")
check(authd.may_present_decide(0, 1000), "DECIDE: root (the away courier) may present")
check(authd.may_present_decide(0, None), "DECIDE: root may present with no relay uid")
check(not authd.may_present_decide(1001, 1000), "DECIDE: another account is refused")
check(not authd.may_present_decide(None, 1000), "DECIDE: an unknown peer is refused")
sys.exit(1 if fails else 0)
PY

TMP="$(mktemp -d)"
DAEMON_PID=""
# shellcheck disable=SC2329 # invoked via `trap ... EXIT`, not called directly
HOSTILE=""
cleanup() {
  [[ -n "$DAEMON_PID" ]] && kill "$DAEMON_PID" >/dev/null 2>&1
  [[ -n "$DAEMON_PID" ]] && wait "$DAEMON_PID" 2>/dev/null
  rm -rf "$TMP"
  [[ -n "$HOSTILE" ]] && rm -rf "$HOSTILE"
  return 0
}
trap cleanup EXIT

PARENT="testparent"
ACTUAL_PARENT="$(id -un)"
LITERAL_PARENT="literalparent"
# $6$saltsalt$... is a fixed sha512-crypt hash of "secret123" (openssl passwd
# -6 -salt saltsalt secret123). The $6$ format is glibc/libxcrypt-standard,
# so this string verifies the same on any Linux box regardless of how it was
# produced.
SHADOW="$TMP/shadow"
cat >"$SHADOW" <<'EOF'
testparent:$6$saltsalt$4wxWeHqpAHNNJcQMSu6jvr3dQTQoGoqMQhPAP0o5Ygzna6vr4y0u6.EZzboAAqg6dXU4q/OfcYqdrvZixR76r0:19000:0:99999:7:::
EOF
chmod 600 "$SHADOW"
printf '%s\n' "$ACTUAL_PARENT:\$6\$saltsalt\$4wxWeHqpAHNNJcQMSu6jvr3dQTQoGoqMQhPAP0o5Ygzna6vr4y0u6.EZzboAAqg6dXU4q/OfcYqdrvZixR76r0:19000:0:99999:7:::" >>"$SHADOW"
printf '%s\n' "$LITERAL_PARENT:\$6\$saltsalt\$0FVsTi4s.CcD67i2TdHHh5LCdakVZDinKQex3IDU3pxpBcNZAf16uKS5Pl8ESI02Hn7q7RH9Opfd1SKhEMYRj.:19000:0:99999:7:::" >>"$SHADOW"
SOCK="$TMP/auth.sock"

send() { # candidate -> ordinary VERIFY frame, prints daemon's reply, trimmed
  printf 'VERIFY\n%s\n' "$1" | python3 -c '
import socket, sys
s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM); s.settimeout(5)
s.connect(sys.argv[1]); s.sendall(sys.stdin.buffer.read()); s.shutdown(socket.SHUT_WR)
sys.stdout.write(s.recv(4096).decode(errors="replace").strip())
' "$SOCK"
}

send_bootstrap() { # candidate -> BOOTSTRAP frame, prints the daemon's reply
  printf 'BOOTSTRAP\n%s\n' "$1" | python3 -c '
import socket, sys
s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM); s.settimeout(5)
s.connect(sys.argv[1]); s.sendall(sys.stdin.buffer.read()); s.shutdown(socket.SHUT_WR)
sys.stdout.write(s.recv(4096).decode(errors="replace").strip())
' "$SOCK"
}

# =====================================================================
# review S1/S2/S3: the GRANT allowlist and the peer-uid check
# =====================================================================
#
# Unit-level, against the daemon's own check_grant(), so this runs on every
# platform (no socket, no crypt(3), no root). check_grant is what stands
# between a kid's request and root applying it.

ETC="$TMP/etc"
mkdir -p "$ETC/kids"
ME="$(id -un)"
printf 'band=6-8\n' >"$ETC/kids/$ME.conf"
printf 'band=6-8\n' >"$ETC/kids/kid-ada.conf"

# grant_check JSON UID -> the refusal reason, or "OK". The request goes
# through a file, not argv, so no amount of shell quoting can change what
# check_grant actually sees.
grant_check() {
  printf '%s' "$1" >"$TMP/request.json"
  python3 - "$AUTHD" "$DIR/lib" "$ETC" "$TMP/request.json" "$2" <<'PYEOF'
import importlib.machinery, importlib.util, json, sys
spec = importlib.util.spec_from_loader("authd", importlib.machinery.SourceFileLoader("authd", sys.argv[1]))
authd = importlib.util.module_from_spec(spec); spec.loader.exec_module(authd)
with open(sys.argv[4], encoding="utf-8") as f:
    request = json.load(f)
reason = authd.check_grant(request, int(sys.argv[5]), sys.argv[3], sys.argv[2])
print("OK" if reason is None else reason)
PYEOF
}

MYUID="$(id -u)"

# req KID KIND WHAT [MINUTES] -- one request as a JSON line. Built here
# rather than inline at each call site: an unquoted {a,b,c} is a brace
# expansion, and a JSON object inline in a test is exactly that shape.
req() {
  local kid="$1" kind="$2" what="$3" minutes="${4:-}"
  if [[ -n "$minutes" ]]; then
    printf '{"kid":"%s","kind":"%s","what":"%s","minutes":%s}' "$kid" "$kind" "$what" "$minutes"
  else
    printf '{"kid":"%s","kind":"%s","what":"%s"}' "$kid" "$kind" "$what"
  fi
}

check "$(grant_check "$(req "$ME" app minecraft)" "$MYUID")" "OK" \
  "a well-formed grant from its own uid is allowed"
check "$(grant_check "$(req "$ME" time 30 30)" "$MYUID")" "OK" \
  "a well-formed time grant is allowed"

# S2: the kid field is checked against the connecting peer's real uid.
r="$(grant_check "$(req kid-ada time 600 600)" "$MYUID")"
case "$r" in
  OK) bad "S2: a grant for someone else's account was allowed" ;;
  *"not 'kid-ada'"*) ok "S2: a grant naming another kid is refused (peer uid decides)" ;;
  *) bad "S2: refused, but for the wrong reason ($r)" ;;
esac

# S3: a path-like kid never gets as far as a filesystem path.
while read -r kid kind what minutes; do
  [[ -n "$kid" ]] || continue
  j="$(req "$kid" "$kind" "$what" "${minutes//-/}")"
  r="$(grant_check "$j" "$MYUID" 2>&1)"
  if [[ "$r" == "OK" ]]; then
    bad "S3: the allowlist accepted a request it must refuse: $j"
  elif [[ -z "$r" ]]; then
    bad "S3: check_grant crashed instead of refusing: $j"
  else
    ok "S3: refused $j"
  fi
done <<EOF
../../../../etc/sudoers.d site x.com -
$ME site ../../etc/passwd -
$ME site .hidden -
$ME app a/b -
$ME shell bash -
$ME time 99999 99999
$ME time 5 600
EOF

# An account with no profile is not a kid, however well-formed the request.
rm -f "$ETC/kids/$ME.conf"
r="$(grant_check "$(req "$ME" app minecraft)" "$MYUID")"
case "$r" in
  *"not a provisioned kid"*) ok "an unprovisioned account cannot be granted anything" ;;
  *) bad "an unprovisioned account was not refused ($r)" ;;
esac
printf 'band=6-8\n' >"$ETC/kids/$ME.conf"

# =====================================================================
# review S7: the rate limiter is per peer uid, and it decays
# =====================================================================

limiter_out="$(
  python3 - "$AUTHD" <<'PYEOF'
import importlib.machinery, importlib.util, sys
spec = importlib.util.spec_from_loader("authd", importlib.machinery.SourceFileLoader("authd", sys.argv[1]))
authd = importlib.util.module_from_spec(spec); spec.loader.exec_module(authd)
lim = authd.RateLimiter()
for _ in range(10):
    lim.record_wrong(1001)              # the kid, hammering the socket
print("kid-locked" if lim.locked(1001) else "kid-open")
print("parent-locked" if lim.locked(1000) else "parent-open")
lim.record_correct(1000)
print("parent-still-open" if not lim.locked(1000) else "parent-still-locked")
PYEOF
)"
check "$(sed -n 1p <<<"$limiter_out")" "kid-locked" "S7: ten misses lock the uid that made them"
check "$(sed -n 2p <<<"$limiter_out")" "parent-open" "S7: the parent's uid is untouched by the kid's misses"
check "$(sed -n 3p <<<"$limiter_out")" "parent-still-open" "S7: the parent can still verify while the kid is locked out"

# R-BOOTMODE-7: bootstrap is bound to the kernel peer's eligible parent
# account, so passwordless sudo cannot make a wrong candidate pass. These
# calls use the real uid lookup and eligibility check, with no identity mocks.
bootstrap_out="$(
  python3 - "$AUTHD" "$SHADOW" <<'PYEOF'
import importlib.machinery, importlib.util, sys
spec = importlib.util.spec_from_loader("authd_bootstrap", importlib.machinery.SourceFileLoader("authd_bootstrap", sys.argv[1]))
module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
limiter = module.RateLimiter()
nonwheel = next((entry.pw_uid for entry in __import__("pwd").getpwall()
                 if entry.pw_uid > 0 and not module.is_eligible_parent(entry.pw_uid)), None)
for label, uid in (("root", 0), ("lookup-failure", -1), ("non-wheel", nonwheel)):
    if uid is None:
        print(f"{label} skip")
    else:
        print(f"{label} no" if not module.verify_bootstrap(
            b"secret123", None, sys.argv[2], limiter, uid
        ) else f"{label} accepted")
PYEOF
)"
check "$(sed -n '1p' <<<"$bootstrap_out")" "root no" \
  "R-BOOTMODE-7: bootstrap rejects a root peer"
check "$(sed -n '2p' <<<"$bootstrap_out")" "lookup-failure no" \
  "R-BOOTMODE-7: bootstrap rejects a uid lookup failure"
case "$(sed -n '3p' <<<"$bootstrap_out")" in
  "non-wheel no" | "non-wheel skip") ok "R-BOOTMODE-7: bootstrap rejects a non-wheel peer" ;;
  *) bad "R-BOOTMODE-7: non-wheel peer was accepted ($bootstrap_out)" ;;
esac

# =====================================================================
# review S4: the verifier a kid runs is not a verifier a kid controls
# =====================================================================

# Deliberately OUTSIDE $TMP: $TMP is the build-time test root the copy
# below is allowed to use, and the whole point is that nothing else is.
HOSTILE="$(mktemp -d)"
python3 - "$HOSTILE/yes.sock" <<'PYEOF' &
import os, socket, sys
p = sys.argv[1]
s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
if os.path.exists(p):
    os.unlink(p)
s.bind(p); s.listen(5)
while True:
    try:
        c, _ = s.accept()
    except OSError:
        break
    try:
        c.recv(4096); c.sendall(b"ok\n")
    finally:
        c.close()
PYEOF
HOSTILE_PID=$!
for _ in $(seq 1 50); do
  [[ -S "$HOSTILE/yes.sock" ]] && break
  sleep 0.1
done

# A kid's environment says "ask this socket instead". The verifier reads
# no environment at all now (review §2.1), so this must be ignored.
if OMARCHY_KIDS_AUTH_SOCK="$HOSTILE/yes.sock" bash -c "echo anything | '$CLIENT'"; then
  bad "S4: OMARCHY_KIDS_AUTH_SOCK was honoured"
else
  ok "S4: OMARCHY_KIDS_AUTH_SOCK is ignored (the verifier reads no environment)"
fi
check "$(grep -c 'OMARCHY_KIDS_' "$CLIENT")" "0" \
  "S4: the verifier's source mentions no OMARCHY_KIDS_* variable at all"

# ...and so must the flag.
if bash -c "echo anything | '$CLIENT' --socket '$HOSTILE/yes.sock'"; then
  bad "S4: --socket from a non-root caller was honoured"
else
  ok "S4: --socket is refused for a non-root caller"
fi

# A kid-controlled PATH must not be able to make the helper believe it is
# root. The hostile socket answers "ok", so a bare `id -u` would turn this
# into a false success.
mkdir -p "$HOSTILE/bin"
printf '%s\n' '#!/bin/bash' 'echo 0' >"$HOSTILE/bin/id"
chmod +x "$HOSTILE/bin/id"
if [[ "$(/usr/bin/id -u)" == 0 ]]; then
  ok "S4: hostile-PATH root-check regression is not applicable to root"
else
  set +e
  probe_output="$(PATH="$HOSTILE/bin:$PATH" /bin/bash -c "echo anything | '$CLIENT' --socket '$HOSTILE/yes.sock'" 2>&1)"
  probe_status=$?
  set -u
  if [[ "$probe_status" == 1 && "$probe_output" == *"root-only"* ]]; then
    ok "S4: parent-auth root check ignores a hostile PATH"
  else
    bad "S4: a hostile PATH changed the root-only socket result (status $probe_status, output '$probe_output')"
  fi
fi

# The build-time test root is the only exception, and it is empty in the
# file as committed (test/shell.d/pkgbuild-test.sh asserts that too).
check "$(grep -c '^TEST_SOCKET_ROOT=""$' "$CLIENT")" "1" \
  "S4: the shipped verifier has an empty build-time test socket root"

# The copy runs from a scratch tree (lib/ beside it), because it resolves
# lib/ from its own `readlink -f "$0"` and from nowhere else.
source "$(dirname "${BASH_SOURCE[0]}")/tree.sh"
kids_tree "$TMP/tree" "$DIR"
TESTCLIENT="$TMP/tree/bin/omarchy-kids-parent-auth"
sed "s|^TEST_SOCKET_ROOT=\"\"$|TEST_SOCKET_ROOT=\"$TMP\"|" "$CLIENT" >"$TESTCLIENT"
chmod +x "$TESTCLIENT"

# Sanity: the copy really can speak to a socket under its own test root,
# so the refusals below are refusals, not a broken script.
if bash -c "echo anything | '$TESTCLIENT' --socket '$TMP/nothing-listening.sock'" 2>&1 | grep -q "no way to reach"; then
  bad "the test copy of the verifier cannot speak the protocol at all"
else
  ok "the test copy of the verifier can use a socket under its own test root"
fi
if bash -c "echo anything | '$TESTCLIENT' --socket '$HOSTILE/yes.sock'"; then
  bad "S4: a socket outside the build-time test root was honoured"
else
  ok "S4: even with a test root, a socket outside it is refused"
fi

kill "$HOSTILE_PID" >/dev/null 2>&1
wait "$HOSTILE_PID" 2>/dev/null

# The PAM line names the helper by absolute path, so pam_exec never
# consults the kid's PATH, and the helper above never consults the kid's
# environment for the socket either.
check "$(grep -c 'pam_exec.so quiet expose_authtok /usr/bin/omarchy-kids-parent-auth' "$DIR/lib/posture.sh")" "1" \
  "S4: the PAM line execs the verifier by absolute path"
check "$(grep -c 'systemctl enable --now omarchy-kids-authd.socket' "$DIR/omarchy-kids.install")" "1" \
  "package installation enables and starts authd before the first wizard run"
check "$(grep -c 'OMARCHY_KIDS_PARENT' "$AUTHD")" "0" \
  "authd does not let an environment variable select the parent account"

# The authd socket is the first parent-auth dependency. A failed startup must
# fail the scriptlet rather than being hidden by a best-effort `|| true`.
INSTALL_RUN="$TMP/fake-run/systemd/system"
INSTALL_STUBS="$TMP/install-stubs"
INSTALL_COPY="$TMP/omarchy-kids.install"
mkdir -p "$INSTALL_RUN" "$INSTALL_STUBS"
sed "s|/run/systemd/system|$INSTALL_RUN|g" "$DIR/omarchy-kids.install" >"$INSTALL_COPY"
cat >"$INSTALL_STUBS/groupadd" <<'EOF'
#!/bin/bash
exit 0
EOF
cat >"$INSTALL_STUBS/systemctl" <<'EOF'
#!/bin/bash
if [[ "$*" == *"enable --now omarchy-kids-authd.socket"* ]]; then
  [[ "${FAIL_ENABLE:-0}" == 1 ]] && exit 1
fi
if [[ "$*" == *"try-restart omarchy-kids-authd.service"* ]]; then
  [[ "${FAIL_TRY_RESTART:-0}" == 1 ]] && exit 1
fi
exit 0
EOF
chmod +x "$INSTALL_STUBS"/*
if (
  PATH="$INSTALL_STUBS:$PATH"
  export FAIL_ENABLE=1
  . "$INSTALL_COPY"
  post_install >/dev/null 2>&1
); then
  bad "a failed authd socket startup is returned by post_install"
else
  ok "a failed authd socket startup is returned by post_install"
fi
if (
  PATH="$INSTALL_STUBS:$PATH"
  export FAIL_TRY_RESTART=1
  . "$INSTALL_COPY"
  post_upgrade >/dev/null 2>&1
); then
  bad "a failed authd restart is returned by post_upgrade"
else
  ok "a failed authd restart is returned by post_upgrade"
fi
check "$(grep -c 'to `id -un`' "$DIR/docs/conf.md")" "1" \
  "conf documentation names id -un as the parent identity source"
check "$(grep -c 'OMARCHY_KIDS_INVOKING_USER' "$DIR/docs/conf.md")" "0" \
  "conf documentation names no invoking-user environment override"
# =====================================================================
# GRANT over the wire: what must be refused, refused everywhere
# =====================================================================
#
# These run on every platform: every one of them is refused before the
# password is ever consulted, so no crypt(3) is needed to prove that root
# applied nothing. (macOS has no SO_PEERCRED, so the peer-uid check refuses
# there for that reason instead -- either way the answer is "no".)

send2() { # header password -> reply, trimmed
  printf '%s\n%s\n' "$1" "$2" | python3 -c '
import socket, sys
s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM); s.settimeout(5)
s.connect(sys.argv[1]); s.sendall(sys.stdin.buffer.read()); s.shutdown(socket.SHUT_WR)
sys.stdout.write(s.recv(4096).decode(errors="replace").strip())
' "$SOCK"
}

send_decide() { # frame-file -> reply, trimmed
  python3 - "$SOCK" "$1" <<'PY'
import socket, sys
s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM); s.settimeout(5)
s.connect(sys.argv[1])
s.sendall(b"DECIDE " + open(sys.argv[2], "rb").read() + b"\n")
sys.stdout.write(s.recv(4096).decode(errors="replace").strip())
PY
}

send_pair() { # frame-file -> reply, trimmed
  python3 - "$SOCK" "$1" <<'PY'
import socket, sys
s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM); s.settimeout(5)
s.connect(sys.argv[1])
s.sendall(b"PAIR " + open(sys.argv[2], "rb").read() + b"\n")
sys.stdout.write(s.recv(4096).decode(errors="replace").strip())
PY
}

send_review() { # frame-file -> reply, trimmed
  python3 - "$SOCK" "$1" <<'PY'
import socket, sys
s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM); s.settimeout(5)
s.connect(sys.argv[1])
s.sendall(b"REVIEW " + open(sys.argv[2], "rb").read() + b"\n")
sys.stdout.write(s.recv(4096).decode(errors="replace").strip())
PY
}

# A record of every apply-grant the daemon asks for, so we can prove it
# asked for none of the ones it should have refused.
APPLIED="$TMP/applied.log"
cat >"$TMP/fake-ask" <<EOF
#!/bin/bash
printf '%s\n' "\$*" >> "$APPLIED"
EOF
chmod +x "$TMP/fake-ask"
: >"$APPLIED"
DEV_APPLIED="$TMP/dev-applied.log"
cat >"$TMP/fake-devices" <<EOF
#!/bin/bash
printf '%s\n' "\$*" >> "$DEV_APPLIED"
EOF
chmod +x "$TMP/fake-devices"
: >"$DEV_APPLIED"
REVIEW_APPLIED="$TMP/review-applied.log"
cat >"$TMP/fake-review" <<EOF
#!/bin/bash
printf '%s\n' "\$*" >> "$REVIEW_APPLIED"
EOF
chmod +x "$TMP/fake-review"
: >"$REVIEW_APPLIED"

start_daemon() {
  local parent="${1:-$PARENT}" relay="${2:-$(id -un)}"
  kill "$DAEMON_PID" >/dev/null 2>&1
  [[ -n "$DAEMON_PID" ]] && wait "$DAEMON_PID" 2>/dev/null
  rm -f "$SOCK"
  python3 "$AUTHD" --socket "$SOCK" --shadow "$SHADOW" --parent "$parent" \
    --etc "$ETC" --lib "$DIR/lib" --ask-bin "$TMP/fake-ask" \
    --devices-bin "$TMP/fake-devices" --pairing-dir "$TMP/pairing" \
    --reviews-dir "$TMP/reviews/open" --review-bin "$TMP/fake-review" \
    --nonce-ledger "$TMP/nonces.json" --relay-user "$relay" &
  DAEMON_PID=$!
  for _ in $(seq 1 50); do
    [[ -S "$SOCK" ]] && break
    sleep 0.1
  done
  [[ -S "$SOCK" ]]
}

if ! start_daemon; then
  echo "SKIP authd-test.sh: this host cannot bind the temporary Unix socket"
  exit $fail
fi

# Every shape the review named, over the real socket. None may be applied.
while read -r label kid kind what minutes password; do
  [[ -n "$label" ]] || continue
  : >"$APPLIED"
  r="$(send2 "GRANT $(req "$kid" "$kind" "$what" "${minutes//-/}")" "$password")"
  case "$r" in
    no*) ok "GRANT refused: $label" ;;
    *) bad "GRANT was NOT refused ($label): got '$r'" ;;
  esac
  check "$(wc -l <"$APPLIED" | tr -d ' ')" "0" "GRANT applied nothing: $label"
done <<EOF
wrong password $ME app minecraft - wrongpass
another kid's account kid-ada time 600 600 secret123
a path-like kid ../../../../etc/sudoers.d site x.com - secret123
a path-like host $ME site ../../etc/passwd - secret123
an unknown kind $ME shell bash - secret123
an out-of-range time $ME time 99999 99999 secret123
EOF

# A malformed GRANT line is refused without a traceback or a hang.
r="$(send2 "GRANT not-json-at-all" "secret123")"
case "$r" in
  no*) ok "a malformed GRANT is refused" ;;
  *) bad "a malformed GRANT gave '$r'" ;;
esac

# =====================================================================
# DECIDE: a paired device's signed decision (R-NOTIFY-4). Needs crypto.
# =====================================================================
if python3 -c "import cryptography" >/dev/null 2>&1; then
  mkdir -p "$ETC/devices"
  python3 - "$DIR/lib/devices.py" "$ETC" "$TMP" <<'PY'
import base64, importlib.util, json, os, sys, time
devices_py, etc, tmp = sys.argv[1], sys.argv[2], sys.argv[3]
spec = importlib.util.spec_from_file_location("kids_devices", devices_py)
devices = importlib.util.module_from_spec(spec)
spec.loader.exec_module(devices)
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
key = Ed25519PrivateKey.generate()
pub = base64.b64encode(key.public_key().public_bytes_raw()).decode()
os.makedirs(os.path.join(etc, "devices"), exist_ok=True)
with open(os.path.join(etc, "devices", "d1.conf"), "w") as f:
    f.write(f"id=d1\nname=Phone\nplatform=android\nsign_pub={pub}\nbox_pub={pub}\nscopes=decide,act\n")
rec = {"device_id": "d1", "request_id": "req-1", "decision": "approve", "reply": "After dinner", "ts": int(time.time()), "nonce": "n1"}
sig = base64.b64encode(key.sign(devices.canonical(rec))).decode()
with open(os.path.join(tmp, "decide-frame.json"), "w") as f:
    json.dump({"record": rec, "signature": sig}, f, separators=(",", ":"))
PY
  start_daemon
  : >"$APPLIED"
  r="$(send_decide "$TMP/decide-frame.json")"
  if [[ "$(uname -s)" == "Linux" ]]; then
    # SO_PEERCRED is what makes the relay check real; it is Linux-only.
    check "$r" "ok" "DECIDE: a device's signed decision is applied"
    check "$(wc -l <"$APPLIED" | tr -d ' ')" "1" "DECIDE: exactly one apply ran"
    grep -q 'approve req-1 --by device:d1 --apply' "$APPLIED" &&
      ok "DECIDE: applied through omarchy-kids-ask by device id" ||
      bad "DECIDE: did not apply through ask"
    grep -q -- '--reply After dinner' "$APPLIED" &&
      ok "DECIDE: the signed reply line reaches the queue record" ||
      bad "DECIDE: the reply was dropped"
    check "$(send_decide "$TMP/decide-frame.json")" "no replayed-nonce" "DECIDE: a replay is refused"
    check "$(wc -l <"$APPLIED" | tr -d ' ')" "1" "DECIDE: a replay applied nothing"
    # A resolved but wrong relay account is a uid mismatch, not a missing one.
    start_daemon "$PARENT" nobody
    check "$(send_decide "$TMP/decide-frame.json")" "no not the relay" "DECIDE: a resolved non-relay account is refused"
    check "$(wc -l <"$APPLIED" | tr -d ' ')" "1" "DECIDE: a non-relay caller applied nothing"
  else
    # Elsewhere peer_uid is unknown, so the relay check fails closed.
    check "$r" "no not the relay" "DECIDE: without SO_PEERCRED it fails closed (the gate runs the accept path)"
  fi
  start_daemon "$PARENT" "no-such-relay-account"
  check "$(send_decide "$TMP/decide-frame.json")" "no not the relay" "DECIDE: an unresolved relay account is refused"

  # ---- REVIEW: a device's signed add-on review decision (R-NOTIFY-12) ----
  python3 - "$DIR/lib/devices.py" "$ETC" "$TMP" <<'PY'
import base64, importlib.util, json, os, sys, time
devices_py, etc, tmp = sys.argv[1], sys.argv[2], sys.argv[3]
spec = importlib.util.spec_from_file_location("kids_devices", devices_py)
devices = importlib.util.module_from_spec(spec); spec.loader.exec_module(devices)
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey

def device(name, dev_id, scopes):
    key = Ed25519PrivateKey.generate()
    pub = base64.b64encode(key.public_key().public_bytes_raw()).decode()
    with open(os.path.join(etc, "devices", name + ".conf"), "w") as f:
        f.write(f"id={dev_id}\nname=Phone\nplatform=android\nsign_pub={pub}\nbox_pub={pub}\nscopes={scopes}\n")
    return key

# d2 may decide; d3 may not (the scope comes from the registry, never the frame).
decision_key = device("d2", "d2", "decide,act")
nodecide_key = device("d3", "d3", "act")
app_id = "firefox"
rid = devices.review_id_for("kid-ada", app_id)
gone = devices.review_id_for("kid-ada", "gone")
seen = "ab" * 32
now = int(time.time())

def write_review(review_id, now_fp):
    os.makedirs(os.path.join(tmp, "reviews", "open"), exist_ok=True)
    with open(os.path.join(tmp, "reviews", "open", review_id + ".json"), "w") as f:
        json.dump({"kid": "kid-ada", "id": app_id, "was": "aa" * 32, "now": now_fp,
                   "detected_at": now, "state": "open"}, f)

def frame(key, dev_id, review_id, decision, seen_fp, nonce):
    rec = {"device_id": dev_id, "review_id": review_id, "decision": decision,
           "seen": seen_fp, "ts": int(time.time()), "nonce": nonce}
    sig = base64.b64encode(key.sign(devices.canonical(rec))).decode()
    return {"record": rec, "signature": sig}

write_review(rid, seen)  # the review the parent looked at, still at `seen`
frames = {
    "review-approve.json": frame(decision_key, "d2", rid, "approve", seen, "r1"),
    "review-deny.json": frame(decision_key, "d2", rid, "deny", seen, "r2"),
    "review-changed.json": frame(decision_key, "d2", rid, "approve", "cd" * 32, "r3"),
    "review-gone.json": frame(decision_key, "d2", gone, "approve", seen, "r4"),
    "review-scope.json": frame(nodecide_key, "d3", rid, "approve", seen, "r5"),
    # A request decision's record: the wrong shape, so it can never ride REVIEW.
    "review-malformed.json": {"record": {"device_id": "d2", "request_id": "req-1",
                                          "decision": "approve", "ts": int(time.time()),
                                          "nonce": "r6"}, "signature": "AA=="},
}

# ---- ACT (R-NOTIFY-13): grant and end -------------------------------------
act_key = device("d6", "d6", "act")
decide_only_key = device("d7", "d7", "decide")
# The profile kid_account_ok looks for (authd validates the target before it acts).
os.makedirs(os.path.join(etc, "kids"), exist_ok=True)
with open(os.path.join(etc, "kids", "kid-ada.conf"), "w") as f:
    f.write("name=Ada\nband=6-8\n")

def act_frame(key, dev_id, account, action, nonce, minutes=None):
    rec = {"device_id": dev_id, "account": account, "action": action,
           "ts": int(time.time()), "nonce": nonce}
    if minutes is not None:
        rec["minutes"] = minutes
    sig = base64.b64encode(key.sign(devices.canonical(rec))).decode()
    return {"record": rec, "signature": sig}

frames.update({
    "act-grant.json": act_frame(act_key, "d6", "kid-ada", "grant", "a1", 15),
    "act-end.json": act_frame(act_key, "d6", "kid-ada", "end", "a2"),
    "act-root.json": act_frame(act_key, "d6", "root", "grant", "a3", 15),
    "act-scope.json": act_frame(decide_only_key, "d7", "kid-ada", "grant", "a4", 15),
    "act-zero.json": act_frame(act_key, "d6", "kid-ada", "grant", "a5", 0),
    "act-end-minutes.json": act_frame(act_key, "d6", "kid-ada", "end", "a6", 15),
    "act-replay.json": act_frame(act_key, "d6", "kid-ada", "grant", "a1", 15),
    "act-malformed.json": {"record": {"device_id": "d6", "request_id": "req-1",
                                      "decision": "approve", "ts": int(time.time()),
                                      "nonce": "a7"}, "signature": "AA=="},
})
for name, obj in frames.items():
    with open(os.path.join(tmp, name), "w") as f:
        json.dump(obj, f, separators=(",", ":"))
PY
  # The open-review file rules are pure and platform-free: check them here, so
  # they are covered wherever the suite runs, not only where SO_PEERCRED is.
  if python3 - "$DIR/lib/devices.py" "$TMP/reviews" <<'PY'
import importlib.util, json, os, sys
devices_py, reviews = sys.argv[1], sys.argv[2]
spec = importlib.util.spec_from_file_location("kids_devices", devices_py)
d = importlib.util.module_from_spec(spec); spec.loader.exec_module(d)
open_dir = os.path.join(reviews, "open")
rid = d.review_id_for("kid-ada", "firefox")
fails = []

def want(ok, what):
    if not ok:
        fails.append(what)

record, reason = d.read_open_review(open_dir, rid)
want(record is not None and reason == "ok", "an open review reads")
want(d.read_open_review(open_dir, d.review_id_for("kid-ada", "gone")) == (None, "no-such-review"),
     "a review that is not there is refused")
want(d.read_open_review(open_dir, "../../etc/shadow") == (None, "no-such-review"),
     "a path-like review id is refused")
closed_id = "kid-ada." + "0" * 16
with open(os.path.join(open_dir, closed_id + ".json"), "w") as f:
    json.dump({"kid": "kid-ada", "id": "x", "now": "aa", "state": "closed"}, f)
want(d.read_open_review(open_dir, closed_id)[1] == "no-such-review", "a closed review is refused")
mismatch_id = "kid-ada." + "1" * 16
with open(os.path.join(open_dir, mismatch_id + ".json"), "w") as f:
    json.dump({"kid": "kid-ada", "id": "com.example.other", "now": "aa", "state": "open"}, f)
want(d.read_open_review(open_dir, mismatch_id)[1] == "no-such-review",
     "a file whose app id does not match the review id is refused")
kid_id = "kid-dot." + rid.split(".", 1)[1]
with open(os.path.join(open_dir, kid_id + ".json"), "w") as f:
    json.dump({"kid": "kid-ada", "id": "firefox", "now": "aa", "state": "open"}, f)
want(d.read_open_review(open_dir, kid_id)[1] == "no-such-review",
     "a file whose kid does not match the review id is refused")
link_id = "kid-ada." + "2" * 16
os.symlink(os.path.join(open_dir, rid + ".json"), os.path.join(open_dir, link_id + ".json"))
want(d.read_open_review(open_dir, link_id)[1] == "no-such-review", "a symlinked review is refused")
print("; ".join(fails))
sys.exit(1 if fails else 0)
PY
  then
    ok "REVIEW: the open-review file rules hold (open, missing, path-like, closed, mismatch, symlink)"
  else
    bad "REVIEW: the open-review file rules failed"
  fi
  # The handler called directly, with the peer check patched to root, so the
  # verify-and-apply path is covered where SO_PEERCRED is not (this dev box).
  if python3 - "$AUTHD" "$DIR/lib/devices.py" "$ETC" "$TMP" <<'PY'
import importlib.machinery, importlib.util, json, os, sys
authd_path, devices_py, etc, tmp = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
loader = importlib.machinery.SourceFileLoader("kids_authd", authd_path)
spec = importlib.util.spec_from_loader("kids_authd", loader)
authd = importlib.util.module_from_spec(spec); loader.exec_module(authd)
spec2 = importlib.util.spec_from_file_location("kids_devices", devices_py)
devices = importlib.util.module_from_spec(spec2); spec2.loader.exec_module(devices)


class Cfg:
    pass


cfg = Cfg()
cfg.devices = devices
cfg.ledger = devices.NonceLedger(os.path.join(tmp, "direct-nonces.json"))
cfg.etc = etc
cfg.reviews_dir = os.path.join(tmp, "reviews", "open")
cfg.review_bin = os.path.join(tmp, "fake-review")
cfg.relay_uid = None
# The fake review bin appends its argv to this file (see $REVIEW_APPLIED above).
applied = os.path.join(tmp, "review-applied.log")
open(applied, "w").close()
authd.peer_uid = lambda conn: 0  # root may present a REVIEW

fails = []


def want(got, want_value, what):
    if got != want_value:
        fails.append(f"{what}: want {want_value!r}, got {got!r}")


def send(name):
    with open(os.path.join(tmp, name)) as f:
        frame = json.load(f)
    line = "REVIEW " + json.dumps(frame, separators=(",", ":"))
    return authd.handle_review(line, None, cfg).decode().strip()


want(send("review-approve.json"), "ok", "an approve frame applies")
want("approve kid-ada firefox --seen " + "ab" * 32 + " --apply" in open(applied).read(), True,
     "the review command ran with the file's own kid, id, and the signed fingerprint")
want(send("review-approve.json"), "no replayed-nonce", "the same frame twice is a replay")
want(send("review-deny.json"), "ok", "a deny frame applies")
want("deny kid-ada firefox --apply" in open(applied).read(), True, "the deny verb ran")
want(send("review-changed.json"), "no changed-again",
     "a fingerprint the app did not sign is refused")
want(send("review-gone.json"), "no no-such-review", "a review that is not open is refused")
want(send("review-scope.json"), "no scope-missing", "a device without the decide scope is refused")
want(send("review-malformed.json"), "no malformed", "a request record cannot ride REVIEW")

# ---- ACT (R-NOTIFY-13): grant and end, from the handler called directly -----
# The target check is stubbed to one account so the grant/end wiring is covered
# on any platform; devices-test.sh covers the real kid_account_ok rules. The
# real check is still exercised unpatched, below.
act_log = os.path.join(tmp, "act-applied.log")
fake_act = os.path.join(tmp, "fake-act")
with open(fake_act, "w") as f:
    f.write("#!/bin/bash\nprintf '%s\\n' \"$*\" >> " + act_log + "\n")
os.chmod(fake_act, 0o755)
cfg.time_bin = fake_act
cfg.exit_bin = fake_act
real_kid_check = devices.kid_account_ok
devices.kid_account_ok = lambda etc_dir, account: account == "kid-ada"
open(act_log, "w").close()


def send_act(name):
    with open(os.path.join(tmp, name)) as f:
        frame = json.load(f)
    return authd.handle_act("ACT " + json.dumps(frame, separators=(",", ":")), None, cfg).decode().strip()


want(send_act("act-grant.json"), "ok", "a grant frame applies")
want("grant kid-ada 15" in open(act_log).read(), True, "granted through omarchy-kids-time")
want(send_act("act-grant.json"), "no replayed-nonce", "the same action twice is a replay")
want(send_act("act-end.json"), "ok", "an end frame applies")
want("--finish --kid kid-ada" in open(act_log).read(), True, "ended through omarchy-kids-exit --finish")
want(send_act("act-root.json"), "no not-a-kid", "the parent/root is never a target")
want("grant root" in open(act_log).read(), False, "a refused target ran nothing")
want(send_act("act-scope.json"), "no scope-missing", "a decide-only device cannot act")
want(send_act("act-zero.json"), "no malformed", "minutes out of range is refused")
want(send_act("act-end-minutes.json"), "no malformed", "an end carrying minutes is refused")
want(send_act("act-malformed.json"), "no malformed", "a request record cannot ride ACT")
want(real_kid_check(etc, "root"), False, "kid_account_ok refuses root")
devices.kid_account_ok = real_kid_check
print("; ".join(fails))
sys.exit(1 if fails else 0)
PY
  then
    ok "REVIEW+ACT: the handlers apply, replay and refuse as specified (direct call)"
  else
    bad "REVIEW+ACT: the direct handler checks failed"
  fi
  start_daemon
  : >"$REVIEW_APPLIED"
  r="$(send_review "$TMP/review-approve.json")"
  if [[ "$(uname -s)" == "Linux" ]]; then
    check "$r" "ok" "REVIEW: a device's signed review decision is applied"
    grep -q 'approve kid-ada firefox --seen abababababababababababababababababababababababababababababababab --apply' "$REVIEW_APPLIED" &&
      ok "REVIEW: ran the review command with the file's own kid, id, and the signed fingerprint" ||
      bad "REVIEW: did not run the review command with the file's kid, id and fingerprint"
    check "$(send_review "$TMP/review-approve.json")" "no replayed-nonce" \
      "REVIEW: a replay is refused"
    check "$(send_review "$TMP/review-deny.json")" "ok" "REVIEW: a deny is applied"
    grep -q 'deny kid-ada firefox --apply' "$REVIEW_APPLIED" &&
      ok "REVIEW: ran the deny verb the command takes" ||
      bad "REVIEW: did not run deny"
    : >"$REVIEW_APPLIED"
    check "$(send_review "$TMP/review-changed.json")" "no changed-again" \
      "REVIEW: a review whose fingerprint moved since the app looked is refused"
    check "$(wc -l <"$REVIEW_APPLIED" | tr -d ' ')" "0" \
      "REVIEW: a changed-again applied nothing"
    check "$(send_review "$TMP/review-gone.json")" "no no-such-review" \
      "REVIEW: a decision for a review that is not open is refused"
    check "$(send_review "$TMP/review-scope.json")" "no scope-missing" \
      "REVIEW: a device without the decide scope is refused"
    check "$(send_review "$TMP/review-malformed.json")" "no malformed" \
      "REVIEW: a request-decision record cannot ride REVIEW"
  else
    check "$r" "no not the relay" "REVIEW: without SO_PEERCRED it fails closed"
  fi

  # PAIR: a single-use proof registers a device (R-NOTIFY-5)
  python3 - "$DIR/lib/devices.py" "$TMP/pairing" "$TMP/pair-frame.json" <<'PY'
import base64, importlib.util, json, sys, time
devices_py, pdir, out = sys.argv[1], sys.argv[2], sys.argv[3]
spec = importlib.util.spec_from_file_location("kids_devices", devices_py)
devices = importlib.util.module_from_spec(spec)
spec.loader.exec_module(devices)
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
k = Ed25519PrivateKey.generate()
pub = base64.b64encode(k.public_key().public_bytes_raw()).decode()
rec = devices.write_pairing(pdir, "dX", "decide,act", int(time.time()))
proof = devices.pairing_proof(rec["token"], "Phone", pub, pub)
with open(out, "w") as f:
    json.dump({"id": "dX", "name": "Phone", "platform": "android",
               "sign_pub": pub, "box_pub": pub, "proof": proof}, f, separators=(",", ":"))
PY
  start_daemon
  : >"$DEV_APPLIED"
  r="$(send_pair "$TMP/pair-frame.json")"
  if [[ "$(uname -s)" == "Linux" ]]; then
    check "$r" "ok" "PAIR: a valid pairing proof registers the device (R-NOTIFY-5)"
    grep -q 'add --id dX .*--by pair --apply' "$DEV_APPLIED" &&
      ok "PAIR: registered through omarchy-kids-devices (by pair, --apply)" ||
      bad "PAIR: did not register through the devices command"
    check "$(send_pair "$TMP/pair-frame.json")" "no unknown-pairing" "PAIR: the pairing record is single-use"
    # A failing registration must keep the record for a retry.
    python3 - "$DIR/lib/devices.py" "$TMP/pairing" "$TMP/pair-frame-2.json" <<'PY'
import base64, importlib.util, json, sys, time
devices_py, pdir, out = sys.argv[1], sys.argv[2], sys.argv[3]
spec = importlib.util.spec_from_file_location("kids_devices", devices_py)
devices = importlib.util.module_from_spec(spec)
spec.loader.exec_module(devices)
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
k = Ed25519PrivateKey.generate()
pub = base64.b64encode(k.public_key().public_bytes_raw()).decode()
rec = devices.write_pairing(pdir, "dY", "decide,act", int(time.time()))
proof = devices.pairing_proof(rec["token"], "Phone", pub, pub)
with open(out, "w") as f:
    json.dump({"id": "dY", "name": "Phone", "platform": "android",
               "sign_pub": pub, "box_pub": pub, "proof": proof}, f, separators=(",", ":"))
PY
    printf '#!/bin/bash\nexit 1\n' >"$TMP/fake-devices"
    chmod +x "$TMP/fake-devices"
    check "$(send_pair "$TMP/pair-frame-2.json")" "no apply failed" "PAIR: a failing registration keeps the record"
    cat >"$TMP/fake-devices" <<EOF
#!/bin/bash
printf '%s\n' "\$*" >> "$DEV_APPLIED"
EOF
    chmod +x "$TMP/fake-devices"
    check "$(send_pair "$TMP/pair-frame-2.json")" "ok" "PAIR: the kept record registers on a retry"
    start_daemon "$PARENT" nobody
    check "$(send_pair "$TMP/pair-frame.json")" "no not the relay" "PAIR: a resolved non-relay account is refused"
  else
    check "$r" "no not the relay" "PAIR: without SO_PEERCRED it fails closed"
  fi
else
  echo "SKIP authd-test.sh: DECIDE/PAIR checks need python-cryptography"
fi

# =====================================================================
# The live daemon (needs a working crypt(3) on this host)
# =====================================================================

if ! python3 -c 'import ctypes; next(l for n in ("libcrypt.so.2","libcrypt.so.1") for l in [__import__("ctypes").CDLL(n)])' >/dev/null 2>&1; then
  echo "SKIP authd-test.sh: libcrypt not loadable here -- the live-daemon password checks did not run"
  echo "     (the allowlist, peer-uid, rate-limiter and socket-redirection checks above did)"
  exit $fail
fi

start_daemon || exit $fail

check "$(send secret123)" "ok" "correct password -> ok"
check "$(send wrongpass)" "no" "wrong password -> no"

LONG="$(python3 -c 'print("a" * 600)')"
check "$(send "$LONG")" "no" "overlong line -> no (and doesn't count as a miss)"

if bash -c "echo secret123 | '$TESTCLIENT' --socket '$SOCK'"; then
  echo "ok   client exits 0 on correct password"
else
  echo "FAIL client exits 0 on correct password"
  fail=1
fi
if bash -c "echo wrongpass | '$TESTCLIENT' --socket '$SOCK'"; then
  echo "FAIL client should exit 1 on wrong password"
  fail=1
else
  echo "ok   client exits 1 on wrong password"
fi
if PAM_TYPE=account bash -c "echo secret123 | '$TESTCLIENT' --socket '$SOCK'"; then
  echo "FAIL client should exit 1 when PAM_TYPE != auth"
  fail=1
else
  echo "ok   client exits 1 when PAM_TYPE=account"
fi

# Two more misses cross the "three wrongs" threshold (one miss already spent
# above); a correct password offered while locked must still come back "no".
send bad1 >/dev/null
send bad2 >/dev/null
check "$(send secret123)" "no" "correct password while locked (3 misses) -> no"

# --- GRANT over the wire, the accepting half (needs crypt(3)) ------------

start_daemon || exit $fail
: >"$APPLIED"
r="$(send2 "GRANT $(req "$ME" app minecraft)" "secret123")"
check "$r" "ok" "GRANT with the right password, from the right uid, is granted"
check "$(grep -c -- "apply-grant --kid $ME --kind app --what minecraft --apply" "$APPLIED")" "1" \
  "GRANT applies through omarchy-kids-ask apply-grant, as root"

# The real socket uses the kernel peer uid for bootstrap eligibility. The
# expected result is derived from the daemon's real account and group lookups,
# not from a test double.
start_daemon "$ACTUAL_PARENT"
eligible="$(
  python3 - "$AUTHD" <<'PYEOF'
import importlib.machinery, importlib.util, os, sys
spec = importlib.util.spec_from_loader("authd_peer", importlib.machinery.SourceFileLoader("authd_peer", sys.argv[1]))
module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
print("ok" if module.is_eligible_parent(os.getuid()) else "no")
PYEOF
)"
check "$(send_bootstrap wrongpass)" "no" \
  "R-BOOTMODE-7: socket bootstrap rejects a wrong candidate"
check "$(send_bootstrap secret123)" "$eligible" \
  "R-BOOTMODE-7: socket bootstrap binds eligibility to SO_PEERCRED"

# Ordinary verification has an explicit frame, so a password equal to the
# BOOTSTRAP control word is still an ordinary candidate.
start_daemon "$LITERAL_PARENT"
check "$(send BOOTSTRAP)" "ok" \
  "ordinary VERIFY accepts the literal BOOTSTRAP password"

kill "$DAEMON_PID" >/dev/null 2>&1
wait "$DAEMON_PID" 2>/dev/null
DAEMON_PID=""

exit $fail
