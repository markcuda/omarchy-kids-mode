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
import base64, datetime, hashlib, importlib.util, ipaddress, itertools, json, os, socket, ssl, subprocess, sys, threading, time

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
def fake_authd(ready, reply=b"ok\n"):
    srv = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM); srv.bind(auth_sock); srv.listen(1); srv.settimeout(30)
    ready.set(); conn, _ = srv.accept(); conn.recv(4096); conn.sendall(reply); conn.close(); srv.close()

status = os.path.join(tmp, "status.json")
queue = os.path.join(tmp, "queue"); os.makedirs(queue, exist_ok=True)
with open(status, "w") as f:
    json.dump({"generated_at": "x", "kids": [{"kid": "kid-ada", "live": True}]}, f)
# One open add-on review, so the state's reviews list is proven, not just present.
reviews = os.path.join(tmp, "reviews", "open"); os.makedirs(reviews, exist_ok=True)
review_id = "kid-ada." + hashlib.sha256(b"org.mozilla.firefox").hexdigest()[:16]
with open(os.path.join(reviews, review_id + ".json"), "w") as f:
    json.dump({"kid": "kid-ada", "id": "org.mozilla.firefox", "was": "aa" * 32,
               "now": "bb" * 32, "detected_at": 5, "state": "open"}, f)

