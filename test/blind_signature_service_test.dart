import 'dart:typed_data';

import 'package:blind_rsa_signatures/blind_rsa_signatures.dart';
import 'package:criptocracia_app/services/blind_signature_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BlindSignatureService — cryptographic helpers', () {
    late KeyPair keyPair;
    late PublicKey publicKey;
    late SecretKey secretKey;

    setUpAll(() async {
      keyPair = await KeyPair.generate(null);
      publicKey = keyPair.publicKey;
      secretKey = keyPair.secretKey;
    });

    test('generateNonce returns 32 random bytes', () {
      final nonce1 = BlindSignatureService.generateNonce();
      final nonce2 = BlindSignatureService.generateNonce();

      expect(nonce1.length, equals(32));
      expect(nonce2.length, equals(32));
      // Extremely unlikely to be equal.
      expect(nonce1, isNot(equals(nonce2)));
    });

    test('hashMessage produces 32-byte SHA-256 digest', () {
      final data = Uint8List.fromList([1, 2, 3, 4, 5]);
      final hash = BlindSignatureService.hashMessage(data);

      expect(hash.length, equals(32));

      // Same input → same output.
      final hash2 = BlindSignatureService.hashMessage(data);
      expect(hash, equals(hash2));

      // Different input → different output.
      final different = BlindSignatureService.hashMessage(
        Uint8List.fromList([5, 4, 3]),
      );
      expect(hash, isNot(equals(different)));
    });

    test('full blind → sign → unblind → verify cycle', () {
      final nonce = BlindSignatureService.generateNonce();
      final hashedNonce = BlindSignatureService.hashMessage(nonce);
      const options = Options.defaultOptions;

      // Client blinds the message.
      final blindingResult = publicKey.blind(null, hashedNonce, true, options);

      // Server (EC) signs the blinded message.
      final blindSig = secretKey.blindSign(
        null,
        blindingResult.blindMessage,
        options,
      );

      // Client unblinds.
      final unblindedSig = BlindSignatureService.unblindSignature(
        blindSig: blindSig,
        secret: blindingResult.secret,
        messageRandomizer: blindingResult.messageRandomizer,
        message: hashedNonce,
        rsaPubKey: publicKey,
      );

      expect(unblindedSig, isNotEmpty);

      // Anyone can verify.
      final valid = BlindSignatureService.verifyToken(
        message: hashedNonce,
        signature: unblindedSig,
        messageRandomizer: blindingResult.messageRandomizer,
        rsaPubKey: publicKey,
      );
      expect(valid, isTrue);
    });

    test('verifyToken rejects tampered signature', () {
      final nonce = BlindSignatureService.generateNonce();
      final hashedNonce = BlindSignatureService.hashMessage(nonce);
      const options = Options.defaultOptions;

      final blindingResult = publicKey.blind(null, hashedNonce, true, options);
      final blindSig = secretKey.blindSign(
        null,
        blindingResult.blindMessage,
        options,
      );
      final unblindedSig = BlindSignatureService.unblindSignature(
        blindSig: blindSig,
        secret: blindingResult.secret,
        messageRandomizer: blindingResult.messageRandomizer,
        message: hashedNonce,
        rsaPubKey: publicKey,
      );

      // Tamper with one byte.
      final tampered = Uint8List.fromList(unblindedSig);
      tampered[0] ^= 0xFF;

      final valid = BlindSignatureService.verifyToken(
        message: hashedNonce,
        signature: tampered,
        messageRandomizer: blindingResult.messageRandomizer,
        rsaPubKey: publicKey,
      );
      expect(valid, isFalse);
    });

    test('verifyToken rejects wrong message', () {
      final nonce = BlindSignatureService.generateNonce();
      final hashedNonce = BlindSignatureService.hashMessage(nonce);
      const options = Options.defaultOptions;

      final blindingResult = publicKey.blind(null, hashedNonce, true, options);
      final blindSig = secretKey.blindSign(
        null,
        blindingResult.blindMessage,
        options,
      );
      final unblindedSig = BlindSignatureService.unblindSignature(
        blindSig: blindSig,
        secret: blindingResult.secret,
        messageRandomizer: blindingResult.messageRandomizer,
        message: hashedNonce,
        rsaPubKey: publicKey,
      );

      // Wrong message.
      final wrongMessage = BlindSignatureService.hashMessage(
        BlindSignatureService.generateNonce(),
      );

      final valid = BlindSignatureService.verifyToken(
        message: wrongMessage,
        signature: unblindedSig,
        messageRandomizer: blindingResult.messageRandomizer,
        rsaPubKey: publicKey,
      );
      expect(valid, isFalse);
    });

    test('unblindSignature works with RSA key loaded from PEM', () async {
      // Generate a fresh key pair, export to PEM, re-import.
      final kp = await KeyPair.generate(null);
      final pem = kp.publicKeyPem;
      final reimported = PublicKey.fromPem(pem);

      final nonce = BlindSignatureService.generateNonce();
      final hashedNonce = BlindSignatureService.hashMessage(nonce);
      const options = Options.defaultOptions;

      final blindingResult = reimported.blind(null, hashedNonce, true, options);
      final blindSig = kp.secretKey.blindSign(
        null,
        blindingResult.blindMessage,
        options,
      );

      final unblindedSig = BlindSignatureService.unblindSignature(
        blindSig: blindSig,
        secret: blindingResult.secret,
        messageRandomizer: blindingResult.messageRandomizer,
        message: hashedNonce,
        rsaPubKey: reimported,
      );

      final valid = BlindSignatureService.verifyToken(
        message: hashedNonce,
        signature: unblindedSig,
        messageRandomizer: blindingResult.messageRandomizer,
        rsaPubKey: reimported,
      );
      expect(valid, isTrue);
    });

    test('unblindSignature works with RSA key loaded from DER', () async {
      final kp = await KeyPair.generate(null);
      final der = kp.publicKeyDer;
      final reimported = PublicKey.fromDer(der);

      final nonce = BlindSignatureService.generateNonce();
      final hashedNonce = BlindSignatureService.hashMessage(nonce);
      const options = Options.defaultOptions;

      final blindingResult = reimported.blind(null, hashedNonce, true, options);
      final blindSig = kp.secretKey.blindSign(
        null,
        blindingResult.blindMessage,
        options,
      );

      final unblindedSig = BlindSignatureService.unblindSignature(
        blindSig: blindSig,
        secret: blindingResult.secret,
        messageRandomizer: blindingResult.messageRandomizer,
        message: hashedNonce,
        rsaPubKey: reimported,
      );

      final valid = BlindSignatureService.verifyToken(
        message: hashedNonce,
        signature: unblindedSig,
        messageRandomizer: blindingResult.messageRandomizer,
        rsaPubKey: reimported,
      );
      expect(valid, isTrue);
    });
  });
}
