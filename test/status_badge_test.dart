import 'package:criptocracia_app/l10n/app_localizations.dart';
import 'package:criptocracia_app/models/election.dart';
import 'package:criptocracia_app/widgets/status_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StatusBadge', () {
    Widget buildBadge(ElectionStatus status) {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: StatusBadge(status: status)),
      );
    }

    testWidgets('displays Active for active status', (tester) async {
      await tester.pumpWidget(buildBadge(ElectionStatus.active));
      expect(find.text('Active'), findsOneWidget);
    });

    testWidgets('displays Upcoming for upcoming status', (tester) async {
      await tester.pumpWidget(buildBadge(ElectionStatus.upcoming));
      expect(find.text('Upcoming'), findsOneWidget);
    });

    testWidgets('displays Finished for finished status', (tester) async {
      await tester.pumpWidget(buildBadge(ElectionStatus.finished));
      expect(find.text('Finished'), findsOneWidget);
    });

    testWidgets('displays Canceled for canceled status', (tester) async {
      await tester.pumpWidget(buildBadge(ElectionStatus.canceled));
      expect(find.text('Canceled'), findsOneWidget);
    });

    test('colorFor returns correct values', () {
      expect(StatusBadge.colorFor(ElectionStatus.active), Colors.green);
      expect(StatusBadge.colorFor(ElectionStatus.upcoming), Colors.orange);
      expect(StatusBadge.colorFor(ElectionStatus.finished), Colors.grey);
      expect(StatusBadge.colorFor(ElectionStatus.canceled), Colors.red);
    });
  });
}
