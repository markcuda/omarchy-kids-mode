// The app's UI over a fake relay: the request list renders, Approve and Decline
// sign through the session (captured by the fake), and a reply chip rides a
// decline. The logic itself is tested in the omarchy_kids_parent package.

import 'package:flutter_test/flutter_test.dart';
import 'package:omarchy_kids_app/main.dart';
import 'package:omarchy_kids_parent/relay_transport.dart';
import 'package:omarchy_kids_parent/session.dart';
import 'package:omarchy_kids_parent/state_model.dart';

class FakeRelay implements RelayTransport {
  BoxState state;
  final List<Map<String, Object?>> decided = [];
  FakeRelay(this.state);

  @override
  String get pinnedFingerprint => 'ab' * 32;
  @override
  Future<BoxState> boxState({required int ts, required String nonce}) async => state;
  @override
  Stream<BoxState> boxEvents({required int ts, required String nonce}) => const Stream.empty();
  @override
  Future<Map<String, dynamic>> pair(String frame) async => {'reply': 'ok'};
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

Future<Session> sessionWith(FakeRelay relay) => Session.load(
      deviceId: 'd-1',
      relay: relay,
      keystore: InMemoryKeystore(),
      now: () => 1758530400,
      newNonce: () => 'n-1',
    );

class ThrowingRelay extends FakeRelay {
  ThrowingRelay() : super(stateWith([]));
  @override
  Future<BoxState> boxState({required int ts, required String nonce}) async =>
      throw StateError('relay unreachable');
}

BoxState stateWith(List<Map<String, Object?>> requests) => BoxState.fromJson({
      'kids': [
        {'kid': 'kid-ada', 'minutes_left': 12, 'live': true},
      ],
      'requests': requests,
    });

void main() {
  testWidgets('an open request renders in the parent words', (tester) async {
    final relay = FakeRelay(stateWith([
      {'id': 'req-1', 'kid': 'kid-ada', 'kind': 'time', 'what': '15', 'minutes': 15, 'asked_at': 1},
    ]));
    await tester.pumpWidget(KidsApp(session: await sessionWith(relay)));
    await tester.pumpAndSettle();
    expect(find.text('kid-ada asked for 15 more minutes'), findsOneWidget);
  });

  testWidgets('nothing to answer is said plainly, not a blank screen', (tester) async {
    final relay = FakeRelay(stateWith([]));
    await tester.pumpWidget(KidsApp(session: await sessionWith(relay)));
    await tester.pumpAndSettle();
    expect(find.text('Nothing to answer right now.'), findsOneWidget);
  });

  testWidgets('Approve signs the request and returns to the list', (tester) async {
    final relay = FakeRelay(stateWith([
      {'id': 'req-1', 'kid': 'kid-ada', 'kind': 'app', 'what': 'minecraft', 'asked_at': 1},
    ]));
    await tester.pumpWidget(KidsApp(session: await sessionWith(relay)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('kid-ada asked to use minecraft'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Approve'));
    await tester.pumpAndSettle();
    expect(relay.decided.single['request_id'], 'req-1');
    expect(relay.decided.single['decision'], 'approve');
  });

  testWidgets('a reply chip rides a Decline', (tester) async {
    final relay = FakeRelay(stateWith([
      {'id': 'req-2', 'kid': 'kid-ada', 'kind': 'app', 'what': 'minecraft', 'asked_at': 1},
    ]));
    await tester.pumpWidget(KidsApp(session: await sessionWith(relay)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('kid-ada asked to use minecraft'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('After dinner'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Decline'));
    await tester.pumpAndSettle();
    expect(relay.decided.single['decision'], 'decline');
    expect(relay.decided.single['reply'], 'After dinner');
  });

  testWidgets('an unpaired app says to pair', (tester) async {
    await tester.pumpWidget(KidsApp(session: null));
    await tester.pumpAndSettle();
    expect(find.textContaining('Pair with the computer'), findsOneWidget);
  });

  testWidgets('an unreachable box is an honest message, not a crash or a fake state', (tester) async {
    final relay = ThrowingRelay();
    await tester.pumpWidget(KidsApp(session: await sessionWith(relay)));
    await tester.pumpAndSettle();
    expect(find.textContaining("Can't reach the computer"), findsOneWidget);
  });
}
