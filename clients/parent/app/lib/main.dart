// The parent app's Flutter UI over the omarchy_kids_parent logic (N-8). This is
// the thin layer: pairing, the requests from the box, and Approve / Decline (with
// the parent's reply chips) that sign and post through the Session. The logic,
// the crypto and the transport live in the package beside it and are tested there.

import 'dart:async' show StreamSubscription, Timer, unawaited;
import 'dart:io' show Platform;

import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:omarchy_kids_parent/relay_client.dart';
import 'package:omarchy_kids_parent/session.dart';
import 'package:omarchy_kids_parent/state_model.dart';
import 'package:omarchy_kids_parent/transport.dart';

import 'app_root.dart';
import 'keystore.dart';
import 'local_notifier.dart';
import 'notifier.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // The system keystore where it works; a memory-only fallback, said out loud on
  // the pairing screen, where it does not (I-6).
  final opened = await openKeystore();
  // A notification only where the platform can raise one; the label on the
  // requests screen says which (R-NOTIFY-14.2).
  final notifier = LocalNotifier.supported ? LocalNotifier() : const NoopNotifier();
  runApp(
    MaterialApp(
      title: 'Kids Mode',
      theme: ThemeData(colorSchemeSeed: const Color(0xff8fb8ff), useMaterial3: true),
      home: AppRoot(
        keystore: opened.keystore,
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
        notifier: notifier,
        noticeNote: LocalNotifier.supported
            ? 'Notifies while the app is open. Nothing arrives while it is closed; open it to see '
                'what is waiting.'
            : 'This platform has no notifications in this build. Open the app to see what is waiting.', 
        storageNote: opened.note,
      ),
    ),
  );
}

/// The parent's requests, newest first.
class HomeScreen extends StatefulWidget {
  final Session session;

  /// Raises a notification for a request or review that arrives while the app is
  /// open (R-NOTIFY-14); null where a test does not care.
  final Notifier? notifier;

  /// The honest note about what notifications do here (R-NOTIFY-14.2).
  final String? noticeNote;

  /// Forget the box on this device and return to pairing (the app offers it in
  /// the overflow menu). Null in a test that has no pairing to forget.
  final Future<void> Function()? onForget;

  const HomeScreen({super.key, required this.session, this.notifier, this.noticeNote, this.onForget});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  BoxState? _state;
  String? _error;
  StreamSubscription<BoxState>? _watch;
  Timer? _retry;
  int _backoff = 1;

  /// Raises a notification for a request or review that arrives while the app is
  /// open (R-NOTIFY-14). Null when no notifier was given.
  NoticeFeed? _notice;

  /// A tap that arrived for a row the current document does not carry yet (the
  /// notification launched the app); opened on the next document if the row is
  /// there, dropped otherwise (R-NOTIFY-14.3: "else the list").
  NoticeTap? _pendingTap;

  /// The note under the list; the refusal line replaces it if the platform
  /// declines the permission (R-NOTIFY-14.2).
  String? _noticeNote;

  /// Bumped by every feed event: a signed read that lands after one is stale and
  /// is dropped, so a slow read cannot overwrite a newer list.
  int _seq = 0;

