#!/bin/bash
# Tests lib/courier.py and bin/omarchy-kids-relay-courier -- the one off-LAN
# process (SPEC.md R-NOTIFY-8, N-11). A local HTTP server captures what it posts,
# and the captured body must be a sealed envelope that opens with the device's
# private box key. Skips where python-cryptography is absent.
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=test/shell.d/lib.sh
source "$DIR/test/shell.d/lib.sh"
# shellcheck source=test/shell.d/tree.sh
source "$DIR/test/shell.d/tree.sh"

if ! python3 -c "import cryptography" >/dev/null 2>&1; then
  echo "SKIP courier-test.sh: python-cryptography not installed — the courier checks did not run"
  exit 0
fi

pass() { echo "PASS  $*"; }
fail() {
  echo "FAIL  $*"
  rc=1
}
rc=0
check_status() { # got want label
  if [[ "$1" == "$2" ]]; then pass "$3"; else fail "$3 (want exit $2, got $1)"; fi
}
check_contains() { # haystack needle label
  if [[ "$1" == *"$2"* ]]; then pass "$3"; else fail "$3 (want '$2' in '$1')"; fi
}

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"; [[ -n "${SERVER_PID:-}" ]] && kill "$SERVER_PID" 2>/dev/null' EXIT
STUBS="$TMP/stubs"
ETC="$TMP/etc"
ROOT="$TMP/root"
mkdir -p "$STUBS" "$ETC/relay" "$ROOT/run/omarchy-kids"

kids_tree "$TMP/tree" "$DIR"
BIN="$TMP/tree/bin/omarchy-kids-relay-courier"
kids_id_stub "$STUBS" root 0
export PATH="$STUBS:$PATH"
kids_set_const "$BIN" ETC "$ETC"
kids_set_const "$BIN" AUTH_SOCK "$TMP/auth.sock"
kids_set_const "$BIN" SYSROOT "$ROOT"
export KIDS_TEST_UID=0

# A local server that appends every POST body to a file and reports its port.
POSTS="$TMP/posts"
PORTFILE="$TMP/port"
: >"$POSTS"
GETBODY="$TMP/getbody"
GETLOG="$TMP/getlog"
: >"$GETLOG"
python3 - "$PORTFILE" "$POSTS" "$GETBODY" "$GETLOG" <<'PY' &
import http.server
import json
import socketserver
import sys
import urllib.parse

portfile, posts, getbody, getlog = sys.argv[1:5]


class Handler(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        length = int(self.headers.get("Content-Length", "0"))
        body = self.rfile.read(length)
        key = self.headers.get("X-Gotify-Key", "")
        with open(posts, "ab") as f:
            f.write(("%s\t%s\t" % (self.path, key)).encode() + body + b"\n")
        self.send_response(200)
        self.end_headers()
        self.wfile.write(b"ok")

    def do_GET(self):
        with open(getlog, "a") as f:
            f.write(self.path + "\n")
        try:
            with open(getbody, "r") as f:
                lines = [line for line in f.read().splitlines() if line.strip()]
        except OSError:
            lines = []
        # Honour ntfy's `since=<time>`: inclusive, so the boundary line comes back
        # (the courier must skip the ids it already carried).
        query = urllib.parse.urlsplit(self.path).query
        since = urllib.parse.parse_qs(query).get("since", [None])[0]
        if since and since.isdigit():
            kept = []
            for line in lines:
                try:
                    if (json.loads(line).get("time") or 0) >= int(since):
                        kept.append(line)
                except ValueError:
                    continue
            lines = kept
        body = ("\n".join(lines) + "\n").encode() if lines else b""
        self.send_response(200)
        self.send_header("Content-Type", "application/x-ndjson")
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *args):
        pass


with socketserver.TCPServer(("127.0.0.1", 0), Handler) as server:
    with open(portfile, "w") as f:
        f.write(str(server.server_address[1]))
    server.serve_forever()
