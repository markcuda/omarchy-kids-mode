// The app's model of the relay's state document (Appendix H, lib/relay.py's
// build_state): the kids, the open requests and the recently decided ones. The
// box writes it best-effort, so every field is parsed defensively here too -- a
// missing or odd value reads as a safe default rather than crashing the UI, the
// same way the box tolerates a missing source.

/// One kid's live row.
class KidStatus {
  final String kid;
  final int minutesLeft;
  final bool paused;
  final bool live;

  KidStatus({required this.kid, required this.minutesLeft, required this.paused, required this.live});

  /// A kid account's shape (lib/devices.py's RE_KID_ACCOUNT); the app only shows
  /// controls for an account it could name in an ACT.
  static final RegExp accountPattern = RegExp(r'^[a-z_][a-z0-9_-]*$');

  factory KidStatus.fromJson(Map<String, dynamic> json) => KidStatus(
        kid: _clean(json['kid'], 32),
        minutesLeft: _int(json['minutes_left']),
        paused: json['paused'] == true,
        live: json['live'] == true,
      );
}

/// One open request. `minutes` is set only for a `time` request, `askedAt` orders
/// them (the box's `asked_at`).
class OpenRequest {
  final String id;
  final String kid;
  final String kind;
  final String what;
  final int? minutes;
  final int? askedAt;

  OpenRequest({
    required this.id,
    required this.kid,
    required this.kind,
    required this.what,
    this.minutes,
    this.askedAt,
  });

  /// The box's own request-id shape (lib/ask.py's RE_ID, which
  /// lib/notify_watch.py also uses); the app only shows and acts on a request
  /// whose id it could POST back.
  static final RegExp idPattern = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._+@-]{0,127}$');

  factory OpenRequest.fromJson(Map<String, dynamic> json) => OpenRequest(
        id: _clean(json['id'], 128),
        kid: _clean(json['kid'], 32),
        kind: _clean(json['kind'], 32),
        what: _clean(json['what'], 120),
        minutes: json['minutes'] is num ? (json['minutes'] as num).toInt() : null,
        askedAt: json['asked_at'] is int ? json['asked_at'] as int : null,
      );
}

/// One request decided in the last 24 hours, with the outcome.
class RecentDecision extends OpenRequest {
  final String state;

  RecentDecision({
    required super.id,
    required super.kid,
    required super.kind,
    required super.what,
    super.minutes,
    super.askedAt,
    required this.state,
  });

  factory RecentDecision.fromJson(Map<String, dynamic> json) {
    final base = OpenRequest.fromJson(json);
    return RecentDecision(
      id: base.id,
      kid: base.kid,
      kind: base.kind,
      what: base.what,
      minutes: base.minutes,
      askedAt: base.askedAt,
      state: _clean(json['state'], 32),
    );
  }
}

/// One open add-on review (R-NOTIFY-12): an approved app whose surface changed
/// since it was stamped. `was` and `now` are the surface fingerprints the parent
/// compares (the app shows both; Check decides nothing); `now` is "missing" when
/// the desktop file no longer resolves. `id` is the review id the decision names.
class OpenReview {
  final String id;
  final String kid;
  final String app;
  final String was;
  final String now;
  final int? detectedAt;

  OpenReview({
    required this.id,
    required this.kid,
    required this.app,
    required this.was,
    required this.now,
    this.detectedAt,
  });

  /// The box's review-id shape (lib/devices.py's RE_REVIEW_ID, the file name
  /// omarchy-kids-review writes); the app only shows and decides a review whose
  /// id it could POST back.
  static final RegExp idPattern = RegExp(r'^[a-z_][a-z0-9_-]*\.[0-9a-f]{16}$');

  /// What the app may sign as `seen`: a sha256 fingerprint, or the box's own
  /// sentinel for a desktop file that is gone.
  static final RegExp _seenPattern = RegExp(r'^(?:[0-9a-f]{64}|missing)$');

  bool get decidable => _seenPattern.hasMatch(now);