probe = socket.socket(); probe.bind(("127.0.0.1", 0)); port = probe.getsockname()[1]; probe.close()
ready = threading.Event(); threading.Thread(target=fake_authd, args=(ready,), daemon=True).start(); ready.wait(30)
proc = subprocess.Popen([sys.executable, os.path.join(root, "bin", "omarchy-kids-relayd"),
                         "--bind", "127.0.0.1", "--port", str(port), "--cert", cert_path, "--key", key_path,
                         "--devices-json", devices_json, "--status", status, "--queue", queue, "--auth-sock", auth_sock,
                         "--reviews", reviews,
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
    check([r["id"] for r in json.loads(body)["reviews"]] == [review_id],
          "the state document carries the open add-on review (R-NOTIFY-12)")

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

    # R-NOTIFY-12: a review decision rides the same path, with its own record.
    rev_id = "kid-ada." + "a" * 16
    rev_rec = {"device_id": "d1", "review_id": rev_id, "decision": "approve",
               "seen": "ab" * 32, "ts": int(time.time()), "nonce": "rev-1"}
    rev_sig = base64.b64encode(dev_key.sign(devices.canonical(rev_rec))).decode()
    rev_frame = json.dumps({"record": rev_rec, "signature": rev_sig})
    rev_path = "/v1/reviews/" + rev_id + "/decision"
    try:
        os.unlink(auth_sock)
    except OSError:
        pass
    ready_rev = threading.Event()
    threading.Thread(target=fake_authd, args=(ready_rev,), daemon=True).start()
    if not ready_rev.wait(30):
        raise RuntimeError("the review stub did not start")
    code, body = request("POST", rev_path,
                         signed_headers(rev_path, rev_frame.encode(), method="POST"), rev_frame.encode())
    check(code == 200 and json.loads(body)["reply"] == "ok", "a review POST is forwarded to authd")
    code, _ = request("POST", rev_path, {}, rev_frame.encode())
    check(code == 403, "an unsigned review POST is refused at the relay")

    # R-NOTIFY-13: a grant and an end ride the same path, with their own record.
    act_rec = {"device_id": "d1", "account": "kid-ada", "action": "grant",
               "minutes": 15, "ts": int(time.time()), "nonce": "act-1"}
    act_sig = base64.b64encode(dev_key.sign(devices.canonical(act_rec))).decode()
    act_frame = json.dumps({"record": act_rec, "signature": act_sig})
    granth_path = "/v1/kids/kid-ada/grant"
    try:
        os.unlink(auth_sock)
    except OSError:
        pass
    ready_act = threading.Event()
    threading.Thread(target=fake_authd, args=(ready_act,), daemon=True).start()
    if not ready_act.wait(30):
        raise RuntimeError("the act stub did not start")
    code, body = request("POST", granth_path,
                         signed_headers(granth_path, act_frame.encode(), method="POST"), act_frame.encode())
    check(code == 200 and json.loads(body)["reply"] == "ok", "a grant POST is forwarded to authd")
    code, _ = request("POST", granth_path, {}, act_frame.encode())
    check(code == 403, "an unsigned grant POST is refused at the relay")
    bad_account_path = "/v1/kids/Kid!/grant"
    bad_account_frame = json.dumps({"record": dict(act_rec, account="Kid!"), "signature": act_sig})
    code, _ = request("POST", bad_account_path,
                      signed_headers(bad_account_path, bad_account_frame.encode(), method="POST"),
                      bad_account_frame.encode())
    check(code == 400, "an account that is not a kid account is refused before authd")
    # A record naming another account, or the wrong action, is refused before authd.
    other_account = json.dumps({"record": dict(act_rec, account="kid-dot"), "signature": act_sig})
    code, _ = request("POST", granth_path,
                      signed_headers(granth_path, other_account.encode(), method="POST"), other_account.encode())
    check(code == 400, "a grant naming another account is refused before authd")
    wrong_action = json.dumps({"record": dict(act_rec, action="end", minutes=None), "signature": act_sig})
    code, _ = request("POST", granth_path,
                      signed_headers(granth_path, wrong_action.encode(), method="POST"), wrong_action.encode())
    check(code == 400, "an end record on the grant route is refused before authd")
    zero = json.dumps({"record": dict(act_rec, minutes=0), "signature": act_sig})
    code, _ = request("POST", granth_path,
                      signed_headers(granth_path, zero.encode(), method="POST"), zero.encode())
    check(code == 400, "minutes out of range is refused before authd")
    # end
    end_rec = {"device_id": "d1", "account": "kid-ada", "action": "end",
               "ts": int(time.time()), "nonce": "act-2"}
    end_sig = base64.b64encode(dev_key.sign(devices.canonical(end_rec))).decode()
    end_frame = json.dumps({"record": end_rec, "signature": end_sig})
    end_path = "/v1/kids/kid-ada/end"
    try:
        os.unlink(auth_sock)
    except OSError:
        pass
    ready_end = threading.Event()
    threading.Thread(target=fake_authd, args=(ready_end,), daemon=True).start()
    if not ready_end.wait(30):
        raise RuntimeError("the end stub did not start")
    code, body = request("POST", end_path,
                         signed_headers(end_path, end_frame.encode(), method="POST"), end_frame.encode())
    check(code == 200 and json.loads(body)["reply"] == "ok", "an end POST is forwarded to authd")
    end_with_minutes = json.dumps({"record": dict(end_rec, minutes=15), "signature": end_sig})
    code, _ = request("POST", end_path,
                      signed_headers(end_path, end_with_minutes.encode(), method="POST"), end_with_minutes.encode())
    check(code == 400, "an end record carrying minutes is refused before authd")
    bad_id_path = "/v1/reviews/not-a-review/decision"
    code, _ = request("POST", bad_id_path,
                      signed_headers(bad_id_path, rev_frame.encode(), method="POST"), rev_frame.encode())
    check(code == 400, "a path that is not a review id is refused before authd")
    other = json.dumps({"record": dict(rev_rec, review_id="kid-ada." + "b" * 16), "signature": rev_sig})
    code, _ = request("POST", rev_path,
                      signed_headers(rev_path, other.encode(), method="POST"), other.encode())
    check(code == 400, "a record naming another review is refused before authd")

    # Pairing is pre-auth and carried to authd (R-NOTIFY-5): the single-use token
    # in the frame is the credential, verified by root.
    try:
        os.unlink(auth_sock)
    except OSError:
        pass
    ready2 = threading.Event()
    threading.Thread(target=fake_authd, args=(ready2,), daemon=True).start()
    if not ready2.wait(30):
        raise RuntimeError("the second authd stub did not start")
    pair_frame = json.dumps({"id": "d2", "name": "Phone", "platform": "android",
                             "sign_pub": "x", "box_pub": "y", "proof": "p"})
    code, body = request("POST", "/v1/pair", {}, pair_frame.encode())
    check(code == 200 and json.loads(body)["reply"] == "ok", "a pair POST is forwarded to authd")
    code, _ = request("POST", "/v1/pair", {}, b'{"id":"d2"}')
    check(code == 400, "a malformed pair POST is refused before authd")

    # A refusal is generic: an unauthenticated caller gets no authd reason.
    try:
        os.unlink(auth_sock)
    except OSError:
        pass
    ready3 = threading.Event()
    threading.Thread(target=fake_authd, args=(ready3, b"no bad-proof\n"), daemon=True).start()
    if not ready3.wait(30):
        raise RuntimeError("the third authd stub did not start")
    code, body = request("POST", "/v1/pair", {}, pair_frame.encode())
    check(code == 403 and b"bad-proof" not in body, "a pair refusal is generic to the caller")

    # SSE: a signed /v1/events streams a state event
    ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT); ctx.check_hostname = False; ctx.verify_mode = ssl.CERT_NONE
    ss = ctx.wrap_socket(socket.create_connection(("127.0.0.1", port), timeout=10), server_hostname="127.0.0.1")
    h = signed_headers("/v1/events")
    ss.sendall(("GET /v1/events HTTP/1.1\r\nHost: x\r\n" + "".join(f"{k}: {v}\r\n" for k, v in h.items()) + "\r\n").encode())
    data = b""
    ss.settimeout(8)
    try:
        while b"event: state" not in data:
            chunk = ss.recv(4096)
            if not chunk:
                break
            data += chunk
    except OSError:
        pass
    ss.close()
    check(b"event: state" in data and b"kid-ada" in data, "a signed SSE stream sends the state")

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

# --- lifecycle: it stops itself once Kids Mode is no longer in use ---------
idle_status = os.path.join(tmp, "status-idle.json")
with open(idle_status, "w") as f:
    json.dump({"kids": [{"kid": "kid-ada", "live": False}]}, f)
idle_queue = os.path.join(tmp, "queue-idle")
os.makedirs(idle_queue, exist_ok=True)
probe2 = socket.socket()
probe2.bind(("127.0.0.1", 0))
port2 = probe2.getsockname()[1]
probe2.close()
proc2 = subprocess.Popen([sys.executable, os.path.join(root, "bin", "omarchy-kids-relayd"),
                          "--bind", "127.0.0.1", "--port", str(port2), "--cert", cert_path, "--key", key_path,
                          "--devices-json", devices_json, "--status", idle_status, "--queue", idle_queue,
                          "--auth-sock", auth_sock, "--nonce-ledger", os.path.join(tmp, "nonces2.json"),
                          "--share", os.path.join(root, "share"), "--lib", os.path.join(root, "lib"),
                          "--needless-seconds", "1"],
                         stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
# Hold a device event-stream open: the relay must still stop -- an SSE
# subscriber is not an always-on listener (R-NOTIFY-1).
ctx2 = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT); ctx2.check_hostname = False; ctx2.verify_mode = ssl.CERT_NONE
ss2 = None
for _ in range(50):
    try:
        ss2 = ctx2.wrap_socket(socket.create_connection(("127.0.0.1", port2), timeout=5), server_hostname="127.0.0.1")
        h2 = signed_headers("/v1/events")
        ss2.sendall(("GET /v1/events HTTP/1.1\r\nHost: x\r\n" + "".join(f"{k}: {v}\r\n" for k, v in h2.items()) + "\r\n").encode())
        break
    except OSError:
        ss2 = None
        time.sleep(0.2)
try:
    stderr = proc2.communicate(timeout=30)[1].decode()
    check("not in use" in stderr, "the relay stops itself once Kids Mode is no longer in use, even with a device streaming (R-NOTIFY-1)")
except subprocess.TimeoutExpired:
    proc2.kill()
    check(False, "the relay stops itself once Kids Mode is no longer in use, even with a device streaming (R-NOTIFY-1)")
if ss2 is not None:
    ss2.close()

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
