import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'services/election_service.dart';
import 'services/nostr_service.dart';
import 'services/settings_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsService>(
          create: (_) => SettingsService()..load(),
        ),
        ChangeNotifierProvider<NostrService>(create: (_) => NostrService()),
        ChangeNotifierProxyProvider<NostrService, ElectionService>(
          create: (context) =>
              ElectionService(nostrService: context.read<NostrService>()),
          update: (_, nostrService, previous) =>
              previous ?? ElectionService(nostrService: nostrService),
        ),
      ],
      child: const CriptocraciaApp(),
    ),
  );
}
