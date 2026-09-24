// The app's UI over a fake relay: the request list, Approve/Decline with a reply
// chip, the honest states, and pairing (paste the code, type the fingerprint,
// confirm, pair). The logic itself is tested in the omarchy_kids_parent package.

import 'dart:async';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omarchy_kids_app/app_root.dart';
import 'package:omarchy_kids_app/main.dart';
import 'package:omarchy_kids_parent/relay_transport.dart';
import 'package:omarchy_kids_parent/session.dart';
import 'package:omarchy_kids_parent/state_model.dart';

class FakeRelay implements RelayTransport {
  BoxState state;
  final String pin;
  final List<Map<String, Object?>> decided = [];
  final List<String> paired = [];
  final List<StreamController<BoxState>> opened = [];

  /// Holds the next signed read open, so a test can land it after a feed event.
  Future<BoxState>? pendingRead;
  FakeRelay(this.state, {String? pin}) : pin = pin ?? ('ab' * 32);

  /// The feed the screen is listening to now; a reconnect opens a new one.
  StreamController<BoxState> get events => opened.last;
  void emit(BoxState next) => events.add(next);
  void fail(Object error) => events.addError(error);
  Future<void> close() => events.close();

  @override
  String get pinnedFingerprint => pin;
  @override
  Future<BoxState> boxState({required int ts, required String nonce}) async =>
      pendingRead != null ? await pendingRead! : state;
  @override
  Stream<BoxState> boxEvents({required int ts, required String nonce}) {
    final controller = StreamController<BoxState>.broadcast();
    opened.add(controller);
    return controller.stream;
  }
  @override
  Future<Map<String, dynamic>> pair(String frame) async {
    paired.add(frame);
    return {'reply': 'ok'};
  }

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

/// A box that is not there: both the read and the feed fail, as they would.
class ThrowingRelay extends FakeRelay {
  ThrowingRelay() : super(stateWith([]));
  @override
  Future<BoxState> boxState({required int ts, required String nonce}) async =>
      throw StateError('relay unreachable');
  @override
  Stream<BoxState> boxEvents({required int ts, required String nonce}) =>
      Stream<BoxState>.error(StateError('relay unreachable'));
}

/// Stands in for KidsRelayClient: records the address it was dialled at and
/// returns a fake, pinned to the fingerprint it was given.
class FakeConnect {
  final List<({String host, int port, String pin, String deviceId})> dialed = [];
  final List<FakeRelay> relays = [];

