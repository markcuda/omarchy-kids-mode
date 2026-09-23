// The parent app's signing, pairing and envelope code (SPEC.md R-NOTIFY-4/5/8;
// clients/parent/README.md is the contract, clients/parent/test-vectors is the
// proof). Pure Dart, no Flutter: the app's UI is later, this is the half that
// must match lib/devices.py and lib/envelope.py byte for byte.
//
// The one trap worth naming: the box canonicalises with Python's json.dumps,
// whose `ensure_ascii` default escapes every non-ASCII character as \uXXXX.
// Dart's jsonEncode does not, so `canonicalJson` below does it by hand; the
// vectors carry a "Après dîner" reply to catch exactly that.

import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

const List<int> signContext = [0x6f, 0x6d, 0x61, 0x72, 0x63, 0x68, 0x79, 0x2d, 0x6b, 0x69, 0x64, 0x73, 0x2d, 0x64, 0x65, 0x63, 0x69, 0x73, 0x69, 0x6f, 0x6e, 0x2d, 0x76, 0x31, 0x0a]; // "omarchy-kids-decision-v1\n"
const List<int> requestContext = [0x6f, 0x6d, 0x61, 0x72, 0x63, 0x68, 0x79, 0x2d, 0x6b, 0x69, 0x64, 0x73, 0x2d, 0x72, 0x65, 0x71, 0x75, 0x65, 0x73, 0x74, 0x2d, 0x76, 0x31, 0x0a]; // "omarchy-kids-request-v1\n"

/// JSON as the box serialises it: sorted keys, compact separators, and every
/// non-ASCII character escaped as \uXXXX (Python's ensure_ascii=True default).
String canonicalJson(Object? value) {
  final buffer = StringBuffer();
  _writeJson(buffer, value);
  return buffer.toString();
}

void _writeJson(StringBuffer out, Object? value) {
  if (value == null) {
    out.write('null');
  } else if (value is bool) {
    out.write(value ? 'true' : 'false');
  } else if (value is int) {
    out.write(value.toString());
  } else if (value is double) {
    out.write(value.toString());
  } else if (value is String) {
    _writeString(out, value);
  } else if (value is List) {
    out.write('[');
    for (var i = 0; i < value.length; i++) {
      if (i > 0) out.write(',');
      _writeJson(out, value[i]);
    }
    out.write(']');
  } else if (value is Map) {
    final keys = value.keys.map((k) => k.toString()).toList()..sort();
    out.write('{');
    for (var i = 0; i < keys.length; i++) {
      if (i > 0) out.write(',');
      _writeString(out, keys[i]);
      out.write(':');
      _writeJson(out, value[keys[i]]);
    }
    out.write('}');
  } else {
    throw ArgumentError('canonicalJson: unsupported ${value.runtimeType}');
  }
}

void _writeString(StringBuffer out, String value) {
  out.write('"');
  for (final rune in value.runes) {
    switch (rune) {
      case 0x22:
        out.write(r'\u0022');
      case 0x5c:
        out.write(r'\\');
      case 0x08:
        out.write(r'\b');
      case 0x0c:
        out.write(r'\f');
      case 0x0a:
        out.write(r'\n');
      case 0x0d:
        out.write(r'\r');
      case 0x09:
        out.write(r'\t');
      default:
        if (rune < 0x20 || rune > 0x7e) {
          // Python writes lowercase \uXXXX; a rune above the BMP needs a
          // surrogate pair, as Python's ensure_ascii also produces.
          if (rune <= 0xffff) {
            out.write('\\u${rune.toRadixString(16).padLeft(4, '0')}');
          } else {
            final v = rune - 0x10000;
            final high = 0xd800 + (v >> 10);
            final low = 0xdc00 + (v & 0x3ff);
            out.write('\\u${high.toRadixString(16).padLeft(4, '0')}');
            out.write('\\u${low.toRadixString(16).padLeft(4, '0')}');
          }
        } else {
          out.writeCharCode(rune);
        }
    }
  }
  out.write('"');
}

Uint8List _concat(List<List<int>> parts) {
  final builder = BytesBuilder(copy: false);
  for (final part in parts) {
    builder.add(part);
  }
  return builder.toBytes();
}

/// The bytes a device signs for a decision: the context, then the canonical record.
Uint8List decisionMessage(Map<String, Object?> record) =>
    _concat([signContext, utf8.encode(canonicalJson(record))]);

