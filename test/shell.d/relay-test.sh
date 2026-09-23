#!/bin/bash
# Tests lib/relay.py -- the LAN relay's state builder, decision forwarder and
# idle rule (SPEC.md R-NOTIFY-1/2). No network listener is started here; that is
# the HTTP layer's test.
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=test/shell.d/lib.sh
source "$DIR/test/shell.d/lib.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

python3 - "$DIR/lib/relay.py" "$TMP" <<'PY'
import importlib.util, json, os, socket, sys, threading

relay_py, tmp = sys.argv[1], sys.argv[2]
spec = importlib.util.spec_from_file_location("kids_relay", relay_py)
relay = importlib.util.module_from_spec(spec)
spec.loader.exec_module(relay)

fails = []
def check(cond, label):
    print(("PASS  " if cond else "FAIL  ") + label)
    if not cond:
        fails.append(label)

# --- build_state -----------------------------------------------------------
status = os.path.join(tmp, "status.json")
queue = os.path.join(tmp, "queue")
os.makedirs(queue, exist_ok=True)
with open(status, "w") as f:
    json.dump({"generated_at": "2026-09-22T12:00:00Z",
               "kids": [{"kid": "kid-ada", "minutes_left": 12, "paused": False, "live": True}]}, f)
with open(os.path.join(queue, "1-kid-ada-time.json"), "w") as f:
    json.dump({"kid": "kid-ada", "kind": "time", "what": "15", "minutes": 15,
               "asked_at": 1, "state": "open"}, f)
with open(os.path.join(queue, "2-kid-ada-app.json"), "w") as f:
    json.dump({"kid": "kid-ada", "kind": "app", "what": "gcompris",
               "asked_at": 2, "state": "approved"}, f)
with open(os.path.join(queue, "3-bad.json"), "w") as f:
    f.write("{not json")

state = relay.build_state(status, queue)
check(state["kids"][0]["kid"] == "kid-ada", "build_state carries the kids")
check(len(state["requests"]) == 1 and state["requests"][0]["id"] == "1-kid-ada-time",
      "build_state lists only the open request, with its id")
check(state["requests"][0]["minutes"] == 15, "build_state carries the request fields")

# a missing status/queue is empty, never an error
empty = relay.build_state(os.path.join(tmp, "nope.json"), os.path.join(tmp, "nope"))
check(empty["kids"] == [] and empty["requests"] == [], "build_state is empty when the sources are missing")

# --- forward_decide --------------------------------------------------------
sock_path = os.path.join(tmp, "auth.sock")
seen = []

def fake_authd(reply, ready):
    srv = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    srv.bind(sock_path)
    srv.listen(1)
    srv.settimeout(10)
    ready.set()
    conn, _ = srv.accept()
    data = b""
    while b"\n" not in data:
        chunk = conn.recv(4096)
        if not chunk:
            break
        data += chunk
    seen.append(data.decode())
    conn.sendall(reply)
    conn.close()
    srv.close()

ready = threading.Event()
t = threading.Thread(target=fake_authd, args=(b"ok\n", ready))
t.start()
if not ready.wait(10):
    raise RuntimeError("authd stub did not start in time")
reply = relay.forward_decide(sock_path, '{"record":{},"signature":"x"}')
t.join(10)
check(reply == "ok", "forward_decide returns authd's reply")
check(seen and seen[0].startswith("DECIDE "), "forward_decide sends the DECIDE frame")

os.unlink(sock_path)
ready = threading.Event()
t = threading.Thread(target=fake_authd, args=(b"no replayed-nonce\n", ready))
t.start()
if not ready.wait(10):
    raise RuntimeError("authd stub did not start in time")
reply = relay.forward_decide(sock_path, '{"record":{}}')
t.join(10)
check(reply == "no replayed-nonce", "forward_decide passes a refusal back verbatim")

check(relay.forward_decide(os.path.join(tmp, "none.sock"), "{}") is None,
      "forward_decide is None when authd is unreachable")

# --- needs_stopping (R-NOTIFY-1) -------------------------------------------
check(not relay.needs_stopping(True, None, 10_000, 60), "a needed relay never stops")
check(not relay.needs_stopping(False, 100, 130, 60), "it stays up inside the not-needed grace")
check(relay.needs_stopping(False, 100, 160, 60), "it stops once Kids Mode has not been in use for the grace")
check(not relay.needs_stopping(False, None, 10_000, 60), "no grace has started yet")

# --- is_needed / the not-needed exit rule (R-NOTIFY-1) --------------------
check(relay.is_needed(status, queue), "needed: a live kid and an open request")

s2 = os.path.join(tmp, "status-idle.json")
with open(s2, "w") as f:
    json.dump({"kids": [{"kid": "kid-ada", "live": False}]}, f)
q2 = os.path.join(tmp, "queue-idle")
os.makedirs(q2, exist_ok=True)
check(not relay.is_needed(s2, q2), "not needed: no live kid, no open request")
with open(os.path.join(q2, "open.json"), "w") as f:
    json.dump({"state": "open"}, f)
check(relay.is_needed(s2, q2), "needed: an open request alone")
q3 = os.path.join(tmp, "queue-none")
os.makedirs(q3, exist_ok=True)
check(not relay.is_needed(os.path.join(tmp, "missing.json"), q3),
      "not needed when the status is unreadable (fail-closed: stops sooner, the tick restarts it)")

# A pairing window is Kids Mode in use too. Root publishes only its expiry in
# status.json (the record stays root-only, so the relay never sees the token).
import time as _time

s_pair = os.path.join(tmp, "status-pair.json")
with open(s_pair, "w") as f:
    json.dump({"pairing_open_until": int(_time.time()) + 300, "kids": []}, f)
check(relay.is_needed(s_pair, q3), "needed: a pairing window published in status.json")
with open(s_pair, "w") as f:
    json.dump({"pairing_open_until": int(_time.time()) - 1, "kids": []}, f)
check(not relay.is_needed(s_pair, q3), "not needed: an expired pairing window")
with open(s_pair, "w") as f:
    json.dump({"pairing_open_until": "soon", "kids": []}, f)
check(not relay.is_needed(s_pair, q3), "a malformed pairing_open_until reads as no window, and never raises")

check(not relay.needs_stopping(True, 0, 100_000, 60),
      "a live kid or open request keeps it up however idle the clock says")

sys.exit(1 if fails else 0)
PY
st=$?
if [[ $st -eq 0 ]]; then
  echo "relay-test RESULT: PASS"
else
  echo "relay-test RESULT: FAIL"
fi
exit $st
