// The app's root: it opens the remembered pairing, or asks for one (N-8). The
// keystore and the transport factory are injected, so the whole boot -- paired or
// not -- is widget-tested without a box.

import 'package:flutter/material.dart';
import 'package:cryptography/cryptography.dart';
import 'package:omarchy_kids_parent/app_link.dart';
import 'package:omarchy_kids_parent/pairing.dart';
import 'package:omarchy_kids_parent/relay_transport.dart';
import 'package:omarchy_kids_parent/session.dart';

import 'main.dart';
import 'notifier.dart';
import 'pairing_screen.dart';

/// Builds the client for one box address, pinned to the fingerprint the parent
/// compared, carrying the device's identity and signing key. The app passes
/// KidsRelayClient; a test passes a fake.
typedef TransportFactory = RelayTransport Function({
  required String host,
  required int port,
  required String pin,
  required String deviceId,
  required SimpleKeyPair keyPair,
});

/// The app: one keystore, one pinned box, and the actions the parent's screen
/// offers. It holds no UI of its own beyond choosing between pairing and home.
class AppRoot extends StatefulWidget {
  final Keystore keystore;
  final TransportFactory connect;
  final String name;
  final String platform;

  /// The app's notifications (R-NOTIFY-14), or null where a test does not care.
  final Notifier? notifier;

  /// The honest note about what notifications do here (R-NOTIFY-14.2), or null.
  final String? noticeNote;

  /// An honest note about where the pairing is kept, for a build that fell back
  /// to memory because the system keystore was not usable.
  final String? storageNote;

  const AppRoot({
    super.key,
    required this.keystore,
    required this.connect,
    required this.name,
    required this.platform,
    this.notifier,
    this.noticeNote,
    this.storageNote,
  });

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  Session? _session;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    // Every keystore read is inside the guard: a store that cannot answer at all
    // must land on the pairing screen with the reset offered, never on a spinner.
    try {
      final paired = PairingResult.decode(await widget.keystore.loadPaired());
      if (paired == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      final where = pairingAddresses(paired.addresses);
      if (where.isEmpty) {
        if (mounted) {
          setState(() {
            _loading = false;
            _error = 'the paired computer gave no address to reach it at';
          });
        }
        return;
      }
      final keyPair = await loadSignKeyPair(widget.keystore);
      final relay = widget.connect(
        host: where.first.host,
        port: where.first.port,
        pin: paired.pin,
        deviceId: paired.deviceId,
        keyPair: keyPair,
      );
      final session = Session(
        deviceId: paired.deviceId,
        keyPair: keyPair,
        relay: relay,
      );
      if (!mounted) return;
      setState(() {
        _session = session;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = "Couldn't open the session: $error";
      });
    }
  }

  /// Forget the paired box on this device and go back to pairing. The box keeps
  /// its own record until the parent revokes the device there.
  Future<void> _forget() async {
    // The platform keeps notifications after the process dies; a forgotten box
    // must not leave its rows on the shade (R-NOTIFY-14.4).
    await widget.notifier?.cancelAll();
    await widget.keystore.clearPaired();
    if (!mounted) return;
    setState(() => _session = null);
    await _boot();
  }

  /// The escape from a stored key the app can no longer read: clear the seeds and
  /// the pairing, so this device pairs again as a new one.
  Future<void> _resetKeys() async {
    await widget.notifier?.cancelAll();
    await widget.keystore.reset();
    if (!mounted) return;
    setState(() => _session = null);
    await _boot();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final session = _session;
    if (session != null) {
      return HomeScreen(
        session: session,
        notifier: widget.notifier,
        noticeNote: widget.noticeNote,
        onForget: _forget,
      );
    }
    return PairingScreen(
      keystore: widget.keystore,
      connect: widget.connect,
      name: widget.name,
      platform: widget.platform,
      storageNote: widget.storageNote,
      noticeNote: widget.noticeNote,
      bootError: _error,
      // Always offered here: this is the only screen a parent reaches when the
      // app cannot read a stored key, whether that failed at boot (a bad paired
      // record or key) or only later (a bad box seed, first read at a pairing).
      onResetKeys: _resetKeys,
      onPaired: (_) => _boot(),
    );
  }
}
