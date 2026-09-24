// The link between what the box prints and what the app needs (N-8): the pairing
// URI rides inside whatever the parent copied from the terminal, the addresses
// are bare hosts, and the fingerprint is what they read off the box's screen.
// Parsing lives here, in the package, so it is unit-tested without a UI.

/// The relay's port, fixed by the box (bin/omarchy-kids-notify: PORT=8447). The
/// pairing URI's `addr=` values are bare hosts, so this fills the port in.
const int defaultRelayPort = 8447;

// The URI as the box prints it, stopping at whitespace or the shell's or a
// terminal's quotes and brackets.
final RegExp _pairingUri = RegExp(r'''omarchy-kids://pair\?[^\s"'`<>()]+''');

final RegExp _fingerprint = RegExp(r'^[0-9a-fA-F]{64}$');

/// The first pairing URI in pasted text (a whole terminal line, a quoted string,
/// a multi-line paste), or null if there is none.
String? extractPairingUri(String text) => _pairingUri.firstMatch(text)?.group(0);

/// A fingerprint as a parent may type it (upper case, spaces or colons between
/// bytes) normalized to the 64 lower-case hex the pin holds, or null.
String? normalizeFingerprint(String input) {
  final cleaned = input.replaceAll(RegExp(r'[\s:]+'), '');
  if (!_fingerprint.hasMatch(cleaned)) return null;
  return cleaned.toLowerCase();
}

/// The box's addresses as host + port, in the order it listed them. A bare
/// address takes [defaultPort]; `host:port` is read as written; IPv6 must be
/// bracketed as `[::1]` or `[::1]:port`. Anything else is dropped rather than
/// guessed at. The app dials the first today; trying the rest is still to come.
List<({String host, int port})> pairingAddresses(
  List<String> addresses, {
  int defaultPort = defaultRelayPort,
}) {
  final out = <({String host, int port})>[];
  for (final raw in addresses) {
    final parsed = parseAddress(raw, defaultPort: defaultPort);
    if (parsed != null) out.add(parsed);
  }
  return out;
}

/// One address, or null if it is not a host the client can dial.
({String host, int port})? parseAddress(String raw, {int defaultPort = defaultRelayPort}) {
  final value = raw.trim();
  if (value.isEmpty) return null;
  String host;
  String? portText;
  if (value.startsWith('[')) {
    final end = value.indexOf(']');
    if (end <= 1) return null;
    host = value.substring(1, end);
    final rest = value.substring(end + 1);
    if (rest.isEmpty) {
      portText = null;
    } else if (rest.startsWith(':')) {
      portText = rest.substring(1);
    } else {
      return null;
    }
  } else {
    final colons = ':'.allMatches(value).length;
    if (colons == 0) {
      host = value;
    } else if (colons == 1) {
      final split = value.lastIndexOf(':');
      host = value.substring(0, split);
      portText = value.substring(split + 1);
    } else {
      // An unbracketed IPv6 literal: the port would be ambiguous.
      return null;
    }
  }
  if (host.isEmpty) return null;
  if (portText == null) return (host: host, port: defaultPort);
  final port = int.tryParse(portText);
  if (port == null || port < 1 || port > 65535) return null;
  return (host: host, port: port);
}
