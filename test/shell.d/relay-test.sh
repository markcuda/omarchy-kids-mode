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
import importlib.util, json, os, socket, sys, threading, time

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
               "asked_at": 2, "state": "approved", "decided_at": int(time.time()), "reply": "OK"}, f)
with open(os.path.join(queue, "3-kid-ada-site.json"), "w") as f:
    json.dump({"kid": "kid-ada", "kind": "site", "what": "example.com",
               "asked_at": 3, "state": "declined", "decided_at": int(time.time()) - 60, "reply": ""}, f)
with open(os.path.join(queue, "4-old.json"), "w") as f:
    json.dump({"kid": "kid-ada", "kind": "app", "what": "old", "asked_at": 4,
               "state": "approved", "decided_at": int(time.time()) - 90000}, f)
with open(os.path.join(queue, "5-nodate.json"), "w") as f:
    json.dump({"kid": "kid-ada", "kind": "app", "what": "nodate", "asked_at": 5, "state": "approved"}, f)
with open(os.path.join(queue, "6-bad.json"), "w") as f:
    f.write("{not json")

state = relay.build_state(status, queue)
check(state["kids"][0]["kid"] == "kid-ada", "build_state carries the kids")
check(len(state["requests"]) == 1 and state["requests"][0]["id"] == "1-kid-ada-time",
      "build_state lists only the open request, with its id")
check(state["requests"][0]["minutes"] == 15, "build_state carries the request fields")
check(set(state["requests"][0]) == {"id", "kid", "kind", "what", "minutes", "asked_at"},
      "an open request's row is exactly its six keys (R-NOTIFY-15.1)")

# recent (R-NOTIFY-15.1): the request row plus state, decided_at and reply?; the
# old record is outside the window and the undated one is in neither list.
recent = {row["id"]: row for row in state["recent"]}
check(recent.get("2-kid-ada-app", {}).get("reply") == "OK",
      "a recent row carries the parent's reply when there was one")
check(recent["2-kid-ada-app"]["state"] == "approved" and isinstance(recent["2-kid-ada-app"]["decided_at"], int),
      "a recent row carries state and decided_at")
check("reply" not in recent.get("3-kid-ada-site", {"reply": "x"}),
      "a decision with no reply puts no reply key on the row")
check(len(state["recent"]) == 2, "only the in-window decisions are recent")
check("5-nodate" not in recent and "5-nodate" not in [r["id"] for r in state["requests"]],
      "a decision with no integer decided_at is in neither list")
check("4-old" not in recent, "a decision older than the window is not recent")

# a missing status/queue is empty, never an error
empty = relay.build_state(os.path.join(tmp, "nope.json"), os.path.join(tmp, "nope"))
check(empty["kids"] == [] and empty["requests"] == [], "build_state is empty when the sources are missing")

# --- build_state: open add-on reviews (R-NOTIFY-12) -------------------------
import hashlib
reviews = os.path.join(tmp, "reviews", "open")
os.makedirs(reviews, exist_ok=True)
app_id = "org.mozilla.firefox"
rid = "kid-ada." + hashlib.sha256(app_id.encode()).hexdigest()[:16]
with open(os.path.join(reviews, rid + ".json"), "w") as f:
    json.dump({"kid": "kid-ada", "id": app_id, "was": "aa" * 32, "now": "bb" * 32,
               "detected_at": 7, "state": "open"}, f)
# skipped: closed, a digest that does not match the app id, junk, a stray name
with open(os.path.join(reviews, "kid-ada." + "0" * 16 + ".json"), "w") as f:
    json.dump({"kid": "kid-ada", "id": "com.example.x", "state": "closed"}, f)
with open(os.path.join(reviews, "kid-ada." + "1" * 16 + ".json"), "w") as f:
    json.dump({"kid": "kid-ada", "id": app_id, "state": "open"}, f)
with open(os.path.join(reviews, "kid-ada." + "2" * 16 + ".json"), "w") as f:
    f.write("{not json")
