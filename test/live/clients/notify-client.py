#!/usr/bin/env python3
"""A scripted notification client for the live acceptance run (N-6/N-9/N-10).

It stands in for the not-yet-built parent app: it pairs with a pairing token and
signs a decision, a review decision or an ACT (grant/end), exactly as
`clients/parent/README.md` specifies. Stdlib plus
python-cryptography only (both package dependencies); it is a test helper, not
shipped in the package.

  notify-client.py pair --key FILE --id ID --token TOKEN [--name N]
  notify-client.py decide --key FILE --id ID --request REQ_ID [--decision approve|decline]
"""

import argparse
import base64
import hashlib
import hmac
import json
import os
import socket
import ssl
import sys
import time

from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey

HOST = os.environ.get("KIDS_RELAY_HOST", "127.0.0.1")
PORT = int(os.environ.get("KIDS_RELAY_PORT", "8447"))
SIGN_CONTEXT = b"omarchy-kids-decision-v1\n"
REQUEST_CONTEXT = b"omarchy-kids-request-v1\n"


def b64(raw):
    return base64.b64encode(raw).decode()


def load_key(path):
    if os.path.exists(path):
        with open(path, "rb") as f:
            seed = f.read()
    else:
        seed = os.urandom(32)
        fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
        with os.fdopen(fd, "wb") as f:
            f.write(seed)
    return Ed25519PrivateKey.from_private_bytes(seed)


def raw_pub(key):
    return key.public_key().public_bytes(serialization.Encoding.Raw, serialization.PublicFormat.Raw)


def https_request(method, path, body, headers=None):
    ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE  # the live runner pins nothing; the app pins the SPKI
    head = "".join(f"{k}: {v}\r\n" for k, v in (headers or {}).items())
    with socket.create_connection((HOST, PORT), timeout=10) as raw:
        with ctx.wrap_socket(raw, server_hostname=HOST) as s:
            s.sendall(
                f"{method} {path} HTTP/1.1\r\nHost: {HOST}\r\n{head}Content-Length: {len(body)}\r\n\r\n".encode()
                + body
            )
            data = b""
            while b"\r\n\r\n" not in data:
                chunk = s.recv(4096)
                if not chunk:
                    break
                data += chunk
            head_bytes, _, rest = data.partition(b"\r\n\r\n")
            return int(head_bytes.split(b" ")[1]), rest


def do_pair(args):
    key = load_key(args.key)
    sign_pub = b64(raw_pub(key))
    box_pub = b64(b"\x01" * 32)  # the app would use an X25519 key; only the string is checked here
    proof = hmac.new(
        bytes.fromhex(args.token), f"{sign_pub}|{box_pub}|{args.name}".encode(), hashlib.sha256
    ).hexdigest()
    frame = {
        "id": args.id,
        "name": args.name,
        "platform": "linux",
        "sign_pub": sign_pub,
        "box_pub": box_pub,
        "proof": proof,
    }
    body = json.dumps(frame, separators=(",", ":"), sort_keys=True).encode()
    code, reply = https_request("POST", "/v1/pair", body)
    print(f"pair {code} {reply.decode(errors='replace').strip()}")
    return 0 if code == 200 else 1


def do_decide(args):
    key = load_key(args.key)
    now = int(time.time())
    nonce = f"live-{os.getpid()}-{now}"
    record = {
        "device_id": args.id,
        "request_id": args.request,
        "decision": args.decision,
        "ts": now,
        "nonce": nonce,
    }
    record_sig = b64(
        key.sign(SIGN_CONTEXT + json.dumps(record, sort_keys=True, separators=(",", ":")).encode())
    )
    body = json.dumps({"record": record, "signature": record_sig}, separators=(",", ":"), sort_keys=True).encode()
    path = f"/v1/requests/{args.request}/decision"
    message = {
        "device_id": args.id,
        "ts": now,
        "nonce": nonce,
        "method": "POST",
        "path": path,
        "body_sha256": hashlib.sha256(body).hexdigest(),
    }
    sig = b64(
        key.sign(REQUEST_CONTEXT + json.dumps(message, sort_keys=True, separators=(",", ":")).encode())
    )
    headers = {"X-Kids-Device": args.id, "X-Kids-Sig": f"{now}.{nonce}.{sig}"}
    code, reply = https_request("POST", path, body, headers)
    print(f"decide {code} {reply.decode(errors='replace').strip()}")
    return 0 if code == 200 else 1


