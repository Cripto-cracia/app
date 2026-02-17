import 'package:criptocracia_app/widgets/countdown_timer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CountdownTimer', () {
    testWidgets('shows countdown for future time', (tester) async {
      final target = DateTime.now().add(const Duration(hours: 2, minutes: 30));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: CountdownTimer(targetTime: target)),
        ),
      );

      // Should contain hours and minutes.
      expect(find.textContaining('h'), findsOneWidget);
      expect(find.textContaining('m'), findsOneWidget);
    });

    testWidgets('shows Ended for past time', (tester) async {
      final target = DateTime.now().subtract(const Duration(hours: 1));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: CountdownTimer(targetTime: target)),
        ),
      );

      expect(find.text('Ended'), findsOneWidget);
    });

    testWidgets('shows prefix when provided', (tester) async {
      final target = DateTime.now().add(const Duration(hours: 1));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CountdownTimer(targetTime: target, prefix: 'Ends in'),
          ),
        ),
      );

      expect(find.textContaining('Ends in'), findsOneWidget);
    });
  });

  group('formatDuration', () {
    test('formats days hours minutes seconds', () {
      final result = CountdownTimer.formatDuration(
        const Duration(days: 2, hours: 3, minutes: 15, seconds: 42),
      );
      expect(result, '2d 3h 15m 42s');
    });

    test('formats zero duration', () {
      expect(CountdownTimer.formatDuration(Duration.zero), '0s');
    });

    test('formats hours only', () {
      final result = CountdownTimer.formatDuration(const Duration(hours: 5));
      expect(result, '5h 0s');
    });
  });
}
