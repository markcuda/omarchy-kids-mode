// What the session needs from the box, so its decision flow is testable without a
// network. KidsRelayClient implements it against the real relay; a test fakes it.

import 'state_model.dart';

abstract class RelayTransport {
  /// The SPKI fingerprint this transport pins — the value the parent compared.
  String get pinnedFingerprint;

  Future<BoxState> boxState({required int ts, required String nonce});
  Stream<BoxState> boxEvents({required int ts, required String nonce});
  Future<Map<String, dynamic>> decide({
    required Map<String, Object?> record,
    required int ts,
    required String nonce,
  });

  /// POST a signed ACT (R-NOTIFY-13): a grant or an end. `record` is what
  /// [actRecord] builds; its `account` and `action` are the path.
  Future<Map<String, dynamic>> act({
    required Map<String, Object?> record,
    required int ts,
    required String nonce,
  });

  /// POST a signed review decision (R-NOTIFY-12). `record` is the review record
  /// [reviewDecisionRecord] builds; its `review_id` is the path segment.
  Future<Map<String, dynamic>> decideReview({
    required Map<String, Object?> record,
    required int ts,
    required String nonce,
  });
  Future<Map<String, dynamic>> pair(String frame);
}
