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
        {'id': 'r1', 'kid': 'kid-ada', 'kind': 'time', 'what': '15', 'minutes': 15, 'asked_at': 1},
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
    expect(state.requests.single.id, 'r1');
    expect(state.requests.single.minutes, 15);
    expect(state.recent.single.state, 'approved');
  });

  test('odds fields read as safe defaults, not throws', () {
    final state = BoxState.fromJson({
      'generated_at': 42, // not a string
      'kids': 'nope', // not a list
      'requests': [42, {'id': 1, 'minutes': 'lots'}], // a non-map row and odd scalars
      'recent': null,
    });
    expect(state.generatedAt, isNull);
    expect(state.kids, isEmpty);
    expect(state.requests.length, 1); // the 42 is dropped
    expect(state.requests.single.id, '');
    expect(state.requests.single.minutes, isNull, reason: 'a non-numeric minutes is null, not a crash');
    expect(state.recent, isEmpty);
  });

  test('an empty document parses to empty lists', () {
    final state = BoxState.fromJson({});
    expect(state.kids, isEmpty);
    expect(state.requests, isEmpty);
    expect(state.recent, isEmpty);
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
