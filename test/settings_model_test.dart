import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:criptocracia_app/models/settings.dart';

void main() {
  group('AppSettings', () {
    test('default constructor has empty relays and system theme', () {
      const settings = AppSettings();
      expect(settings.relayUrls, isEmpty);
      expect(settings.ecPubKey, isNull);
      expect(settings.themeMode, ThemeMode.system);
    });

    test('copyWith creates modified copy', () {
      const original = AppSettings(
        relayUrls: ['wss://a.com'],
        ecPubKey: 'npub1abc',
        themeMode: ThemeMode.dark,
      );
      final copy = original.copyWith(themeMode: ThemeMode.light);
      expect(copy.themeMode, ThemeMode.light);
      expect(copy.relayUrls, ['wss://a.com']);
      expect(copy.ecPubKey, 'npub1abc');
    });

    test('copyWith clearEcPubKey sets ecPubKey to null', () {
      const original = AppSettings(ecPubKey: 'npub1abc');
      final copy = original.copyWith(clearEcPubKey: true);
      expect(copy.ecPubKey, isNull);
    });

    test('equality works correctly', () {
      const a = AppSettings(relayUrls: ['wss://a.com']);
      const b = AppSettings(relayUrls: ['wss://a.com']);
      const c = AppSettings(relayUrls: ['wss://b.com']);
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });
}
