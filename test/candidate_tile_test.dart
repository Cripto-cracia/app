import 'package:criptocracia_app/models/candidate.dart';
import 'package:criptocracia_app/widgets/candidate_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CandidateTile', () {
    const candidate = Candidate(id: 1, name: 'Alice');

    Widget buildTile({bool isSelected = false, VoidCallback? onTap}) {
      return MaterialApp(
        home: Scaffold(
          body: CandidateTile(
            candidate: candidate,
            isSelected: isSelected,
            onTap: onTap,
          ),
        ),
      );
    }

    testWidgets('displays candidate name', (tester) async {
      await tester.pumpWidget(buildTile());
      expect(find.text('Alice'), findsOneWidget);
    });

    testWidgets('displays candidate ID', (tester) async {
      await tester.pumpWidget(buildTile());
      expect(find.text('ID: 1'), findsOneWidget);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(buildTile(onTap: () => tapped = true));

      await tester.tap(find.text('Alice'));
      expect(tapped, isTrue);
    });

    testWidgets('shows selection icon', (tester) async {
      await tester.pumpWidget(buildTile());
      expect(find.byIcon(Icons.radio_button_unchecked), findsOneWidget);
    });

    testWidgets('shows checked icon when selected', (tester) async {
      await tester.pumpWidget(buildTile(isSelected: true));
      expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
    });
  });
}
