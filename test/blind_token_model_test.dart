import 'dart:typed_data';

import 'package:criptocracia_app/models/blind_token.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BlindToken', () {
    late BlindToken token;

    setUp(() {
      token = BlindToken(
        electionId: 'f5f7',
        nonce: Uint8List.fromList(List.generate(32, (i) => i)),
        hashedNonce: Uint8List.fromList(List.generate(32, (i) => i + 32)),
        blindedMessage: Uint8List.fromList(List.generate(256, (i) => i % 256)),
        secret: Uint8List.fromList(List.generate(256, (i) => (i * 3) % 256)),
        messageRandomizer: Uint8List.fromList(List.generate(32, (i) => i + 64)),
        requestId: 'test-req-123',
        status: BlindTokenStatus.pending,
      );
    });

    test('isReady returns false when pending', () {
      expect(token.isReady, isFalse);
    });

    test('isReady returns true when received with signature', () {
      token.status = BlindTokenStatus.received;
      token.unblindedSignature = Uint8List.fromList(
        List.generate(256, (i) => i),
      );
      expect(token.isReady, isTrue);
    });

    test('isReady returns false when received but no signature', () {
      token.status = BlindTokenStatus.received;
      expect(token.isReady, isFalse);
    });

    group('serialization', () {
      test('toMap / fromMap roundtrip preserves all fields', () {
        token.status = BlindTokenStatus.received;
        token.blindSignature = Uint8List.fromList(
          List.generate(256, (i) => (i * 7) % 256),
        );
        token.unblindedSignature = Uint8List.fromList(
          List.generate(256, (i) => (i * 11) % 256),
        );
        token.errorMessage = null;

        final map = token.toMap();
        final restored = BlindToken.fromMap(map);

        expect(restored.electionId, equals(token.electionId));
        expect(restored.nonce, equals(token.nonce));
        expect(restored.hashedNonce, equals(token.hashedNonce));
        expect(restored.blindedMessage, equals(token.blindedMessage));
        expect(restored.secret, equals(token.secret));
        expect(restored.messageRandomizer, equals(token.messageRandomizer));
        expect(restored.blindSignature, equals(token.blindSignature));
        expect(restored.unblindedSignature, equals(token.unblindedSignature));
        expect(restored.status, equals(BlindTokenStatus.received));
        expect(restored.requestId, equals(token.requestId));
      });

      test('toJson / fromJson roundtrip', () {
        final json = token.toJson();
        final restored = BlindToken.fromJson(json);

        expect(restored.electionId, equals(token.electionId));
        expect(restored.nonce, equals(token.nonce));
        expect(restored.status, equals(BlindTokenStatus.pending));
      });

      test('handles null optional fields', () {
        final tokenNoRandomizer = BlindToken(
          electionId: 'abc1',
          nonce: Uint8List(32),
          hashedNonce: Uint8List(32),
          blindedMessage: Uint8List(256),
          secret: Uint8List(256),
          messageRandomizer: null,
          requestId: 'req-456',
        );

        final map = tokenNoRandomizer.toMap();
        expect(map.containsKey('message_randomizer'), isFalse);
        expect(map.containsKey('blind_signature'), isFalse);
        expect(map.containsKey('unblinded_signature'), isFalse);
        expect(map.containsKey('error_message'), isFalse);

        final restored = BlindToken.fromMap(map);
        expect(restored.messageRandomizer, isNull);
        expect(restored.blindSignature, isNull);
        expect(restored.unblindedSignature, isNull);
        expect(restored.errorMessage, isNull);
      });

      test('serializes error status and message', () {
        token.status = BlindTokenStatus.error;
        token.errorMessage = 'Something went wrong';

        final map = token.toMap();
        expect(map['status'], equals('error'));
        expect(map['error_message'], equals('Something went wrong'));

        final restored = BlindToken.fromMap(map);
        expect(restored.status, equals(BlindTokenStatus.error));
        expect(restored.errorMessage, equals('Something went wrong'));
      });

      test('all status values survive roundtrip', () {
        for (final status in BlindTokenStatus.values) {
          token.status = status;
          final map = token.toMap();
          final restored = BlindToken.fromMap(map);
          expect(restored.status, equals(status));
        }
      });
    });

    test('toString includes election ID and status', () {
      expect(token.toString(), contains('f5f7'));
      expect(token.toString(), contains('pending'));
    });
  });
}
