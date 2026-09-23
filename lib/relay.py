"""lib/relay.py -- the LAN relay's non-network core (R-NOTIFY-1/2).

`build_state` makes the /v1/state document from the root-written status.json and
the queue; `forward_decide` hands a signed decision frame to authd's DECIDE
socket and returns its one-line reply; `idle_expired` decides when the relay may
stop. The relay never decides (R-NOTIFY-2): it reads the parent-readable sources
and forwards to root, nothing more.

Stdlib only -- verification and the decision are root's, in lib/devices.py and
lib/ask.py. The relay is not a lock; it may stop at any time without weakening a
fence.
"""

import glob
import json
import os
import socket

QUEUE_SUFFIX = ".json"


def _read_json(path):
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as f:
            data = json.load(f)
    except (OSError, ValueError):
        return None
    return data if isinstance(data, dict) else None


def build_state(status_path, queue_dir):
    """The /v1/state document. Best-effort: a missing source is an empty list."""
    status = _read_json(status_path) or {}
    kids = status.get("kids")
    if not isinstance(kids, list):
        kids = []
    requests = []
    if queue_dir:
        for path in sorted(glob.glob(os.path.join(queue_dir, "*" + QUEUE_SUFFIX))):
            record = _read_json(path)
            if record is None or record.get("state") != "open":
                continue
            requests.append(
                {
                    "id": os.path.basename(path)[: -len(QUEUE_SUFFIX)],
                    "kid": record.get("kid", ""),
                    "kind": record.get("kind", ""),
                    "what": record.get("what", ""),
                    "minutes": record.get("minutes"),
                    "asked_at": record.get("asked_at"),
                }
            )
    return {
        "generated_at": status.get("generated_at"),
        "kids": kids,
        "requests": requests,
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


def idle_expired(last_activity, now, idle_seconds, connected_clients=0):
    """True once the relay has been quiet long enough to stop.

    Running only while Kids Mode is in use is R-NOTIFY-1; a connected device
    keeps it up whatever the clock says.
    """
    if connected_clients > 0:
        return False
    return now - last_activity >= idle_seconds