  @override
  void initState() {
    super.initState();
    _noticeNote = widget.noticeNote;
    final notifier = widget.notifier;
    if (notifier != null) {
      _notice = NoticeFeed(notifier);
      unawaited(notifier.initialize(onTap: _onNoticeTap).then((granted) {
        if (!granted && mounted) {
          setState(() => _noticeNote =
              'Notifications are off for this app in your system settings. Open the app to see what is waiting.');
        }
      }));
    }
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
      // The read can be the first document of the run (it paints before the
      // feed's first event), so it seeds the notification sets too; otherwise a
      // request that was in the read but arrived after opening would be raised
      // as if it were new.
      final notice = _notice;
      if (notice != null) unawaited(notice.update(state));
      _openPending();
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
        final notice = _notice;
        if (notice != null) unawaited(notice.update(state));
        _openPending();
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
          if (widget.onForget != null)
            PopupMenuButton<String>(
              tooltip: 'More',
              onSelected: (value) {
                if (value == 'forget') _confirmForget();
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'forget', child: Text('Forget this computer…')),
              ],
            ),
        ],
      ),
      body: state == null
          ? (_error == null ? const Center(child: CircularProgressIndicator()) : _Notice(message: _error!))
          : Column(
              children: [
                if (_error != null) _Stale(message: _error!),
                Expanded(child: _body(state)),
              ],
            ),
    );
  }

  /// A pull: ask for a read, and only rebuild the feed if it is not running.
  void _reload() {
    _read();
    if (_watch == null) _watchNow();
  }

  /// Ask before forgetting: it stops this device getting the box's requests, and
  /// the box keeps its own record until the parent revokes the device there.
  Future<void> _confirmForget() async {
    final forget = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Forget this computer?'),
        content: const Text(
          'This device stops getting the computer\'s requests until you pair it again. '
          'The computer keeps the device until you revoke it there.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Forget')),
        ],
      ),
    );
    if (forget == true) await widget.onForget!();
  }

  Widget _body(BoxState state) {
    final children = <Widget>[];
    // R-NOTIFY-12: an add-on that changed since the parent approved it comes
    // first, above the kid's requests, because it is the thing that needs a look.
    if (state.reviews.isNotEmpty) {
      children.add(const _SectionHeader('Add-ons that changed'));
      for (final review in state.reviews) {
        children.add(ListTile(
          title: Text(describeReview(review)),
          subtitle: Text(review.kid),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _pushReview(review),
        ));
      }
      children.add(const Divider(height: 1));
    }
    // The kids this phone can act for (R-NOTIFY-13): a tap opens the two
    // actions. Only a kid account the box would accept is listed.
    final kids = state.kids.where((kid) => KidStatus.accountPattern.hasMatch(kid.kid)).toList();
    if (kids.isNotEmpty) {
      children.add(const _SectionHeader('Kids'));
      for (final kid in kids) {
        children.add(ListTile(
          title: Text(kid.kid),
          subtitle: Text(_kidLine(kid)),
          trailing: const Icon(Icons.chevron_right),
          onTap: () async {
            final acted = await Navigator.of(context).push<bool>(
              MaterialPageRoute(
                builder: (_) => KidScreen(session: widget.session, kid: kid),
              ),
            );
            if (acted == true) _reload();
          },
        ));
      }
      children.add(const Divider(height: 1));
    }
    if (state.reviews.isNotEmpty || kids.isNotEmpty) {
      children.add(const _SectionHeader('Requests'));
    }
    if (_noticeNote != null) {
      children.add(Padding(
        padding: const EdgeInsets.all(16),
        child: Text(_noticeNote!, style: Theme.of(context).textTheme.bodySmall),
      ));
    }
    if (state.requests.isEmpty) {
      children.add(
        const Padding(
          padding: EdgeInsets.all(24),
          child: Text('Nothing to answer right now.', textAlign: TextAlign.center),
        ),
      );
    } else {
      for (final request in state.requests) {
        children.add(ListTile(
          title: Text(describeRequest(request, _kidName(state, request.kid))),
          subtitle: Text(request.kind),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _pushRequest(request),
        ));
      }
    }
    return ListView(children: children);
  }

  /// A tapped notification: open the row it names if the current document has
  /// it, else remember it for the next document (a cold-start tap).
  void _onNoticeTap(NoticeTap tap) {
    if (!mounted) return;
    if (!_openNotice(tap)) _pendingTap = tap;
  }

  void _openPending() {
    final tap = _pendingTap;
    if (tap == null) return;
    // One attempt, on the first document after the tap: the row is there or the
    // tap is stale (the review was decided before the app opened).
    _pendingTap = null;
    _openNotice(tap);
  }

  bool _openNotice(NoticeTap tap) {
    final state = _state;
    if (state == null) return false;
    if (tap.kind == 'request') {
      for (final request in state.requests) {
        if (request.id == tap.id) {
          _pushRequest(request);
          return true;
        }
      }
      return false;
    }
    for (final review in state.reviews) {
      if (review.id == tap.id) {
        _pushReview(review);
        return true;
      }
    }
    return false;
  }

  Future<void> _pushRequest(OpenRequest request) async {
    final answered = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => RequestScreen(session: widget.session, request: request)),
    );
    if (answered == true) _reload();
  }

  Future<void> _pushReview(OpenReview review) async {
    final answered = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ReviewScreen(session: widget.session, review: review)),
    );
    if (answered == true) _reload();
  }

  /// What a kid row says under the account: minutes left while running, or why
  /// there is nothing to count.
  String _kidLine(KidStatus kid) {
    if (kid.paused) return 'paused · ${kid.minutesLeft} min left';
    if (!kid.live) return 'not running';
    return '${kid.minutesLeft} min left';
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

/// One kid: more time today, or end the session. Both sign with this device's
/// key and the `act` scope the parent gave it -- no password is typed here, and
/// the box refuses the action without that scope (R-NOTIFY-13).
class KidScreen extends StatefulWidget {
  final Session session;
  final KidStatus kid;
  const KidScreen({super.key, required this.session, required this.kid});

  @override
  State<KidScreen> createState() => _KidScreenState();
}

class _KidScreenState extends State<KidScreen> {
  static const _choices = [15, 30, 60];
  int _minutes = 30;
  bool _busy = false;
  String? _error;

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      setState(() {
        _busy = false;
        _error = _refusal(error);
      });
    }
  }

  /// The box's own reasons in the parent's words.
  String _refusal(Object error) {
    final text = error.toString();
    if (text.contains('scope-missing')) {
      return 'This device was paired to decide requests, not to act. Ask on the computer, or pair it again with the act scope.';
    }
    if (text.contains('not-a-kid')) {
      return 'The computer would not take that account.';
    }
    return "Couldn't send that: $error";
  }

  Future<void> _confirmEnd() async {
    final end = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('End ${widget.kid.kid}\'s session?'),
        content: const Text('Their session ends now. They can sign in again if they still have time.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('End now')),
        ],
      ),
    );
    if (end == true) await _run(() => widget.session.endSession(widget.kid.kid));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.kid.kid)),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              widget.kid.live ? '${widget.kid.minutesLeft} min left' : 'Not running',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 24),
            const Text('More time today'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final minutes in _choices)
                  ChoiceChip(
                    label: Text('$minutes min'),
                    selected: _minutes == minutes,
                    onSelected: _busy ? null : (chosen) => setState(() => _minutes = chosen ? minutes : _minutes),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _busy ? null : () => _run(() => widget.session.grantTime(widget.kid.kid, _minutes)),
              child: Text('Give $_minutes minutes'),
            ),
            const SizedBox(height: 24),
            const Text('End session'),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _busy ? null : _confirmEnd,
              child: const Text('End session now'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 16),
            Text(
              'This phone acts with the key the computer paired; no password is typed. '
              'More time is for today only.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );
}

