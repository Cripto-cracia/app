import 'package:criptocracia_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:criptocracia_app/app.dart';
import 'package:criptocracia_app/config/constants.dart';
import 'package:criptocracia_app/models/election.dart';
import 'package:criptocracia_app/screens/home_screen.dart';
import 'package:criptocracia_app/services/election_service.dart';

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

      expect(find.text('Welcome to ${AppConstants.appName}'), findsOneWidget);
      expect(find.text(AppConstants.appName), findsOneWidget);
    });
  });

  group('CriptocraciaApp', () {
    testWidgets('can be instantiated and renders', (WidgetTester tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<ElectionService>.value(
          value: _FakeElectionService(),
          child: const CriptocraciaApp(),
        ),
      );

      expect(find.byType(MaterialApp), findsOneWidget);
      expect(find.text('Elections'), findsOneWidget);
    });
  });
}
