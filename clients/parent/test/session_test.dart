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
  final List<Map<String, Object?>> reviewed = [];
  final List<Map<String, Object?>> acted = [];
  final List<(int, String)> requestHeaders = [];
  BoxState state = BoxState(kids: [], requests: [], recent: []);
  final List<BoxState> events = [];

  @override
  Future<BoxState> boxState({required int ts, required String nonce}) async => state;

  @override
  Stream<BoxState> boxEvents({required int ts, required String nonce}) => Stream.fromIterable(events);

  @override
  String get pinnedFingerprint => 'ab' * 32;

  @override
  Future<Map<String, dynamic>> pair(String frame) async => {'reply': 'ok'};

  @override
  Future<Map<String, dynamic>> decide({
    required Map<String, Object?> record,
    required int ts,
    required String nonce,
  }) async {
    decided.add(record);
    requestHeaders.add((ts, nonce));
    return {'reply': 'ok'};
  }

  @override
  Future<Map<String, dynamic>> decideReview({
    required Map<String, Object?> record,
    required int ts,
    required String nonce,
  }) async {
    reviewed.add(record);
    return {'reply': 'ok'};
  }

  @override
  Future<Map<String, dynamic>> act({
    required Map<String, Object?> record,
    required int ts,
    required String nonce,
  }) async {
    acted.add(record);
    return {'reply': 'ok'};
  }
}

OpenRequest req(String id, {String kind = 'app', String what = 'x', int? minutes}) =>
    OpenRequest(id: id, kid: 'kid-ada', kind: kind, what: what, minutes: minutes);

void main() {
  late FakeRelay relay;
  late Session session;

  var counter = 0;

  setUp(() async {
    relay = FakeRelay();
    counter = 0;
    session = await Session.load(
      deviceId: 'd-1',
      relay: relay,
      keystore: InMemoryKeystore(),
      now: () => 1758530400,
      newNonce: () => 'n-${counter++}',
    );
  });

  test('approve signs the record the box will verify', () async {
    await session.approve(req('req-1'));
    expect(relay.decided.single, {
      'device_id': 'd-1',
      'request_id': 'req-1',
      'decision': 'approve',
      'ts': 1758530400,
      'nonce': 'n-0',
      'kid': 'kid-ada',
      'kind': 'app',
      'what': 'x',
    });
    // The header's nonce is a different one: separate replay domains.
    expect(relay.requestHeaders.single.$2, 'n-1');
    expect(relay.requestHeaders.single.$2, isNot(relay.decided.single['nonce']));
  });

  test('a request id the box would refuse is rejected locally', () async {
    for (final bad in ['', '../etc', 'a/b', 'has space']) {
      await expectLater(session.approve(req(bad)), throwsArgumentError, reason: bad);
    }
    expect(relay.decided, isEmpty);
  });

  test('decline carries the reply, and a long one is refused before sending', () async {
    await session.decline(req('req-2'), reply: 'After dinner');
    expect(relay.decided.single['decision'], 'decline');
    expect(relay.decided.single['reply'], 'After dinner');

    await expectLater(
      session.decline(req('req-3'), reply: 'x' * 81),
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

  test('grantTime and endSession sign the ACT records the box takes', () async {
    await session.grantTime('kid-ada', 30);
    final grant = relay.acted.single;
    expect(grant['account'], 'kid-ada');
    expect(grant['action'], 'grant');
    expect(grant['minutes'], 30);
    expect(grant['device_id'], session.deviceId);
    await session.endSession('kid-ada');
    final end = relay.acted.last;
    expect(end['action'], 'end');
    expect(end.containsKey('minutes'), isFalse);
    expect(() => session.grantTime('Kid!', 10), throwsArgumentError);
    expect(() => session.endSession('../etc'), throwsArgumentError);
  });
}
