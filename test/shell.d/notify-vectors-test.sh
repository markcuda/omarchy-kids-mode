#!/bin/bash
# Tests the shared signing vectors the parent app is written against (N-8):
# clients/parent/test-vectors/notify-vectors.json must match lib/devices.py's
# exact scheme, and every signature must verify under the public key the file
# itself carries. Skips where python-cryptography is absent, like authd-test.
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VECTORS="$DIR/clients/parent/test-vectors/notify-vectors.json"

pass() { echo "PASS  $*"; }
fail() {
  echo "FAIL  $*"
  rc=1
}
rc=0

if ! python3 -c "import cryptography" >/dev/null 2>&1; then
  echo "SKIP notify-vectors-test.sh: python-cryptography not installed — the vector checks did not run"
  exit 0
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
GEN="$TMP/generated.json"

# The committed file is generated: regenerate and compare, so a scheme change
# that forgets the vectors fails here (and the app's tests would then read a
# stale contract).
if python3 "$DIR/clients/parent/test-vectors/generate.py" "$GEN" 2>"$TMP/gen.err"; then
  if diff -u "$VECTORS" "$GEN" >"$TMP/diff" 2>&1; then
    pass "the committed vectors match the current scheme"
  else
    fail "the committed vectors are stale — rerun generate.py"
    sed -n '1,20p' "$TMP/diff"
  fi
else
  fail "generate.py failed"
  cat "$TMP/gen.err"
fi

# Verify independently of generate.py: the public key in the file must verify
# the signatures in the file, over the contexts and messages lib/devices.py
# defines.
python3 - "$DIR" <<'PY'
import base64
import importlib.util
import json
import os
import sys

root = sys.argv[1]
sys.path.insert(0, os.path.join(root, "lib"))
import devices  # noqa: E402

from cryptography.hazmat.primitives import serialization  # noqa: E402
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey, Ed25519PublicKey  # noqa: E402

fails = []


def check(cond, label):
    print(("PASS  " if cond else "FAIL  ") + label)
    if not cond:
        fails.append(label)


with open(os.path.join(root, "clients/parent/test-vectors/notify-vectors.json"), encoding="utf-8") as f:
    doc = json.load(f)

_env_spec = importlib.util.spec_from_file_location("kids_envelope", os.path.join(root, "lib", "envelope.py"))
envelope = importlib.util.module_from_spec(_env_spec)
_env_spec.loader.exec_module(envelope)

check(
    doc["contexts_b64"]["decision"] == base64.b64encode(devices.SIGN_CONTEXT).decode(),
    "the decision signing context matches lib/devices.py",
)
check(
    doc["contexts_b64"]["request"] == base64.b64encode(devices.REQUEST_CONTEXT).decode(),
    "the request signing context matches lib/devices.py",
)

pub = Ed25519PublicKey.from_public_bytes(base64.b64decode(doc["sign_pub_b64"], validate=True))
seed = bytes.fromhex(doc["sign_seed_hex"])
derived = (
    Ed25519PrivateKey.from_private_bytes(seed)
    .public_key()
    .public_bytes(serialization.Encoding.Raw, serialization.PublicFormat.Raw)
)
check(
    base64.b64encode(derived).decode() == doc["sign_pub_b64"],
    "the seed in the file derives the public key in the file",
)

dec_ok = True
try:
    pub.verify(base64.b64decode(doc["decision_signature_b64"], validate=True), devices.canonical(doc["decision"]))
except Exception:
    dec_ok = False
check(dec_ok, "the decision signature verifies over the canonical record")
check(
    doc["decision_message_b64"] == base64.b64encode(devices.canonical(doc["decision"])).decode(),
    "the recorded decision message is the canonical record the box signs",
)

req = doc["request"]
req_ok = True
try:
    pub.verify(
        base64.b64decode(doc["request_signature_b64"], validate=True),
        devices.request_message(
            req["device_id"], req["ts"], req["nonce"], req["method"], req["path"], base64.b64decode(req["body_b64"])
        ),
    )
except Exception:
    req_ok = False
check(req_ok, "the request signature verifies over the request message")
check(
    doc["request_message_b64"]
    == base64.b64encode(
        devices.request_message(
            req["device_id"], req["ts"], req["nonce"], req["method"], req["path"], base64.b64decode(req["body_b64"])
        )
    ).decode(),
    "the recorded request message is what the box signs",
)

pair = doc["pairing"]
check(
    devices.pairing_proof(pair["token"], pair["name"], pair["sign_pub"], pair["box_pub"]) == pair["proof"],
    "the pairing proof recomputes from the token in the file",
)

env = doc["envelope"]
plaintext = base64.b64decode(env["plaintext_b64"])
check(
    envelope.open_envelope("d-vector", bytes.fromhex(env["box_priv_hex"]), env["envelope"]) == plaintext,
    "the away envelope (N-11) opens with the box private key",
)
check(
    envelope.seal(
        "d-vector", env["box_pub_b64"], plaintext,
        eph_priv=bytes.fromhex(env["eph_hex"]), nonce=bytes.fromhex(env["nonce_hex"]),
    )
    == env["envelope"],
    "the envelope reseals to the same bytes",
)

sys.exit(1 if fails else 0)
PY
st=$?
((st == 0)) || rc=1

echo "notify-vectors-test RESULT: $([[ $rc == 0 ]] && echo PASS || echo FAIL)"
exit $rc
