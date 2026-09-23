// The parent app's wire layer: the frames and headers the box's relay expects.
// Pure functions over SimpleKeyPair, no sockets, so they are testable against the
// shared vectors; the HTTP/TLS transport and the UI come later.
//
// The box verifies all of this (SPEC.md Appendix H, lib/devices.py), so this file
// must not change the bytes: the pairing endpoint takes {id, name, platform,
// sign_pub, box_pub, proof}; every signed request carries X-Kids-Device and
// X-Kids-Sig: <ts>.<nonce>.<base64>; a decision POST carries {record, signature}
// and the same headers.

import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'notify_crypto.dart';

const String kidsPairScheme = 'omarchy-kids://pair';

/// The eight quick replies the app offers under a Decline (SPEC.md Appendix D
/// caps a reply at 80 printable characters; `lib/devices.py`'s MAX_REPLY).
const List<String> defaultReplyChips = [
  'After dinner',
  'Not today',
  'Ask me again tomorrow',
  'Finish your homework first',
  'Maybe at the weekend',
  'Let me think about it',
  'Only 15 minutes',
  'Come and ask me',
];

/// The `/v1/pair` body for one device. `boxPub` is the device's own X25519
/// public key; the proof shows it holds the token without sending the token.
Future<String> buildPairFrame({
  required String id,
  required String name,
  required String platform,
  required String tokenHex,
  required String signPub,
  required String boxPub,
}) async {
  final proof = await pairingProof(tokenHex, name, signPub, boxPub);
  final frame = {
    'id': id,
    'name': name,
    'platform': platform,
    'sign_pub': signPub,
    'box_pub': boxPub,
    'proof': proof,
  };
  return jsonEncode(frame);
}

/// The two headers that authenticate one relay request. `body` is the exact
/// bytes sent; `ts` and `nonce` are passed in so a test (and a retry) can pin them.
Future<Map<String, String>> signedHeaders({
  required SimpleKeyPair keyPair,
  required String deviceId,
  required int ts,
  required String nonce,
  required String method,
  required String path,
  required List<int> body,
}) async {
  final message = requestMessage(
    deviceId: deviceId,
    ts: ts,
    nonce: nonce,
    method: method,
    path: path,
    body: body,
  );
  final signature = await signBase64(keyPair, message);
  return {
    'X-Kids-Device': deviceId,
    'X-Kids-Sig': '$ts.$nonce.$signature',
  };
}

/// The `/v1/requests/<id>/decision` body: the signed record.
Future<String> buildDecisionBody({
  required SimpleKeyPair keyPair,
  required Map<String, Object?> record,
}) async {
  final signature = await signBase64(keyPair, decisionMessage(record));
  return jsonEncode({'record': record, 'signature': signature});
}

/// A decision record with a fresh ts and nonce. `reply` is optional and, when
/// given, must be printable and at most 80 characters (the box refuses more).
Map<String, Object?> decisionRecord({
  required String deviceId,
  required String requestId,
  required String decision,
  required int ts,
  required String nonce,
  String? reply,
}) {
  if (decision != 'approve' && decision != 'decline') {
    throw ArgumentError("decision must be 'approve' or 'decline'");
  }
  if (reply != null && (reply.length > 80 || reply.runes.any((r) => r < 0x20 || r > 0x7e))) {
    throw ArgumentError('reply must be at most 80 printable ASCII characters');
  }
  final record = <String, Object?>{
    'device_id': deviceId,
    'request_id': requestId,
    'decision': decision,
    'ts': ts,
    'nonce': nonce,
  };
  if (reply != null) {
    record['reply'] = reply;
  }
  return record;
}

/// The token and the box's addresses out of a pairing URI.
class PairingUri {
  final String id;
  final String token;
  final List<String> addresses;

  PairingUri({required this.id, required this.token, required this.addresses});

  static PairingUri parse(String uri) {
    final parsed = Uri.parse(uri);
    if (parsed.scheme != 'omarchy-kids' || parsed.host != 'pair') {
      throw FormatException('not a pairing URI: $uri');
    }
    final id = parsed.queryParameters['id'] ?? '';
    final token = parsed.queryParameters['token'] ?? '';
    if (id.isEmpty || token.isEmpty) {
      throw const FormatException('the pairing URI needs an id and a token');
    }
    final addrs = (parsed.queryParameters['addr'] ?? '')
        .split(',')
        .where((a) => a.isNotEmpty)
        .toList();
    return PairingUri(id: id, token: token, addresses: addrs);
  }
}

/// The envelope bytes the courier posts, ready to open (N-11).
Future<Uint8List> openStateEnvelope({
  required String deviceId,
  required List<int> boxSeed,
  required String body,
}) {
  final envelope = jsonDecode(body) as Map<String, Object?>;
  return Envelope.open(deviceId: deviceId, boxSeed: boxSeed, envelope: envelope);
}
