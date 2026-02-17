import 'package:flutter/material.dart';

import 'config/theme.dart';
import 'screens/elections_list_screen.dart';

/// The root widget of the Cripto-cracia application.
class CriptocraciaApp extends StatelessWidget {
  const CriptocraciaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cripto-cracia',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: const ElectionsListScreen(),
    );
  }
}
