// The app's UI over a fake relay: the request list, Approve/Decline with a reply
// chip, the honest states, and pairing (paste the code, type the fingerprint,
// confirm, pair). The logic itself is tested in the omarchy_kids_parent package.

import 'dart:async';
import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omarchy_kids_app/app_root.dart';
import 'package:omarchy_kids_app/keystore.dart';
import 'package:omarchy_kids_app/notifier.dart';
import 'package:omarchy_kids_app/main.dart';
import 'package:omarchy_kids_parent/relay_transport.dart';
import 'package:omarchy_kids_parent/session.dart';
import 'package:omarchy_kids_parent/state_model.dart';

import 'fakes.dart';

class FakeRelay implements RelayTransport {
  BoxState state;
  final String pin;
  final List<Map<String, Object?>> decided = [];
  final List<Map<String, Object?>> reviewed = [];
  final List<Map<String, Object?>> acted = [];
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

/// A box that refuses an ACT the way the real one does when the device lacks the
/// `act` scope (403 with `no scope-missing`).
class ScopeRefusingRelay extends FakeRelay {
  ScopeRefusingRelay(super.state);
  @override
  Future<Map<String, dynamic>> act({
    required Map<String, Object?> record,
    required int ts,
    required String nonce,
  }) async =>
      throw Exception('act: 403 {"reply":"no scope-missing"}');
}

/// A box that refuses a review decision the way the real one does on a stale
/// fingerprint (403 with `no changed-again`).
class RefusingRelay extends FakeRelay {
  RefusingRelay(super.state);
  @override
  Future<Map<String, dynamic>> decideReview({
    required Map<String, Object?> record,
    required int ts,
    required String nonce,
  }) async =>
      throw Exception('decideReview: 403 {"reply":"no changed-again"}');
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

Future<void> pumpHome(
  WidgetTester tester,
  FakeRelay relay, {
  Notifier? notifier,
  String? noticeNote,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: HomeScreen(session: await sessionWith(relay), notifier: notifier, noticeNote: noticeNote),
    ),
  );
  await tester.pumpAndSettle();
}

final _uri = 'omarchy-kids://pair?v=1&id=dev-1&token=${'a' * 40}&addr=192.168.1.5';

/// A keystore that already holds a pairing, so the app opens on the requests.
Future<InMemoryKeystore> pairedKeystore() async {
  final keystore = InMemoryKeystore();
  await keystore.savePaired(
    jsonEncode({'deviceId': 'dev-1', 'pin': 'ab' * 32, 'addresses': ['192.168.1.5']}),
  );
  return keystore;
}

Future<void> pumpPairing(
  WidgetTester tester, {
  required FakeConnect connect,
  Keystore? keystore,
  Notifier? notifier,
  String? noticeNote,
}) async {
  await tester.pumpWidget(MaterialApp(
    home: AppRoot(
      keystore: keystore ?? InMemoryKeystore(),
      connect: connect.call,
      name: 'parent-phone',
      platform: 'linux',
      notifier: notifier,
      noticeNote: noticeNote,
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

  testWidgets('a paired app offers to forget the computer, and Cancel keeps it', (tester) async {
    final keystore = await pairedKeystore();
    await pumpPairing(tester, connect: FakeConnect(), keystore: keystore);
    expect(find.byTooltip('Refresh'), findsOneWidget, reason: 'on the list screen');
    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Forget this computer…'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Refresh'), findsOneWidget, reason: 'on the list screen');
    expect(await keystore.loadPaired(), isNotNull);
  });

  testWidgets('Forget clears the pairing, stops the feed, and returns to pairing', (tester) async {
    final keystore = await pairedKeystore();
    final connect = FakeConnect();
    await pumpPairing(tester, connect: connect, keystore: keystore);
    expect(connect.relays.first.opened.first.hasListener, isTrue, reason: 'the feed runs while paired');
    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Forget this computer…'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Forget'));
    await tester.pumpAndSettle();
    expect(find.text('Pair with the computer'), findsOneWidget);
    expect(await keystore.loadPaired(), isNull);
    expect(connect.relays.first.opened.first.hasListener, isFalse,
        reason: 'forgetting drops the old feed, not just the pin');
  });

