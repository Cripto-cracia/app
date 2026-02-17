import 'package:criptocracia_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// Placeholder home screen displayed on app launch.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.appName)),
      body: Center(child: Text(l10n.welcomeMessage)),
    );
  }
}
