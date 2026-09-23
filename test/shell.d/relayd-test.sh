#!/bin/bash
# Tests bin/omarchy-kids-relayd over real TLS (SPEC.md R-NOTIFY-1/2): the fence
# in the unit, a signed read served, the refusals (unsigned, bad signature,
# replay, stale, unknown device, avatar traversal, plaintext), and a decision
# forwarded to authd. Needs python-cryptography to mint a certificate and sign.
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=test/shell.d/lib.sh
source "$DIR/test/shell.d/lib.sh"

fail=0
# The fence is a label claim until the unit carries it.
if grep -q '^IPAddressDeny=any$' "$DIR/systemd/omarchy-kids-relayd.service" &&
  grep -q '^IPAddressAllow=localhost link-local multicast 10\.0\.0\.0/8 172\.16\.0\.0/12 192\.168\.0\.0/16 fc00::/7 fe80::/10$' \
    "$DIR/systemd/omarchy-kids-relayd.service"; then
  echo "PASS  the relayd unit denies every address but the LAN (R-NOTIFY-1)"
else
  echo "FAIL  the relayd unit's fence is missing or the allow list is wrong"
  fail=1
fi

if ! python3 -c "import cryptography" >/dev/null 2>&1; then
  echo "SKIP relayd-test.sh: python-cryptography not installed — the TLS checks did not run"
  exit $fail
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

python3 - "$DIR" "$TMP" <<'PY'
import base64, datetime, importlib.util, ipaddress, itertools, json, os, socket, ssl, subprocess, sys, threading, time

root, tmp = sys.argv[1], sys.argv[2]
fails = []
def check(cond, label):
    print(("PASS  " if cond else "FAIL  ") + label)
    if not cond:
        fails.append(label)

def load(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod

devices = load(os.path.join(root, "lib", "devices.py"), "kids_devices")
from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.x509.oid import NameOID

# --- self-signed cert for 127.0.0.1 ---------------------------------------
tls_key = ec.generate_private_key(ec.SECP256R1())
name = x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, "127.0.0.1")])
now = datetime.datetime.now(datetime.timezone.utc)
cert = (x509.CertificateBuilder().subject_name(name).issuer_name(name)
        .public_key(tls_key.public_key()).serial_number(x509.random_serial_number())
        .not_valid_before(now - datetime.timedelta(days=1))
        .not_valid_after(now + datetime.timedelta(days=1))
        .add_extension(x509.SubjectAlternativeName([x509.IPAddress(ipaddress.ip_address("127.0.0.1"))]), critical=False)
        .sign(tls_key, hashes.SHA256()))
cert_path, key_path = os.path.join(tmp, "cert.pem"), os.path.join(tmp, "key.pem")
with open(cert_path, "wb") as f:
    f.write(cert.public_bytes(serialization.Encoding.PEM))
with open(key_path, "wb") as f:
    f.write(tls_key.private_bytes(serialization.Encoding.PEM,
                                  serialization.PrivateFormat.PKCS8, serialization.NoEncryption()))

# --- the public device copy, and a 0600 conf with a WRONG key -------------
# The relay runs as its own user and cannot read the 0600 confs; that it reads
# devices.json is proved by the conf holding a different (bogus) key.
dev_key = Ed25519PrivateKey.generate()
pub = base64.b64encode(dev_key.public_key().public_bytes_raw()).decode()
bogus = base64.b64encode(b"\x00" * 32).decode()
run_dir = os.path.join(tmp, "run"); os.makedirs(run_dir, exist_ok=True)
devices_json = os.path.join(run_dir, "devices.json")
with open(devices_json, "w") as f:
    json.dump([{"id": "d1", "name": "Phone", "platform": "android",
                "sign_pub": pub, "box_pub": pub, "scopes": ["decide", "act"]}], f)
os.chmod(devices_json, 0o644)
etc = os.path.join(tmp, "etc"); os.makedirs(os.path.join(etc, "devices"), exist_ok=True)
conf = os.path.join(etc, "devices", "d1.conf")
with open(conf, "w") as f:
    f.write(f"id=d1\nname=Phone\nplatform=android\nsign_pub={bogus}\nbox_pub={bogus}\nscopes=decide,act\n")
os.chmod(conf, 0o600)

counter = itertools.count()
def signed_headers(path, body=b"", ts=None, nonce=None, device="d1", method="GET"):
    nonce = nonce or f"n{next(counter)}"
    t = int(time.time()) if ts is None else ts
    sig = base64.b64encode(dev_key.sign(devices.request_message(device, t, nonce, method, path, body))).decode()
    return {"X-Kids-Device": device, "X-Kids-Sig": f"{t}.{nonce}.{sig}"}

# --- stub authd for the decision POST -------------------------------------
auth_sock = os.path.join(tmp, "auth.sock")
def fake_authd(ready):
    srv = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM); srv.bind(auth_sock); srv.listen(1); srv.settimeout(10)
    ready.set(); conn, _ = srv.accept(); conn.recv(4096); conn.sendall(b"ok\n"); conn.close(); srv.close()