PY
SERVER_PID=$!
for _ in $(seq 1 50); do
  [[ -s "$PORTFILE" ]] && break
  sleep 0.1
done
PORT="$(cat "$PORTFILE" 2>/dev/null)"

# A real X25519 keypair for the paired device, so the courier's envelope can be
# opened by the test.
python3 - "$TMP/key.json" <<'PY'
import base64, json, sys
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric.x25519 import X25519PrivateKey
key = X25519PrivateKey.generate()
pub = base64.b64encode(key.public_key().public_bytes(serialization.Encoding.Raw, serialization.PublicFormat.Raw)).decode()
priv = key.private_bytes(serialization.Encoding.Raw, serialization.PrivateFormat.Raw, serialization.NoEncryption()).hex()
json.dump({"pub": pub, "priv_hex": priv}, open(sys.argv[1], "w"))
PY
BOX_PUB="$(jq -r .pub "$TMP/key.json")"
printf '[{"id":"d-vector","name":"Phone","platform":"android","scopes":["decide"],"sign_pub":"x","box_pub":"%s"}]\n' "$BOX_PUB" \
  >"$ROOT/run/omarchy-kids/devices.json"
printf '{"generated_at":"x","kids":[{"kid":"kid-ada","live":true}]}\n' >"$ROOT/run/omarchy-kids/status.json"

# Notifications on (the certificate exists), with a config pointing at the server.
: >"$ETC/relay/cert.pem"
printf 'transport=ntfy\nurl=http://127.0.0.1:%s\ntopic=test\n' "$PORT" >"$ETC/courier.conf"

# --- dry-run posts nothing ------------------------------------------------
out="$("$BIN" 2>&1)"
check_contains "$out" "[dry-run]" "the courier previews by default"
check_status "$(wc -c <"$POSTS" | tr -d ' ')" "0" "dry-run posts nothing"

# --- --apply seals and posts ----------------------------------------------
out="$("$BIN" --apply 2>&1)"
check_contains "$out" "d-vector: 200" "the courier reports the post"
body="$(head -n1 "$POSTS" | cut -f3-)"
[[ -n "$body" ]] && pass "the server received a POST" || fail "the server received nothing"

python3 - "$DIR" "$TMP/key.json" "$ROOT/run/omarchy-kids/status.json" "$body" <<'PY'
import importlib.util
import json
import os
import sys

root, keyfile, status, body = sys.argv[1:5]
spec = importlib.util.spec_from_file_location("kids_envelope", os.path.join(root, "lib", "envelope.py"))
envelope = importlib.util.module_from_spec(spec)
spec.loader.exec_module(envelope)
key = json.load(open(keyfile))
opened = envelope.open_envelope("d-vector", bytes.fromhex(key["priv_hex"]), json.loads(body))
state = json.loads(opened)
ok = state["kids"][0]["kid"] == "kid-ada"
print(("PASS  " if ok else "FAIL  ") + "the posted body is a sealed envelope the device opens")
sys.exit(0 if ok else 1)
PY
[[ $? -eq 0 ]] && pass "the posted envelope carries the state" || fail "the posted envelope did not open to the state"

# --- an unchanged state is not posted again -------------------------------
: >"$POSTS"
out="$("$BIN" --apply 2>&1)"
check_contains "$out" "state has not changed" "an unchanged state is skipped"
check_status "$(wc -c <"$POSTS" | tr -d ' ')" "0" "nothing is posted for an unchanged state"
printf '{"generated_at":"y","kids":[{"kid":"kid-ada","live":false}]}\n' >"$ROOT/run/omarchy-kids/status.json"
out="$("$BIN" --apply 2>&1)"
check_contains "$out" "d-vector: 200" "a changed state is posted again"

