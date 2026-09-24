// The state model parses the relay's document defensively: a missing or odd
// field must read as a safe default, never crash the app (the box writes the
// document best-effort).

import 'package:test/test.dart';

import '../lib/state_model.dart';

void main() {
  test('a full document parses', () {
    final state = BoxState.fromJson({
      'generated_at': '2026-09-22T12:00:00Z',
      'kids': [
        {'kid': 'kid-ada', 'minutes_left': 12, 'paused': false, 'live': true},
        {'kid': 'kid-cy', 'minutes_left': 0, 'paused': true, 'live': false},
      ],
      'requests': [
        {'id': 'r1', 'kid': 'kid-ada', 'kind': 'time', 'what': '15', 'minutes': 15, 'asked_at': 1000000009},
      ],
      'recent': [
        {'id': 'r0', 'kid': 'kid-cy', 'kind': 'app', 'what': 'gcompris', 'state': 'approved'},
      ],
    });
    expect(state.generatedAt, '2026-09-22T12:00:00Z');
    expect(state.kids.length, 2);
    expect(state.kids.first.minutesLeft, 12);
    expect(state.kids.first.live, isTrue);
    expect(state.kids[1].paused, isTrue);
    expect(state.kids[1].live, isFalse);
    expect(state.liveKids.length, 1);
    final request = state.requests.single;
    expect(request.id, 'r1');
    expect(request.kid, 'kid-ada');
    expect(request.kind, 'time');
    expect(request.what, '15');
    expect(request.minutes, 15);
    expect(request.askedAt, 1000000009);
    expect(state.recent.single.state, 'approved');
  });

  test('odd fields read as safe defaults, and an unusable row is dropped', () {
    final state = BoxState.fromJson({
      'generated_at': 42, // not a string
      'kids': 'nope', // not a list
      'requests': [
        42, // not a map
        {'id': 1, 'minutes': 'lots'}, // no usable id
        {'id': '../etc/passwd'}, // an id the app could not POST back
        {'id': 'ok-1', 'minutes': 'lots'}, // usable id, odd minutes
      ],
      'recent': null,
    });
    expect(state.generatedAt, isNull);
    expect(state.kids, isEmpty);
    expect(state.requests.length, 1, reason: 'only the row with a usable id survives');
    expect(state.requests.single.id, 'ok-1');
    expect(state.requests.single.minutes, isNull, reason: 'a non-numeric minutes is null, not a crash');
    expect(state.requests.single.askedAt, isNull);
    expect(state.recent, isEmpty);
    expect(state.reviews, isEmpty);
  });

  test('paused and live are strictly boolean (the box uses `is True`)', () {
    final state = BoxState.fromJson({
      'kids': [
        {'kid': 'kid-ada', 'live': 1, 'paused': 'true'},
        {'kid': 'kid-cy', 'live': true, 'paused': 0},
      ],
    });
    expect(state.kids[0].live, isFalse, reason: '1 is not true');
    expect(state.kids[0].paused, isFalse, reason: '"true" is not true');
    expect(state.kids[1].live, isTrue);
    expect(state.kids[1].paused, isFalse);
  });

  test('control characters are stripped and long values capped', () {
    final state = BoxState.fromJson({
      'requests': [
        {'id': 'r1', 'kid': 'kid-ada\u0007', 'kind': 'app', 'what': 'a' * 500},
      ],
    });
    final request = state.requests.single;
    expect(request.kid, 'kid-ada', reason: 'the bell is dropped');
    expect(request.what.length, 120, reason: 'the value is capped');
  });

  test('a huge list is bounded', () {
    final rows = [for (var i = 0; i < 500; i++) {'id': 'r$i', 'kid': 'kid-ada', 'kind': 'app', 'what': 'x'}];
    final state = BoxState.fromJson({'requests': rows});
    expect(state.requests.length, 64);
  });

  test('reviews parse, and only the decidable ones are kept (R-NOTIFY-12)', () {
    final rid = 'kid-ada.' + 'a' * 16;
    final state = BoxState.fromJson({
      'reviews': [
        {'id': rid, 'kid': 'kid-ada', 'app': 'firefox', 'was': 'a' * 64, 'now': 'b' * 64, 'detected_at': 5},
        // the removed add-on the box records with its own sentinel: decidable
        {'id': 'kid-ada.' + 'c' * 16, 'kid': 'kid-ada', 'app': 'gone', 'was': 'a' * 64, 'now': 'missing'},
        // skipped: an id the app could not POST back, and a `now` it could not sign
        {'id': 'not-a-review', 'kid': 'kid-ada', 'app': 'x', 'now': 'b' * 64},
        {'id': 'kid-ada.' + 'd' * 16, 'kid': 'kid-ada', 'app': 'x', 'now': 'nonsense'},
      ],
    });
    expect(state.reviews.length, 2);
    expect(state.reviews.first.id, rid);
    expect(state.reviews.first.app, 'firefox');
    expect(state.reviews.first.decidable, isTrue);
    expect(state.reviews.last.now, 'missing');
    expect(describeReview(state.reviews.first), 'firefox changed since you approved it');
    expect(describeReview(state.reviews.last), 'gone is no longer installed');
  });

  test('an empty document parses to empty lists', () {
    final state = BoxState.fromJson({});
    expect(state.kids, isEmpty);
    expect(state.requests, isEmpty);
    expect(state.recent, isEmpty);
    expect(state.reviews, isEmpty);
    expect(BoxState.fromJson({'kids': []}).liveKids, isEmpty);
  });

  test('describeRequest names the kid and the ask', () {
    final time = OpenRequest(id: 'r1', kid: 'kid-ada', kind: 'time', what: '15', minutes: 15);
    expect(describeRequest(time, 'Ada'), 'Ada asked for 15 more minutes');
    final app = OpenRequest(id: 'r2', kid: 'kid-ada', kind: 'app', what: 'minecraft');
    expect(describeRequest(app, 'Ada'), 'Ada asked to use minecraft');
    final unnamed = OpenRequest(id: 'r3', kid: 'kid-ada', kind: 'site', what: 'example.com');
    expect(describeRequest(unnamed, ''), 'Your kid asked to use example.com');
    final odd = OpenRequest(id: 'r4', kid: 'kid-ada', kind: 'plugin', what: '');
    expect(describeRequest(odd, 'Ada'), 'Ada asked to use plugin');
  });
}
