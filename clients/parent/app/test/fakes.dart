// Shared test doubles (not a test file itself; the runner runs *_test.dart).

import 'package:omarchy_kids_app/keystore.dart';
import 'package:omarchy_kids_app/notifier.dart';

/// An in-memory [SecretStore]: what the OS store would hold between runs, and a
/// switch to make it fail like a device with no keystore.
class FakeStore implements SecretStore {
  final Map<String, String> values = {};

  /// Every read, write and delete fails, as on a device with no keystore.
  bool broken = false;

  /// Keys whose read fails while the rest of the store works (an item that did
  /// not survive a backup, say).
  final Set<String> readThrows = {};

  @override
  Future<String?> read(String key) async {
    if (broken || readThrows.contains(key)) throw StateError('no keystore');
    return values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    if (broken) throw StateError('no keystore');
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    if (broken) throw StateError('no keystore');
    // Deleting a value that could not be read removes it for good, as it would
    // on a device (the restored-backup case): a read after the delete is null,
    // not an error.
    readThrows.remove(key);
    values.remove(key);
  }
}

/// A store that accepts writes, drops them, and reads back nothing -- the shape
/// of a keystore that is present but not usable, which the probe must notice.
class DroppingStore implements SecretStore {
  @override
  Future<String?> read(String key) async => null;
  @override
  Future<void> write(String key, String value) async {}
  @override
  Future<void> delete(String key) async {}
}

class FakeNotifier implements Notifier {
  final shows = <({String kind, String id, String title, String body})>[];
  final cancels = <({String kind, String id})>[];
  int cancelAlls = 0;
  void Function(NoticeTap)? onTap;
  bool granted = true;

  @override
  Future<bool> initialize({required void Function(NoticeTap tap) onTap}) async {
    this.onTap = onTap;
    return granted;
  }
  @override
  Future<void> show({
    required String kind,
    required String id,
    required String title,
    required String body,
  }) async {
    shows.add((kind: kind, id: id, title: title, body: body));
  }

  @override
  Future<void> cancel({required String kind, required String id}) async {
    cancels.add((kind: kind, id: id));
  }

  @override
  Future<void> cancelAll() async => cancelAlls++;
}
