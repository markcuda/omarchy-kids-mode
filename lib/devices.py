"""lib/devices.py -- root-side verification of a paired device's decision.

R-NOTIFY-4: a decision is accepted only after root verifies a signature from a
paired, unrevoked device over the exact decision, within a bounded clock skew
and with a single-use nonce. The relay never decides (R-NOTIFY-2); this module
is what the root side calls before applying anything. (Checking the decision
against the write-once queue record and the already-decided refusal are the
caller's job, part 2.)

Stdlib plus python-cryptography (Ed25519). Where that library is absent the
verification fails closed with reason "crypto-unavailable", the same shape
authd's libcrypt checks already use; the tests skip there.

The signed bytes are fixed here and documented so the client (N-8) can match:

    b"omarchy-kids-decision-v1\\n" + json.dumps(record, sort_keys=True,
                                                separators=(",", ":")).encode()

`record` is exactly: {device_id, request_id, decision, ts, nonce} plus an
optional {reply}; the signature is base64 of the Ed25519 signature.
"""

import base64
import binascii
import fcntl
import json
import os
import re
import stat

try:
    from cryptography.exceptions import InvalidSignature
    from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PublicKey

    HAVE_CRYPTO = True
except ImportError:  # pragma: no cover - the skip path
    HAVE_CRYPTO = False

SIGN_CONTEXT = b"omarchy-kids-decision-v1\n"
SKEW_SECONDS = 300
# Twice the skew: a nonce is remembered strictly longer than a timestamp is
# accepted, so a replay of a still-in-skew record can never find it pruned.
NONCE_TTL_SECONDS = 600
MAX_REPLY = 80
MAX_NONCE = 128

RE_DEVICE_ID = re.compile(r"\A[A-Za-z0-9][A-Za-z0-9._-]{0,62}\Z")
RE_REQUEST_ID = re.compile(r"\A[A-Za-z0-9][A-Za-z0-9._:-]{0,127}\Z")
DEVICE_FIELDS = ("id", "name", "platform", "sign_pub", "box_pub", "scopes")
ALLOWED_KEYS = {"device_id", "request_id", "decision", "reply", "ts", "nonce"}
DECISIONS = ("approve", "decline")


class LedgerError(Exception):
    """The nonce ledger exists but cannot be trusted; fail closed."""


def _open_regular(path):
    """Path's text if it is a root-owned regular file, else None.

    os.open with O_NOFOLLOW (never a planted symlink) then fstat on the fd
    (never a check-then-open race), the shape lib/data.py already uses.
    FileNotFoundError -> None; any other OSError propagates for the caller.
    """
    try:
        fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_CLOEXEC)
    except FileNotFoundError:
        return None
    try:
        st = os.fstat(fd)
        if not stat.S_ISREG(st.st_mode):
            return None
        if os.geteuid() == 0 and st.st_uid != 0:
            return None
        with os.fdopen(fd, "r", encoding="utf-8", errors="replace") as f:
            fd = -1
            return f.read()
    finally:
        if fd >= 0:
            os.close(fd)


def load_device(etc_dir, device_id):
    """The device record, or None if unknown, revoked, malformed, or unsafe."""
    if not isinstance(device_id, str) or not RE_DEVICE_ID.match(device_id):
        return None
    base = os.path.join(etc_dir, "devices", device_id)
    if os.path.exists(base + ".conf.revoked"):
        return None
    try:
        text = _open_regular(base + ".conf")
    except OSError:
        return None
    if text is None:
        return None
    record = {"id": device_id}
    for line in text.splitlines():
        key, sep, value = line.partition("=")
        if sep:
            record[key.strip()] = value.strip()
    for field in DEVICE_FIELDS:
        if not record.get(field):
            return None
    record["scopes"] = [s for s in record["scopes"].split(",") if s]
    return record


def canonical(record):
    return SIGN_CONTEXT + json.dumps(record, sort_keys=True, separators=(",", ":")).encode("utf-8")


def valid_record(record):
    """True only for the exact decision shape; anything else is malformed."""
    if not isinstance(record, dict) or set(record) - ALLOWED_KEYS:
        return False
    if record.get("decision") not in DECISIONS:
        return False
    if not isinstance(record.get("device_id"), str) or not RE_DEVICE_ID.match(record["device_id"]):
        return False
    if not isinstance(record.get("request_id"), str) or not RE_REQUEST_ID.match(record["request_id"]):
        return False
    nonce = record.get("nonce")
    if not isinstance(nonce, str) or not nonce or len(nonce) > MAX_NONCE:
        return False
    ts = record.get("ts")
    if not isinstance(ts, int) or isinstance(ts, bool):
        return False
    reply = record.get("reply")
    if reply is not None and (
        not isinstance(reply, str) or len(reply) > MAX_REPLY or any(not c.isprintable() for c in reply)
    ):
        return False
    return True


