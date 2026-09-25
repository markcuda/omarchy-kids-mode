// The app's controller: it ties the relay, the device key and the state model
// together so the UI is a thin layer. The transport and the clock/nonce are
// injectable, so the decision flow is unit-tested without a network or a real box.

import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

import 'relay_client.dart';
import 'relay_transport.dart';
import 'state_model.dart';

/// Where the device's signing seed lives. A Flutter build would store it in the
/// platform keystore; a test uses [InMemoryKeystore]. Only the seed is secret;
/// the device id and the pinned fingerprint are not.
abstract class Keystore {
  Future<List<int>?> loadSignSeed();
  Future<void> saveSignSeed(List<int> seed);

  /// The device's X25519 box key seed (the away envelope's recipient key).
  Future<List<int>?> loadBoxSeed();
  Future<void> saveBoxSeed(List<int> seed);

  /// The pairing result, as JSON: {deviceId, pin, addresses}.
  Future<String?> loadPaired();
  Future<void> savePaired(String json);

  /// Forget the paired box on this device. The box keeps its own record of the
  /// device until the parent revokes it there; this only clears the local pin,
  /// the address and the device id, so the app can pair again (a box that
  /// re-keyed has a pin this app can no longer match).
  Future<void> clearPaired();

  /// Forget everything this device remembers: the paired box and the device's
  /// own keys. This is the escape from a stored key that can no longer be read
  /// (an item restored from another device, say). The box still holds the old
  /// device record until the parent revokes it there, and this device pairs
  /// again as a new one.
  Future<void> reset();
}

class InMemoryKeystore implements Keystore {
  List<int>? _signSeed;
  List<int>? _boxSeed;
  String? _paired;
  InMemoryKeystore([this._signSeed]);
  @override
  Future<List<int>?> loadSignSeed() async => _signSeed;
  @override
  Future<void> saveSignSeed(List<int> seed) async => _signSeed = seed;
  @override
  Future<List<int>?> loadBoxSeed() async => _boxSeed;
  @override
  Future<void> saveBoxSeed(List<int> seed) async => _boxSeed = seed;
  @override
  Future<String?> loadPaired() async => _paired;
  @override
  Future<void> savePaired(String json) async => _paired = json;
  @override
  Future<void> clearPaired() async => _paired = null;
  @override
  Future<void> reset() async {
    _signSeed = null;
    _boxSeed = null;
    _paired = null;
  }
}

/// The parent's session: one device key, one pinned box, and the actions the UI
/// offers. It never decides anything itself -- it signs what the parent chose and
/// the box verifies and applies it.
class Session {
  final String deviceId;
  final SimpleKeyPair keyPair;
  final RelayTransport relay;
  final int Function() now;
  final String Function() newNonce;

  Session({
    required this.deviceId,
    required this.keyPair,
    required this.relay,
    int Function()? now,
    String Function()? newNonce,
  })  : now = now ?? (() => DateTime.now().millisecondsSinceEpoch ~/ 1000),
        newNonce = newNonce ?? _randomNonce;

  /// A session whose device key comes from the keystore, generating one the
  /// first time (the app's first run).
  static Future<Session> load({
    required String deviceId,
    required RelayTransport relay,
    required Keystore keystore,
    int Function()? now,
    String Function()? newNonce,
  }) async {
    final keyPair = await loadSignKeyPair(keystore);
    return Session(
      deviceId: deviceId,
      keyPair: keyPair,
      relay: relay,
      now: now,
      newNonce: newNonce,
    );
  }

  Future<BoxState> refresh() => relay.boxState(ts: now(), nonce: newNonce());

  /// Watch the box for changes, signed with a fresh timestamp and nonce at each
  /// call. The transport's stream is handed straight to the listener: a dropped
  /// connection, the liveness timeout, or a clean close all reach the UI as they
  /// happen, with nothing in between to swallow them.
  Stream<BoxState> watch() => relay.boxEvents(ts: now(), nonce: newNonce());