  factory OpenReview.fromJson(Map<String, dynamic> json) => OpenReview(
        id: _clean(json['id'], 128),
        kid: _clean(json['kid'], 32),
        app: _clean(json['app'], 128),
        was: _clean(json['was'], 128),
        now: _clean(json['now'], 128),
        detectedAt: json['detected_at'] is int ? json['detected_at'] as int : null,
      );
}

/// The whole document.
class BoxState {
  final String? generatedAt;
  final List<KidStatus> kids;
  final List<OpenRequest> requests;
  final List<RecentDecision> recent;
  final List<OpenReview> reviews;

  BoxState({
    this.generatedAt,
    required this.kids,
    required this.requests,
    required this.recent,
    this.reviews = const [],
  });

  factory BoxState.fromJson(Map<String, dynamic> json) => BoxState(
        generatedAt: json['generated_at'] is String ? json['generated_at'] as String : null,
        kids: _bounded(_rows(json['kids'])).map(KidStatus.fromJson).toList(),
        requests: _bounded(_rows(json['requests']))
            .map(OpenRequest.fromJson)
            .where((row) => OpenRequest.idPattern.hasMatch(row.id))
            .toList(),
        recent: _bounded(_rows(json['recent']))
            .map(RecentDecision.fromJson)
            .where((row) => OpenRequest.idPattern.hasMatch(row.id))
            .toList(),
        reviews: _bounded(_rows(json['reviews']))
            .map(OpenReview.fromJson)
            .where((row) => OpenReview.idPattern.hasMatch(row.id) && row.decidable)
            .toList(),
      );

  /// The kid rows that are live right now, in the order the box sent them.
  List<KidStatus> get liveKids => kids.where((kid) => kid.live).toList();
}

/// One review in the parent's words: what changed, and that deciding is the
/// parent's call (Check shows this and nothing more).
String describeReview(OpenReview review) {
  final app = review.app.isEmpty ? review.id : review.app;
  if (review.now == 'missing') {
    return '$app is no longer installed';
  }
  return '$app changed since you approved it';
}

/// One request in the parent's words (the notification copy).
String describeRequest(OpenRequest request, String kidName) {
  final who = kidName.isEmpty ? 'Your kid' : kidName;
  if (request.kind == 'time' && request.minutes != null) {
    return '$who asked for ${request.minutes} more minutes';
  }
  final what = request.what.isEmpty ? request.kind : request.what;
  return '$who asked to use $what';
}

int _int(Object? value) => value is num ? value.toInt() : 0;

// A kid or a request value is display data from an unauthenticated source (the
// away envelope), so it is stripped of control/format characters and capped, the
// same cleaning the box's own notifier does (lib/notify_watch.py).
String _clean(Object? value, int limit) {
  if (value is! String) return '';
  final out = StringBuffer();
  for (final rune in value.runes) {
    if (_printable(rune)) out.writeCharCode(rune);
    if (out.length >= limit) break;
  }
  return out.toString();
}

bool _printable(int rune) {
  if (rune == 0x20) return true;
  if (rune < 0x21) return false;
  if (rune == 0x7f || (rune >= 0x80 && rune <= 0x9f)) return false;
  if (rune == 0x00a0) return false;
  if (rune >= 0x2000 && rune <= 0x200f) return false;
  if (rune >= 0x2028 && rune <= 0x202f) return false;
  if (rune >= 0x2060 && rune <= 0x206f) return false;
  if (rune == 0xfeff) return false;
  return true;
}

/// A list of maps, ignoring anything else (the document is best-effort).
List<Map<String, dynamic>> _rows(Object? value) {
  if (value is! List) return [];
  return value.whereType<Map>().map((row) => row.cast<String, dynamic>()).toList();
}

/// No list is unbounded: a hostile document cannot make the app build a huge UI.
List<Map<String, dynamic>> _bounded(List<Map<String, dynamic>> rows) =>
    rows.length > 64 ? rows.sublist(0, 64) : rows;