class NonceLedger:
    """A seen-nonce set with a TTL, persisted to one root-owned file.

    A replay is refused because a nonce is written once and remembered for
    NONCE_TTL_SECONDS. The read-modify-write holds an flock on a sibling lock
    file, so it is safe across separate processes (the CLI runs one per call).

    Fail closed: only a missing file means "nothing seen yet"; any other read or
    parse failure raises LedgerError, and an entry that is not a plain int is
    kept (never pruned), so a damaged ledger can never un-see a nonce.
    """

    def __init__(self, path, ttl=NONCE_TTL_SECONDS):
        self.path = path
        self.lockpath = path + ".lock"
        self.ttl = ttl

    def _read_file(self):
        try:
            text = _open_regular(self.path)
        except OSError as exc:
            raise LedgerError(f"cannot read {self.path}: {exc}") from exc
        if not text:
            return {}
        try:
            loaded = json.loads(text)
        except ValueError as exc:
            raise LedgerError(f"malformed ledger {self.path}") from exc
        if not isinstance(loaded, dict):
            raise LedgerError(f"malformed ledger {self.path}")
        return loaded

    def _write_file(self, seen):
        directory = os.path.dirname(self.path) or "."
        os.makedirs(directory, mode=0o750, exist_ok=True)
        tmp = f"{self.path}.{os.getpid()}.tmp"
        with open(tmp, "w", encoding="utf-8") as f:
            json.dump(seen, f, sort_keys=True)
        os.chmod(tmp, 0o600)
        os.replace(tmp, self.path)

    def check_and_add(self, key, now):
        """True and records the key, or False if it was already seen."""
        if not isinstance(key, str) or not key or len(key) > MAX_NONCE + 64:
            return False
        directory = os.path.dirname(self.path) or "."
        os.makedirs(directory, mode=0o750, exist_ok=True)
        with open(self.lockpath, "w", encoding="utf-8") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            try:
                seen = self._read_file()
                for old in [k for k, v in seen.items() if isinstance(v, int) and now - v > self.ttl]:
                    del seen[old]
                if key in seen:
                    return False
                seen[key] = now
                self._write_file(seen)
                return True
            finally:
                fcntl.flock(lock, fcntl.LOCK_UN)


def verify_decision(etc_dir, ledger, record, signature_b64, now, scope="decide"):
    """(ok, reason). Fail closed: any doubt is a refusal."""
    if not HAVE_CRYPTO:
        return False, "crypto-unavailable"
    if not valid_record(record):
        return False, "malformed"
    device = load_device(etc_dir, record["device_id"])
    if device is None:
        return False, "unknown-device"
    if scope not in device["scopes"]:
        return False, "scope-missing"
    if abs(now - record["ts"]) > SKEW_SECONDS:
        return False, "stale-timestamp"
    try:
        public = Ed25519PublicKey.from_public_bytes(base64.b64decode(device["sign_pub"], validate=True))
        signature = base64.b64decode(signature_b64, validate=True)
        public.verify(signature, canonical(record))
    except (InvalidSignature, ValueError, TypeError, binascii.Error):
        return False, "bad-signature"
    # Only after the signature is good is the nonce burned, keyed per device:
    # an unauthenticated guess cannot consume a genuine decision's nonce, and two
    # devices may use the same nonce string.
    try:
        fresh = ledger.check_and_add(f"{device['id']}:{record['nonce']}", now)
    except LedgerError:
        return False, "ledger-unreadable"
    if not fresh:
        return False, "replayed-nonce"
    return True, "ok"


def _main(argv):  # pragma: no cover - a thin CLI for tests and the panel card
    import argparse

    parser = argparse.ArgumentParser(prog="devices.py")
    parser.add_argument("--etc", default="/etc/omarchy-kids")
    parser.add_argument("--ledger", default="/var/lib/omarchy-kids/devices/nonces.json")
    parser.add_argument("--now", type=int, required=True)
    parser.add_argument("--signature", required=True)
    parser.add_argument("--scope", default="decide")
    parser.add_argument("record", help="the decision record as JSON")
    args = parser.parse_args(argv)
    record = json.loads(args.record)
    ok, reason = verify_decision(
        args.etc, NonceLedger(args.ledger), record, args.signature, args.now, args.scope
    )
    print(reason)
    return 0 if ok else 1


if __name__ == "__main__":  # pragma: no cover
    import sys

    sys.exit(_main(sys.argv[1:]))
