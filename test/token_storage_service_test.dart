import 'dart:io';
import 'dart:typed_data';

import 'package:criptocracia_app/models/blind_token.dart';
import 'package:criptocracia_app/services/secure_storage.dart';
import 'package:criptocracia_app/services/token_storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('token_storage_test_');
    SharedPreferences.setMockInitialValues({});
    await SecureStorage.init(path: tempDir.path);
  });

  tearDown(() async {
    await SecureStorage.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  BlindToken makeToken(String electionId) {
    return BlindToken(
      electionId: electionId,
      nonce: Uint8List.fromList(List.generate(32, (i) => i)),
      hashedNonce: Uint8List.fromList(List.generate(32, (i) => i + 32)),
      blindedMessage: Uint8List.fromList(List.generate(64, (i) => i)),
      secret: Uint8List.fromList(List.generate(64, (i) => i * 2)),
      messageRandomizer: Uint8List.fromList(List.generate(32, (i) => i + 64)),
      requestId: 'req-$electionId',
      status: BlindTokenStatus.received,
      unblindedSignature: Uint8List.fromList(List.generate(64, (i) => i * 3)),
    );
  }

  group('TokenStorageService', () {
    test('saveToken and getToken roundtrip', () async {
      final token = makeToken('e001');
      await TokenStorageService.saveToken(token);

      final loaded = await TokenStorageService.getToken('e001');
      expect(loaded, isNotNull);
      expect(loaded!.electionId, equals('e001'));
      expect(loaded.nonce, equals(token.nonce));
      expect(loaded.unblindedSignature, equals(token.unblindedSignature));
      expect(loaded.status, equals(BlindTokenStatus.received));
    });

    test('getToken returns null for unknown election', () async {
      final loaded = await TokenStorageService.getToken('unknown');
      expect(loaded, isNull);
    });

    test('hasToken returns correct values', () async {
      expect(await TokenStorageService.hasToken('e002'), isFalse);

      await TokenStorageService.saveToken(makeToken('e002'));
      expect(await TokenStorageService.hasToken('e002'), isTrue);
    });

    test('deleteToken removes the token', () async {
      await TokenStorageService.saveToken(makeToken('e003'));
      expect(await TokenStorageService.hasToken('e003'), isTrue);

      await TokenStorageService.deleteToken('e003');
      expect(await TokenStorageService.hasToken('e003'), isFalse);
      expect(await TokenStorageService.getToken('e003'), isNull);
    });

    test('saveToken overwrites existing token', () async {
      final token1 = makeToken('e004');
      await TokenStorageService.saveToken(token1);

      final token2 = makeToken('e004');
      token2.status = BlindTokenStatus.error;
      token2.errorMessage = 'test error';
      await TokenStorageService.saveToken(token2);

      final loaded = await TokenStorageService.getToken('e004');
      expect(loaded, isNotNull);
      expect(loaded!.status, equals(BlindTokenStatus.error));
      expect(loaded.errorMessage, equals('test error'));
    });

    test('getAllTokens returns tokens for given election IDs', () async {
      await TokenStorageService.saveToken(makeToken('e010'));
      await TokenStorageService.saveToken(makeToken('e011'));

      final tokens = await TokenStorageService.getAllTokens([
        'e010',
        'e011',
        'e012',
      ]);
      expect(tokens.length, equals(2));
      expect(tokens.map((t) => t.electionId), containsAll(['e010', 'e011']));
    });
  });
}
