// Pairing, as the parent does it: paste the code the computer printed, type the
// fingerprint it showed, compare, and pair. The screen never pairs on its own and
// never hides the fingerprint -- the parent confirms it (I-6).

import 'package:flutter/material.dart';
import 'package:omarchy_kids_parent/app_link.dart';
import 'package:omarchy_kids_parent/pairing.dart';
import 'package:omarchy_kids_parent/relay_client.dart';
import 'package:omarchy_kids_parent/session.dart';

import 'app_root.dart';

class PairingScreen extends StatefulWidget {
  final Keystore keystore;
  final TransportFactory connect;
  final String name;
  final String platform;
  final String? storageNote;
  final String? bootError;

  /// Offered only when boot failed: clear a stored key the app cannot read and
  /// pair afresh. Null when there is nothing to recover from.
  final Future<void> Function()? onResetKeys;
  final void Function(PairingResult) onPaired;

  const PairingScreen({
    super.key,
    required this.keystore,
    required this.connect,
    required this.name,
    required this.platform,
    required this.onPaired,
    this.storageNote,
    this.bootError,
    this.onResetKeys,
  });

  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen> {
  final _uri = TextEditingController();
  final _fingerprint = TextEditingController();
  PairingUri? _parsed;
  String? _pin;
  ({String host, int port})? _where;
  bool _confirming = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _uri.dispose();
    _fingerprint.dispose();
    super.dispose();
  }

  /// Read what was pasted and typed; show the confirmation, or say what is wrong.
  void _review() {
    setState(() {
      _error = null;
      final raw = extractPairingUri(_uri.text);
      if (raw == null) {
        _error = 'Paste the whole code from the computer (it starts with omarchy-kids://pair).';
        return;
      }
      final PairingUri uri;
      try {
        uri = PairingUri.parse(raw);
      } on FormatException catch (error) {
        _error = "That code isn't one this app can use: ${error.message}";
        return;
      }
      final pin = normalizeFingerprint(_fingerprint.text);
      if (pin == null) {
        _error = 'Type the 64-character fingerprint the computer showed.';
        return;
      }
      final where = pairingAddresses(uri.addresses);
      if (where.isEmpty) {
        _error = "That code doesn't say where the computer is.";
        return;
      }
      _parsed = uri;
      _pin = pin;
      _where = where.first;
      _confirming = true;
    });
  }

  Future<void> _pair() async {
    final uri = _parsed;
    final pin = _pin;
    final where = _where;
    if (uri == null || pin == null || where == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final keyPair = await loadSignKeyPair(widget.keystore);
      final relay = widget.connect(
        host: where.host,
        port: where.port,
        pin: pin,
        deviceId: uri.id,
        keyPair: keyPair,
      );
      final result = await pairWithBox(
        uri: uri,
        name: widget.name,
        platform: widget.platform,
        keystore: widget.keystore,
        relay: relay,
      );
      if (mounted) widget.onPaired(result);
    } catch (error) {
      setState(() {
        _busy = false;
        _error = "Pairing didn't work: $error";
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Pair with the computer')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (widget.bootError != null) ...[
              _Error(text: widget.bootError!),
              const SizedBox(height: 16),
            ],
            if (!_confirming) ..._ask() else ..._confirm(),
          ],
        ),
      );

  List<Widget> _ask() => [
        const Text('1. On the computer, run:  sudo omarchy-kids-notify pair --apply'),
        const SizedBox(height: 8),
        TextField(
          controller: _uri,
          minLines: 2,
          maxLines: 4,
          enabled: !_busy,
          autocorrect: false,
          decoration: const InputDecoration(
            labelText: 'Paste the omarchy-kids://pair code',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        const Text('2. Type the fingerprint the computer showed'),
        const SizedBox(height: 8),
        TextField(
          controller: _fingerprint,
          enabled: !_busy,
          autocorrect: false,
          decoration: const InputDecoration(
            labelText: 'Fingerprint (64 hex characters)',
            border: OutlineInputBorder(),
          ),
        ),
        if (_error != null) ...[const SizedBox(height: 16), _Error(text: _error!)],
        const SizedBox(height: 24),
        FilledButton(onPressed: _busy ? null : _review, child: const Text('Continue')),
        if (widget.storageNote != null) ...[
          const SizedBox(height: 16),
          Text(widget.storageNote!, style: Theme.of(context).textTheme.bodySmall),
        ],
        if (widget.onResetKeys != null) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: _busy ? null : _confirmReset,
              child: const Text('Trouble? Reset this device'),
            ),
          ),
        ],
      ];

  /// Ask, then clear this device's keys and pairing. The box keeps the old device
  /// record until the parent revokes it there.
  Future<void> _confirmReset() async {
    final reset = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset this device?'),
        content: const Text(
          'This clears the keys this device made and its pairing. The computer keeps the old '
          'device until you revoke it there, and this device will pair again as a new one.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Reset')),
        ],
      ),
    );
    if (reset == true) {
      await widget.onResetKeys!();
      if (mounted) {
        setState(() {
          _confirming = false;
          _error = null;
        });
      }
    }
  }

  List<Widget> _confirm() {
    final pin = _pin!;
    final where = _where!;
    return [
      const Text('Check the fingerprint against the computer. If it is different, stop.'),
      const SizedBox(height: 12),
      SelectableText(
        pin,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 16),
      ),
      const SizedBox(height: 12),
      Text('It will reach the computer at ${where.host}:${where.port}.'),
      if (_error != null) ...[const SizedBox(height: 16), _Error(text: _error!)],
      const SizedBox(height: 24),
      FilledButton(onPressed: _busy ? null : _pair, child: const Text('Pair')),
      const SizedBox(height: 8),
      TextButton(
        onPressed: _busy
            ? null
            : () => setState(() {
                  _confirming = false;
                  _error = null;
                }),
        child: const Text('Back'),
      ),
    ];
  }
}

class _Error extends StatelessWidget {
  final String text;
  const _Error({required this.text});
  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      );
}
