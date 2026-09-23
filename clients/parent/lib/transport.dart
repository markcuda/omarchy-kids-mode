// The app's trust anchor: the relay's certificate is self-signed and pinned by
// its SubjectPublicKeyInfo SHA-256, the value the parent reads off the pairing
// screen (lib/cert.py's spki_fingerprint, docs/notify.md). There is no CA and no
// name to trust, so pinning is what stops a fake relay on the same network --
// this is the piece the wire layer's URI parser cannot do alone.
//
// Pure functions over the certificate's DER: no sockets here, so they are
// testable against a fixture whose fingerprint the box's own generator printed.

import 'dart:convert';
import 'dart:typed_data';

import 'package:asn1lib/asn1lib.dart';

import 'notify_crypto.dart';

/// The SubjectPublicKeyInfo of a certificate's tbsCertificate.
ASN1Sequence _subjectPublicKeyInfo(ASN1Sequence tbs) {
  // tbsCertificate ::= SEQUENCE { [0] version?, serialNumber, signature,
  //   issuer, validity, subject, subjectPublicKeyInfo, ... }
  var index = 0;
  final first = tbs.elements.isNotEmpty ? tbs.elements.first : null;
  if (first is ASN1Object && first.tag == 0xa0) {
    index = 1; // the explicit [0] version
  }
  final spki = tbs.elements[index + 5];
  if (spki is! ASN1Sequence) {
    throw const FormatException('no subjectPublicKeyInfo in the certificate');
  }
  return spki;
}

/// SHA-256 of the certificate's SubjectPublicKeyInfo, lower-case hex — the value
/// a device pins and the parent compares. Matches lib/cert.py byte for byte.
String spkiFingerprintFromDer(List<int> der) {
  final parser = ASN1Parser(Uint8List.fromList(der));
  final certificate = parser.nextObject();
  if (certificate is! ASN1Sequence || certificate.elements.isEmpty) {
    throw const FormatException('not a certificate');
  }
  final tbs = certificate.elements.first;
  if (tbs is! ASN1Sequence) {
    throw const FormatException('no tbsCertificate');
  }
  return sha256Hex(_subjectPublicKeyInfo(tbs).encodedBytes);
}

/// The same, from a PEM certificate (the pairing screen's value is hex).
String spkiFingerprintFromPem(String pem) => spkiFingerprintFromDer(derFromPem(pem));

/// The DER bytes of a PEM certificate (the base64 between the markers).
Uint8List derFromPem(String pem) {
  final body = pem
      .split('\n')
      .where((line) => !line.contains('-----'))
      .join()
      .trim();
  if (body.isEmpty) {
    throw const FormatException('empty PEM');
  }
  return base64.decode(body);
}

/// True when the certificate's SPKI hash equals the pinned one. Hex compare, so
/// a case difference does not defeat the pin.
bool spkiMatches(List<int> der, String pinnedHex) {
  final actual = spkiFingerprintFromDer(der).toLowerCase();
  final want = pinnedHex.replaceAll(':', '').toLowerCase();
  if (actual.length != want.length) {
    return false;
  }
  var diff = 0;
  for (var i = 0; i < actual.length; i++) {
    diff |= actual.codeUnitAt(i) ^ want.codeUnitAt(i);
  }
  return diff == 0;
}