/// One changed add-on: what changed, and the parent's Approve / Deny. The
/// fingerprints are the whole of Check -- this screen decides nothing until a
/// button is tapped (I-6).
class ReviewScreen extends StatefulWidget {
  final Session session;
  final OpenReview review;
  const ReviewScreen({super.key, required this.session, required this.review});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _answer(String decision) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (decision == 'approve') {
        await widget.session.approveReview(widget.review.id, widget.review.now);
      } else {
        await widget.session.denyReview(widget.review.id, widget.review.now);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      setState(() {
        _busy = false;
        _error = _refusal(error);
      });
    }
  }

  /// The box's own reasons in the parent's words: a surface that moved on, or a
  /// review already decided, are not failures to hide behind "couldn't send".
  String _refusal(Object error) {
    final text = error.toString();
    if (text.contains('changed-again')) {
      return 'That add-on changed again since you looked. Refresh to see the new change.';
    }
    if (text.contains('no-such-review')) {
      return 'That one was already decided. Refresh to see what is left.';
    }
    return "Couldn't send that: $error";
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.review.kid)),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(describeReview(widget.review), style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 24),
            const Text('What changed'),
            const SizedBox(height: 8),
            SelectableText(
              'was  ${widget.review.was}\nnow  ${widget.review.now}',
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            ),
            const SizedBox(height: 8),
            const Text(
              'This is what the computer reports. Nothing is decided until you choose below.',
              style: TextStyle(fontSize: 12),
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
              onPressed: _busy ? null : () => _answer('deny'),
              child: const Text('Deny (hide it again)'),
            ),
          ],
        ),
      );
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
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
