// The session's decision flow, with a fake transport and an in-memory keystore:
// approving and declining sign the record the box will verify, a reply rides
// along (and an over-long one is refused before anything is sent), and the
// device key is generated once and reloaded.

import 'package:test/test.dart';

import '../lib/relay_transport.dart';
import '../lib/session.dart';
import '../lib/state_model.dart';

class FakeRelay implements RelayTransport {
  final List<Map<String, Object?>> decided = [];
  BoxState state = BoxState(kids: [], requests: [], recent: []);
  final List<BoxState> events = [];

  @override
  Future<BoxState> boxState({required int ts, required String nonce}) async => state;

  @override
  Stream<BoxState> boxEvents({required int ts, required String nonce}) => Stream.fromIterable(events);

  @override
  Future<Map<String, dynamic>> decide({
    required Map<String, Object?> record,
    required int ts,
    required String nonce,
  }) async {
    decided.add(record);
    return {'reply': 'ok'};
  }
}

void main() {
  late FakeRelay relay;
  late Session session;

  setUp(() async {
    relay = FakeRelay();
    session = await Session.load(
      deviceId: 'd-1',
      relay: relay,
      keystore: InMemoryKeystore(),
      now: () => 1758530400,
      newNonce: () => 'n-fixed',
    );
  });

  test('approve signs the record the box will verify', () async {
    await session.approve('req-1');
    expect(relay.decided.single, {
      'device_id': 'd-1',
      'request_id': 'req-1',
      'decision': 'approve',
      'ts': 1758530400,
      'nonce': 'n-fixed',
    });
  });

  test('decline carries the reply, and a long one is refused before sending', () async {
    await session.decline('req-2', reply: 'After dinner');
    expect(relay.decided.single['decision'], 'decline');
    expect(relay.decided.single['reply'], 'After dinner');

    await expectLater(
      session.decline('req-3', reply: 'x' * 81),
      throwsArgumentError,
    );
    expect(relay.decided.length, 1, reason: 'nothing was sent for the refused reply');
  });

  test('the device key is generated once and reloaded', () async {
    final keystore = InMemoryKeystore();
    final first = await Session.load(deviceId: 'd-1', relay: relay, keystore: keystore);
    final second = await Session.load(deviceId: 'd-1', relay: relay, keystore: keystore);
    expect(await first.signPub, equals(await second.signPub));
    expect(await first.signPub, isNotEmpty);
  });

  test('refresh and watch use the transport', () async {
    relay.state = BoxState.fromJson({
      'kids': [
        {'kid': 'kid-ada', 'minutes_left': 5, 'live': true},
      ]
    });
    final state = await session.refresh();
    expect(state.liveKids.single.kid, 'kid-ada');

    relay.events.add(BoxState.fromJson({'requests': []}));
    expect(await session.watch().first.then((s) => s.requests), isEmpty);
  });
}
