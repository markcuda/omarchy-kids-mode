// The link between the box's screen and the pairing screen (N-8): pulling the URI
// out of a terminal paste, accepting a fingerprint typed with spaces or colons,
// and turning bare addresses into host + port.

import 'package:omarchy_kids_parent/app_link.dart';
import 'package:test/test.dart';

void main() {
  final token = 'a' * 40;

  test('a pairing URI is found in a whole terminal line', () {
    final line = 'omarchy-kids://pair?v=1&id=dev-1&token=$token&addr=192.168.1.5,100.64.0.2';
    expect(extractPairingUri(line), line);
  });

  test('a URI is found among quotes, noise and newlines', () {
    final uri = 'omarchy-kids://pair?v=1&id=dev-1&token=$token&addr=192.168.1.5';
    final pasted = 'scan this:\n  "$uri"\n  fingerprint: ${'ab' * 32}';
    expect(extractPairingUri(pasted), uri);
  });

  test('the URI stops before the shell brackets around it', () {
    final uri = 'omarchy-kids://pair?v=1&id=dev-1&token=$token&addr=192.168.1.5';
    expect(extractPairingUri('  $uri  '), uri);
    expect(extractPairingUri('copy this: ($uri)'), uri);
    expect(extractPairingUri('`$uri`'), uri);
    expect(extractPairingUri('<$uri>'), uri);
  });

  test('no URI is null, not a wrong guess', () {
    expect(extractPairingUri('fingerprint: ${'ab' * 32}'), isNull);
    expect(extractPairingUri(''), isNull);
  });

  test('a fingerprint is accepted with spaces, colons and capitals', () {
    final lower = 'abcd' * 16;
    expect(normalizeFingerprint('ABCD:' * 16), lower);
    expect(normalizeFingerprint(List.filled(32, 'cd').join(':')), 'cd' * 32);
    expect(normalizeFingerprint(List.filled(64, 'a').join(' ')), 'a' * 64);
    expect(normalizeFingerprint('  $lower\n'), lower);
  });

  test('a fingerprint that is not 64 hex is null', () {
    expect(normalizeFingerprint('nope'), isNull);
    expect(normalizeFingerprint('ab' * 31), isNull);
    expect(normalizeFingerprint('ab' * 33), isNull);
    expect(normalizeFingerprint('zz' * 32), isNull);
  });

  test('a bare address takes the box port, and the order is kept', () {
    final parsed = pairingAddresses(const ['192.168.1.5', '100.64.0.2']);
    expect(parsed, [(host: '192.168.1.5', port: 8447), (host: '100.64.0.2', port: 8447)]);
  });

  test('an explicit port is read, and a bracketed IPv6 literal works', () {
    expect(parseAddress('192.168.1.5:9443'), (host: '192.168.1.5', port: 9443));
    expect(parseAddress('[fd00::2]'), (host: 'fd00::2', port: 8447));
    expect(parseAddress('[fd00::2]:9443'), (host: 'fd00::2', port: 9443));
  });

  test('a bad address is dropped, not guessed at', () {
    expect(parseAddress(''), isNull);
    expect(parseAddress(':8447'), isNull);
    expect(parseAddress('fd00::2'), isNull, reason: 'an unbracketed IPv6 port is ambiguous');
    expect(parseAddress('[fd00::2]x'), isNull);
    expect(parseAddress('host:0'), isNull);
    expect(parseAddress('host:70000'), isNull);
    expect(pairingAddresses(const ['192.168.1.5', 'nope::', '']), [(host: '192.168.1.5', port: 8447)]);
  });
}