# --- the Gotify transport: /message with the token in a header -------------
printf 'transport=gotify\nurl=http://127.0.0.1:%s\ntopic=test\ntoken=tok-secret\n' "$PORT" >"$ETC/courier.conf"
: >"$POSTS"
out="$("$BIN" --apply 2>&1)"
check_contains "$out" "d-vector: 200" "the gotify post succeeds"
line="$(head -n1 "$POSTS")"
check_contains "$(printf '%s' "$line" | cut -f1)" "/message" "gotify posts to /message"
check_contains "$(printf '%s' "$line" | cut -f2)" "tok-secret" "gotify sends the token in a header"
python3 - "$DIR" "$TMP/key.json" "$(printf '%s' "$line" | cut -f3-)" <<'PY'
import importlib.util, json, os, sys
root, keyfile, body = sys.argv[1:4]
spec = importlib.util.spec_from_file_location("kids_envelope", os.path.join(root, "lib", "envelope.py"))
envelope = importlib.util.module_from_spec(spec); spec.loader.exec_module(envelope)
key = json.load(open(keyfile))
message = json.loads(body)["message"]
state = json.loads(envelope.open_envelope("d-vector", bytes.fromhex(key["priv_hex"]), json.loads(message)))
print(("PASS  " if state["kids"][0]["kid"] == "kid-ada" else "FAIL  ") + "the gotify message carries the sealed state")
sys.exit(0 if state["kids"][0]["kid"] == "kid-ada" else 1)
PY
[[ $? -eq 0 ]] || fail "the gotify message did not carry the state"

# --- a non-https server is refused ----------------------------------------
printf 'transport=ntfy\nurl=http://example.com\ntopic=test\n' >"$ETC/courier.conf"
: >"$POSTS"
out="$("$BIN" --apply 2>&1)"
check_status "$?" 2 "a non-https server is refused"
check_contains "$out" "must be https" "the refusal says why"
check_status "$(wc -c <"$POSTS" | tr -d ' ')" "0" "nothing is posted to a non-https server"

# --- a failed send exits nonzero ------------------------------------------
printf 'transport=ntfy\nurl=https://127.0.0.1:1\ntopic=test\n' >"$ETC/courier.conf"
out="$("$BIN" --apply 2>&1)"
check_status "$?" 1 "a failed send exits nonzero"

# --- notifications off sends nothing --------------------------------------
rm -f "$ETC/relay/cert.pem"
: >"$POSTS"
out="$("$BIN" --apply 2>&1)"
check_contains "$out" "notifications are off; nothing to send" "notifications off sends nothing"
check_status "$(wc -c <"$POSTS" | tr -d ' ')" "0" "nothing is posted while notifications are off"

# --- no config sends nothing ----------------------------------------------
: >"$ETC/relay/cert.pem"
rm -f "$ETC/courier.conf"
out="$("$BIN" --apply 2>&1)"
check_contains "$out" "no parent server is configured" "no config sends nothing"
check_status "$(wc -c <"$POSTS" | tr -d ' ')" "0" "nothing is posted with no server configured"

# --- poll: carry the app's signed decisions to authd (N-11) ----------------
AUTH_LOG="$TMP/auth.log"
: >"$AUTH_LOG"
python3 - "$TMP/auth.sock" "$AUTH_LOG" <<'PY' &
import os, socket, sys
path, log = sys.argv[1], sys.argv[2]
try:
    os.unlink(path)
except OSError:
    pass
srv = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
srv.bind(path); srv.listen(4); srv.settimeout(20)
while True:
    try:
        conn, _ = srv.accept()
    except socket.timeout:
        break
    data = b""
    while b"\n" not in data:
        chunk = conn.recv(4096)
        if not chunk:
            break
        data += chunk
    with open(log, "ab") as f:
        f.write(data)
    conn.sendall(b"ok\n")
    conn.close()
PY
AUTH_PID=$!
for _ in $(seq 1 50); do
  [[ -S "$TMP/auth.sock" ]] && break
  sleep 0.1
done

