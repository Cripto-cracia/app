import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:criptocracia_app/services/secure_storage.dart';

void main() {
  group('SecureStorage', () {
    late Directory tempDir;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
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

    test('init opens the encrypted boxes without errors', () async {
      await SecureStorage.init(path: tempDir.path);
      // No exception means success.
    });

    test('throws if used before init', () {
      expect(() => SecureStorage.read(key: 'anything'), throwsStateError);
    });

    test('write / read round-trip (settings namespace)', () async {
      await SecureStorage.init(path: tempDir.path);
      await SecureStorage.write(key: 'test_key', value: 'hello');
      final value = await SecureStorage.read(key: 'test_key');
      expect(value, 'hello');
    });

    test('write / read round-trip (keys namespace)', () async {
      await SecureStorage.init(path: tempDir.path);
      await SecureStorage.write(
        key: 'secret',
        value: 'top_secret',
        namespace: StorageNamespace.keys,
      );
      final value = await SecureStorage.read(
        key: 'secret',
        namespace: StorageNamespace.keys,
      );
      expect(value, 'top_secret');
    });

    test('namespaces are isolated', () async {
      await SecureStorage.init(path: tempDir.path);
      await SecureStorage.write(key: 'k', value: 'settings_val');
      await SecureStorage.write(
        key: 'k',
        value: 'keys_val',
        namespace: StorageNamespace.keys,
      );

      expect(await SecureStorage.read(key: 'k'), 'settings_val');
      expect(
        await SecureStorage.read(key: 'k', namespace: StorageNamespace.keys),
        'keys_val',
      );
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

    test('mnemonic is stored in keys namespace, not settings', () async {
      await SecureStorage.init(path: tempDir.path);
      await SecureStorage.saveMnemonic('test mnemonic phrase');

      // Should not be accessible via default (settings) namespace
      final fromSettings = await SecureStorage.read(key: 'nostr_mnemonic');
      expect(fromSettings, isNull);

      // Should be accessible via keys namespace
      final fromKeys = await SecureStorage.read(
        key: 'nostr_mnemonic',
        namespace: StorageNamespace.keys,
      );
      expect(fromKeys, 'test mnemonic phrase');
    });

    test('close and reinit preserves data', () async {
      await SecureStorage.init(path: tempDir.path);
      await SecureStorage.write(key: 'persist', value: 'me');
      await SecureStorage.saveMnemonic('keep this');
      await SecureStorage.close();

      await SecureStorage.init(path: tempDir.path);
      expect(await SecureStorage.read(key: 'persist'), 'me');
      expect(await SecureStorage.loadMnemonic(), 'keep this');
    });

    group('migration', () {
      test('migrates encryption key from SharedPreferences', () async {
        // Simulate legacy state: encryption key in SharedPreferences
        final legacyKey = base64Encode(List<int>.generate(32, (i) => i));
        SharedPreferences.setMockInitialValues({
          'criptocracia_enc_key': legacyKey,
        });
        FlutterSecureStorage.setMockInitialValues({});

        await SecureStorage.init(path: tempDir.path);

        // Legacy key should be removed from SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('criptocracia_enc_key'), isNull);
      });
    });
  });
}
