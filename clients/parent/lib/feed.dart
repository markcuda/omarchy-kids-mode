// What the app raises as a notification, and what it clears (R-NOTIFY-14).
//
// The feed carries the whole document on every `state` event, so "new" is a diff
// against what this run has already raised, never against a fresh baseline: a
// request that arrived while the connection was down and the process alive is
// new and is raised once. Pure functions, so the rule is tested without a phone.

import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import 'state_model.dart';

/// The requests in `next` whose id this run has not seen yet.
List<OpenRequest> newRequests(Set<String> seen, BoxState next) =>
    next.requests.where((request) => !seen.contains(request.id)).toList();

/// The reviews in `next` whose id this run has not seen yet.
List<OpenReview> newReviews(Set<String> seen, BoxState next) =>
    next.reviews.where((review) => !seen.contains(review.id)).toList();

/// The request ids the document currently carries.
Set<String> liveRequestIds(BoxState state) => state.requests.map((r) => r.id).toSet();

/// The review ids the document currently carries.
Set<String> liveReviewIds(BoxState state) => state.reviews.map((r) => r.id).toSet();

/// The platform notification id for one row: the first four bytes of
/// `sha256("<kind>:<id>")` masked to a non-negative 31-bit integer. Derived, so
/// the same row always lands on the same id and a repost replaces rather than
/// stacks; the kind is in the hash, so a request and a review can never collide.
Future<int> platformNotificationId(String kind, String id) async {
  final hash = await Sha256().hash(utf8.encode('$kind:$id'));
  final bytes = hash.bytes;
  return ((bytes[0] << 24) | (bytes[1] << 16) | (bytes[2] << 8) | bytes[3]) & 0x7fffffff;
}
