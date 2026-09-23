// The app's trust anchor: the relay's certificate is self-signed and pinned by
// its SubjectPublicKeyInfo SHA-256, the value the parent reads off the pairing
// screen (lib/cert.py's spki_fingerprint, docs/notify.md). There is no CA and no
// name to trust, so pinning is what stops a fake relay on the same network --
// this is the piece the wire layer's URI parser cannot do alone.
//
// Pure functions over the certificate's DER: no sockets here, so they are
// testable against a fixture whose fingerprint the box's own generator printed.
//
// Wiring note: a badCertificateCallback only fires for a certificate the
// platform store would reject, so the client must use a SecurityContext with no
// trusted roots (or check the peer certificate on every connection) for the pin
// to actually decide.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:asn1lib/asn1lib.dart';
import 'package:cryptography/cryptography.dart';

import 'notify_crypto.dart';
import 'relay_client.dart';
import 'relay_transport.dart';
import 'state_model.dart';

/// The SubjectPublicKeyInfo of a certificate's tbsCertificate.
ASN1Sequence _subjectPublicKeyInfo(ASN1Sequence tbs) {
  // tbsCertificate ::= SEQUENCE { [0] version?, serialNumber, signature,
  //   issuer, validity, subject, subjectPublicKeyInfo, ... }
  var index = 0;
  final first = tbs.elements.isNotEmpty ? tbs.elements.first : null;
  if (first is ASN1Object && first.tag == 0xa0) {
    index = 1; // the explicit [0] version
  }
  final spki = tbs.elements[index + 5];
  if (spki is! ASN1Sequence) {
    throw const FormatException('no subjectPublicKeyInfo in the certificate');
  }
  return spki;
}

/// SHA-256 of the certificate's SubjectPublicKeyInfo, lower-case hex — the value
/// a device pins and the parent compares. Matches lib/cert.py byte for byte.
String spkiFingerprintFromDer(List<int> der) {
  final parser = ASN1Parser(Uint8List.fromList(der));
  final certificate = parser.nextObject();
  if (certificate is! ASN1Sequence || certificate.elements.isEmpty) {
    throw const FormatException('not a certificate');
  }
  final tbs = certificate.elements.first;
  if (tbs is! ASN1Sequence) {
    throw const FormatException('no tbsCertificate');
  }
  return sha256Hex(_subjectPublicKeyInfo(tbs).encodedBytes);
}

/// The same, from a PEM certificate (the pairing screen's value is hex).
String spkiFingerprintFromPem(String pem) => spkiFingerprintFromDer(derFromPem(pem));

/// The DER bytes of a PEM certificate (the base64 between the markers).
Uint8List derFromPem(String pem) {
  final body = pem
      .split('\n')
      .where((line) => !line.contains('-----'))
      .join()
      .trim();
  if (body.isEmpty) {
    throw const FormatException('empty PEM');
  }
  return base64.decode(body);
}

/// True when the certificate's SPKI hash equals the pinned one. Hex compare, so
/// a case difference does not defeat the pin.
bool spkiMatches(List<int> der, String pinnedHex) {
  final actual = spkiFingerprintFromDer(der).toLowerCase();
  final want = pinnedHex.replaceAll(':', '').toLowerCase();
  if (actual.length != want.length) {
    return false;
  }
  var diff = 0;
  for (var i = 0; i < actual.length; i++) {
    diff |= actual.codeUnitAt(i) ^ want.codeUnitAt(i);
  }
  return diff == 0;
}

/// An SSE field value: everything after the colon, minus exactly one leading
/// space (the spec strips one, not all -- a value may begin with a space).
String _sseValue(String rest) => rest.startsWith(' ') ? rest.substring(1) : rest;

/// The Server-Sent Events the relay sends (bin/omarchy-kids-relayd): `state`
/// events with a JSON data line, and heartbeat comments. Anything else is
/// ignored, and an event without its terminating blank line is not emitted.
///
/// `sseData` yields the raw data strings (joined, SSE-style, with a single LF);
/// `parseSse` decodes them. Split so the join can be asserted without JSON.
Stream<String> sseData(Stream<String> lines) async* {
  var event = '';
  final data = StringBuffer();
  await for (final line in lines) {
    if (line.isEmpty) {
      if (event == 'state' && data.isNotEmpty) {
        yield data.toString();
      }
      event = '';
      data.clear();
      continue;
    }
    if (line.startsWith(':')) {
      continue; // a heartbeat comment
    }
    if (line.startsWith('event:')) {
      event = _sseValue(line.substring('event:'.length));
    } else if (line.startsWith('data:')) {
      if (data.isNotEmpty) data.write('\n');
      data.write(_sseValue(line.substring('data:'.length)));
    }
  }
}

Stream<Map<String, dynamic>> parseSse(Stream<String> lines) async* {
  await for (final data in sseData(lines)) {
    yield jsonDecode(data) as Map<String, dynamic>;
  }
}

/// The relay beats every 25 seconds (bin/omarchy-kids-relayd's HEARTBEAT); a
/// stream that goes three beats without a line ends, so a half-open connection
/// cannot hang forever.
const Duration relayHeartbeat = Duration(seconds: 25);
const Duration relayQuiet = Duration(seconds: 75);

/// End `lines` with an error after `quiet` of silence. The heartbeat's absence
/// is the only liveness signal on a connection that may be half-open.
Stream<String> withLiveness(Stream<String> lines, Duration quiet) => lines.timeout(
      quiet,
      onTimeout: (sink) => sink.addError(const SocketException('the relay went quiet')),
    );

// --- the client ------------------------------------------------------------

