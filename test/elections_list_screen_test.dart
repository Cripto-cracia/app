import 'package:criptocracia_app/models/election.dart';
import 'package:criptocracia_app/screens/elections_list_screen.dart';
import 'package:criptocracia_app/services/election_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// A fake ElectionService that doesn't require a real NostrService.
class FakeElectionService extends ChangeNotifier implements ElectionService {
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
  void startDiscovery() {
    // No-op in tests.
  }

  @override
  void stopDiscovery() {}

  @override
  void refreshElections() {}
}

void main() {
  group('ElectionsListScreen', () {
    late FakeElectionService electionService;

    setUp(() {
      electionService = FakeElectionService();
    });

    Widget buildApp() {
      return ChangeNotifierProvider<ElectionService>.value(
        value: electionService,
        child: const MaterialApp(home: ElectionsListScreen()),
      );
    }

    testWidgets('shows empty state when no elections', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump();

      expect(find.text('No elections found'), findsOneWidget);
      expect(find.text('Refresh'), findsOneWidget);
    });

    testWidgets('shows Elections title in app bar', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump();

      expect(find.text('Elections'), findsOneWidget);
    });

    testWidgets('has filter button', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump();

      expect(find.byIcon(Icons.filter_list), findsOneWidget);
    });
  });
}
