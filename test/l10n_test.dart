import 'package:criptocracia_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppLocalizations', () {
    testWidgets('loads English locale by default', (tester) async {
      late AppLocalizations l10n;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Builder(
            builder: (context) {
              l10n = AppLocalizations.of(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(l10n.elections, 'Elections');
      expect(l10n.settings, 'Settings');
      expect(l10n.vote, 'Vote');
      expect(l10n.refresh, 'Refresh');
      expect(l10n.language, 'Language');
      expect(l10n.nVotes(1), '1 vote');
      expect(l10n.nVotes(5), '5 votes');
      expect(l10n.nCandidates(1), '1 candidate');
      expect(l10n.nCandidates(3), '3 candidates');
      expect(l10n.candidatesCount(2), 'Candidates (2)');
      expect(l10n.electionDetailComingSoon('Test'), contains('Test'));
    });

    testWidgets('loads Spanish locale', (tester) async {
      late AppLocalizations l10n;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('es'),
          home: Builder(
            builder: (context) {
              l10n = AppLocalizations.of(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(l10n.elections, 'Elecciones');
      expect(l10n.settings, 'Configuración');
      expect(l10n.vote, 'Votar');
      expect(l10n.refresh, 'Actualizar');
      expect(l10n.language, 'Idioma');
      expect(l10n.nVotes(1), '1 voto');
      expect(l10n.nVotes(5), '5 votos');
      expect(l10n.nCandidates(1), '1 candidato');
      expect(l10n.nCandidates(3), '3 candidatos');
      expect(l10n.candidatesCount(2), 'Candidatos (2)');
      expect(l10n.electionDetailComingSoon('Test'), contains('Test'));
    });

    test('supports exactly en and es', () {
      expect(
        AppLocalizations.supportedLocales,
        containsAll([const Locale('en'), const Locale('es')]),
      );
      expect(AppLocalizations.supportedLocales, hasLength(2));
    });
  });
}
