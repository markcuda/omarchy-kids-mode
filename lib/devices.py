"""lib/devices.py -- root-side verification of a paired device's decision.

R-NOTIFY-4: a decision is accepted only after root verifies a signature from a
paired, unrevoked device over the exact decision, within a bounded clock skew
and with a single-use nonce. The relay never decides (R-NOTIFY-2); this module
is what the root side calls before applying anything.

Stdlib plus python-cryptography (Ed25519). Where that library is absent the
verification fails closed with reason "crypto-unavailable", the same shape
authd's libcrypt checks already use; the tests skip there.

The signed bytes are fixed here and documented so the client (N-8) can match:

    b"omarchy-kids-decision-v1\\n" + json.dumps(record, sort_keys=True,
                                                separators=(",", ":")).encode()

`record` is the decision object: at least {device_id, request_id, decision} plus
{reply?, ts, nonce}; the signature is base64 of the Ed25519 signature.
"""

import base64
import binascii
import json
import os
import re
import threading

try:
    from cryptography.exceptions import InvalidSignature
    from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PublicKey

    HAVE_CRYPTO = True
except ImportError:  # pragma: no cover - the skip path
    HAVE_CRYPTO = False

SIGN_CONTEXT = b"omarchy-kids-decision-v1\n"
SKEW_SECONDS = 300
NONCE_TTL_SECONDS = 600
MAX_REPLY = 80

RE_DEVICE_ID = re.compile(r"\A[A-Za-z0-9][A-Za-z0-9._-]{0,62}\Z")
DEVICE_FIELDS = ("id", "name", "platform", "sign_pub", "box_pub", "scopes")


def _safe_read(path):
    """Read a root-owned regular file, refusing a symlink or a foreign owner.

    The device id in a signed record is untrusted; the path it builds must
    already be validated, and a planted symlink must never be followed.
    """
    try:
        st = os.lstat(path)
    except OSError:
        return None
    if not os.path.isfile(path) or os.path.islink(path):
        return None
    if os.geteuid() == 0 and st.st_uid != 0:
        return None
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as f:
            return f.read()
    except OSError:
        return None


def load_device(etc_dir, device_id):
    """The device record, or None if unknown, revoked, or malformed."""
    if not isinstance(device_id, str) or not RE_DEVICE_ID.match(device_id):
        return None
    path = os.path.join(etc_dir, "devices", device_id + ".conf")
    if os.path.exists(path + ".revoked"):
        return None
    text = _safe_read(path)
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


class NonceLedger:
    """A seen-nonce set with a TTL, persisted to one root-owned file.

    A replay is refused because a nonce is written once and remembered for
    NONCE_TTL_SECONDS, and a decision record is write-once besides.
    """

    def __init__(self, path, ttl=NONCE_TTL_SECONDS):
        self.path = path
        self.ttl = ttl
        self._lock = threading.Lock()
        self._seen = {}
        text = _safe_read(path)
        if text:
            try:
                loaded = json.loads(text)
                if isinstance(loaded, dict):
                    self._seen = {k: int(v) for k, v in loaded.items()}
            except (ValueError, TypeError):
                self._seen = {}

    def _prune(self, now):
        for nonce in [n for n, t in self._seen.items() if now - t > self.ttl]:
            del self._seen[nonce]

    def _save(self):
        directory = os.path.dirname(self.path) or "."
        os.makedirs(directory, mode=0o750, exist_ok=True)
        tmp = f"{self.path}.{os.getpid()}.tmp"
        with open(tmp, "w", encoding="utf-8") as f:
            json.dump(self._seen, f, sort_keys=True)
        os.chmod(tmp, 0o600)
        os.replace(tmp, self.path)

    def check_and_add(self, nonce, now):
        """True and records the nonce, or False if it was already seen."""
        if not isinstance(nonce, str) or not nonce or len(nonce) > 128:
            return False
        with self._lock:
            self._prune(now)
            if nonce in self._seen:
                return False
            self._seen[nonce] = now
            self._save()
            return True


def verify_decision(etc_dir, ledger, record, signature_b64, now, scope="decide"):
    """(ok, reason). Fail closed: any doubt is a refusal."""
    if not HAVE_CRYPTO:
        return False, "crypto-unavailable"
    if not isinstance(record, dict):
        return False, "malformed"
    device = load_device(etc_dir, record.get("device_id"))
    if device is None:
        return False, "unknown-device"
    if scope not in device["scopes"]:
        return False, "scope-missing"
    ts = record.get("ts")
    if not isinstance(ts, int) or isinstance(ts, bool) or abs(now - ts) > SKEW_SECONDS:
        return False, "stale-timestamp"
    nonce = record.get("nonce")
    if not ledger.check_and_add(nonce, now):
        return False, "replayed-nonce"
    try:
        public = Ed25519PublicKey.from_public_bytes(base64.b64decode(device["sign_pub"], validate=True))
        signature = base64.b64decode(signature_b64, validate=True)
        public.verify(signature, canonical(record))
    except (InvalidSignature, ValueError, binascii.Error):
        return False, "bad-signature"
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
    ledger = NonceLedger(args.ledger)
    ok, reason = verify_decision(args.etc, ledger, record, args.signature, args.now, args.scope)
    print(reason)
    return 0 if ok else 1


if __name__ == "__main__":  # pragma: no cover
    import sys

    sys.exit(_main(sys.argv[1:]))
