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


def make_self_signed(cert_path, key_path, common_name, days=DEFAULT_DAYS):
    """Write a fresh EC P-256 certificate and its key (PEM). Returns the SPKI hash.

    The security comes from the parent pinning the fingerprint at pairing, not
    from any name, so the SAN carries the host as a name and as an IP when it is
    one.
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
    fingerprint = cert.fingerprint(hashes.SHA256()).hex()
    return fingerprint


def _main(argv):
    if not HAVE_CRYPTO:
        print("cert.py: python-cryptography is not installed", file=sys.stderr)
        return 1
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
