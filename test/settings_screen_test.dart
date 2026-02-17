import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:criptocracia_app/screens/settings_screen.dart';
import 'package:criptocracia_app/services/secure_storage.dart';
import 'package:criptocracia_app/services/settings_service.dart';

void main() {
  late SettingsService settingsService;
  late Directory tempDir;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('settings_screen_test_');
    await SecureStorage.close();
    await SecureStorage.init(path: tempDir.path);
    settingsService = SettingsService();
    await settingsService.load();
  });

  tearDown(() async {
    await SecureStorage.close();
    await tempDir.delete(recursive: true);
  });

  Widget buildApp() {
    return ChangeNotifierProvider<SettingsService>.value(
      value: settingsService,
      child: MaterialApp(
        home: Material(
          child: MediaQuery(
            data: const MediaQueryData(size: Size(400, 1200)),
            child: const SettingsScreen(),
          ),
        ),
      ),
    );
  }

  group('SettingsScreen', () {
    testWidgets('renders relays and EC sections', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Relays'), findsOneWidget);
      expect(find.text('Electoral Commission Public Key'), findsOneWidget);
    });

    testWidgets('shows default relays', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.text('wss://relay.damus.io'), findsOneWidget);
    });

    testWidgets('shows mnemonic section', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.text('Mnemonic Backup'), findsOneWidget);
      expect(find.text('No mnemonic stored.'), findsOneWidget);
    });

    testWidgets('shows theme section when scrolled', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      // Scroll down to find the theme section
      await tester.scrollUntilVisible(
        find.text('Theme'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Theme'), findsOneWidget);
    });

    testWidgets('add relay dialog opens', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      expect(find.text('Add Relay'), findsOneWidget);
      expect(find.text('Relay URL'), findsOneWidget);
    });
  });
}
