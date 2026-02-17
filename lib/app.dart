import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'config/theme.dart';
import 'screens/elections_list_screen.dart';
import 'screens/settings_screen.dart';
import 'services/settings_service.dart';

/// The root widget of the Cripto-cracia application.
class CriptocraciaApp extends StatelessWidget {
  const CriptocraciaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsService>(
      builder: (context, settingsService, _) {
        final themeMode = settingsService.loaded
            ? settingsService.settings.themeMode
            : ThemeMode.system;
        return MaterialApp(
          title: 'Cripto-cracia',
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: themeMode,
          home: const ElectionsListScreen(),
          routes: {'/settings': (_) => const SettingsScreen()},
        );
      },
    );
  }
}
