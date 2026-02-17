import 'package:criptocracia_app/l10n/app_localizations.dart';
import 'package:criptocracia_app/models/candidate.dart';
import 'package:criptocracia_app/models/election_result.dart';
import 'package:criptocracia_app/widgets/election_results_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const candidates = [
    Candidate(id: 1, name: 'Alice'),
    Candidate(id: 2, name: 'Bob'),
  ];

  Widget buildWidget(ElectionResult results) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: ElectionResultsWidget(results: results)),
    );
  }

  group('ElectionResultsWidget', () {
    testWidgets('shows empty state when no votes', (tester) async {
      final results = ElectionResult.fromTallies(
        electionId: 'e1',
        tallies: {},
        candidates: candidates,
        lastUpdated: DateTime(2025),
      );

      await tester.pumpWidget(buildWidget(results));

      expect(find.text('No votes recorded yet'), findsOneWidget);
    });

    testWidgets('displays candidate names and vote counts', (tester) async {
      final results = ElectionResult.fromTallies(
        electionId: 'e1',
        tallies: {1: 7, 2: 3},
        candidates: candidates,
        lastUpdated: DateTime(2025),
      );

      await tester.pumpWidget(buildWidget(results));

      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Bob'), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('10 votes'), findsOneWidget);
    });

    testWidgets('shows percentages', (tester) async {
      final results = ElectionResult.fromTallies(
        electionId: 'e1',
        tallies: {1: 3, 2: 1},
        candidates: candidates,
        lastUpdated: DateTime(2025),
      );

      await tester.pumpWidget(buildWidget(results));

      expect(find.text('75.0%'), findsOneWidget);
      expect(find.text('25.0%'), findsOneWidget);
    });

    testWidgets('shows leader icon for top candidate', (tester) async {
      final results = ElectionResult.fromTallies(
        electionId: 'e1',
        tallies: {1: 5, 2: 2},
        candidates: candidates,
        lastUpdated: DateTime(2025),
      );

      await tester.pumpWidget(buildWidget(results));

      // The trophy icon should be present for the leader.
      expect(find.byIcon(Icons.emoji_events), findsOneWidget);
    });

    testWidgets('singular vote label for 1 vote', (tester) async {
      final results = ElectionResult.fromTallies(
        electionId: 'e1',
        tallies: {1: 1},
        candidates: candidates,
        lastUpdated: DateTime(2025),
      );

      await tester.pumpWidget(buildWidget(results));

      expect(find.text('1 vote'), findsOneWidget);
    });

    testWidgets('contains LinearProgressIndicator bars', (tester) async {
      final results = ElectionResult.fromTallies(
        electionId: 'e1',
        tallies: {1: 5, 2: 5},
        candidates: candidates,
        lastUpdated: DateTime(2025),
      );

      await tester.pumpWidget(buildWidget(results));

      expect(find.byType(LinearProgressIndicator), findsNWidgets(2));
    });
  });
}
