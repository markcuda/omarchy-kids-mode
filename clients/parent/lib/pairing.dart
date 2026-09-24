// The app's pairing: the parent shows the box's URI and reads its fingerprint off
// the box's screen; the device generates its own keys, sends the proof (never the
// token), and remembers the box it paired with. The pin is what the parent
// compared, and it is what the app trusts the box by from then on.

import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

import 'relay_client.dart';
import 'relay_transport.dart';
import 'session.dart';

class PairingResult {
  final String deviceId;
  final String pin;
  final List<String> addresses;

  PairingResult({required this.deviceId, required this.pin, required this.addresses});

  Map<String, Object?> toJson() => {'deviceId': deviceId, 'pin': pin, 'addresses': addresses};

  factory PairingResult.fromJson(Map<String, dynamic> json) => PairingResult(
        deviceId: json['deviceId'] is String ? json['deviceId'] as String : '',
        pin: json['pin'] is String ? json['pin'] as String : '',
        addresses:
            json['addresses'] is List ? (json['addresses'] as List).whereType<String>().toList() : const [],
      );

  static PairingResult? decode(String? stored) {
    if (stored == null) return null;
    try {
      final json = jsonDecode(stored);
      if (json is! Map<String, dynamic>) return null; // junk that parses as JSON
      return PairingResult.fromJson(json);
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }
}

final RegExp _fingerprint = RegExp(r'^[0-9a-fA-F]{64}$');

/// Pair this device with the box the URI names. The stored pin is the fingerprint
/// the transport actually pins (the value the parent compared against the box's
/// screen), so the app cannot remember one it never used. `uri.token` is the
/// single-use token, which never travels -- the frame carries only the proof.
Future<PairingResult> pairWithBox({
  required PairingUri uri,
  required String name,
  required String platform,
  required Keystore keystore,
  required RelayTransport relay,
}) async {
  final pin = relay.pinnedFingerprint;
  if (!_fingerprint.hasMatch(pin)) {
    throw ArgumentError('not an SPKI fingerprint: $pin');
  }
  final signSeed = await _seed(keystore.loadSignSeed, keystore.saveSignSeed);
  final boxSeed = await _seed(keystore.loadBoxSeed, keystore.saveBoxSeed);
  final signPub = base64.encode(
    (await (await Ed25519().newKeyPairFromSeed(signSeed)).extractPublicKey()).bytes,
  );
  final boxPub = base64.encode(
    (await (await X25519().newKeyPairFromSeed(boxSeed)).extractPublicKey()).bytes,
  );
  final frame = await buildPairFrame(
    id: uri.id,
    name: name,
    platform: platform,
    tokenHex: uri.token,
    signPub: signPub,
    boxPub: boxPub,
  );
  final reply = await relay.pair(frame);
  if (reply['reply'] != 'ok') {
    throw StateError('pairing was refused: $reply');
  }
  final result = PairingResult(deviceId: uri.id, pin: pin, addresses: uri.addresses);
  await keystore.savePaired(jsonEncode(result.toJson()));
  return result;
}

Future<List<int>> _seed(
  Future<List<int>?> Function() load,
  Future<void> Function(List<int>) save,
) async {
  final existing = await load();
  if (existing != null) return existing;
  final seed = List<int>.generate(32, (_) => Random.secure().nextInt(256));
  await save(seed);
  return seed;
}
