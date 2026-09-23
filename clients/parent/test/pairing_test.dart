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
  Map<String, dynamic> reply = {'reply': 'ok'};

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
      pin: 'deadbeef' * 8,
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
    expect(PairingResult.decode(await keystore.loadPaired())?.deviceId, 'd-9');
  });

  test('the device keys are generated once and reused', () async {
    final relay = FakeRelay();
    final keystore = InMemoryKeystore();
    await pairWithBox(uri: uri, pin: 'p', name: 'n', platform: 'ios', keystore: keystore, relay: relay);
    await pairWithBox(uri: uri, pin: 'p', name: 'n', platform: 'ios', keystore: keystore, relay: relay);
    expect(relay.frames[0]['sign_pub'], relay.frames[1]['sign_pub']);
    expect(relay.frames[0]['box_pub'], relay.frames[1]['box_pub']);
  });

  test('a refused pairing throws and saves nothing', () async {
    final relay = FakeRelay()..reply = {'error': 'pairing refused'};
    final keystore = InMemoryKeystore();
    await expectLater(
      pairWithBox(uri: uri, pin: 'p', name: 'n', platform: 'ios', keystore: keystore, relay: relay),
      throwsStateError,
    );
    expect(await keystore.loadPaired(), isNull);
  });
}
