// The SSE parser: the relay sends `state` events with a JSON data line and
// heartbeat comments. A unit test here pins the edge cases the integration test's
// single connection cannot: comments, multi-line data, other events, and a
// truncated final event.

import 'dart:async';

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

  test('multi-line data is joined with a single newline', () async {
    // Assert the joined string itself: a dropped separator gives the same JSON
    // value, so only the raw data can prove the join.
    final data = sseData(Stream.fromIterable([
      'event: state',
      'data: {"a": 1,',
      'data: "b": 2}',
      '',
    ]));
    expect(await data.toList(), ['{"a": 1,\n"b": 2}']);
  });

  test('a value after the colon keeps a second leading space', () async {
    // SSE strips exactly one leading space; the second is part of the value.
    final events = parseSse(Stream.fromIterable([
      'event:  state', // two spaces after the colon -> " state", not "state"
      'data: {"kids": []}',
      '',
    ]));
    expect(await events.toList(), isEmpty, reason: 'the event name is " state", not "state"');
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

  test('a stream that goes quiet errors instead of hanging', () async {
    final controller = StreamController<String>();
    controller.add('event: state');
    controller.add('data: {"kids": []}');
    // no terminating blank line, and the stream is never closed: silence only
    final events = parseSse(withLiveness(controller.stream, const Duration(milliseconds: 50)));
    await expectLater(events, emitsError(anything));
    await controller.close();
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
