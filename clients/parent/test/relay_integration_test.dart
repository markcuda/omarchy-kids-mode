// The Dart client against the box's real relay: start bin/omarchy-kids-relayd
// (python) with a throwaway certificate, pin it, and make a signed read. This is
// the end-to-end proof of the transport -- TLS, the pin, the signed headers -- and
// it skips where python3 or python-cryptography is absent.

import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:test/test.dart';

import '../lib/relay_client.dart';
import '../lib/transport.dart';

void main() {
  final repo = Directory.current.parent.parent.path; // clients/parent -> repo root
  final hasPython = _runs('python3', ['-c', 'import cryptography']);

  test('a pinned client reads the state from the real relay', () async {
    final tmp = Directory.systemTemp.createTempSync('kids-relay-integration-');
    Process? relay;
    try {
      // A throwaway certificate and key from the box's own generator (not committed).
      final cert = '${tmp.path}/cert.pem';
      final key = '${tmp.path}/key.pem';
      final minted = Process.runSync('python3', ['$repo/lib/cert.py', cert, key, '--host', '127.0.0.1']);
      expect(minted.exitCode, 0, reason: minted.stderr.toString());

      // The device this test is: an Ed25519 key the relay will verify against.
      final deviceId = 'd-it';
      final deviceKey = await Ed25519().newKeyPair();
      final signPub = base64.encode((await deviceKey.extractPublicKey()).bytes);
      File('${tmp.path}/devices.json').writeAsStringSync(jsonEncode([
        {
          'id': deviceId,
          'name': 'Integration',
          'platform': 'linux',
          'scopes': ['decide'],
          'sign_pub': signPub,
          'box_pub': signPub,
        }
      ]));
      File('${tmp.path}/status.json').writeAsStringSync('{"generated_at":"x","kids":[]}');
      Directory('${tmp.path}/queue').createSync();

      final port = await _freePort();
      relay = await Process.start('python3', [
        '$repo/bin/omarchy-kids-relayd',
        '--bind', '127.0.0.1',
        '--port', '$port',
        '--cert', cert,
        '--key', key,
        '--devices-json', '${tmp.path}/devices.json',
        '--status', '${tmp.path}/status.json',
        '--queue', '${tmp.path}/queue',
        '--auth-sock', '${tmp.path}/auth.sock',
        '--nonce-ledger', '${tmp.path}/nonces.json',
        '--share', '$repo/share',
        '--lib', '$repo/lib',
      ]);
      relay.stderr.drain<void>();
      expect(await _waitForPort(port), isTrue, reason: 'the relay never listened');

      final pin = spkiFingerprintFromPem(File(cert).readAsStringSync());
      final client = KidsRelayClient(
        host: '127.0.0.1',
        port: port,
        pinnedSpki: pin,
        deviceId: deviceId,
        keyPair: deviceKey,
      );
      final state = await client.state(ts: _now(), nonce: 'it-1');
      expect(state.containsKey('kids'), isTrue);
      expect(state['kids'], isEmpty);
      // The same document through the app's model.
      final model = await client.boxState(ts: _now(), nonce: 'it-model');
      expect(model.kids, isEmpty);
      expect(model.requests, isEmpty);

      // The SSE stream sends the state as soon as it connects; the heartbeat
      // comments are dropped by the parser.
      final first = await client
          .events(ts: _now(), nonce: 'it-events')
          .first
          .timeout(const Duration(seconds: 10));
      expect(first.containsKey('kids'), isTrue);
      expect(first['kids'], isEmpty);

      // A POST reaches the relay's forwarding step: the signature verifies (a
      // framing or signature error would be 400/403), and only authd is missing,
      // so the relay answers 502. This is what would have caught a chunked body.
      Future<void> expectReachesAuthd(Future<Object?> call) async {
        try {
          await call;
          fail('the relay answered, but authd is not running');
        } on HttpException catch (e) {
          expect(e.message, contains('502'), reason: 'expected the relay to forward, got ${e.message}');
        }
      }

      await expectReachesAuthd(client.decide(
        record: {
          'device_id': deviceId,
          'request_id': 'req-it',
          'decision': 'approve',
          'kid': 'kid-ada',
          'kind': 'time',
          'what': '15',
          'minutes': 15,
          'ts': _now(),
          'nonce': 'it-decide',
        },
        ts: _now(),
        nonce: 'it-decide',
      ));
      // An ACT reaches the relay's forwarding step too: the path is
      // /v1/kids/<account>/<action> and the record passes the relay's own shape
      // checks, so only the missing authd (502) stands in the way. This pins the
      // path the app builds against the real relay.
      await expectReachesAuthd(client.act(
        record: {
          'device_id': deviceId,
          'account': 'kid-ada',
          'action': 'grant',
          'minutes': 15,
          'ts': _now(),
          'nonce': 'it-act',
        },
        ts: _now(),
        nonce: 'it-act',
      ));
      await expectReachesAuthd(client.act(
        record: {
          'device_id': deviceId,
          'account': 'kid-ada',
          'action': 'end',
          'ts': _now(),
          'nonce': 'it-act-end',
        },
        ts: _now(),
        nonce: 'it-act-end',
      ));
      // The relay refuses an end that carries minutes before it forwards (400,
      // not 502): a hand-built record, since the app's own builder forbids it.
      await expectLater(
        client.act(
          record: {
            'device_id': deviceId,
            'account': 'kid-ada',
            'action': 'end',
            'minutes': 15,
            'ts': _now(),
            'nonce': 'it-act-bad',
          },
          ts: _now(),
          nonce: 'it-act-bad',
        ),
        throwsA(predicate((e) => e.toString().contains('400'))),
      );
      await expectReachesAuthd(client.pair(await _pairFrame(deviceId, deviceKey, cert)));

      // A different pin must not be accepted: the self-signed certificate the
      // relay presents is exactly what the pin decides.
      final wrong = KidsRelayClient(
        host: '127.0.0.1',
        port: port,
        pinnedSpki: '00' * 32,
        deviceId: deviceId,
        keyPair: deviceKey,
      );
      await expectLater(wrong.state(ts: _now(), nonce: 'it-2'), throwsA(anything));
    } finally {
      relay?.kill();
      await relay?.exitCode;
      tmp.deleteSync(recursive: true);
    }
  }, skip: hasPython ? false : 'python3 or python-cryptography not installed');
}

/// A pairing frame for the test: the token never travels, only the proof.
Future<String> _pairFrame(String deviceId, SimpleKeyPair key, String certPath) async {
  final token = 'ab' * 20; // 40 hex characters
  final signPub = base64.encode((await key.extractPublicKey()).bytes);
  return buildPairFrame(
    id: deviceId,
    name: 'Integration',
    platform: 'linux',
    tokenHex: token,
    signPub: signPub,
    boxPub: signPub,
  );
}

int _now() => DateTime.now().millisecondsSinceEpoch ~/ 1000;

bool _runs(String exe, List<String> args) {
  try {
    return Process.runSync(exe, args).exitCode == 0;
  } on ProcessException {
    return false;
  }
}

Future<int> _freePort() async {
  final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = socket.port;
  await socket.close();
  return port;
}

Future<bool> _waitForPort(int port) async {
  for (var i = 0; i < 50; i++) {
    try {
      final socket = await Socket.connect('127.0.0.1', port, timeout: const Duration(milliseconds: 200));
      socket.destroy();
      return true;
    } on SocketException {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }
  return false;
}
