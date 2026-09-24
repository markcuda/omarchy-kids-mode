// The app's notification rules (R-NOTIFY-14): only a request or a review that
// arrives after the first document, one per id, cleared when the id leaves the
// document. The seam is here so the rules are tested with a fake; the platform
// adapter lives in the app (lib/notifier.dart).

import 'dart:convert';

import 'package:omarchy_kids_parent/state_model.dart';

/// What a notification tap asks the app to open.
class NoticeTap {
  final String kind; // 'request' or 'review'
  final String id;
  const NoticeTap(this.kind, this.id);
}

/// The notification payload (R-NOTIFY-14.3): the kind and the id, nothing else.
String noticePayload(String kind, String id) => jsonEncode({'kind': kind, 'id': id});

/// Parse a payload, or null for anything that is not one: the platform may hand
/// back a payload from another build or a stale process, and a tap must never
/// open a screen for an id the box would not accept.
NoticeTap? parseNoticePayload(String? payload) {
  if (payload == null) return null;
  try {
    final json = jsonDecode(payload);
    if (json is! Map || json['kind'] is! String || json['id'] is! String) return null;
    final kind = json['kind'] as String;
    final id = json['id'] as String;
    if (kind != 'request' && kind != 'review') return null;
    if (id.isEmpty || id.length > 128) return null;
    return NoticeTap(kind, id);
  } on FormatException {
    return null;
  }
}

/// What the app raises a notification through. The app passes its platform
/// adapter; a test passes a fake that records the calls.
abstract class Notifier {
  /// Prepare the platform (permission, tap handler) once. `onTap` is called with
  /// a notification the parent tapped, while the app is alive. Returns whether
  /// the platform will actually raise one (a refused permission is false), so the
  /// screen can say the truth instead of the optimistic default.
  Future<bool> initialize({required void Function(NoticeTap tap) onTap});

  /// Raise (or replace) the notification for one row.
  Future<void> show({
    required String kind,
    required String id,
    required String title,
    required String body,
  });

  /// Clear the notification for one row (its id left the document).
  Future<void> cancel({required String kind, required String id});

  /// Clear every notification the app owns (process start, Forget).
  Future<void> cancelAll();
}

/// The label a row shows for a kid: the account the box published. (A display
/// name would come from the kid's own profile, which the document does not
/// carry; the list and a notification must say the same thing.)
String kidLabel(BoxState state, String kid) => kid;

/// A notifier that raises nothing: the adapter for a platform with no
/// notification support (Windows in this build). The lists and decisions work
/// unchanged; the notice label says nothing will be raised here.
class NoopNotifier implements Notifier {
  const NoopNotifier();

  @override
  Future<bool> initialize({required void Function(NoticeTap tap) onTap}) async => false;

  @override
  Future<void> show({
    required String kind,
    required String id,
    required String title,
    required String body,
  }) async {}

  @override
  Future<void> cancel({required String kind, required String id}) async {}

  @override
  Future<void> cancelAll() async {}
}

/// Watches the feed and drives a [Notifier]. The first document of a run seeds
/// the sets and raises nothing; every later document raises a notification for
/// each id it has not seen and cancels each raised id that is gone (R-NOTIFY-14).
///
/// The sets are the *last* document's ids, not every id ever seen: a review id is
/// stable for a kid and an add-on, so a review decided and later reopened carries
/// the same id and must raise again. Folds are serialized on one chain, because
/// the work awaits the platform between the diff and the bookkeeping and two
/// documents landing together would otherwise both see the old set.
class NoticeFeed {
  final Notifier notifier;
  final _seenRequests = <String>{};
  final _seenReviews = <String>{};
  final _raisedRequests = <String>{};
  final _raisedReviews = <String>{};
  bool _seeded = false;
  Future<void> _chain = Future<void>.value();

  NoticeFeed(this.notifier);

  /// True until the first document has been folded in (a fresh run is silent).
  bool get silent => !_seeded;

  /// Fold one document in, in arrival order, raising and clearing as the rule says.
  Future<void> update(BoxState state) {
    final next = _chain.then((_) => _fold(state));
    // Keep the chain alive whatever a fold does; the caller still sees the error.
    _chain = next.then((_) {}, onError: (_) {});
    return next;
  }

  Future<void> _fold(BoxState state) async {
    final liveRequests = state.requests.map((r) => r.id).toSet();
    final liveReviews = state.reviews.map((r) => r.id).toSet();
    if (!_seeded) {
      // The first document seeds; it raises nothing, and anything the platform
      // still holds from a previous run is cleared.
      _seenRequests
        ..clear()
        ..addAll(liveRequests);
      _seenReviews
        ..clear()
        ..addAll(liveReviews);
      _raisedRequests.clear();
      _raisedReviews.clear();
      _seeded = true;
      await notifier.cancelAll();
      return;
    }
    for (final request in state.requests.where((r) => !_seenRequests.contains(r.id))) {
      await notifier.show(
        kind: 'request',
        id: request.id,
        title: describeRequest(request, kidLabel(state, request.kid)),
        body: 'Open to approve or decline',
      );
      _raisedRequests.add(request.id);
    }
    for (final review in state.reviews.where((r) => !_seenReviews.contains(r.id))) {
      await notifier.show(
        kind: 'review',
        id: review.id,
        title: describeReview(review),
        body: 'Open to approve, deny or check',
      );
      _raisedReviews.add(review.id);
    }
    for (final id in _raisedRequests.where((id) => !liveRequests.contains(id)).toList()) {
      await notifier.cancel(kind: 'request', id: id);
      _raisedRequests.remove(id);
    }
    for (final id in _raisedReviews.where((id) => !liveReviews.contains(id)).toList()) {
      await notifier.cancel(kind: 'review', id: id);
      _raisedReviews.remove(id);
    }
    // The last document's ids are what a replay is compared against.
    _seenRequests
      ..clear()
      ..addAll(liveRequests);
    _seenReviews
      ..clear()
      ..addAll(liveReviews);
  }
}