/// The bytes a device signs for a relay request: the context, then the canonical
/// object with the body's hex SHA-256.
Uint8List requestMessage({
  required String deviceId,
  required int ts,
  required String nonce,
  required String method,
  required String path,
  required List<int> body,
}) {
  final message = {
    'device_id': deviceId,
    'ts': ts,
    'nonce': nonce,
    'method': method,
    'path': path,
    'body_sha256': sha256Hex(body),
  };
  return _concat([requestContext, utf8.encode(canonicalJson(message))]);
}

String sha256Hex(List<int> bytes) {
  final digest = Sha256().toSync().hashSync(bytes).bytes;
  return digest.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

String base64Of(List<int> bytes) => base64.encode(bytes);

Uint8List base64To(String text) => base64.decode(text);

/// Ed25519 over the message, base64, as the box verifies it.
Future<String> signBase64(SimpleKeyPair keyPair, Uint8List message) async {
  final signature = await Ed25519().sign(message, keyPair: keyPair);
  return base64Of(signature.bytes);
}

Future<SimpleKeyPair> signKeyFromSeed(List<int> seed) => Ed25519().newKeyPairFromSeed(seed);

/// The single-use pairing proof (R-NOTIFY-5): hex HMAC-SHA256 keyed by the raw
/// token bytes, over "sign_pub|box_pub|name". The token itself never travels.
Future<String> pairingProof(String tokenHex, String name, String signPub, String boxPub) async {
  final hmac = Hmac.sha256();
  final mac = await hmac.calculateMac(
    utf8.encode('$signPub|$boxPub|$name'),
    secretKey: SecretKey(_hexToBytes(tokenHex)),
  );
  return _bytesToHex(mac.bytes);
}

Uint8List _hexToBytes(String hex) {
  final out = Uint8List(hex.length ~/ 2);
  for (var i = 0; i < out.length; i++) {
    out[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return out;
}

String _bytesToHex(List<int> bytes) => bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

/// The away envelope (N-11): a fresh ephemeral X25519 key, ECDH with the
/// device's box key, HKDF-SHA256, ChaCha20-Poly1305 with the device id as
/// associated data. The box seals; the app opens with its private box key.
class Envelope {
  static const List<int> _salt = [0x6f, 0x6d, 0x61, 0x72, 0x63, 0x68, 0x79, 0x2d, 0x6b, 0x69, 0x64, 0x73, 0x2d, 0x65, 0x6e, 0x76, 0x65, 0x6c, 0x6f, 0x70, 0x65, 0x2d, 0x76, 0x31]; // "omarchy-kids-envelope-v1"
  static const List<int> _info = [0x78, 0x32, 0x35, 0x35, 0x31, 0x39, 0x2d, 0x63, 0x68, 0x61, 0x63, 0x68, 0x61, 0x32, 0x30, 0x70, 0x6f, 0x6c, 0x79, 0x31, 0x33, 0x30, 0x35]; // "x25519-chacha20poly1305"

  static Future<SecretKey> _derive(SecretKey shared) {
    final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
    return hkdf.deriveKey(secretKey: shared, nonce: _salt, info: _info);
  }

  static Future<SimplePublicKey> publicKeyOf(List<int> seed) async {
    final pair = await X25519().newKeyPairFromSeed(seed);
    return pair.extractPublicKey();
  }

  /// Open an envelope with the device's private box seed, returning the
  /// plaintext. Throws on a bad key, a tampered ciphertext or another device id.
  static Future<Uint8List> open({
    required String deviceId,
    required List<int> boxSeed,
    required Map<String, Object?> envelope,
  }) async {
    final keyPair = await X25519().newKeyPairFromSeed(boxSeed);
    final ephPub = SimplePublicKey(base64To(envelope['eph_pub']! as String), type: KeyPairType.x25519);
    final shared = await X25519().sharedSecretKey(keyPair: keyPair, remotePublicKey: ephPub);
    final key = await _derive(shared);
    // The box's ciphertext is encryption||tag (16 bytes), Python's AEAD shape;
    // package:cryptography wants the tag separately.
    final sealed = base64To(envelope['ct']! as String);
    final tag = sealed.sublist(sealed.length - 16);
    final ciphertext = sealed.sublist(0, sealed.length - 16);
    final cipher = Chacha20.poly1305Aead();
    final clear = await cipher.decrypt(
      SecretBox(ciphertext, nonce: base64To(envelope['nonce']! as String), mac: Mac(tag)),
      secretKey: key,
      aad: utf8.encode(deviceId),
    );
    return Uint8List.fromList(clear);
  }
}
