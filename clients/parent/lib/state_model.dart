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

  factory KidStatus.fromJson(Map<String, dynamic> json) => KidStatus(
        kid: _string(json['kid']),
        minutesLeft: _int(json['minutes_left']),
        paused: json['paused'] == true,
        live: json['live'] == true,
      );
}

/// One open request. `minutes` is set only for a `time` request.
class OpenRequest {
  final String id;
  final String kid;
  final String kind;
  final String what;
  final int? minutes;

  OpenRequest({required this.id, required this.kid, required this.kind, required this.what, this.minutes});

  factory OpenRequest.fromJson(Map<String, dynamic> json) => OpenRequest(
        id: _string(json['id']),
        kid: _string(json['kid']),
        kind: _string(json['kind']),
        what: _string(json['what']),
        minutes: json['minutes'] is num ? (json['minutes'] as num).toInt() : null,
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
      state: _string(json['state']),
    );
  }
}

/// The whole document.
class BoxState {
  final String? generatedAt;
  final List<KidStatus> kids;
  final List<OpenRequest> requests;
  final List<RecentDecision> recent;

  BoxState({this.generatedAt, required this.kids, required this.requests, required this.recent});

  factory BoxState.fromJson(Map<String, dynamic> json) => BoxState(
        generatedAt: json['generated_at'] is String ? json['generated_at'] as String : null,
        kids: _rows(json['kids']).map(KidStatus.fromJson).toList(),
        requests: _rows(json['requests']).map(OpenRequest.fromJson).toList(),
        recent: _rows(json['recent']).map(RecentDecision.fromJson).toList(),
      );

  /// The kid rows that are live right now, in the order the box sent them.
  List<KidStatus> get liveKids => kids.where((kid) => kid.live).toList();
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

String _string(Object? value) => value is String ? value : '';
int _int(Object? value) => value is num ? value.toInt() : 0;

/// A list of maps, ignoring anything else (the document is best-effort).
List<Map<String, dynamic>> _rows(Object? value) {
  if (value is! List) return [];
  return value.whereType<Map>().map((row) => row.cast<String, dynamic>()).toList();
}