  testWidgets('a refused permission says so instead of the note it was given', (tester) async {
    final notifier = FakeNotifier()..status = NoticeStatus.refused;
    await pumpHome(
      tester,
      FakeRelay(stateWith([])),
      notifier: notifier,
      noticeNote: 'Notifies while the app is open.',
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Notifications are off'), findsOneWidget);
    expect(find.textContaining('Notifies while the app is open.'), findsNothing);
  });

  testWidgets('a platform with no adapter keeps the note that says so', (tester) async {
    final notifier = FakeNotifier()..status = NoticeStatus.unsupported;
    await pumpHome(
      tester,
      FakeRelay(stateWith([])),
      notifier: notifier,
      noticeNote: 'This platform has no notifications in this build.',
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('no notifications in this build'), findsOneWidget);
    expect(find.textContaining('Notifications are off'), findsNothing,
        reason: 'there is no setting to turn on');
  });

  testWidgets('Forget clears the notifications too', (tester) async {
    final keystore = await pairedKeystore();
    final notifier = FakeNotifier();
    await pumpPairing(tester, connect: FakeConnect(), keystore: keystore, notifier: notifier);
    final before = notifier.cancelAlls;
    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Forget this computer…'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Forget'));
    await tester.pumpAndSettle();
    expect(notifier.cancelAlls, greaterThan(before), reason: 'a forgotten box leaves no rows behind');
  });

  testWidgets('a request that arrives while the app is open raises a notification, and a tap opens it', (tester) async {
    final relay = FakeRelay(stateWith([]));
    final notifier = FakeNotifier();
    await pumpHome(tester, relay, notifier: notifier);
    expect(notifier.shows, isEmpty, reason: 'the first document is silent');
    expect(notifier.cancelAlls, 1);
    relay.emit(stateWith([
      {'id': 'req-9', 'kid': 'kid-ada', 'kind': 'app', 'what': 'minecraft', 'asked_at': 1},
    ]));
    await tester.pump();
    await tester.pump();
    expect(notifier.shows.single.id, 'req-9');
    expect(notifier.shows.single.title, 'kid-ada asked to use minecraft');
    // The parent taps it: the row opens.
    notifier.onTap!(const NoticeTap('request', 'req-9'));
    await tester.pumpAndSettle();
    expect(find.text('Approve'), findsOneWidget);
  });

  testWidgets('a tap for a row the document does not carry yet waits for it', (tester) async {
    final relay = FakeRelay(stateWith([]));
    final notifier = FakeNotifier();
    await pumpHome(tester, relay, notifier: notifier);
    // The tap launched the app: the row is not in the first document yet.
    notifier.onTap!(const NoticeTap('request', 'req-later'));
    await tester.pumpAndSettle();
    expect(find.text('Approve'), findsNothing, reason: 'nothing to open yet');
    relay.emit(stateWith([
      {'id': 'req-later', 'kid': 'kid-ada', 'kind': 'time', 'what': '15', 'minutes': 15, 'asked_at': 2},
    ]));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('Approve'), findsOneWidget, reason: 'opened once the row arrived');
  });

  testWidgets('recently decided rows show the outcome and the reply, newest first, inert', (tester) async {
    final relay = FakeRelay(BoxState.fromJson({
      'kids': [
        {'kid': 'kid-ada', 'live': true},
      ],
      'requests': [],
      'recent': [
        {'id': 'r1', 'kid': 'kid-ada', 'kind': 'app', 'what': 'minecraft',
         'state': 'approved', 'decided_at': 1000, 'reply': 'After dinner'},
        {'id': 'r2', 'kid': 'kid-ada', 'kind': 'site', 'what': 'example.com',
         'state': 'declined', 'decided_at': 2000},
      ],
    }));
    await pumpHome(tester, relay);
    expect(find.text('Recently decided'), findsOneWidget);
    expect(find.text('Approved: "After dinner"'), findsOneWidget);
    expect(find.text('Declined'), findsOneWidget);
    expect(find.textContaining('Nothing here can be changed'), findsOneWidget);
    // Newest first (r2's decided_at is the later one).
    final newer = tester.getTopLeft(find.text('kid-ada asked to use example.com')).dy;
    final older = tester.getTopLeft(find.text('kid-ada asked to use minecraft')).dy;
    expect(newer, lessThan(older), reason: 'sorted by decided_at, newest first');
    // Inert: the recent rows carry no tap handler (the kid row above does).
    final recentTile = tester.widget<ListTile>(
      find.widgetWithText(ListTile, 'Approved: "After dinner"'),
    );
    expect(recentTile.onTap, isNull, reason: 'a recent row cannot be acted on');
  });

  testWidgets('the section is after the requests list, capped at 20', (tester) async {
    // A tall view, so all 20 rows are built: a 600px ListView would never mount
    // the 21st row and the cap assertion would be vacuous.
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final relay = FakeRelay(BoxState.fromJson({
      'kids': [
        {'kid': 'kid-ada', 'live': true},
      ],
      'requests': [
        {'id': 'req-1', 'kid': 'kid-ada', 'kind': 'app', 'what': 'minecraft', 'asked_at': 1},
      ],
      'recent': [
        for (var i = 0; i < 25; i++)
          {'id': 'r$i', 'kid': 'kid-ada', 'kind': 'app', 'what': 'app$i',
           'state': 'approved', 'decided_at': 1000 + i},
      ],
    }));
    await pumpHome(tester, relay);
    final requestY = tester.getTopLeft(find.text('kid-ada asked to use minecraft')).dy;
    final headerY = tester.getTopLeft(find.text('Recently decided')).dy;
    expect(requestY, lessThan(headerY), reason: 'the section follows the requests');
    expect(find.text('kid-ada asked to use app24'), findsOneWidget);
    expect(find.text('kid-ada asked to use app5'), findsOneWidget);
    expect(find.text('kid-ada asked to use app4'), findsNothing,
        reason: 'only the newest 20 of 25 are shown');
  });

  testWidgets('equal decided_at ties are ordered by id, and a today row shows a bare time', (tester) async {
    final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final relay = FakeRelay(BoxState.fromJson({
      'kids': [],
      'requests': [],
      'recent': [
        {'id': 'a', 'kid': 'kid-ada', 'kind': 'app', 'what': 'x',
         'state': 'approved', 'decided_at': 500},
        {'id': 'b', 'kid': 'kid-ada', 'kind': 'app', 'what': 'y',
         'state': 'approved', 'decided_at': 500},
        {'id': 'c', 'kid': 'kid-ada', 'kind': 'app', 'what': 'z',
         'state': 'approved', 'decided_at': nowSeconds},
      ],
    }));
    await pumpHome(tester, relay);
    expect(
      tester.getTopLeft(find.text('kid-ada asked to use y')).dy,
      lessThan(tester.getTopLeft(find.text('kid-ada asked to use x')).dy),
      reason: 'an equal time breaks by id, descending',
    );
    expect(find.textContaining(RegExp(r'^\d{2}:\d{2}$')), findsOneWidget,
        reason: 'a decision from today shows a bare time');
  });

  testWidgets('no recently-decided section when the window is empty', (tester) async {
    await pumpHome(tester, FakeRelay(stateWith([])));
    expect(find.text('Recently decided'), findsNothing);
  });

  testWidgets('a live kid is listed with their minutes and opens the two actions', (tester) async {
    await pumpHome(tester, FakeRelay(stateWith([])));
    expect(find.text('Kids'), findsOneWidget);
    expect(find.text('kid-ada'), findsOneWidget);
    expect(find.text('12 min left'), findsOneWidget);
    await tester.tap(find.text('kid-ada'));
    await tester.pumpAndSettle();
    expect(find.text('More time today'), findsOneWidget);
    expect(find.text('Give 30 minutes'), findsOneWidget);
    expect(find.text('End session now'), findsOneWidget);
    expect(find.textContaining('no password is typed'), findsOneWidget);
  });

  testWidgets('giving time signs a grant with the chosen minutes', (tester) async {
    final relay = FakeRelay(stateWith([]));
    await pumpHome(tester, relay);
    await tester.tap(find.text('kid-ada'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('15 min'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Give 15 minutes'));
    await tester.pumpAndSettle();
    expect(relay.acted.single['account'], 'kid-ada');
    expect(relay.acted.single['action'], 'grant');
    expect(relay.acted.single['minutes'], 15);
    expect(find.byTooltip('Refresh'), findsOneWidget, reason: 'back on the list');
  });

  testWidgets('ending a session asks first, then signs an end with no minutes', (tester) async {
    final relay = FakeRelay(stateWith([]));
    await pumpHome(tester, relay);
    await tester.tap(find.text('kid-ada'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('End session now'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(relay.acted, isEmpty, reason: 'Cancel sends nothing');
    await tester.tap(find.text('End session now'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('End now'));
    await tester.pumpAndSettle();
    expect(relay.acted.single['action'], 'end');
    expect(relay.acted.single.containsKey('minutes'), isFalse);
  });

  testWidgets('a device without the act scope is told so, not left guessing', (tester) async {
    final relay = ScopeRefusingRelay(stateWith([]));
    await pumpHome(tester, relay);
    await tester.tap(find.text('kid-ada'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Give 30 minutes'));
    await tester.pumpAndSettle();
    expect(find.textContaining('not to act'), findsOneWidget);
    expect(find.text('Give 30 minutes'), findsOneWidget, reason: 'still here to try another way');
  });

  testWidgets('a changed add-on is shown above the requests, and opens to what changed', (tester) async {
    final rid = 'kid-ada.' + 'a' * 16;
    final relay = FakeRelay(BoxState.fromJson({
      'kids': [
        {'kid': 'kid-ada', 'live': true},
      ],
      'requests': [
        {'id': 'req-1', 'kid': 'kid-ada', 'kind': 'app', 'what': 'minecraft', 'asked_at': 1},
      ],
      'reviews': [
        {'id': rid, 'kid': 'kid-ada', 'app': 'firefox', 'was': 'a' * 64, 'now': 'b' * 64, 'detected_at': 5},
      ],
    }));
    await pumpHome(tester, relay);
    expect(find.text('Add-ons that changed'), findsOneWidget);
    expect(find.text('firefox changed since you approved it'), findsOneWidget);
    expect(find.text('kid-ada asked to use minecraft'), findsOneWidget);
    await tester.tap(find.text('firefox changed since you approved it'));
    await tester.pumpAndSettle();
    expect(find.textContaining('was  ${'a' * 64}'), findsOneWidget);
    expect(find.textContaining('now  ${'b' * 64}'), findsOneWidget);
  });

  testWidgets('Approve sends the fingerprint the review showed', (tester) async {
    final rid = 'kid-ada.' + 'a' * 16;
    final relay = FakeRelay(BoxState.fromJson({
      'kids': [],
      'requests': [],
      'reviews': [
        {'id': rid, 'kid': 'kid-ada', 'app': 'firefox', 'was': 'a' * 64, 'now': 'b' * 64},
      ],
    }));
    await pumpHome(tester, relay);
    await tester.tap(find.text('firefox changed since you approved it'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Approve'));
    await tester.pumpAndSettle();
    expect(relay.reviewed.single['review_id'], rid);
    expect(relay.reviewed.single['decision'], 'approve');
    expect(relay.reviewed.single['seen'], 'b' * 64);
    expect(find.byTooltip('Refresh'), findsOneWidget, reason: 'back on the list after answering');
    expect(find.text('Approve'), findsNothing);
  });

  testWidgets("a refusal the box gives is shown in the parent's words, not as a success", (tester) async {
    final rid = 'kid-ada.' + 'a' * 16;
    final relay = RefusingRelay(BoxState.fromJson({
      'kids': [],
      'requests': [],
      'reviews': [
        {'id': rid, 'kid': 'kid-ada', 'app': 'firefox', 'was': 'a' * 64, 'now': 'b' * 64},
      ],
    }));
    await pumpHome(tester, relay);
    await tester.tap(find.text('firefox changed since you approved it'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Approve'));
    await tester.pumpAndSettle();
    expect(find.textContaining('changed again since you looked'), findsOneWidget);
    expect(find.text('Approve'), findsOneWidget, reason: 'still here to try again');
  });

  testWidgets('Deny sends a deny with the same fingerprint', (tester) async {
    final rid = 'kid-ada.' + 'a' * 16;
    final relay = FakeRelay(BoxState.fromJson({
      'kids': [],
      'requests': [],
      'reviews': [
        {'id': rid, 'kid': 'kid-ada', 'app': 'gone', 'was': 'a' * 64, 'now': 'missing'},
      ],
    }));
    await pumpHome(tester, relay);
    expect(find.text('gone is no longer installed'), findsOneWidget);
    await tester.tap(find.text('gone is no longer installed'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Deny (hide it again)'));
    await tester.pumpAndSettle();
    expect(relay.reviewed.single['decision'], 'deny');
    expect(relay.reviewed.single['seen'], 'missing');
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

  testWidgets('a pairing is kept, so a later run opens on the requests, not the code', (tester) async {
    final store = FakeStore();
    final connect = FakeConnect();
    await pumpPairing(tester, connect: connect, keystore: SecureKeystore(store));
    await tester.enterText(find.byType(TextField).at(0), _uri);
    await tester.enterText(find.byType(TextField).at(1), 'ab' * 32);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pair'));
    await tester.pumpAndSettle();
    expect(find.text('Nothing to answer right now.'), findsOneWidget);
    expect(store.values[SecureKeystore.pairedKey], isNotNull);
    // A new run of the app with the same store: no code, no fingerprint.
    await tester.pumpWidget(const SizedBox());
    await pumpPairing(tester, connect: FakeConnect(), keystore: SecureKeystore(store));
    expect(find.byTooltip('Refresh'), findsOneWidget, reason: 'on the list screen');
    expect(find.text('Pair with the computer'), findsNothing);
  });

  testWidgets('a store that cannot even be read lands on pairing with a way out, not a spinner', (tester) async {
    final store = FakeStore()..readThrows.add(SecureKeystore.pairedKey);
    final keystore = SecureKeystore(store);
    await pumpPairing(tester, connect: FakeConnect(), keystore: keystore);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.textContaining("Couldn't open the session"), findsOneWidget);
    expect(find.text('Trouble? Reset this device'), findsOneWidget);
    await tester.tap(find.text('Trouble? Reset this device'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    expect(store.readThrows, isEmpty, reason: 'the reset deleted the unreadable item');
    expect(await keystore.loadPaired(), isNull);
    expect(find.textContaining("Couldn't open the session"), findsNothing);
  });

  testWidgets('a bad box seed, only read at a pairing, still offers the reset', (tester) async {
    final store = FakeStore();
    store.values[SecureKeystore.boxKey] = base64.encode(List.filled(31, 1));
    final keystore = SecureKeystore(store);
    await pumpPairing(tester, connect: FakeConnect(), keystore: keystore);
    // No paired record, so boot is fine and only the pairing reads the seed.
    expect(find.text('Pair with the computer'), findsOneWidget);
    expect(find.textContaining("Couldn't open the session"), findsNothing);
    await tester.enterText(find.byType(TextField).at(0), _uri);
    await tester.enterText(find.byType(TextField).at(1), 'ab' * 32);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pair'));
    await tester.pumpAndSettle();
    expect(find.textContaining("Pairing didn't work"), findsOneWidget);
    await tester.tap(find.text('Trouble? Reset this device'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    expect(await keystore.loadBoxSeed(), isNull);
  });

  testWidgets('a stored key the app cannot read is not a dead end: Reset clears it', (tester) async {
    final store = FakeStore();
    store.values[SecureKeystore.signKey] = base64.encode(List.filled(31, 1));
    store.values[SecureKeystore.pairedKey] = jsonEncode({
      'deviceId': 'dev-1',
      'pin': 'ab' * 32,
      'addresses': ['192.168.1.5'],
    });
    final keystore = SecureKeystore(store);
    await pumpPairing(tester, connect: FakeConnect(), keystore: keystore);
    expect(find.textContaining("Couldn't open the session"), findsOneWidget);
    await tester.tap(find.text('Trouble? Reset this device'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    expect(await keystore.loadSignSeed(), isNull);
    expect(await keystore.loadPaired(), isNull);
    expect(find.text('Pair with the computer'), findsOneWidget);
    expect(find.textContaining("Couldn't open the session"), findsNothing);
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