def do_review(args):
    key = load_key(args.key)
    now = int(time.time())
    nonce = f"live-{os.getpid()}-{now}"
    record = {
        "device_id": args.id,
        "review_id": args.review_id,
        "decision": args.decision,
        "seen": args.seen,
        "ts": now,
        "nonce": nonce,
    }
    record_sig = b64(
        key.sign(SIGN_CONTEXT + json.dumps(record, sort_keys=True, separators=(",", ":")).encode())
    )
    body = json.dumps({"record": record, "signature": record_sig}, separators=(",", ":"), sort_keys=True).encode()
    path = f"/v1/reviews/{args.review_id}/decision"
    message = {
        "device_id": args.id,
        "ts": now,
        "nonce": nonce,
        "method": "POST",
        "path": path,
        "body_sha256": hashlib.sha256(body).hexdigest(),
    }
    sig = b64(
        key.sign(REQUEST_CONTEXT + json.dumps(message, sort_keys=True, separators=(",", ":")).encode())
    )
    headers = {"X-Kids-Device": args.id, "X-Kids-Sig": f"{now}.{nonce}.{sig}"}
    code, reply = https_request("POST", path, body, headers)
    print(f"review {code} {reply.decode(errors='replace').strip()}")
    return 0 if code == 200 else 1


def do_act(args):
    key = load_key(args.key)
    now = int(time.time())
    nonce = f"live-{os.getpid()}-{now}"
    record = {
        "device_id": args.id,
        "account": args.account,
        "action": args.action,
        "ts": now,
        "nonce": nonce,
    }
    if args.action == "grant":
        record["minutes"] = args.minutes
    record_sig = b64(
        key.sign(SIGN_CONTEXT + json.dumps(record, sort_keys=True, separators=(",", ":")).encode())
    )
    body = json.dumps({"record": record, "signature": record_sig}, separators=(",", ":"), sort_keys=True).encode()
    path = f"/v1/kids/{args.account}/{args.action}"
    message = {
        "device_id": args.id,
        "ts": now,
        "nonce": nonce,
        "method": "POST",
        "path": path,
        "body_sha256": hashlib.sha256(body).hexdigest(),
    }
    sig = b64(
        key.sign(REQUEST_CONTEXT + json.dumps(message, sort_keys=True, separators=(",", ":")).encode())
    )
    headers = {"X-Kids-Device": args.id, "X-Kids-Sig": f"{now}.{nonce}.{sig}"}
    code, reply = https_request("POST", path, body, headers)
    print(f"act {code} {reply.decode(errors='replace').strip()}")
    return 0 if code == 200 else 1


def main():
    parser = argparse.ArgumentParser(prog="notify-client.py")
    sub = parser.add_subparsers(dest="cmd", required=True)
    pair = sub.add_parser("pair")
    pair.add_argument("--key", required=True)
    pair.add_argument("--id", required=True)
    pair.add_argument("--token", required=True)
    pair.add_argument("--name", default="live-client")
    decide = sub.add_parser("decide")
    decide.add_argument("--key", required=True)
    decide.add_argument("--id", required=True)
    decide.add_argument("--request", required=True)
    decide.add_argument("--decision", default="approve", choices=["approve", "decline"])
    review = sub.add_parser("review")
    review.add_argument("--key", required=True)
    review.add_argument("--id", required=True)
    review.add_argument("--review-id", required=True)
    review.add_argument("--decision", default="approve", choices=["approve", "deny"])
    review.add_argument("--seen", required=True)
    act = sub.add_parser("act")
    act.add_argument("--key", required=True)
    act.add_argument("--id", required=True)
    act.add_argument("--account", required=True)
    act.add_argument("--action", default="grant", choices=["grant", "end"])
    act.add_argument("--minutes", type=int, default=15)
    args = parser.parse_args()
    if args.cmd == "pair":
        return do_pair(args)
    if args.cmd == "decide":
        return do_decide(args)
    if args.cmd == "review":
        return do_review(args)
    return do_act(args)


if __name__ == "__main__":
    sys.exit(main())
