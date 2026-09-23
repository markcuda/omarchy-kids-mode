#!/bin/bash
# Tests lib/devices.py's decision verification (SPEC.md R-NOTIFY-4). The crypto
# needs python-cryptography; where it is absent the file skips, the same way
# authd-test.sh skips its libcrypt checks.
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=test/shell.d/lib.sh
source "$DIR/test/shell.d/lib.sh"

if ! python3 -c "import cryptography" >/dev/null 2>&1; then
  echo "SKIP device-verify-test.sh: python-cryptography not installed — the accept/refusal checks did not run"
  exit 0
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

python3 - "$DIR/lib/devices.py" "$TMP" <<'PY'
import base64, importlib.util, json, os, sys

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
now = 1_800_000_000
key = Ed25519PrivateKey.generate()
pub = base64.b64encode(key.public_key().public_bytes_raw()).decode()
conf = os.path.join(etc, "devices", "d1.conf")

def write_conf(scopes="decide,act"):
    with open(conf, "w") as f:
        f.write(f"id=d1\nname=Phone\nplatform=android\nsign_pub={pub}\nbox_pub={pub}\nscopes={scopes}\n")

def signed(**over):
    rec = {"device_id": "d1", "request_id": "req-1", "decision": "approve", "ts": now, "nonce": "n1"}
    rec.update(over)
    return rec, base64.b64encode(key.sign(devices.canonical(rec))).decode()

def verify(rec, sig, ledger="l.json", scope="decide", now_=now):
    return devices.verify_decision(etc, devices.NonceLedger(os.path.join(tmp, ledger)), rec, sig, now_, scope)

write_conf()

# accept
rec, sig = signed()
ok, reason = verify(rec, sig)
check(ok and reason == "ok", "a device's signed decision verifies (R-NOTIFY-4)")

# a bad signature must not consume the nonce (a DoS otherwise)
rec2, _ = signed(nonce="n-dos")
bad = base64.b64encode(b"x" * 64).decode()
ok, reason = verify(rec2, bad, ledger="dos.json")
check(not ok and reason == "bad-signature", "a bad signature is refused")
ok, reason = verify(rec2, base64.b64encode(key.sign(devices.canonical(rec2))).decode(), ledger="dos.json")
check(ok and reason == "ok", "a bad-signature attempt does not burn the nonce")

# replay
ok, reason = verify(rec, sig)
check(not ok and reason == "replayed-nonce", "a replayed nonce is refused")

# per-device nonce: d2 may reuse the same nonce string
with open(os.path.join(etc, "devices", "d2.conf"), "w") as f:
    f.write(f"id=d2\nname=Tablet\nplatform=ios\nsign_pub={pub}\nbox_pub={pub}\nscopes=decide\n")
rec_d2, sig_d2 = signed(device_id="d2", nonce="n1")
ok, reason = verify(rec_d2, sig_d2)
check(ok and reason == "ok", "two devices may use the same nonce string")

# malformed shapes
for over, label in [
    ({"decision": "banana"}, "an unknown decision"),
    ({"request_id": ""}, "an empty request_id"),
    ({"ts": "1800000000"}, "a non-int ts"),
    ({"nonce": ""}, "an empty nonce"),
    ({"reply": "x" * (devices.MAX_REPLY + 1)}, "an over-long reply"),
    ({"extra": "x"}, "an unexpected key"),
]:
    rec3, sig3 = signed(**over)
    ok, reason = verify(rec3, sig3)
    check(not ok and reason == "malformed", f"a record with {label} is malformed")

# tampered decision
rec4, sig4 = signed(nonce="n4")
rec4["decision"] = "decline"
ok, reason = verify(rec4, sig4)
check(not ok and reason == "bad-signature", "a tampered decision is refused")

# stale timestamp
rec5, sig5 = signed(nonce="n5", ts=now - devices.SKEW_SECONDS - 1)
ok, reason = verify(rec5, sig5)
check(not ok and reason == "stale-timestamp", "a stale decision is refused")

# unknown device and a path-like id (malformed before any path is built)
rec6, sig6 = signed(nonce="n6", device_id="nope")
ok, reason = verify(rec6, sig6)
check(not ok and reason == "unknown-device", "an unknown device is refused")
rec7, sig7 = signed(nonce="n7", device_id="../../etc/shadow")
ok, reason = verify(rec7, sig7)
check(not ok and reason == "malformed", "a path-like device id is malformed, never a path")

# scope
rec8, sig8 = signed(device_id="d2", nonce="n8")
ok, reason = verify(rec8, sig8, scope="act")
check(not ok and reason == "scope-missing", "a device without the scope is refused")
write_conf("decide,act")
rec9, sig9 = signed(nonce="n9")
ok, reason = verify(rec9, sig9, scope="act")
check(ok and reason == "ok", "a device with scope act may act")

# a symlinked conf is never followed
os.symlink(conf, os.path.join(etc, "devices", "d3.conf"))
rec10, sig10 = signed(nonce="n10", device_id="d3")
ok, reason = verify(rec10, sig10)
check(not ok and reason == "unknown-device", "a symlinked device conf is refused")

# a damaged ledger fails closed
with open(os.path.join(tmp, "broken.json"), "w") as f:
    f.write("{not json")
rec11, sig11 = signed(nonce="n11")
ok, reason = verify(rec11, sig11, ledger="broken.json")
check(not ok and reason == "ledger-unreadable", "a damaged ledger fails closed")

# a symlinked or zero-byte ledger also fails closed (not "nothing seen yet")
os.symlink(os.path.join(tmp, "l.json"), os.path.join(tmp, "link.json"))
rec_s, sig_s = signed(nonce="n-sym")
ok, reason = verify(rec_s, sig_s, ledger="link.json")
check(not ok and reason == "ledger-unreadable", "a symlinked ledger fails closed")
open(os.path.join(tmp, "empty.json"), "w").close()
rec_e, sig_e = signed(nonce="n-empty")
ok, reason = verify(rec_e, sig_e, ledger="empty.json")
check(not ok and reason == "ledger-unreadable", "a zero-byte ledger fails closed")

# crypto absent fails closed
devices.HAVE_CRYPTO = False
ok, reason = verify(rec11, sig11)
check(not ok and reason == "crypto-unavailable", "without python-cryptography it fails closed")
devices.HAVE_CRYPTO = True

# revoked
os.rename(conf, conf + ".revoked")
rec12, sig12 = signed(nonce="n12")
ok, reason = verify(rec12, sig12)
check(not ok and reason == "unknown-device", "a revoked device is refused")

# CLI works
os.rename(conf + ".revoked", conf)
import subprocess
rec13, sig13 = signed(nonce="n13")
out = subprocess.run(
    [sys.executable, devices_py, "--etc", etc, "--ledger", os.path.join(tmp, "cli.json"),
     "--now", str(now), "--signature", sig13, json.dumps(rec13)],
    capture_output=True, text=True)
check(out.returncode == 0 and out.stdout.strip() == "ok", "the CLI verifies a decision")

sys.exit(1 if fails else 0)
PY
st=$?
if [[ $st -eq 0 ]]; then
  echo "device-verify-test RESULT: PASS"
else
  echo "device-verify-test RESULT: FAIL"
fi
exit $st
