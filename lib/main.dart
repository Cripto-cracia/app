import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'services/election_service.dart';
import 'services/nostr_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final nostrService = NostrService();
  final electionService = ElectionService(nostrService: nostrService);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<NostrService>.value(value: nostrService),
        ChangeNotifierProvider<ElectionService>.value(value: electionService),
      ],
      child: const CriptocraciaApp(),
    ),
  );
}
