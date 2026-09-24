// The pairing flow: the frame carries the proof, never the token; the device
// generates its keys once and reuses them; a refused pairing throws and saves
// nothing. A fake relay captures the frame.

import 'dart:convert';

import 'package:test/test.dart';

import '../lib/notify_crypto.dart';
import '../lib/pairing.dart';
import '../lib/relay_client.dart';
import '../lib/relay_transport.dart';
import '../lib/session.dart';
import '../lib/state_model.dart';

class FakeRelay implements RelayTransport {
  final List<Map<String, dynamic>> frames = [];
  final List<Map<String, Object?>> reviewed = [];
  Map<String, dynamic> reply = {'reply': 'ok'};

  @override
  String get pinnedFingerprint => 'ab' * 32;

  @override
  Future<Map<String, dynamic>> pair(String frame) async {
    frames.add(jsonDecode(frame) as Map<String, dynamic>);
    return reply;
  }

  @override
  Future<BoxState> boxState({required int ts, required String nonce}) async =>
      BoxState(kids: [], requests: [], recent: []);
  @override
  Stream<BoxState> boxEvents({required int ts, required String nonce}) => const Stream.empty();
  @override
  Future<Map<String, dynamic>> decide({
    required Map<String, Object?> record,
    required int ts,
    required String nonce,
  }) async =>
      {'reply': 'ok'};

  @override
  Future<Map<String, dynamic>> decideReview({
    required Map<String, Object?> record,
    required int ts,
    required String nonce,
  }) async {
    reviewed.add(record);
    return {'reply': 'ok'};
  }
}

class _ShortPinRelay extends FakeRelay {
  @override
  String get pinnedFingerprint => 'nope';
}

void main() {
  final uri = PairingUri.parse(
    'omarchy-kids://pair?v=1&id=d-9&token=${'ab' * 20}&addr=192.168.1.5,100.64.0.7',
  );

  test('the frame carries the proof, never the token', () async {
    final relay = FakeRelay();
    final keystore = InMemoryKeystore();
    final result = await pairWithBox(
      uri: uri,
      name: 'Ada phone',
      platform: 'ios',
      keystore: keystore,
      relay: relay,
    );
    final frame = relay.frames.single;
    expect(frame.keys.toSet(), equals({'id', 'name', 'platform', 'sign_pub', 'box_pub', 'proof'}));
    expect(frame['id'], 'd-9');
    expect(
      frame['proof'],
      equals(await pairingProof(uri.token, 'Ada phone', frame['sign_pub'] as String, frame['box_pub'] as String)),
    );
    expect(frame.values.contains(uri.token), isFalse, reason: 'the token never travels');
    expect(result.deviceId, 'd-9');
    expect(result.addresses, ['192.168.1.5', '100.64.0.7']);
    // The stored pin is the one the transport pins, not a caller's string.
    expect(result.pin, relay.pinnedFingerprint);
    final stored = PairingResult.decode(await keystore.loadPaired());
    expect(stored?.deviceId, 'd-9');
    expect(stored?.pin, relay.pinnedFingerprint);
  });

  test('the device keys are generated once and reused', () async {
    final relay = FakeRelay();
    final keystore = InMemoryKeystore();
    await pairWithBox(uri: uri, name: 'n', platform: 'ios', keystore: keystore, relay: relay);
    await pairWithBox(uri: uri, name: 'n', platform: 'ios', keystore: keystore, relay: relay);
    expect(relay.frames[0]['sign_pub'], relay.frames[1]['sign_pub']);
    expect(relay.frames[0]['box_pub'], relay.frames[1]['box_pub']);
  });

  test('a junk or oddly-shaped stored record decodes to null, not a crash', () {
    expect(PairingResult.decode(null), isNull);
    expect(PairingResult.decode('not json'), isNull);
    expect(PairingResult.decode('[1, 2]'), isNull, reason: 'an array is not a record');
    expect(PairingResult.decode('"a string"'), isNull);
    // A record with odd field types parses to safe defaults rather than throwing.
    final odd = PairingResult.decode('{"deviceId": 7, "addresses": "x"}');
    expect(odd?.deviceId, '');
    expect(odd?.addresses, isEmpty);
  });

  test('a pin that is not a fingerprint is refused before sending', () async {
    final relay = _ShortPinRelay();
    final keystore = InMemoryKeystore();
    await expectLater(
      pairWithBox(uri: uri, name: 'n', platform: 'ios', keystore: keystore, relay: relay),
      throwsArgumentError,
    );
    expect(relay.frames, isEmpty);
  });

  test('a refused pairing throws and saves nothing', () async {
    final relay = FakeRelay()..reply = {'error': 'pairing refused'};
    final keystore = InMemoryKeystore();
    await expectLater(
      pairWithBox(uri: uri, name: 'n', platform: 'ios', keystore: keystore, relay: relay),
      throwsStateError,
    );
    expect(await keystore.loadPaired(), isNull);
  });
}