status = os.path.join(tmp, "status.json")
queue = os.path.join(tmp, "queue"); os.makedirs(queue, exist_ok=True)
with open(status, "w") as f:
    json.dump({"generated_at": "x", "kids": [{"kid": "kid-ada", "live": True}]}, f)

probe = socket.socket(); probe.bind(("127.0.0.1", 0)); port = probe.getsockname()[1]; probe.close()
ready = threading.Event(); threading.Thread(target=fake_authd, args=(ready,), daemon=True).start(); ready.wait(10)
proc = subprocess.Popen([sys.executable, os.path.join(root, "bin", "omarchy-kids-relayd"),
                         "--bind", "127.0.0.1", "--port", str(port), "--cert", cert_path, "--key", key_path,
                         "--devices-json", devices_json, "--status", status, "--queue", queue, "--auth-sock", auth_sock,
                         "--nonce-ledger", os.path.join(tmp, "nonces.json"), "--share", os.path.join(root, "share"),
                         "--lib", os.path.join(root, "lib")],
                        stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)

def request(method, path, headers, body=b""):
    ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT); ctx.check_hostname = False; ctx.verify_mode = ssl.CERT_NONE
    s = socket.create_connection(("127.0.0.1", port), timeout=10)
    ss = ctx.wrap_socket(s, server_hostname="127.0.0.1")
    head = "".join(f"{k}: {v}\r\n" for k, v in headers.items())
    ss.sendall(f"{method} {path} HTTP/1.1\r\nHost: x\r\n{head}Content-Length: {len(body)}\r\n\r\n".encode() + body)
    data = b""
    while b"\r\n\r\n" not in data:
        chunk = ss.recv(4096)
        if not chunk:
            break
        data += chunk
    ss.close()
    head, _, rest = data.partition(b"\r\n\r\n")
    return int(head.split(b" ")[1]), rest

for _ in range(50):
    try:
        request("GET", "/v1/state", signed_headers("/v1/state")); break
    except OSError:
        time.sleep(0.2)

try:
    code, body = request("GET", "/v1/state", signed_headers("/v1/state"))
    check(code == 200 and json.loads(body)["kids"][0]["kid"] == "kid-ada",
          "a signed read is served over TLS (R-NOTIFY-1)")
    check("recent" in json.loads(body), "the state document carries recent (Appendix H)")

    code, _ = request("GET", "/v1/state", {})
    check(code == 403, "an unsigned read is refused")

    bad = signed_headers("/v1/state"); good_sig = bad["X-Kids-Sig"]
    bad["X-Kids-Sig"] = good_sig.split(".")[0] + "." + good_sig.split(".")[1] + "." + base64.b64encode(b"x" * 64).decode()
    check(request("GET", "/v1/state", bad)[0] == 403, "a bad signature is refused")

    replay = signed_headers("/v1/state")
    request("GET", "/v1/state", replay)
    code, body = request("GET", "/v1/state", replay)
    check(code == 403 and json.loads(body).get("error") == "replayed-nonce", "a replayed nonce is refused")

    code, body = request("GET", "/v1/state", signed_headers("/v1/state", ts=int(time.time()) - 400))
    check(code == 403 and json.loads(body).get("error") == "stale-timestamp", "a stale request is refused")

    code, _ = request("GET", "/v1/state", signed_headers("/v1/state", device="nope"))
    check(code == 403, "an unknown device is refused")

    code, _ = request("GET", "/v1/avatars/../x.svg", signed_headers("/v1/avatars/../x.svg"))
    check(code == 404, "an avatar path traversal is refused")

    dec_rec = {"device_id": "d1", "request_id": "req-1", "decision": "approve", "ts": int(time.time()), "nonce": "post-1"}
    dec_sig = base64.b64encode(dev_key.sign(devices.canonical(dec_rec))).decode()
    frame = json.dumps({"record": dec_rec, "signature": dec_sig})
    code, body = request("POST", "/v1/requests/req-1/decision",
                         signed_headers("/v1/requests/req-1/decision", frame.encode(), method="POST"), frame.encode())
    check(code == 200 and json.loads(body)["reply"] == "ok", "a decision POST is forwarded to authd")
    code, _ = request("POST", "/v1/requests/req-1/decision", {}, frame.encode())
    check(code == 403, "an unsigned decision POST is refused at the relay (P1)")

    # a plaintext client gets no HTTP response (TLS is required)
    raw = socket.create_connection(("127.0.0.1", port), timeout=5)
    raw.sendall(b"GET /v1/state HTTP/1.1\r\nHost: x\r\n\r\n")
    raw.settimeout(5)
    try:
        got = raw.recv(64)
    except OSError:
        got = b""
    raw.close()
    check(not got.startswith(b"HTTP/1.1 200"), "a plaintext client is not served")
finally:
    proc.terminate()
    try:
        proc.wait(timeout=10)
    except subprocess.TimeoutExpired:
        proc.kill()

sys.exit(1 if fails else 0)
PY
st=$?
[[ $st -ne 0 ]] && fail=1
if [[ $fail -eq 0 ]]; then
  echo "relayd-test RESULT: PASS"
else
  echo "relayd-test RESULT: FAIL"
fi
exit $fail
