// The parent app's Flutter UI over the omarchy_kids_parent logic (N-8). This is
// the thin layer: pairing, the requests from the box, and Approve / Decline (with
// the parent's reply chips) that sign and post through the Session. The logic,
// the crypto and the transport live in the package beside it and are tested there.

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
  late Future<BoxState> _state;

  @override
  void initState() {
    super.initState();
    _state = widget.session.refresh();
  }

  void _reload() {
    setState(() {
      _state = widget.session.refresh();
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Requests'),
          actions: [IconButton(onPressed: _reload, icon: const Icon(Icons.refresh), tooltip: 'Refresh')],
        ),
        body: FutureBuilder<BoxState>(
          future: _state,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _Notice(message: "Can't reach the computer: ${snapshot.error}");
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final requests = snapshot.data!.requests;
            if (requests.isEmpty) {
              return const _Notice(message: 'Nothing to answer right now.');
            }
            return ListView.separated(
              itemCount: requests.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final request = requests[i];
                return ListTile(
                  title: Text(describeRequest(request, _kidName(snapshot.data!, request.kid))),
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
          },
        ),
      );

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