printf 'transport=ntfy\nurl=http://127.0.0.1:%s\ntopic=test\nreply_topic=replies\n' "$PORT" >"$ETC/courier.conf"
frame='{"record":{"request_id":"r1"},"signature":"sig"}'
# A decision frame, and one non-frame the courier must skip.
# A decision frame (time 1000) and a non-frame (time 1001) the courier must skip.
python3 -c 'import json,sys; print(json.dumps({"id":"m1","time":1000,"message":sys.argv[1]})); print(json.dumps({"id":"m2","time":1001,"message":"not a frame"}))' "$frame" >"$GETBODY"
: >"$GETLOG"
out="$("$BIN" poll --apply 2>&1)"
check_contains "$(cat "$AUTH_LOG")" "DECIDE " "a reply is carried to authd as a DECIDE"
check_contains "$(cat "$AUTH_LOG")" '"request_id":"r1"' "authd receives the signed frame"
check_contains "$out" "reply m1: ok" "the courier reports authd's reply"
check_status "$(grep -c 'DECIDE ' "$AUTH_LOG")" "1" "the non-frame message is skipped"

# The cursor advances, so a second poll forwards nothing.
: >"$AUTH_LOG"
"$BIN" poll --apply >/dev/null 2>&1
check_status "$(grep -c 'DECIDE ' "$AUTH_LOG")" "0" "an already-seen reply is not forwarded again"

# A non-frame or a boundary frame is never carried twice (since=<time> is
# inclusive), and a non-ntfy config is a no-op, not a crash.
printf 'transport=gotify\nurl=http://127.0.0.1:%s\ntopic=test\ntoken=tok\n' "$PORT" >"$ETC/courier.conf"
check_contains "$("$BIN" poll --apply 2>&1)" "nothing to poll" "a gotify config polls nothing (not a crash)"
printf 'transport=ntfy\nurl=http://127.0.0.1:%s\ntopic=test\nreply_topic=replies\n' "$PORT" >"$ETC/courier.conf"

# An offline server does not traceback.
printf 'transport=ntfy\nurl=https://127.0.0.1:1\ntopic=test\nreply_topic=replies\n' >"$ETC/courier.conf"
out="$("$BIN" poll --apply 2>&1)"
check_status "$?" 0 "an unreachable server is not a crash"
check_contains "$out" "unreachable" "the unreachable server is reported"
printf 'transport=ntfy\nurl=http://127.0.0.1:%s\ntopic=test\nreply_topic=replies\n' "$PORT" >"$ETC/courier.conf"

# A dry run forwards nothing.
rm -f "$ROOT/run/omarchy-kids/courier-cursor"
check_contains "$("$BIN" poll 2>&1)" "[dry-run]" "poll previews by default"
check_status "$(grep -c 'DECIDE ' "$AUTH_LOG")" "0" "a dry run carries nothing"

# --- the unit and timer ---------------------------------------------------
SERVICE="$DIR/systemd/omarchy-kids-relay-courier.service"
TIMER="$DIR/systemd/omarchy-kids-relay-courier.timer"
[[ -f "$SERVICE" ]] && pass "the courier service unit exists" || fail "no courier service unit"
[[ -f "$TIMER" ]] && pass "the courier timer unit exists" || fail "no courier timer unit"
check_contains "$(cat "$TIMER")" "Unit=omarchy-kids-relay-courier.service" "the timer drives the courier service"
grep -qx 'ExecStart=-/usr/bin/omarchy-kids-relay-courier --apply' "$SERVICE" &&
  pass "the service sends on the timer (and a failed send does not block the poll)" ||
  fail "the send ExecStart is missing or not prefixed with -"
grep -qx 'ExecStart=/usr/bin/omarchy-kids-relay-courier poll --apply' "$SERVICE" &&
  pass "the service polls on the timer" || fail "the poll ExecStart is missing"
grep -qx 'RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6' "$SERVICE" &&
  pass "the courier may open the network" || fail "the courier's address families are wrong"
grep -qx 'CapabilityBoundingSet=' "$SERVICE" &&
  pass "the courier holds no capabilities" || fail "the courier's capabilities are not exactly empty"

echo "courier-test RESULT: $([[ $rc == 0 ]] && echo PASS || echo FAIL)"
exit $rc
