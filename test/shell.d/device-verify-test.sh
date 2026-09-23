#!/bin/bash
# Tests lib/devices.py's decision verification (SPEC.md R-NOTIFY-4). The crypto
# needs python-cryptography; where it is absent the file skips, the same way
# authd-test.sh skips its libcrypt checks.
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=test/shell.d/lib.sh
source "$DIR/test/shell.d/lib.sh"

if ! python3 -c "import cryptography" >/dev/null 2>&1; then
  echo "SKIP device-verify-test.sh: python-cryptography not installed — the dry-run/refusal checks did not run"
  exit 0
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

DEVICES_PY="$DIR/lib/devices.py"

python3 - "$DEVICES_PY" "$TMP" <<'PY'
import base64, importlib.util, json, os, sys, time

devices_py, tmp = sys.argv[1], sys.argv[2]

spec = importlib.util.spec_from_file_location("kids_devices", devices_py)
devices = importlib.util.module_from_spec(spec)
spec.loader.exec_module(devices)

from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey

fails = []
def check(cond, label):
    print(("PASS  " if cond else "FAIL  ") + label)
    if not cond:
        fails.append(label)

etc = os.path.join(tmp, "etc")
os.makedirs(os.path.join(etc, "devices"), exist_ok=True)
ledger_path = os.path.join(tmp, "nonces.json")

key = Ed25519PrivateKey.generate()
pub_b64 = base64.b64encode(key.public_key().public_bytes_raw()).decode()
with open(os.path.join(etc, "devices", "d1.conf"), "w") as f:
    f.write(f"id=d1\nname=Phone\nplatform=android\nsign_pub={pub_b64}\nbox_pub={pub_b64}\nscopes=decide,act\n")

now = 1_800_000_000
def signed(**over):
    rec = {"device_id": "d1", "request_id": "req-1", "decision": "approve", "ts": now, "nonce": "n1"}
    rec.update(over)
    sig = base64.b64encode(key.sign(devices.canonical(rec))).decode()
    return rec, sig

# accept
rec, sig = signed()
ok, reason = devices.verify_decision(etc, devices.NonceLedger(ledger_path), rec, sig, now)
check(ok and reason == "ok", "a device's signed decision verifies (R-NOTIFY-4)")

# replay: the same nonce again is refused
ok, reason = devices.verify_decision(etc, devices.NonceLedger(ledger_path), rec, sig, now)
check(not ok and reason == "replayed-nonce", "a replayed nonce is refused")

# tampered decision is refused
rec2, sig2 = signed(nonce="n2")
rec2["decision"] = "decline"
ok, reason = devices.verify_decision(etc, devices.NonceLedger(ledger_path), rec2, sig2, now)
check(not ok and reason == "bad-signature", "a tampered decision is refused")

# stale timestamp
rec3, sig3 = signed(nonce="n3", ts=now - devices.SKEW_SECONDS - 1)
ok, reason = devices.verify_decision(etc, devices.NonceLedger(ledger_path), rec3, sig3, now)
check(not ok and reason == "stale-timestamp", "a stale decision is refused")

# unknown device
rec4, sig4 = signed(nonce="n4", device_id="nope")
ok, reason = devices.verify_decision(etc, devices.NonceLedger(ledger_path), rec4, sig4, now)
check(not ok and reason == "unknown-device", "an unknown device is refused")

# path-like device id is refused before any path is built
rec5, sig5 = signed(nonce="n5", device_id="../../etc/shadow")
ok, reason = devices.verify_decision(etc, devices.NonceLedger(ledger_path), rec5, sig5, now)
check(not ok and reason == "unknown-device", "a path-like device id is refused")

# scope: act allowed because the device has it, then removed and refused
rec6, sig6 = signed(nonce="n6")
ok, reason = devices.verify_decision(etc, devices.NonceLedger(ledger_path), rec6, sig6, now, scope="act")
check(ok and reason == "ok", "a device with scope act may act")
with open(os.path.join(etc, "devices", "d1.conf"), "w") as f:
    f.write(f"id=d1\nname=Phone\nplatform=android\nsign_pub={pub_b64}\nbox_pub={pub_b64}\nscopes=decide\n")
rec7, sig7 = signed(nonce="n7")
ok, reason = devices.verify_decision(etc, devices.NonceLedger(ledger_path), rec7, sig7, now, scope="act")
check(not ok and reason == "scope-missing", "a device without the scope is refused")

# revoked
os.rename(os.path.join(etc, "devices", "d1.conf"), os.path.join(etc, "devices", "d1.conf.revoked"))
rec8, sig8 = signed(nonce="n8")
ok, reason = devices.verify_decision(etc, devices.NonceLedger(ledger_path), rec8, sig8, now)
check(not ok and reason == "unknown-device", "a revoked device is refused")

sys.exit(1 if fails else 0)
PY
st=$?
if [[ $st -eq 0 ]]; then
  echo "device-verify-test RESULT: PASS"
else
  echo "device-verify-test RESULT: FAIL"
fi
exit $st
