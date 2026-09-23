#!/bin/bash
# Tests lib/envelope.py -- the end-to-end envelope the away courier will carry
# (SPEC.md R-NOTIFY-8/12, N-11). Seal for one device, open with its private key,
# and refuse a wrong key, a tampered ciphertext, or another device's envelope.
# Skips where python-cryptography is absent, like authd-test.
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

if ! python3 -c "import cryptography" >/dev/null 2>&1; then
  echo "SKIP envelope-test.sh: python-cryptography not installed — the envelope checks did not run"
  exit 0
fi

python3 - "$DIR" <<'PY'
import base64
import importlib.util
import os
import sys

root = sys.argv[1]
spec = importlib.util.spec_from_file_location("kids_envelope", os.path.join(root, "lib", "envelope.py"))
envelope = importlib.util.module_from_spec(spec)
spec.loader.exec_module(envelope)

from cryptography.hazmat.primitives import serialization  # noqa: E402
from cryptography.hazmat.primitives.asymmetric.x25519 import X25519PrivateKey  # noqa: E402

fails = []


def check(cond, label):
    print(("PASS  " if cond else "FAIL  ") + label)
    if not cond:
        fails.append(label)


def raw_pub(priv):
    return base64.b64encode(
        priv.public_key().public_bytes(serialization.Encoding.Raw, serialization.PublicFormat.Raw)
    ).decode()


priv = X25519PrivateKey.generate()
pub = raw_pub(priv)
priv_raw = priv.private_bytes(
    serialization.Encoding.Raw, serialization.PrivateFormat.Raw, serialization.NoEncryption()
)

env = envelope.seal("d-vector", pub, b"Ada asked for 15 more minutes")
check(env["v"] == 1 and set(env) == {"v", "device_id", "eph_pub", "nonce", "ct"}, "the envelope has v/id/eph_pub/nonce/ct")
check(envelope.open_envelope("d-vector", priv_raw, env) == b"Ada asked for 15 more minutes",
      "seal then open recovers the plaintext")

# A wrong private key cannot open it.
other = X25519PrivateKey.generate()
other_raw = other.private_bytes(
    serialization.Encoding.Raw, serialization.PrivateFormat.Raw, serialization.NoEncryption()
)
try:
    envelope.open_envelope("d-vector", other_raw, env)
    check(False, "a wrong key is refused")
except Exception:
    check(True, "a wrong key is refused")

# A tampered ciphertext is refused (AEAD).
bad = dict(env)
raw = bytearray(base64.b64decode(bad["ct"], validate=True))
raw[0] ^= 0x01
bad["ct"] = base64.b64encode(bytes(raw)).decode()
try:
    envelope.open_envelope("d-vector", priv_raw, bad)
    check(False, "a tampered ciphertext is refused")
except Exception:
    check(True, "a tampered ciphertext is refused")

# The associated data binds the device id: another id cannot open it.
try:
    envelope.open_envelope("d-other", priv_raw, env)
    check(False, "another device's id is refused")
except Exception:
    check(True, "another device's id is refused")

# A fixed ephemeral key and nonce make the vectors reproducible.
one = envelope.seal("d-vector", pub, b"x", eph_priv=bytes(range(32)), nonce=bytes(range(12)))
two = envelope.seal("d-vector", pub, b"x", eph_priv=bytes(range(32)), nonce=bytes(range(12)))
check(one == two, "a fixed ephemeral key and nonce give a reproducible envelope")
check(envelope.open_envelope("d-vector", priv_raw, one) == b"x", "the reproducible envelope opens")

sys.exit(1 if fails else 0)
PY
st=$?
if [[ $st -eq 0 ]]; then
  echo "envelope-test RESULT: PASS"
else
  echo "envelope-test RESULT: FAIL"
fi
exit $st
