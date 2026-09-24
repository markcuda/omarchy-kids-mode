// The app's keystore (N-8): the two 32-byte seeds and the paired record, over a
// key-value seam. A corrupt seed is an error, not a silent new identity; a
// missing one is a first run.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:omarchy_kids_app/keystore.dart';
import 'package:omarchy_kids_parent/session.dart';

import 'fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a seed round-trips as base64 and comes back 32 bytes', () async {
    final store = FakeStore();
    final keystore = SecureKeystore(store);
    final seed = List<int>.generate(32, (i) => i);
    await keystore.saveSignSeed(seed);
    expect(store.values[SecureKeystore.signKey], base64.encode(seed));
    expect(await keystore.loadSignSeed(), seed);
  });

  test('the sign seed and the box seed do not collide', () async {
    final store = FakeStore();
    final keystore = SecureKeystore(store);
    await keystore.saveSignSeed(List.filled(32, 1));
    await keystore.saveBoxSeed(List.filled(32, 2));
    expect(await keystore.loadSignSeed(), List.filled(32, 1));
    expect(await keystore.loadBoxSeed(), List.filled(32, 2));
    expect(SecureKeystore.signKey, isNot(SecureKeystore.boxKey));
  });

  test('a seed that has never been saved is null, not an error', () async {
    final keystore = SecureKeystore(FakeStore());
    expect(await keystore.loadSignSeed(), isNull);
    expect(await keystore.loadBoxSeed(), isNull);
    expect(await keystore.loadPaired(), isNull);
  });

  test('a stored seed that is not 32 bytes is an error, not a new identity', () async {
    final store = FakeStore();
    store.values[SecureKeystore.signKey] = base64.encode(List.filled(31, 1));
    expect(SecureKeystore(store).loadSignSeed(), throwsStateError);
  });

  test('a stored seed that is not base64 is an error', () async {
    final store = FakeStore();
    store.values[SecureKeystore.boxKey] = 'not base64!!';
    expect(SecureKeystore(store).loadBoxSeed(), throwsStateError);
  });

  test('saving a seed that is not 32 bytes is refused', () async {
    final keystore = SecureKeystore(FakeStore());
    expect(keystore.saveSignSeed(List.filled(16, 0)), throwsArgumentError);
  });

  test('the pairing round-trips, and forgetting clears it and nothing else', () async {
    final store = FakeStore();
    final keystore = SecureKeystore(store);
    await keystore.saveSignSeed(List.filled(32, 7));
    await keystore.savePaired('{"deviceId":"dev-1","pin":"ab","addresses":[]}');
    expect(await keystore.loadPaired(), contains('dev-1'));
    await keystore.clearPaired();
    expect(await keystore.loadPaired(), isNull);
    expect(await keystore.loadSignSeed(), List.filled(32, 7),
        reason: 'forgetting a box must not drop the device key');
  });

  test('reset forgets the seeds and the pairing', () async {
    final store = FakeStore();
    final keystore = SecureKeystore(store);
    await keystore.saveSignSeed(List.filled(32, 1));
    await keystore.saveBoxSeed(List.filled(32, 2));
    await keystore.savePaired('{"deviceId":"dev-1"}');
    await keystore.reset();
    expect(await keystore.loadSignSeed(), isNull);
    expect(await keystore.loadBoxSeed(), isNull);
    expect(await keystore.loadPaired(), isNull);
  });

  test('a working store is used as it is', () async {
    final opened = await openKeystore(makeStore: FakeStore.new);
    expect(opened.keystore, isA<SecureKeystore>());
    expect(opened.note, isNull);
    expect((opened.keystore as SecureKeystore).loadPaired(), completes);
  });

  test('a store that throws falls back to memory and says so', () async {
    final opened = await openKeystore(makeStore: () => FakeStore()..broken = true);
    expect(opened.keystore, isA<InMemoryKeystore>());
    expect(opened.note, isNotNull);
    expect(opened.note, contains('only'));
  });

  test('a store that silently drops what it is given also falls back', () async {
    // This is why the probe reads the value back rather than trusting the write.
    final opened = await openKeystore(makeStore: DroppingStore.new);
    expect(opened.keystore, isA<InMemoryKeystore>());
    expect(opened.note, isNotNull);
  });

  test('a device with no usable keystore falls back to memory and says so', () async {
    // No platform channels exist here, so the OS store cannot answer: exactly
    // the case the fallback is for.
    final opened = await openKeystore();
    expect(opened.keystore, isA<InMemoryKeystore>());
    expect(opened.note, isNotNull);
    expect(opened.note, contains('only'));
  });
}
