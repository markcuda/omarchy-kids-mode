// The parent app's Flutter UI over the omarchy_kids_parent logic (N-8). This is
// the thin layer: pairing, the requests from the box, and Approve / Decline (with
// the parent's reply chips) that sign and post through the Session. The logic,
// the crypto and the transport live in the package beside it and are tested there.

import 'dart:async' show StreamSubscription, Timer;
import 'dart:io' show Platform;

import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:omarchy_kids_parent/relay_client.dart';
import 'package:omarchy_kids_parent/session.dart';
import 'package:omarchy_kids_parent/state_model.dart';
import 'package:omarchy_kids_parent/transport.dart';

import 'app_root.dart';

void main() {
  // In-memory for now: the platform keystore is the remaining work, and until it
  // exists the pairing does not survive a restart. The screen says so (I-6).
  final keystore = InMemoryKeystore();
  runApp(
    MaterialApp(
      title: 'Kids Mode',
      theme: ThemeData(colorSchemeSeed: const Color(0xff8fb8ff), useMaterial3: true),
      home: AppRoot(
        keystore: keystore,
        connect: ({
          required String host,
          required int port,
          required String pin,
          required String deviceId,
          required SimpleKeyPair keyPair,
        }) =>
            KidsRelayClient(
          host: host,
          port: port,
          pinnedSpki: pin,
          deviceId: deviceId,
          keyPair: keyPair,
        ),
        name: const String.fromEnvironment('KIDS_DEVICE_NAME', defaultValue: 'parent-phone'),
        platform: Platform.operatingSystem,
        storageNote:
            'This build remembers the pairing only while it runs; the platform keystore is still to come.',
      ),
    ),
  );
}

/// The parent's requests, newest first.
class HomeScreen extends StatefulWidget {
  final Session session;
  const HomeScreen({super.key, required this.session});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  BoxState? _state;
  String? _error;
  StreamSubscription<BoxState>? _watch;
  Timer? _retry;
  int _backoff = 1;

  /// Bumped by every feed event: a signed read that lands after one is stale and
  /// is dropped, so a slow read cannot overwrite a newer list.
  int _seq = 0;

  @override
  void initState() {
    super.initState();
    // The feed carries the whole state on connect, so the read is only there to
    // paint something sooner; it is skipped once a list is on screen.
    if (_state == null) _read();
    _watchNow();
  }

  @override
  void dispose() {
    _watch?.cancel();
    _retry?.cancel();
    super.dispose();
  }

  /// One signed read. It is a convenience, never the source of truth: a result
  /// that arrives after a feed event is dropped, and a failure is only worth
  /// saying when there is nothing on screen and no feed to wait for.
  Future<void> _read() async {
    final before = _seq;
    try {
      final state = await widget.session.refresh();
      if (!mounted || _seq != before) return;
      setState(() {
        _state = state;
        _error = null;
      });
    } catch (error) {
      if (!mounted || _seq != before) return;
      if (_state != null || _watch != null) return;
      _lost("Can't reach the computer: $error");
    }
  }

  /// The box's own feed: a state event whenever anything changes, the first one
  /// as soon as the connection opens. A dropped connection is said out loud and
  /// retried; the last known list stays on screen rather than blanking.
  void _watchNow() {
    _watch?.cancel();
    _watch = widget.session.watch().listen(
      (state) {
        if (!mounted) return;
        _seq++;
        setState(() {
          _state = state;
          _error = null;
          _backoff = 1;
        });
      },
      onError: (Object error) {
        if (!mounted) return;
        _watch = null;
        _lost("Lost the connection to the computer: $error");
      },
      onDone: () {
        if (!mounted) return;
        _watch = null;
        _lost('The connection to the computer closed.');
      },
      cancelOnError: true,
    );
  }

  void _lost(String message) {
    setState(() => _error = message);
    _retry ??= Timer(Duration(seconds: _backoff), () {
      _retry = null;
      _backoff = (_backoff * 2).clamp(1, 30);
      // The feed is the recovery (its first event is the whole state); a read
      // here would race it for nothing.
      _watchNow();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = _state;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Requests'),
        actions: [
          IconButton(onPressed: _reload, icon: const Icon(Icons.refresh), tooltip: 'Refresh'),
        ],
      ),
      body: state == null
          ? (_error == null ? const Center(child: CircularProgressIndicator()) : _Notice(message: _error!))
          : Column(
              children: [
                if (_error != null) _Stale(message: _error!),
                Expanded(child: _requests(state)),
              ],
            ),
    );
  }

  /// A pull: ask for a read, and only rebuild the feed if it is not running.
  void _reload() {
    _read();
    if (_watch == null) _watchNow();
  }

  Widget _requests(BoxState state) {
    if (state.requests.isEmpty) {
      return const _Notice(message: 'Nothing to answer right now.');
    }
    return ListView.separated(
      itemCount: state.requests.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final request = state.requests[i];
        return ListTile(
          title: Text(describeRequest(request, _kidName(state, request.kid))),
          subtitle: Text(request.kind),
          trailing: const Icon(Icons.chevron_right),
          onTap: () async {
            final answered = await Navigator.of(context).push<bool>(
              MaterialPageRoute(
                builder: (_) => RequestScreen(session: widget.session, request: request),
              ),
            );
            if (answered == true) _reload();
          },
        );
      },
    );
  }

  /// The kid's display name if the box sent one, else the account.
  String _kidName(BoxState state, String kid) {
    for (final row in state.kids) {
      if (row.kid == kid) return row.kid;
    }
    return kid;
  }
}

/// One request: what they asked, the reply chips, and Approve / Decline.
class RequestScreen extends StatefulWidget {
  final Session session;
  final OpenRequest request;
  const RequestScreen({super.key, required this.session, required this.request});

  @override
  State<RequestScreen> createState() => _RequestScreenState();
}

class _RequestScreenState extends State<RequestScreen> {
  String? _reply;
  bool _busy = false;
  String? _error;

  Future<void> _answer(String decision) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (decision == 'approve') {
        await widget.session.approve(widget.request.id);
      } else {
        await widget.session.decline(widget.request.id, reply: _reply);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      setState(() {
        _busy = false;
        _error = "Couldn't send that: $error";
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.request.kid)),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(describeRequest(widget.request, widget.request.kid), style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 24),
            const Text('A reply for the kid (optional):'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final chip in defaultReplyChips)
                  ChoiceChip(
                    label: Text(chip),
                    selected: _reply == chip,
                    onSelected: _busy ? null : (chosen) => setState(() => _reply = chosen ? chip : null),
                  ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : () => _answer('approve'),
              child: const Text('Approve'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _busy ? null : () => _answer('decline'),
              child: const Text('Decline'),
            ),
          ],
        ),
      );
}

class _Notice extends StatelessWidget {
  final String message;
  const _Notice({required this.message});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(padding: const EdgeInsets.all(24), child: Text(message, textAlign: TextAlign.center)),
      );
}

/// The last known list, with the reason it may be out of date said above it.
class _Stale extends StatelessWidget {
  final String message;
  const _Stale({required this.message});
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        color: Theme.of(context).colorScheme.errorContainer,
        padding: const EdgeInsets.all(12),
        child: Text(
          '$message Showing the last update; trying again.',
          style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
        ),
      );
}