  /// Approve a request, optionally with the parent's own reply line. The request
  /// itself is signed (its kid, type, what and minutes), so the decision binds
  /// the exact record the screen showed (amendment section 20).
  Future<void> approve(OpenRequest request, {String? reply}) => _decide(request, 'approve', reply);

  /// Decline a request, optionally with a reply (a reason the box shows the kid).
  Future<void> decline(OpenRequest request, {String? reply}) => _decide(request, 'decline', reply);

  /// Give a kid more time today (R-NOTIFY-13). The box applies it through
  /// omarchy-kids-time; nothing else changes.
  Future<void> grantTime(String kid, int minutes) => _act(kid, 'grant', minutes);

  /// End a kid's session now. The box applies it through omarchy-kids-exit.
  Future<void> endSession(String kid) => _act(kid, 'end', null);

  /// Approve a changed add-on's new surface (R-NOTIFY-12). `seen` is the review's
  /// own `now`; the box refuses it if the surface moved since the app looked.
  Future<void> approveReview(String reviewId, String seen) => _decideReview(reviewId, 'approve', seen);

  /// Deny a changed add-on: the box hides the app again and clears the review.
  Future<void> denyReview(String reviewId, String seen) => _decideReview(reviewId, 'deny', seen);

  Future<void> _decide(OpenRequest request, String decision, String? reply) async {
    // Fail fast on an id the box would refuse anyway: it is not a request the app
    // could decide, and it must not reach a URL path (state_model drops such rows).
    if (!OpenRequest.idPattern.hasMatch(request.id)) {
      throw ArgumentError('not a request id: ${request.id}');
    }
    // The record's nonce and the request header's nonce are separate replay
    // domains (authd's ledger and the relay's); both are fresh.
    final ts = now();
    final record = decisionRecord(
      deviceId: deviceId,
      requestId: request.id,
      decision: decision,
      ts: ts,
      nonce: newNonce(),
      reply: reply,
      kid: request.kid,
      kind: request.kind,
      what: request.what,
      minutes: request.minutes,
    );
    await relay.decide(record: record, ts: ts, nonce: newNonce());
  }

  Future<void> _act(String kid, String action, int? minutes) async {
    if (!KidStatus.accountPattern.hasMatch(kid)) {
      throw ArgumentError('not a kid account: $kid');
    }
    final ts = now();
    final record = actRecord(
      deviceId: deviceId,
      account: kid,
      action: action,
      minutes: minutes,
      ts: ts,
      nonce: newNonce(),
    );
    await relay.act(record: record, ts: ts, nonce: newNonce());
  }

  Future<void> _decideReview(String reviewId, String decision, String seen) async {
    // Fail fast on an id the box would refuse anyway: it must not reach a URL path.
    if (!OpenReview.idPattern.hasMatch(reviewId)) {
      throw ArgumentError('not a review id: $reviewId');
    }
    final ts = now();
    final record = reviewDecisionRecord(
      deviceId: deviceId,
      reviewId: reviewId,
      decision: decision,
      seen: seen,
      ts: ts,
      nonce: newNonce(),
    );
    await relay.decideReview(record: record, ts: ts, nonce: newNonce());
  }

  /// The device's signing public key, base64 (what the pairing frame sends).
  Future<String> get signPub async =>
      base64.encode((await keyPair.extractPublicKey()).bytes);
}

final Random _random = Random.secure();

/// The device's signing key pair: from the keystore, or generated once and
/// saved. The pairing screen and the session both use this, so the key the box
/// is told about and the key the session signs with are always the same one.
Future<SimpleKeyPair> loadSignKeyPair(Keystore keystore) async {
  var seed = await keystore.loadSignSeed();
  if (seed == null) {
    seed = _randomSeed();
    await keystore.saveSignSeed(seed);
  }
  return Ed25519().newKeyPairFromSeed(seed);
}

List<int> _randomSeed() => List<int>.generate(32, (_) => _random.nextInt(256));

String _randomNonce() {
  final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}
