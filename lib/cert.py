"""lib/cert.py -- mint the relay's self-signed TLS certificate (R-NOTIFY-1).

The relay is TLS-only and the parent pairs by pinning this certificate's
fingerprint, so there is no CA and no DNS name to trust. python-cryptography is
already a package dependency (lib/devices.py uses it); where it is missing this
reports so and the caller fails closed.

Stdlib + cryptography only. Root writes the files; the caller sets the modes.
"""

from __future__ import annotations

import argparse
import datetime
import hashlib
import ipaddress
import os
import sys

try:
    from cryptography import x509
    from cryptography.hazmat.primitives import hashes, serialization
    from cryptography.hazmat.primitives.asymmetric import ec
    from cryptography.x509.oid import NameOID

    HAVE_CRYPTO = True
except ImportError:  # pragma: no cover - the skip path
    HAVE_CRYPTO = False

DEFAULT_DAYS = 3650


def spki_fingerprint(cert_pem_path):
    """The SHA-256 of the certificate's SubjectPublicKeyInfo, lower-case hex.

    This is what the device pins (the mobile pinning APIs take the SPKI), so it
    is what the parent reads off the screen -- not the whole-certificate hash.
    """
    if not HAVE_CRYPTO:
        raise RuntimeError("python-cryptography is not installed")
    with open(cert_pem_path, "rb") as f:
        cert = x509.load_pem_x509_certificate(f.read())
    spki = cert.public_key().public_bytes(
        serialization.Encoding.DER, serialization.PublicFormat.SubjectPublicKeyInfo
    )
    return hashlib.sha256(spki).hexdigest()


def make_self_signed(cert_path, key_path, common_name, days=DEFAULT_DAYS):
    """Write a fresh EC P-256 certificate and its key (PEM). Returns the SPKI hash.

    The security comes from the parent pinning the SPKI fingerprint at pairing,
    not from any name, so the SAN carries the host as a name and as an IP when it
    is one.
    """
    if not HAVE_CRYPTO:
        raise RuntimeError("python-cryptography is not installed")
    key = ec.generate_private_key(ec.SECP256R1())
    subject = x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, common_name or "omarchy-kids")])
    now = datetime.datetime.now(datetime.timezone.utc)
    san = []
    try:
        san.append(x509.IPAddress(ipaddress.ip_address(common_name)))
    except ValueError:
        san.append(x509.DNSName(common_name or "localhost"))
    cert = (
        x509.CertificateBuilder()
        .subject_name(subject)
        .issuer_name(subject)
        .public_key(key.public_key())
        .serial_number(x509.random_serial_number())
        .not_valid_before(now - datetime.timedelta(minutes=5))
        .not_valid_after(now + datetime.timedelta(days=days))
        .add_extension(x509.SubjectAlternativeName(san), critical=False)
        .sign(key, hashes.SHA256())
    )
    for path, data in (
        (key_path, key.private_bytes(serialization.Encoding.PEM, serialization.PrivateFormat.PKCS8, serialization.NoEncryption())),
        (cert_path, cert.public_bytes(serialization.Encoding.PEM)),
    ):
        directory = os.path.dirname(path)
        if directory:
            os.makedirs(directory, mode=0o750, exist_ok=True)
        tmp = f"{path}.{os.getpid()}.tmp"
        with open(tmp, "wb") as f:
            f.write(data)
        os.replace(tmp, path)
    return spki_fingerprint(cert_path)


def _main(argv):
    if not HAVE_CRYPTO:
        print("cert.py: python-cryptography is not installed", file=sys.stderr)
        return 1
    if argv and argv[0] == "spki":
        if len(argv) != 2:
            print("usage: cert.py spki CERT", file=sys.stderr)
            return 2
        print(spki_fingerprint(argv[1]))
        return 0
    parser = argparse.ArgumentParser(prog="cert.py")
    parser.add_argument("cert_path")
    parser.add_argument("key_path")
    parser.add_argument("--host", default="omarchy-kids")
    parser.add_argument("--days", type=int, default=DEFAULT_DAYS)
    args = parser.parse_args(argv)
    print(make_self_signed(args.cert_path, args.key_path, args.host, args.days))
    return 0


if __name__ == "__main__":  # pragma: no cover
    sys.exit(_main(sys.argv[1:]))
