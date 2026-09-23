"""lib/envelope.py -- the end-to-end envelope the away courier carries (N-11, R-NOTIFY-8).

A device's public box key (X25519, stored at pairing) encrypts a state document so
the parent's own server never sees a child's data. The box only *seals*: the app
opens with the matching private key. Off-by-default and one-directional in this
slice -- the courier that posts it is a later step.

Scheme (pinned in SPEC.md Appendix H and by
clients/parent/test-vectors/notify-vectors.json):

1. a fresh ephemeral X25519 keypair, ECDH with the device's box key;
2. HKDF-SHA256 (salt `omarchy-kids-envelope-v1`, info
   `x25519-chacha20poly1305`) to a 32-byte key;
3. ChaCha20-Poly1305, a random 12-byte nonce, the device id as associated data --
   so a sealed document cannot be replayed to another device.

The envelope is `{v, device_id, eph_pub, nonce, ct}`, all base64 except the
version. Stdlib + python-cryptography. `seal` takes an optional ephemeral key and
nonce so the vectors are reproducible; the real path uses fresh random ones.
"""

from __future__ import annotations

import argparse
import base64
import json
import os
import sys

try:
    from cryptography.hazmat.primitives import hashes, serialization
    from cryptography.hazmat.primitives.asymmetric.x25519 import X25519PrivateKey, X25519PublicKey
    from cryptography.hazmat.primitives.ciphers.aead import ChaCha20Poly1305
    from cryptography.hazmat.primitives.kdf.hkdf import HKDF

    HAVE_CRYPTO = True
except ImportError:  # pragma: no cover - the skip path
    HAVE_CRYPTO = False

VERSION = 1
SALT = b"omarchy-kids-envelope-v1"
INFO = b"x25519-chacha20poly1305"


def _b64(raw):
    return base64.b64encode(raw).decode()


def _ub64(text):
    return base64.b64decode(text, validate=True)


def _derive(shared, device_id):
    return HKDF(
        algorithm=hashes.SHA256(), length=32, salt=SALT, info=INFO + b"\x00" + device_id.encode()
    ).derive(shared)


def seal(device_id, box_pub_b64, plaintext, eph_priv=None, nonce=None):
    """Seal `plaintext` for one device; returns the envelope dict.

    `eph_priv` (32 raw bytes) and `nonce` (12 bytes) are for the test vectors; the
    real caller leaves them out and gets fresh random ones.
    """
    if not HAVE_CRYPTO:
        raise RuntimeError("python-cryptography is not installed")
    if not isinstance(device_id, str) or not device_id:
        raise ValueError("device_id is required")
    recipient = X25519PublicKey.from_public_bytes(_ub64(box_pub_b64))
    ephemeral = (
        X25519PrivateKey.from_private_bytes(eph_priv) if eph_priv is not None else X25519PrivateKey.generate()
    )
    eph_pub = ephemeral.public_key().public_bytes(
        serialization.Encoding.Raw, serialization.PublicFormat.Raw
    )
    if nonce is None:
        nonce = os.urandom(12)
    if len(nonce) != 12:
        raise ValueError("nonce must be 12 bytes")
    key = _derive(ephemeral.exchange(recipient), device_id)
    ct = ChaCha20Poly1305(key).encrypt(nonce, plaintext, device_id.encode())
    return {
        "v": VERSION,
        "device_id": device_id,
        "eph_pub": _b64(eph_pub),
        "nonce": _b64(nonce),
        "ct": _b64(ct),
    }


def open_envelope(device_id, box_priv_raw, envelope):
    """Open an envelope with the device's private box key. Raises on any failure."""
    if not HAVE_CRYPTO:
        raise RuntimeError("python-cryptography is not installed")
    if not isinstance(envelope, dict) or envelope.get("v") != VERSION:
        raise ValueError("unsupported envelope")
    if envelope.get("device_id") != device_id:
        raise ValueError("envelope is for another device")
    private = X25519PrivateKey.from_private_bytes(box_priv_raw)
    eph_pub = X25519PublicKey.from_public_bytes(_ub64(envelope["eph_pub"]))
    key = _derive(private.exchange(eph_pub), device_id)
    return ChaCha20Poly1305(key).decrypt(
        _ub64(envelope["nonce"]), _ub64(envelope["ct"]), device_id.encode()
    )


def _main(argv):
    if not HAVE_CRYPTO:
        print("envelope.py: python-cryptography is not installed", file=sys.stderr)
        return 1
    parser = argparse.ArgumentParser(prog="envelope.py")
    sub = parser.add_subparsers(dest="cmd", required=True)
    seal_cmd = sub.add_parser("seal")
    seal_cmd.add_argument("--device-id", required=True)
    seal_cmd.add_argument("--box-pub", required=True)
    seal_cmd.add_argument("--eph-hex")
    seal_cmd.add_argument("--nonce-hex")
    seal_cmd.add_argument("plaintext_file")
    open_cmd = sub.add_parser("open")
    open_cmd.add_argument("--device-id", required=True)
    open_cmd.add_argument("--box-priv-hex", required=True)
    open_cmd.add_argument("envelope_file")
    args = parser.parse_args(argv)
    if args.cmd == "seal":
        with open(args.plaintext_file, "rb") as f:
            plaintext = f.read()
        envelope = seal(
            args.device_id,
            args.box_pub,
            plaintext,
            eph_priv=bytes.fromhex(args.eph_hex) if args.eph_hex else None,
            nonce=bytes.fromhex(args.nonce_hex) if args.nonce_hex else None,
        )
        json.dump(envelope, sys.stdout, indent=2, sort_keys=True)
        print()
        return 0
    with open(args.envelope_file, encoding="utf-8") as f:
        envelope = json.load(f)
    plaintext = open_envelope(args.device_id, bytes.fromhex(args.box_priv_hex), envelope)
    sys.stdout.buffer.write(plaintext)
    return 0


if __name__ == "__main__":  # pragma: no cover
    sys.exit(_main(sys.argv[1:]))
