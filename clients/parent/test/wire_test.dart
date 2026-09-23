// The app's wire layer against the shared vectors: the headers, the pairing
// frame and the decision body must be exactly what the box verifies.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';

import '../lib/notify_crypto.dart';
import '../lib/relay_client.dart';

void main() {
  final doc = jsonDecode(File('test-vectors/notify-vectors.json').readAsStringSync()) as Map<String, dynamic>;
  final seed = _hexToBytes(doc['sign_seed_hex'] as String);
  final deviceId = (doc['decision'] as Map)['device_id'] as String;

  test('the pairing frame carries the proof, never the token', () async {
    final pairing = (doc['pairing'] as Map).cast<String, String>();
    final frame = jsonDecode(
      await buildPairFrame(
        id: 'd-vector',
        name: pairing['name']!,
        platform: 'ios',
        tokenHex: pairing['token']!,
        signPub: pairing['sign_pub']!,
        boxPub: pairing['box_pub']!,
      ),
    ) as Map<String, dynamic>;
    expect(frame['proof'], equals(pairing['proof']));
    expect(frame.keys.toSet(), equals({'id', 'name', 'platform', 'sign_pub', 'box_pub', 'proof'}));
    expect(frame.values.contains(pairing['token']), isFalse);
  });

  test('the request headers carry the recorded signature', () async {
    final request = (doc['request'] as Map).cast<String, dynamic>();
    final keyPair = await signKeyFromSeed(seed);
    final headers = await signedHeaders(
      keyPair: keyPair,
      deviceId: deviceId,
      ts: request['ts'] as int,
      nonce: request['nonce'] as String,
      method: request['method'] as String,
      path: request['path'] as String,
      body: base64.decode(request['body_b64'] as String),
    );
    expect(headers['X-Kids-Device'], equals(deviceId));
    expect(
      headers['X-Kids-Sig'],
      equals('${request['ts']}.${request['nonce']}.${doc['request_signature_b64']}'),
    );
  });

  test('the decision body carries the recorded record and signature', () async {
    final record = (doc['decision'] as Map).cast<String, Object?>();
    final keyPair = await signKeyFromSeed(seed);
    final body = jsonDecode(await buildDecisionBody(keyPair: keyPair, record: record)) as Map<String, dynamic>;
    expect(body['signature'], equals(doc['decision_signature_b64']));
    expect(body['record'], equals(record));
  });

  test('a decision record rejects a bad decision or a long/non-ASCII reply', () {
    expect(
      () => decisionRecord(deviceId: 'd1', requestId: 'r1', decision: 'maybe', ts: 1, nonce: 'n'),
      throwsArgumentError,
    );
    expect(
      () => decisionRecord(deviceId: 'd1', requestId: 'r1', decision: 'decline', ts: 1, nonce: 'n', reply: 'x' * 81),
      throwsArgumentError,
    );
    expect(
      () => decisionRecord(deviceId: 'd1', requestId: 'r1', decision: 'decline', ts: 1, nonce: 'n', reply: 'café'),
      throwsArgumentError,
    );
    final record = decisionRecord(
      deviceId: 'd1',
      requestId: 'r1',
      decision: 'decline',
      ts: 1,
      nonce: 'n',
      reply: 'After dinner',
    );
    expect(record['reply'], equals('After dinner'));
  });

  test('every quick reply is acceptable to the box', () {
    for (final chip in defaultReplyChips) {
      expect(chip.length, lessThanOrEqualTo(80), reason: chip);
      expect(chip.runes.every((r) => r >= 0x20 && r <= 0x7e), isTrue, reason: chip);
    }
  });

  test('a pairing URI yields the id, token and addresses', () {
    final uri = PairingUri.parse(
      'omarchy-kids://pair?v=1&id=d-1&token=abc123&addr=192.168.1.5,100.64.0.7',
    );
    expect(uri.id, equals('d-1'));
    expect(uri.token, equals('abc123'));
    expect(uri.addresses, equals(['192.168.1.5', '100.64.0.7']));
    expect(() => PairingUri.parse('https://example.com'), throwsFormatException);
    expect(() => PairingUri.parse('omarchy-kids://pair?v=1&id=d-1'), throwsFormatException);
  });

  test('the courier envelope opens through the wire helper', () async {
    final env = (doc['envelope'] as Map).cast<String, dynamic>();
    final plaintext = await openStateEnvelope(
      deviceId: 'd-vector',
      boxSeed: _hexToBytes(env['box_priv_hex'] as String),
      body: jsonEncode(env['envelope']),
    );
    expect(plaintext, equals(base64.decode(env['plaintext_b64'] as String)));
  });
}

Uint8List _hexToBytes(String hex) {
  final out = Uint8List(hex.length ~/ 2);
  for (var i = 0; i < out.length; i++) {
    out[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return out;
}
