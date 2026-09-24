// Where the app keeps its secrets between runs (N-8). The Keystore interface is
// the package's; this is the platform side of it, over a small key-value seam so
// the logic is testable without a device, and one adapter over the OS store.

import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:omarchy_kids_parent/session.dart';

/// A string-keyed secret store: one device's private secrets. The adapter over
/// the OS keychain (or the app's own keystore) is [FlutterSecureStore]; a test
/// uses its own.
abstract class SecretStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// The device's secrets under a store: the two 32-byte seeds (base64) and the
/// paired box record. A stored seed that is not 32 bytes is an error, not a
/// silent new identity -- a fresh key under the same device id would just be
/// refused by the box, and the parent would never learn why.
class SecureKeystore implements Keystore {
  static const signKey = 'device.sign_seed';
  static const boxKey = 'device.box_seed';
  static const pairedKey = 'device.paired';
  static const _seedBytes = 32;

  final SecretStore _store;
  SecureKeystore(this._store);

  @override
  Future<List<int>?> loadSignSeed() => _loadSeed(signKey, 'signing');

  @override
  Future<void> saveSignSeed(List<int> seed) => _saveSeed(signKey, seed);

  @override
  Future<List<int>?> loadBoxSeed() => _loadSeed(boxKey, 'box');

  @override
  Future<void> saveBoxSeed(List<int> seed) => _saveSeed(boxKey, seed);

  @override
  Future<String?> loadPaired() => _store.read(pairedKey);

  @override
  Future<void> savePaired(String json) => _store.write(pairedKey, json);

  @override
  Future<void> clearPaired() => _store.delete(pairedKey);

  Future<List<int>?> _loadSeed(String key, String which) async {
    final stored = await _store.read(key);
    if (stored == null) return null;
    final List<int> seed;
    try {
      seed = base64.decode(stored);
    } on FormatException {
      throw StateError('the stored $which key is not valid base64');
    }
    if (seed.length != _seedBytes) {
      throw StateError('the stored $which key is ${seed.length} bytes, not $_seedBytes');
    }
    return seed;
  }

  Future<void> _saveSeed(String key, List<int> seed) async {
    if (seed.length != _seedBytes) {
      throw ArgumentError('a $key seed must be $_seedBytes bytes, got ${seed.length}');
    }
    await _store.write(key, base64.encode(seed));
  }
}

/// The OS store: Keychain on Apple platforms, Keystore-backed EncryptedShared
/// Preferences on Android, the Credential Manager on Windows, the Secret Service
/// on Linux. On a platform with none of those (a Linux box with no keyring) it
/// throws; [openKeystore] falls back and the pairing screen says the pairing will
/// not survive a restart.
class FlutterSecureStore implements SecretStore {
  static const _options = AndroidOptions(encryptedSharedPreferences: true);
  final FlutterSecureStorage _storage;
  FlutterSecureStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  @override
  Future<String?> read(String key) => _storage.read(key: key, aOptions: _options);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value, aOptions: _options);

  @override
  Future<void> delete(String key) => _storage.delete(key: key, aOptions: _options);
}

/// The device's keystore for this run: the OS store when it can keep a value,
/// an in-memory one when it cannot. Returns the keystore and, when it fell back,
/// the note the pairing screen shows.
Future<({Keystore keystore, String? note})> openKeystore() async {
  const probe = 'device.probe';
  try {
    final store = FlutterSecureStore();
    await store.write(probe, 'ok');
    final read = await store.read(probe);
    await store.delete(probe);
    if (read != 'ok') throw StateError('the secure store did not keep the value it was given');
    return (keystore: SecureKeystore(store), note: null);
  } catch (_) {
    return (
      keystore: InMemoryKeystore(),
      note: 'No system keystore is available here, so this build remembers the pairing only '
          'while it runs. On a phone or a laptop it is kept in the system keychain.',
    );
  }
}
