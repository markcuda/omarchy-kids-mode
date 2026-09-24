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

import base64
import os

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


def _derive(shared):
    """HKDF from the ECDH secret. The device id is bound as AEAD associated data,
    not in `info`, so the pinned suite name is the whole info string."""
    return HKDF(algorithm=hashes.SHA256(), length=32, salt=SALT, info=INFO).derive(shared)


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
    key = _derive(ephemeral.exchange(recipient))
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
    key = _derive(private.exchange(eph_pub))
    return ChaCha20Poly1305(key).decrypt(
        _ub64(envelope["nonce"]), _ub64(envelope["ct"]), device_id.encode()
    )
