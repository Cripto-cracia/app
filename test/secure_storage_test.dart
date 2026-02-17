import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:criptocracia_app/services/secure_storage.dart';

void main() {
  group('SecureStorage', () {
    late Directory tempDir;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      tempDir = await Directory.systemTemp.createTemp('hive_test_');
    });

    tearDown(() async {
      await SecureStorage.close();
      try {
        await Hive.close();
      } catch (_) {}
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('init opens the encrypted box without errors', () async {
      await SecureStorage.init(path: tempDir.path);
      // No exception means success.
    });

    test('throws if used before init', () {
      expect(() => SecureStorage.read(key: 'anything'), throwsStateError);
    });

    test('write / read round-trip', () async {
      await SecureStorage.init(path: tempDir.path);
      await SecureStorage.write(key: 'test_key', value: 'hello');
      final value = await SecureStorage.read(key: 'test_key');
      expect(value, 'hello');
    });

    test('read returns null for missing key', () async {
      await SecureStorage.init(path: tempDir.path);
      final value = await SecureStorage.read(key: 'nonexistent');
      expect(value, isNull);
    });

    test('delete removes the key', () async {
      await SecureStorage.init(path: tempDir.path);
      await SecureStorage.write(key: 'k', value: 'v');
      await SecureStorage.delete(key: 'k');
      expect(await SecureStorage.read(key: 'k'), isNull);
    });

    test('exists returns correct boolean', () async {
      await SecureStorage.init(path: tempDir.path);
      expect(await SecureStorage.exists(key: 'k'), isFalse);
      await SecureStorage.write(key: 'k', value: 'v');
      expect(await SecureStorage.exists(key: 'k'), isTrue);
    });

    test('mnemonic helpers save / load / delete / has', () async {
      await SecureStorage.init(path: tempDir.path);

      expect(await SecureStorage.hasMnemonic(), isFalse);
      expect(await SecureStorage.loadMnemonic(), isNull);

      await SecureStorage.saveMnemonic('abandon abandon about');
      expect(await SecureStorage.hasMnemonic(), isTrue);
      expect(await SecureStorage.loadMnemonic(), 'abandon abandon about');

      await SecureStorage.deleteMnemonic();
      expect(await SecureStorage.hasMnemonic(), isFalse);
    });
  });
}
