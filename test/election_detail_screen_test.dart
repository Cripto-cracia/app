import 'package:criptocracia_app/models/candidate.dart';
import 'package:criptocracia_app/screens/election_detail_screen.dart';
import 'package:criptocracia_app/services/election_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'helpers/test_election.dart';

void main() {
  group('ElectionDetailScreen', () {
    late FakeElectionService service;

    setUp(() {
      service = FakeElectionService();
    });

    Widget buildApp(String electionId) {
      return ChangeNotifierProvider<ElectionService>.value(
        value: service,
        child: MaterialApp(home: ElectionDetailScreen(electionId: electionId)),
      );
    }

    testWidgets('shows not found for unknown election', (tester) async {
      await tester.pumpWidget(buildApp('unknown'));
      expect(find.text('Election not found.'), findsOneWidget);
    });

    testWidgets('displays election name', (tester) async {
      service.addElection(createTestElection(name: 'My Election'));
      await tester.pumpWidget(buildApp('test-1'));
      await tester.pump();

      expect(find.text('My Election'), findsNWidgets(2)); // AppBar + header
    });

    testWidgets('displays status badge', (tester) async {
      service.addElection(createTestElection()); // active by default
      await tester.pumpWidget(buildApp('test-1'));
      await tester.pump();

      expect(find.text('Active'), findsOneWidget);
    });

    testWidgets('displays candidates', (tester) async {
      service.addElection(
        createTestElection(
          candidates: const [
            Candidate(id: 1, name: 'Alice'),
            Candidate(id: 2, name: 'Bob'),
          ],
        ),
      );
      await tester.pumpWidget(buildApp('test-1'));
      await tester.pump();

      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Bob'), findsOneWidget);
    });

    testWidgets('shows EC section', (tester) async {
      service.addElection(createTestElection());
      await tester.pumpWidget(buildApp('test-1'));
      await tester.pump();

      expect(find.text('Electoral Commission'), findsOneWidget);
      expect(find.byIcon(Icons.copy), findsOneWidget);
    });

    testWidgets('shows Vote button', (tester) async {
      service.addElection(createTestElection());
      await tester.pumpWidget(buildApp('test-1'));
      await tester.pump();

      await tester.scrollUntilVisible(
        find.text('Vote'),
        200,
        scrollable: find.byType(Scrollable),
      );
      expect(find.text('Vote'), findsOneWidget);
    });

    testWidgets('shows disabled reason for upcoming election', (tester) async {
      final now = DateTime.now();
      service.addElection(
        createTestElection(
          startTime: now.add(const Duration(hours: 1)),
          endTime: now.add(const Duration(hours: 5)),
        ),
      );
      await tester.pumpWidget(buildApp('test-1'));
      await tester.pump();

      await tester.scrollUntilVisible(
        find.text('Voting has not started yet'),
        200,
        scrollable: find.byType(Scrollable),
      );
      expect(find.text('Voting has not started yet'), findsOneWidget);
    });

    testWidgets('shows disabled reason for finished election', (tester) async {
      final now = DateTime.now();
      service.addElection(
        createTestElection(
          startTime: now.subtract(const Duration(hours: 5)),
          endTime: now.subtract(const Duration(hours: 1)),
        ),
      );
      await tester.pumpWidget(buildApp('test-1'));
      await tester.pump();

      await tester.scrollUntilVisible(
        find.text('This election has ended'),
        200,
        scrollable: find.byType(Scrollable),
      );
      expect(find.text('This election has ended'), findsOneWidget);
    });

    testWidgets('candidate selection works for active election', (
      tester,
    ) async {
      service.addElection(createTestElection());
      await tester.pumpWidget(buildApp('test-1'));
      await tester.pump();

      await tester.tap(find.text('Alice'));
      await tester.pump();

      // After selecting, the prompt should disappear.
      expect(find.text('Select a candidate to vote'), findsNothing);
    });
  });
}
