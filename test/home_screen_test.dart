import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:criptocracia_app/app.dart';
import 'package:criptocracia_app/screens/home_screen.dart';

void main() {
  group('HomeScreen', () {
    testWidgets('displays welcome message', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));

      expect(find.text('Welcome to Cripto-cracia'), findsOneWidget);
      expect(find.text('Cripto-cracia'), findsOneWidget);
    });
  });

  group('CriptocraciaApp', () {
    testWidgets('can be instantiated and renders', (WidgetTester tester) async {
      await tester.pumpWidget(const CriptocraciaApp());

      expect(find.byType(MaterialApp), findsOneWidget);
      expect(find.text('Welcome to Cripto-cracia'), findsOneWidget);
    });
  });
}
