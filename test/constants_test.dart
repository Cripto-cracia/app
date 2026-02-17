import 'package:flutter_test/flutter_test.dart';

import 'package:criptocracia_app/config/constants.dart';

void main() {
  group('AppConstants', () {
    test('has correct app name', () {
      expect(AppConstants.appName, 'Cripto-cracia');
    });

    test('has default relays configured', () {
      expect(AppConstants.defaultRelays, isNotEmpty);
      for (final relay in AppConstants.defaultRelays) {
        expect(relay, startsWith('wss://'));
      }
    });

    test('has correct event kinds', () {
      expect(AppConstants.electionEventKind, 35000);
      expect(AppConstants.voteEventKind, 35001);
    });
  });
}