# skipped: the name says kid-dot but the record says kid-ada
with open(os.path.join(reviews, "kid-dot." + rid.split(".", 1)[1] + ".json"), "w") as f:
    json.dump({"kid": "kid-ada", "id": app_id, "state": "open"}, f)
with open(os.path.join(reviews, "not-a-review.json"), "w") as f:
    json.dump({"kid": "kid-ada", "id": app_id, "state": "open"}, f)

state = relay.build_state(status, queue, reviews)
check(len(state["reviews"]) == 1 and state["reviews"][0]["id"] == rid,
      "build_state lists only the open review, with its review id")
check(state["reviews"][0]["app"] == app_id and state["reviews"][0]["kid"] == "kid-ada",
      "build_state carries the review's kid and app id")
check(state["reviews"][0]["was"] == "aa" * 32 and state["reviews"][0]["now"] == "bb" * 32,
      "build_state carries the fingerprints the app shows")
check(state["reviews"][0]["detected_at"] == 7, "build_state carries when the change was detected")
check(relay.build_state(status, queue)["reviews"] == [],
      "no reviews dir argument means no reviews, not an error")
check(relay.build_state(status, queue, os.path.join(tmp, "nope"))["reviews"] == [],
      "a missing reviews dir is empty, never an error")

# --- forward_decide --------------------------------------------------------
sock_path = os.path.join(tmp, "auth.sock")
seen = []

def fake_authd(reply, ready):
    srv = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    srv.bind(sock_path)
    srv.listen(1)
    srv.settimeout(30)
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

def exchange(prefix, payload, reply_bytes):
    """One stub round-trip, retried: a starved parallel run had surfaced as a
    one-off failure here (0/20 alone), so the check is the exchange, not luck."""
    fn = {
        "PAIR": relay.forward_pair,
        "REVIEW": relay.forward_review,
        "ACT": relay.forward_act,
    }.get(prefix, relay.forward_decide)
    for _ in range(3):
        try:
            os.unlink(sock_path)
        except OSError:
            pass
        ready = threading.Event()
        t = threading.Thread(target=fake_authd, args=(reply_bytes, ready))
        t.start()
        if not ready.wait(30):
            continue
        try:
            got = fn(sock_path, payload)
        finally:
            t.join(30)
        if got is not None:
            return got
    return None


reply = exchange("DECIDE", '{"record":{},"signature":"x"}', b"ok\n")
check(reply == "ok", "forward_decide returns authd's reply")
check(seen and seen[-1].startswith("DECIDE "), "forward_decide sends the DECIDE frame")

reply = exchange("DECIDE", '{"record":{}}', b"no replayed-nonce\n")
check(reply == "no replayed-nonce", "forward_decide passes a refusal back verbatim")

# --- forward_pair: pairing is pre-auth and carried to authd ----------------
reply = exchange("PAIR", '{"id":"d2","proof":"p"}', b"ok\n")
check(reply == "ok", "forward_pair returns authd's reply")
check(seen and seen[-1].startswith("PAIR "), "forward_pair sends the PAIR frame")

# --- forward_review: a review decision is carried to authd ------------------
reply = exchange("REVIEW", '{"record":{"review_id":"kid-ada." + "a" * 16},"signature":"x"}', b"ok\n")
check(reply == "ok", "forward_review returns authd's reply")
check(seen and seen[-1].startswith("REVIEW "), "forward_review sends the REVIEW frame")

reply = exchange("REVIEW", '{"record":{}}', b"no changed-again\n")
check(reply == "no changed-again", "forward_review passes a refusal back verbatim")

# --- forward_act: a grant or an end is carried to authd ---------------------
reply = exchange("ACT", '{"record":{"account":"kid-ada","action":"grant","minutes":15},"signature":"x"}', b"ok\n")
check(reply == "ok", "forward_act returns authd's reply")
check(seen and seen[-1].startswith("ACT "), "forward_act sends the ACT frame")

reply = exchange("ACT", '{"record":{}}', b"no not-a-kid\n")
check(reply == "no not-a-kid", "forward_act passes a refusal back verbatim")

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