/// The relay client: a TLS connection whose certificate must match the pinned
/// SPKI, and requests signed with the device's Ed25519 key. No retries, no
/// redirects: one box, one pinned certificate.
class KidsRelayClient implements RelayTransport {
  final String host;
  final int port;
  final String pinnedSpki;
  final String deviceId;
  final SimpleKeyPair keyPair;
  final Duration timeout;

  KidsRelayClient({
    required this.host,
    required this.port,
    required this.pinnedSpki,
    required this.deviceId,
    required this.keyPair,
    this.timeout = const Duration(seconds: 10),
  });

  Future<HttpClient> _client() async {
    // No trusted roots: a self-signed certificate always reaches the callback,
    // where the pin decides. A platform-trusted certificate would otherwise
    // bypass the pin for a public hostname.
    final context = SecurityContext(withTrustedRoots: false);
    final client = HttpClient(context: context);
    client.badCertificateCallback = (cert, _, __) => spkiMatches(cert.der, pinnedSpki);
    client.connectionTimeout = timeout;
    return client;
  }

  Future<_Reply> _send({
    required String method,
    required String path,
    required List<int> body,
    required int ts,
    required String nonce,
  }) async {
    final client = await _client();
    try {
      final uri = Uri(scheme: 'https', host: host, port: port, path: path);
      final request = await client.openUrl(method, uri).timeout(timeout);
      // The relay reads Content-Length, never a chunked body, and it never
      // redirects: sign and send exactly one request.
      request.followRedirects = false;
      final headers = await signedHeaders(
        keyPair: keyPair,
        deviceId: deviceId,
        ts: ts,
        nonce: nonce,
        method: method,
        path: path,
        body: body,
      );
      headers.forEach(request.headers.set);
      if (body.isNotEmpty) {
        request.headers.contentType = ContentType.json;
        request.contentLength = body.length;
        request.headers.chunkedTransferEncoding = false;
        request.add(body);
      }
      final response = await request.close().timeout(timeout);
      final text = await utf8.decoder.bind(response).join();
      return _Reply(response.statusCode, text);
    } finally {
      client.close(force: true);
    }
  }

  /// GET /v1/state as a signed read.
  Future<Map<String, dynamic>> state({required int ts, required String nonce}) async {
    final reply = await _send(method: 'GET', path: '/v1/state', body: const [], ts: ts, nonce: nonce);
    if (reply.status != 200) {
      throw HttpException('state: ${reply.status} ${reply.body}');
    }
    return jsonDecode(reply.body) as Map<String, dynamic>;
  }

  /// GET /v1/state, parsed into the app's model.
  @override
  Future<BoxState> boxState({required int ts, required String nonce}) async =>
      BoxState.fromJson(await state(ts: ts, nonce: nonce));

  /// The SSE feed as the app's model.
  @override
  Stream<BoxState> boxEvents({required int ts, required String nonce}) =>
      events(ts: ts, nonce: nonce).map(BoxState.fromJson);

  /// POST /v1/requests/<id>/decision with the signed record.
  @override
  Future<Map<String, dynamic>> decide({
    required Map<String, Object?> record,
    required int ts,
    required String nonce,
  }) async {
    final requestId = record['request_id'] as String;
    final path = '/v1/requests/$requestId/decision';
    final body = utf8.encode(await buildDecisionBody(keyPair: keyPair, record: record));
    final reply = await _send(method: 'POST', path: path, body: body, ts: ts, nonce: nonce);
    if (reply.status != 200) {
      throw HttpException('decide: ${reply.status} ${reply.body}');
    }
    return jsonDecode(reply.body) as Map<String, dynamic>;
  }

  /// Subscribe to /v1/events (SSE): a stream of the decoded `state` events, one
  /// per change, with the heartbeat comments dropped. Authenticated once at
  /// connect, like the relay expects. The relay beats every 25 seconds, so
  /// silence for three beats ends the stream with an error (a half-open
  /// connection would otherwise hang forever); the caller reconnects and re-signs.
  Stream<Map<String, dynamic>> events({required int ts, required String nonce}) async* {
    final client = await _client();
    try {
      final uri = Uri(scheme: 'https', host: host, port: port, path: '/v1/events');
      final request = await client.getUrl(uri).timeout(timeout);
      request.followRedirects = false;
      final headers = await signedHeaders(
        keyPair: keyPair,
        deviceId: deviceId,
        ts: ts,
        nonce: nonce,
        method: 'GET',
        path: '/v1/events',
        body: const [],
      );
      headers.forEach(request.headers.set);
      final response = await request.close().timeout(timeout);
      if (response.statusCode != 200) {
        final text = await utf8.decoder.bind(response).join();
        throw HttpException('events: ${response.statusCode} $text');
      }
      yield* parseSse(withLiveness(
        utf8.decoder.bind(response).transform(const LineSplitter()),
        relayQuiet,
      ));
    } finally {
      client.close(force: true);
    }
  }

  /// POST /v1/pair (pre-auth: the proof is the credential).
  Future<Map<String, dynamic>> pair(String frame) async {
    final client = await _client();
    try {
      final uri = Uri(scheme: 'https', host: host, port: port, path: '/v1/pair');
      final request = await client.postUrl(uri).timeout(timeout);
      request.followRedirects = false;
      final payload = utf8.encode(frame);
      request.headers.contentType = ContentType.json;
      request.contentLength = payload.length;
      request.headers.chunkedTransferEncoding = false;
      request.add(payload);
      final response = await request.close().timeout(timeout);
      final text = await utf8.decoder.bind(response).join();
      if (response.statusCode != 200) {
        throw HttpException('pair: ${response.statusCode} $text');
      }
      return jsonDecode(text) as Map<String, dynamic>;
    } finally {
      client.close(force: true);
    }
  }
}

class _Reply {
  final int status;
  final String body;
  _Reply(this.status, this.body);
}
