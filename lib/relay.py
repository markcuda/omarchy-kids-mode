"""lib/relay.py -- the LAN relay's non-network core (R-NOTIFY-1/2).

`build_state` makes the /v1/state document from the root-written status.json and
the queue; `forward_decide` hands a signed decision frame to authd's DECIDE
socket and returns its one-line reply; `is_needed` and `needs_stopping` decide
what counts as Kids Mode being in use and when the relay may stop. The relay
never decides (R-NOTIFY-2): it reads the parent-readable sources and forwards to
root, nothing more.

Stdlib only -- verification and the decision are root's, in lib/devices.py and
lib/ask.py. The relay is not a lock; it may stop at any time without weakening a
fence.
"""

import glob
import json
import os
import socket
import time

QUEUE_SUFFIX = ".json"
RECENT_SECONDS = 24 * 3600


def _read_json(path):
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as f:
            data = json.load(f)
    except (OSError, ValueError):
        return None
    return data if isinstance(data, dict) else None


def _request_row(path, record):
    return {
        "id": os.path.basename(path)[: -len(QUEUE_SUFFIX)],
        "kid": record.get("kid", ""),
        "kind": record.get("kind", ""),
        "what": record.get("what", ""),
        "minutes": record.get("minutes"),
        "asked_at": record.get("asked_at"),
    }


def build_state(status_path, queue_dir, now=None):
    """The /v1/state document (Appendix H): kids, open requests, recent decisions.

    Best-effort: a missing source is an empty list.
    """
    now = time.time() if now is None else now
    status = _read_json(status_path) or {}
    kids = status.get("kids")
    if not isinstance(kids, list):
        kids = []
    requests = []
    recent = []
    if queue_dir:
        for path in sorted(glob.glob(os.path.join(queue_dir, "*" + QUEUE_SUFFIX))):
            record = _read_json(path)
            if record is None:
                continue
            if record.get("state") == "open":
                requests.append(_request_row(path, record))
                continue
            decided = record.get("decided_at")
            if isinstance(decided, int) and not isinstance(decided, bool) and now - decided <= RECENT_SECONDS:
                row = _request_row(path, record)
                row["state"] = record.get("state", "")
                recent.append(row)
    return {
        "generated_at": status.get("generated_at"),
        "kids": kids,
        "requests": requests,
        "recent": recent,
    }


def forward_decide(auth_sock, frame_json, timeout=30.0):
    """Send `DECIDE <json>\\n` to authd and return its reply line.

    None on any transport error (the app shows "can't reach the computer");
    authd verifies the frame itself, so the relay only carries it.
    """
    payload = frame_json if isinstance(frame_json, bytes) else frame_json.encode("utf-8")
    conn = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    conn.settimeout(timeout)
    try:
        conn.connect(auth_sock)
        conn.sendall(b"DECIDE " + payload + b"\n")
        conn.shutdown(socket.SHUT_WR)
        reply = conn.recv(4096)
    except OSError:
        return None
    finally:
        conn.close()
    return reply.decode("utf-8", "replace").strip()


def is_needed(status_path, queue_dir):
    """True while Kids Mode is in use: a kid is live, a request is open, or a
    device is pairing.

    R-NOTIFY-1: the relay runs only while Kids Mode is in use and notifications
    are enabled, so this gates its exit as well as its start. Root publishes the
    pairing window's expiry in status.json (`pairing_open_until`); the pairing
    record itself stays root-only, so the relay never sees the token (R-NOTIFY-2).
    Best-effort -- an unreadable source reads as not needed, which only lets the
    relay stop sooner (the ledger tick starts it again within 30 seconds).
    """
    status = _read_json(status_path) or {}
    until = status.get("pairing_open_until")
    if isinstance(until, int) and not isinstance(until, bool) and until > time.time():
        return True
    kids = status.get("kids")
    if isinstance(kids, list):
        for kid in kids:
            if isinstance(kid, dict) and kid.get("live") is True:
                return True
    if queue_dir:
        for path in sorted(glob.glob(os.path.join(queue_dir, "*" + QUEUE_SUFFIX))):
            record = _read_json(path)
            if record is not None and record.get("state") == "open":
                return True
    return False


def needs_stopping(needed, not_needed_since, now, needless_seconds):
    """True once Kids Mode has not been in use for the grace window.

    R-NOTIFY-1: the relay exits on its own when idle. `needed` (a live kid, an
    open request, or a pairing window) holds it up; otherwise it stops after
    `needless_seconds`, even if a device is holding a stream open -- a subscriber
    must not become the always-on listener the requirement forbids.
    """
    if needed or not_needed_since is None:
        return False
    return now - not_needed_since >= needless_seconds
