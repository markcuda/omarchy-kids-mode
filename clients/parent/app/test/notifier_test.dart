// The app's notification rules (R-NOTIFY-14) over a fake: the first document is
// silent, a new row raises once, a row that leaves is cleared, a replay raises
// nothing. The platform adapter is not exercised here.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:omarchy_kids_parent/notify_crypto.dart' show sha256Hex;
import 'package:omarchy_kids_app/notifier.dart';
import 'package:omarchy_kids_parent/state_model.dart';

import 'fakes.dart';

BoxState state({List<Map<String, Object?>> requests = const [], List<Map<String, Object?>> reviews = const []}) =>
    BoxState.fromJson({
      'kids': [
        {'kid': 'kid-ada', 'live': true},
      ],
      'requests': requests,
      'reviews': reviews,
    });

void main() {
  final rid = 'kid-ada.${sha256Hex(utf8.encode('firefox')).substring(0, 16)}';
  final request = {'id': 'req-1', 'kid': 'kid-ada', 'kind': 'app', 'what': 'minecraft'};

  test('the first document is silent and clears anything left over', () async {
    final notifier = FakeNotifier();
    final feed = NoticeFeed(notifier);
    expect(feed.silent, isTrue);
    await feed.update(state(requests: [request]));
    expect(notifier.shows, isEmpty, reason: 'the first document seeds, it does not raise');
    expect(notifier.cancelAlls, 1, reason: 'a previous run may have left notifications');
    expect(feed.silent, isFalse);
  });

  test('a request that arrives later raises once, in the list words', () async {
    final notifier = FakeNotifier();
    final feed = NoticeFeed(notifier);
    await feed.update(state());
    await feed.update(state(requests: [request]));
    expect(notifier.shows.single.kind, 'request');
    expect(notifier.shows.single.id, 'req-1');
    expect(notifier.shows.single.title, 'kid-ada asked to use minecraft');
    expect(notifier.shows.single.body, 'Open to approve or decline');
    // A reconnect replays the same document: nothing more is raised.
    await feed.update(state(requests: [request]));
    expect(notifier.shows.length, 1);
  });

  test('a state read seeds and never raises (R-NOTIFY-14.1)', () async {
    final notifier = FakeNotifier();
    final feed = NoticeFeed(notifier);
    await feed.seed(state(requests: [
      {'id': 'req-1', 'kid': 'kid-ada', 'kind': 'app', 'what': 'x'},
    ]));
    expect(notifier.shows, isEmpty, reason: 'a read seeds the sets; it raises nothing');
    await feed.seed(state(requests: [
      {'id': 'req-1', 'kid': 'kid-ada', 'kind': 'app', 'what': 'x'},
      {'id': 'req-2', 'kid': 'kid-ada', 'kind': 'app', 'what': 'y'},
    ]));
    expect(notifier.shows, isEmpty, reason: 'a later read still raises nothing');
    await feed.update(state(requests: [
      {'id': 'req-1', 'kid': 'kid-ada', 'kind': 'app', 'what': 'x'},
      {'id': 'req-2', 'kid': 'kid-ada', 'kind': 'app', 'what': 'y'},
    ]));
    expect(notifier.shows.length, 1, reason: 'the feed raises the new request');
    expect(notifier.shows.single.id, 'req-2');
  });

  test('a review raises with its own words, and a decision elsewhere clears it', () async {
    final notifier = FakeNotifier();
    final feed = NoticeFeed(notifier);
    await feed.update(state());
    await feed.update(state(reviews: [
      {'id': rid, 'kid': 'kid-ada', 'app': 'firefox', 'now': 'b' * 64},
    ]));
    expect(notifier.shows.single.kind, 'review');
    expect(notifier.shows.single.title, 'firefox changed since you approved it');
    expect(notifier.shows.single.body, 'Open to approve, deny or check');
    // The row leaves the document (decided on the box): clear it.
    await feed.update(state());
    expect(notifier.cancels.single.kind, 'review');
    expect(notifier.cancels.single.id, rid);
    // And a later document without it raises nothing again.
    await feed.update(state());
    expect(notifier.shows.length, 1);
  });

  test('a review reopened after being decided raises again', () async {
    final notifier = FakeNotifier();
    final feed = NoticeFeed(notifier);
    final row = {'id': rid, 'kid': 'kid-ada', 'app': 'firefox', 'now': 'b' * 64};
    await feed.update(state());
    await feed.update(state(reviews: [row]));
    expect(notifier.shows.single.id, rid);
    await feed.update(state()); // decided on the box: the row leaves
    expect(notifier.cancels.single.id, rid);
    await feed.update(state(reviews: [row])); // the add-on changes again, same id
    expect(notifier.shows.length, 2, reason: 'a reopened review carries the same id and must raise');
  });

  test('two documents that land together raise once and clear once', () async {
    final notifier = FakeNotifier();
    final feed = NoticeFeed(notifier);
    await feed.update(state());
    // Not awaited: both folds are in flight at once. Without serialization the
    // second sees the old set and cancels nothing, or both raise.
    final a = feed.update(state(requests: [request]));
    final b = feed.update(state());
    await Future.wait([a, b]);
    expect(notifier.shows.length, 1, reason: 'raised once');
    expect(notifier.cancels.length, 1, reason: 'cleared when it left');
  });

  test('the payload is the kind and the id, and junk parses to null', () {
    expect(parseNoticePayload(noticePayload('request', 'req-1'))!.id, 'req-1');
    expect(parseNoticePayload(noticePayload('review', rid))!.kind, 'review');
    expect(parseNoticePayload(null), isNull);
    expect(parseNoticePayload('not json'), isNull);
    expect(parseNoticePayload('{"kind":"other","id":"x"}'), isNull);
    expect(parseNoticePayload('{"kind":"request"}'), isNull);
    expect(parseNoticePayload('{"kind":"request","id":""}'), isNull);
  });
}