  RelayTransport call({
    required String host,
    required int port,
    required String pin,
    required String deviceId,
    required SimpleKeyPair keyPair,
  }) {
    dialed.add((host: host, port: port, pin: pin, deviceId: deviceId));
    final relay = FakeRelay(stateWith([]), pin: pin);
    relays.add(relay);
    return relay;
  }
}

Future<Session> sessionWith(FakeRelay relay) => Session.load(
      deviceId: 'd-1',
      relay: relay,
      keystore: InMemoryKeystore(),
      now: () => 1758530400,
      newNonce: () => 'n-1',
    );

BoxState stateWith(List<Map<String, Object?>> requests) => BoxState.fromJson({
      'kids': [
        {'kid': 'kid-ada', 'minutes_left': 12, 'live': true},
      ],
      'requests': requests,
    });

Future<void> pumpHome(WidgetTester tester, FakeRelay relay) async {
  await tester.pumpWidget(MaterialApp(home: HomeScreen(session: await sessionWith(relay))));
  await tester.pumpAndSettle();
}

final _uri = 'omarchy-kids://pair?v=1&id=dev-1&token=${'a' * 40}&addr=192.168.1.5';

Future<void> pumpPairing(WidgetTester tester, {required FakeConnect connect, Keystore? keystore}) async {
  await tester.pumpWidget(MaterialApp(
    home: AppRoot(
      keystore: keystore ?? InMemoryKeystore(),
      connect: connect.call,
      name: 'parent-phone',
      platform: 'linux',
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('an open request renders in the parent words', (tester) async {
    await pumpHome(
      tester,
      FakeRelay(stateWith([
        {'id': 'req-1', 'kid': 'kid-ada', 'kind': 'time', 'what': '15', 'minutes': 15, 'asked_at': 1},
      ])),
    );
    expect(find.text('kid-ada asked for 15 more minutes'), findsOneWidget);
  });

  testWidgets('nothing to answer is said plainly, not a blank screen', (tester) async {
    await pumpHome(tester, FakeRelay(stateWith([])));
    expect(find.text('Nothing to answer right now.'), findsOneWidget);
  });

  testWidgets('Approve signs the request and returns to the list', (tester) async {
    final relay = FakeRelay(stateWith([
      {'id': 'req-1', 'kid': 'kid-ada', 'kind': 'app', 'what': 'minecraft', 'asked_at': 1},
    ]));
    await pumpHome(tester, relay);
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
    await pumpHome(tester, relay);
    await tester.tap(find.text('kid-ada asked to use minecraft'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('After dinner'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Decline'));
    await tester.pumpAndSettle();
    expect(relay.decided.single['decision'], 'decline');
    expect(relay.decided.single['reply'], 'After dinner');
  });

  testWidgets('a change on the box appears without a manual refresh', (tester) async {
    final relay = FakeRelay(stateWith([
      {'id': 'req-1', 'kid': 'kid-ada', 'kind': 'app', 'what': 'minecraft', 'asked_at': 1},
    ]));
    await pumpHome(tester, relay);
    expect(find.text('kid-ada asked to use minecraft'), findsOneWidget);
    relay.emit(stateWith([
      {'id': 'req-1', 'kid': 'kid-ada', 'kind': 'app', 'what': 'minecraft', 'asked_at': 1},
      {'id': 'req-2', 'kid': 'kid-ada', 'kind': 'time', 'what': '15', 'minutes': 15, 'asked_at': 2},
    ]));
    await tester.pump();
    await tester.pump();
    expect(find.text('kid-ada asked for 15 more minutes'), findsOneWidget);
  });

  testWidgets('a slow read does not overwrite a newer event', (tester) async {
    final relay = FakeRelay(stateWith([
      {'id': 'req-1', 'kid': 'kid-ada', 'kind': 'app', 'what': 'minecraft', 'asked_at': 1},
    ]));
    final stale = Completer<BoxState>();
    relay.pendingRead = stale.future;
    await tester.pumpWidget(MaterialApp(home: HomeScreen(session: await sessionWith(relay))));
    await tester.pump();
    relay.emit(stateWith([
      {'id': 'req-1', 'kid': 'kid-ada', 'kind': 'app', 'what': 'minecraft', 'asked_at': 1},
      {'id': 'req-2', 'kid': 'kid-ada', 'kind': 'time', 'what': '15', 'minutes': 15, 'asked_at': 2},
    ]));
    await tester.pump();
    await tester.pump();
    expect(find.text('kid-ada asked for 15 more minutes'), findsOneWidget);
    stale.complete(stateWith([
      {'id': 'req-1', 'kid': 'kid-ada', 'kind': 'app', 'what': 'minecraft', 'asked_at': 1},
    ]));
    await tester.pump();
    await tester.pump();
    expect(find.text('kid-ada asked for 15 more minutes'), findsOneWidget,
        reason: 'the older read must not replace the newer list');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Refresh does not tear down a running feed', (tester) async {
    final relay = FakeRelay(stateWith([]));
    await pumpHome(tester, relay);
    await tester.tap(find.byTooltip('Refresh'));
    await tester.pump();
    await tester.pump();
    expect(relay.opened.length, 1, reason: 'the feed keeps running; only a read was sent');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a transport error is said out loud, and the last list stays', (tester) async {
    final relay = FakeRelay(stateWith([
      {'id': 'req-1', 'kid': 'kid-ada', 'kind': 'app', 'what': 'minecraft', 'asked_at': 1},
    ]));
    await pumpHome(tester, relay);
    relay.fail(StateError('the box went away'));
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('Showing the last update'), findsOneWidget);
    expect(find.text('kid-ada asked to use minecraft'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a closed feed is said out loud, and the retry reconnects and clears it', (tester) async {
    final relay = FakeRelay(stateWith([]));
    await pumpHome(tester, relay);
    await relay.close();
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('Showing the last update'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(relay.opened.length, 2, reason: 'a new feed after the retry');
    relay.emit(stateWith([
      {'id': 'req-3', 'kid': 'kid-ada', 'kind': 'app', 'what': 'minecraft', 'asked_at': 3},
    ]));
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('Showing the last update'), findsNothing);
    expect(find.text('kid-ada asked to use minecraft'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('an unreachable box is an honest message, not a crash or a fake state', (tester) async {
    await pumpHome(tester, ThrowingRelay());
    expect(find.textContaining('relay unreachable'), findsOneWidget);
    expect(find.textContaining('Nothing to answer'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('an unpaired app asks for the code, not a blank screen', (tester) async {
    await pumpPairing(tester, connect: FakeConnect());
    expect(find.text('Pair with the computer'), findsOneWidget);
    expect(find.textContaining('omarchy-kids-notify pair --apply'), findsOneWidget);
  });

  testWidgets('pasting the code and the fingerprint shows the fingerprint to compare', (tester) async {
    await pumpPairing(tester, connect: FakeConnect());
    await tester.enterText(find.byType(TextField).at(0), '  $_uri  ');
    await tester.enterText(find.byType(TextField).at(1), 'AB:CD:${'ef' * 30}');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('abcd${'ef' * 30}'), findsOneWidget);
    expect(find.textContaining('192.168.1.5:8447'), findsOneWidget);
  });

  testWidgets('a paste without a code says what is wrong, and does not pair', (tester) async {
    await pumpPairing(tester, connect: FakeConnect());
    await tester.enterText(find.byType(TextField).at(0), 'fingerprint: ${'ab' * 32}');
    await tester.enterText(find.byType(TextField).at(1), 'ab' * 32);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Paste the whole code'), findsOneWidget);
    expect(find.text('Pair'), findsNothing);
  });

  testWidgets('a fingerprint that is not 64 hex says so', (tester) async {
    await pumpPairing(tester, connect: FakeConnect());
    await tester.enterText(find.byType(TextField).at(0), _uri);
    await tester.enterText(find.byType(TextField).at(1), 'nope');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.textContaining('64-character fingerprint'), findsOneWidget);
  });

  testWidgets('Pair sends the proof to the address the code named, then shows the home screen', (tester) async {
    final connect = FakeConnect();
    await pumpPairing(tester, connect: connect);
    await tester.enterText(find.byType(TextField).at(0), _uri);
    await tester.enterText(find.byType(TextField).at(1), 'ab' * 32);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pair'));
    await tester.pumpAndSettle();
    expect(connect.dialed.first.host, '192.168.1.5');
    expect(connect.dialed.first.port, 8447);
    expect(connect.dialed.first.pin, 'ab' * 32);
    expect(connect.dialed.first.deviceId, 'dev-1');
    expect(connect.relays.first.paired.single, contains('"id":"dev-1"'));
    expect(connect.dialed.length, 2, reason: 'once to pair, once after the pairing is remembered');
    expect(find.text('Nothing to answer right now.'), findsOneWidget);
  });
}
