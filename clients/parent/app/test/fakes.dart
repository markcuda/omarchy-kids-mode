// Shared test doubles (not a test file itself; the runner runs *_test.dart).

import 'package:omarchy_kids_app/keystore.dart';

/// An in-memory [SecretStore]: what the OS store would hold between runs, and a
/// switch to make it fail like a device with no keystore.
class FakeStore implements SecretStore {
  final Map<String, String> values = {};
  bool broken = false;

  @override
  Future<String?> read(String key) async {
    if (broken) throw StateError('no keystore');
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
