import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:criptocracia_app/services/secure_storage.dart';
import 'package:criptocracia_app/services/settings_service.dart';

void main() {
  late SettingsService service;
  late Directory tempDir;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('settings_test_');
    await SecureStorage.close();
    await SecureStorage.init(path: tempDir.path);
    service = SettingsService();
  });

  tearDown(() async {
    await SecureStorage.close();
    await tempDir.delete(recursive: true);
  });

  group('SettingsService', () {
    test('load returns defaults when no stored settings', () async {
      await service.load();
      expect(service.loaded, isTrue);
      expect(service.settings.relayUrls, isNotEmpty);
      expect(service.settings.themeMode, ThemeMode.system);
      expect(service.settings.ecPubKey, isNull);
    });

    test('addRelay persists and notifies', () async {
      await service.load();
      var notified = false;
      service.addListener(() => notified = true);

      final result = await service.addRelay('wss://new.relay.com');
      expect(result, isTrue);
      expect(service.settings.relayUrls, contains('wss://new.relay.com'));
      expect(notified, isTrue);
    });

    test('addRelay rejects invalid URL', () async {
      await service.load();
      final result = await service.addRelay('http://not-ws.com');
      expect(result, isFalse);
    });

    test('addRelay rejects duplicate', () async {
      await service.load();
      await service.addRelay('wss://dup.relay.com');
      final result = await service.addRelay('wss://dup.relay.com');
      expect(result, isFalse);
    });

    test('removeRelay persists and notifies', () async {
      await service.load();
      await service.addRelay('wss://remove.me');
      final result = await service.removeRelay('wss://remove.me');
      expect(result, isTrue);
      expect(service.settings.relayUrls, isNot(contains('wss://remove.me')));
    });

    test('removeRelay returns false for unknown URL', () async {
      await service.load();
      final result = await service.removeRelay('wss://unknown.com');
      expect(result, isFalse);
    });

    test('setEcPubKey saves valid npub', () async {
      await service.load();
      const validNpub =
          'npub1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqspczk8';
      await service.setEcPubKey(validNpub);
      expect(service.settings.ecPubKey, equals(validNpub));
    });

    test('setEcPubKey rejects invalid npub', () async {
      await service.load();
      expect(
        () => service.setEcPubKey('invalid'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('setEcPubKey clears when null', () async {
      await service.load();
      await service.setEcPubKey(null);
      expect(service.settings.ecPubKey, isNull);
    });

    test('setThemeMode persists', () async {
      await service.load();
      await service.setThemeMode(ThemeMode.dark);
      expect(service.settings.themeMode, ThemeMode.dark);

      // Reload and verify persistence.
      final service2 = SettingsService();
      await service2.load();
      expect(service2.settings.themeMode, ThemeMode.dark);
    });

    test('relays persist across reloads', () async {
      await service.load();
      await service.addRelay('wss://persist.test');

      final service2 = SettingsService();
      await service2.load();
      expect(service2.settings.relayUrls, contains('wss://persist.test'));
    });
  });

  group('SettingsService validation', () {
    test('isValidRelayUrl accepts wss://', () {
      expect(SettingsService.isValidRelayUrl('wss://relay.com'), isTrue);
    });

    test('isValidRelayUrl accepts ws://', () {
      expect(SettingsService.isValidRelayUrl('ws://relay.com'), isTrue);
    });

    test('isValidRelayUrl rejects http://', () {
      expect(SettingsService.isValidRelayUrl('http://relay.com'), isFalse);
    });

    test('isValidRelayUrl rejects empty host', () {
      expect(SettingsService.isValidRelayUrl('wss://'), isFalse);
    });

    test('isValidNpub accepts valid format', () {
      // 63 chars total: "npub1" (5) + 58 bech32 data chars
      const npub =
          'npub1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqspczk8';
      expect(npub.length, 63);
      expect(SettingsService.isValidNpub(npub), isTrue);
    });

    test('isValidNpub rejects wrong prefix', () {
      expect(SettingsService.isValidNpub('nsec1qqqqqqqqqqqqqqq'), isFalse);
    });

    test('isValidNpub rejects wrong length', () {
      expect(SettingsService.isValidNpub('npub1short'), isFalse);
    });

    test('isValidNpub rejects invalid characters', () {
      // 'b' is not in bech32 charset, but actually it is... 'i' is not
      final invalid = 'npub1${'i' * 58}';
      expect(SettingsService.isValidNpub(invalid), isFalse);
    });
  });
}
