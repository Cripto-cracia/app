import 'dart:io';

import 'package:criptocracia_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:criptocracia_app/app.dart';
import 'package:criptocracia_app/config/constants.dart';
import 'package:criptocracia_app/models/election.dart';
import 'package:criptocracia_app/screens/home_screen.dart';
import 'package:criptocracia_app/services/election_service.dart';
import 'package:criptocracia_app/services/secure_storage.dart';
import 'package:criptocracia_app/services/settings_service.dart';

/// A fake ElectionService for testing the app widget.
class _FakeElectionService extends ChangeNotifier implements ElectionService {
  @override
  List<Election> get elections => [];
  @override
  bool get isDiscovering => false;
  @override
  int get electionCount => 0;
  @override
  List<Election> electionsByStatus(ElectionStatus status) => [];
  @override
  Election? getElection(String id) => null;
  @override
  void startDiscovery() {}
  @override
  void stopDiscovery() {}
  @override
  void refreshElections() {}
}

void main() {
  group('HomeScreen', () {
    testWidgets('displays welcome message', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: HomeScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Welcome to ${AppConstants.appName}'), findsOneWidget);
      expect(find.text(AppConstants.appName), findsOneWidget);
    });
  });

  group('CriptocraciaApp', () {
    late SettingsService settingsService;
    late Directory tempDir;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
      tempDir = await Directory.systemTemp.createTemp('home_screen_app_test_');
      await SecureStorage.close();
      await SecureStorage.init(path: tempDir.path);
      settingsService = SettingsService();
      await settingsService.load();
    });

    tearDown(() async {
      await SecureStorage.close();
      await tempDir.delete(recursive: true);
    });

    testWidgets('can be instantiated and renders', (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ElectionService>.value(
              value: _FakeElectionService(),
            ),
            ChangeNotifierProvider<SettingsService>.value(
              value: settingsService,
            ),
          ],
          child: const CriptocraciaApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(MaterialApp), findsOneWidget);
      expect(find.text('Elections'), findsOneWidget);
    });
  });
}
