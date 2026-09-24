"""lib/relay.py -- the LAN relay's non-network core (R-NOTIFY-1/2).

`build_state` makes the /v1/state document from the root-written status.json, the
queue and the open add-on reviews; `forward_decide` and `forward_review` hand a
signed frame to authd's socket and return its one-line reply; `is_needed` and
`needs_stopping` decide what counts as Kids Mode being in use and when the relay
may stop. The relay never decides (R-NOTIFY-2): it reads the parent-readable
sources and forwards to root, nothing more.

Stdlib only -- verification and the decision are root's, in lib/devices.py and
lib/ask.py. The relay is not a lock; it may stop at any time without weakening a
fence.
"""

import glob
import hashlib
import json
import os
import re
import socket
import time

QUEUE_SUFFIX = ".json"
RECENT_SECONDS = 24 * 3600
# The open add-on reviews (R-NOTIFY-12): one root-written file per review, named
# <kid>.<16 hex of sha256(app id)>.json. The relay reads them (group
# omarchy-parents) and may not decide on them.
REVIEW_SUFFIX = ".json"
RE_REVIEW_NAME = re.compile(r"\A(?P<kid>[a-z_][a-z0-9_-]*)\.(?P<digest>[0-9a-f]{16})\Z")
# The route's own shape check, before anything is forwarded (R-NOTIFY-12).
RE_REVIEW_ID = re.compile(r"\A[a-z_][a-z0-9_-]*\.[0-9a-f]{16}\Z")


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


def _review_row(name, record):
    return {
        "id": name,
        "kid": record.get("kid", ""),
        "app": record.get("id", ""),
        "was": record.get("was", ""),
        "now": record.get("now", ""),
        "detected_at": record.get("detected_at"),
    }


def _open_reviews(reviews_dir):
    """The open reviews, in file-name order (R-NOTIFY-12).

    Best-effort, like the queue: a missing directory is empty. A file whose name
    is not <kid>.<16 hex>.json, whose record is not an object, whose state is not
    "open", or whose own kid/app id do not match the name is skipped -- the state
    may not describe a review that is not there. No row carries a token, a path
    or a desktop-file body.
    """
    rows = []
    if not reviews_dir:
        return rows
    for path in sorted(glob.glob(os.path.join(reviews_dir, "*" + REVIEW_SUFFIX))):
        name = os.path.basename(path)[: -len(REVIEW_SUFFIX)]
        match = RE_REVIEW_NAME.match(name)
        if match is None:
            continue
        record = _read_json(path)
        if record is None or record.get("state") != "open":
            continue
        app_id = record.get("id")
        if record.get("kid") != match.group("kid") or not isinstance(app_id, str):
            continue
        digest = hashlib.sha256(app_id.encode("utf-8")).hexdigest()[:16]
        if digest != match.group("digest"):
            continue
        rows.append(_review_row(name, record))
    return rows


def build_state(status_path, queue_dir, reviews_dir=None, now=None):
    """The /v1/state document (Appendix H): kids, open requests, recent decisions,
    open add-on reviews.

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
        "reviews": _open_reviews(reviews_dir),
    }


def _forward(auth_sock, prefix, frame_json, timeout):
    payload = frame_json if isinstance(frame_json, bytes) else frame_json.encode("utf-8")
    conn = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    conn.settimeout(timeout)
    try:
        conn.connect(auth_sock)
        conn.sendall(prefix + payload + b"\n")
        conn.shutdown(socket.SHUT_WR)
        reply = conn.recv(4096)
    except OSError:
        return None
    finally:
        conn.close()
    return reply.decode("utf-8", "replace").strip()


def forward_decide(auth_sock, frame_json, timeout=30.0):
    """Send `DECIDE <json>\\n` to authd and return its reply line.

    None on any transport error (the app shows "can't reach the computer");
    authd verifies the frame itself, so the relay only carries it.
    """
    return _forward(auth_sock, b"DECIDE ", frame_json, timeout)


def forward_review(auth_sock, frame_json, timeout=30.0):
    """Send `REVIEW <json>\n` to authd and return its reply line.

    R-NOTIFY-12: the frame is the app's signed review decision. As with DECIDE,
    authd verifies and applies it; the relay only carries it.
    """
    return _forward(auth_sock, b"REVIEW ", frame_json, timeout)


def forward_pair(auth_sock, frame_json, timeout=30.0):
    """Send `PAIR <json>\\n` to authd and return its reply line.

    Pairing is pre-auth: the frame carries a proof that the device holds the
    single-use token, and the token itself never travels (R-NOTIFY-5): the relay never reads the root-only pairing record (R-NOTIFY-2),
    it just carries the frame to authd, which verifies the proof and registers
    the device.
    """
    return _forward(auth_sock, b"PAIR ", frame_json, timeout)


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
