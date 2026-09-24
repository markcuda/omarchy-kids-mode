// The feed's notification helpers (R-NOTIFY-14): the new-row diff and the
// derived platform id.

import 'package:omarchy_kids_parent/feed.dart';
import 'package:omarchy_kids_parent/state_model.dart';
import 'package:test/test.dart';

void main() {
  BoxState state({List<Map<String, Object?>> requests = const [], List<Map<String, Object?>> reviews = const []}) =>
      BoxState.fromJson({'requests': requests, 'reviews': reviews});

  test('new requests and reviews are the ones not seen yet', () {
    final next = state(
      requests: [
        {'id': 'req-1', 'kid': 'kid-ada', 'kind': 'app', 'what': 'x'},
        {'id': 'req-2', 'kid': 'kid-ada', 'kind': 'time', 'what': '15', 'minutes': 15},
      ],
      reviews: [
        {'id': 'kid-ada.' + 'a' * 16, 'kid': 'kid-ada', 'app': 'firefox', 'now': 'b' * 64},
      ],
    );
    expect(newRequests({'req-1'}, next).map((r) => r.id), ['req-2']);
    expect(newRequests({'req-1', 'req-2'}, next), isEmpty);
    expect(newReviews({}, next).map((r) => r.id), ['kid-ada.' + 'a' * 16]);
    expect(liveRequestIds(next), {'req-1', 'req-2'});
    expect(liveReviewIds(next), {'kid-ada.' + 'a' * 16});
  });

  test('the platform id is deterministic, non-negative and kind-separated', () async {
    final a = await platformNotificationId('request', 'req-1');
    final b = await platformNotificationId('request', 'req-1');
    final c = await platformNotificationId('request', 'req-2');
    final d = await platformNotificationId('review', 'req-1');
    expect(a, b, reason: 'the same row lands on the same id');
    expect(a, isNot(c));
    expect(a, isNot(d), reason: 'the kind is in the hash');
    for (final id in [a, b, c, d]) {
      expect(id, greaterThanOrEqualTo(0));
      expect(id, lessThanOrEqualTo(0x7fffffff));
    }
  });
}
