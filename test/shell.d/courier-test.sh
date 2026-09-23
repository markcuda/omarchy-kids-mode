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
kids_set_const "$BIN" SYSROOT "$ROOT"
export KIDS_TEST_UID=0

# A local server that appends every POST body to a file and reports its port.
POSTS="$TMP/posts"
PORTFILE="$TMP/port"
: >"$POSTS"
python3 - "$PORTFILE" "$POSTS" <<'PY' &
import http.server
import socketserver
import sys

portfile, posts = sys.argv[1], sys.argv[2]


class Handler(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        length = int(self.headers.get("Content-Length", "0"))
        body = self.rfile.read(length)
        with open(posts, "ab") as f:
            f.write(body + b"\n")
        self.send_response(200)
        self.end_headers()
        self.wfile.write(b"ok")

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
body="$(head -n1 "$POSTS")"
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

echo "courier-test RESULT: $([[ $rc == 0 ]] && echo PASS || echo FAIL)"
exit $rc
