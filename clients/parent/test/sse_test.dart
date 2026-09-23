// The SSE parser: the relay sends `state` events with a JSON data line and
// heartbeat comments. A unit test here pins the edge cases the integration test's
// single connection cannot: comments, multi-line data, other events, and a
// truncated final event.

import 'package:test/test.dart';

import '../lib/transport.dart';

void main() {
  test('a state event with a JSON data line is emitted', () async {
    final events = parseSse(Stream.fromIterable([
      ': heartbeat',
      'event: state',
      'data: {"kids": []}',
      '',
    ]));
    expect(await events.toList(), [
      {'kids': <Object?>[]}
    ]);
  });

  test('multi-line data is joined with newlines', () async {
    final events = parseSse(Stream.fromIterable([
      'event: state',
      'data: {"kids": [],',
      'data:  "reviews": 1}',
      '',
    ]));
    expect(await events.toList(), [
      {'kids': <Object?>[], 'reviews': 1}
    ]);
  });

  test('another event name, a comment and a truncated event yield nothing', () async {
    final events = parseSse(Stream.fromIterable([
      ': connected',
      'event: request.opened',
      'data: {"request": "x"}',
      '',
      'event: state',
      'data: {"kids": []}', // no blank line terminates it
    ]));
    expect(await events.toList(), isEmpty);
  });

  test('two events in one stream both arrive, in order', () async {
    final events = parseSse(Stream.fromIterable([
      'event: state',
      'data: {"kids": []}',
      '',
      'event: state',
      'data: {"kids": [{"kid": "kid-ada"}]}',
      '',
    ]));
    final list = await events.toList();
    expect(list.length, 2);
    expect(list[0]['kids'], isEmpty);
    expect((list[1]['kids'] as List).first, {'kid': 'kid-ada'});
  });
}
