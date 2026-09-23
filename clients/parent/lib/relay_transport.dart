// What the session needs from the box, so its decision flow is testable without a
// network. KidsRelayClient implements it against the real relay; a test fakes it.

import 'state_model.dart';

abstract class RelayTransport {
  Future<BoxState> boxState({required int ts, required String nonce});
  Stream<BoxState> boxEvents({required int ts, required String nonce});
  Future<Map<String, dynamic>> decide({
    required Map<String, Object?> record,
    required int ts,
    required String nonce,
  });
  Future<Map<String, dynamic>> pair(String frame);
}
