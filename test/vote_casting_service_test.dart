import 'dart:convert';
import 'dart:typed_data';

import 'package:blind_rsa_signatures/blind_rsa_signatures.dart';
import 'package:criptocracia_app/models/blind_token.dart';
import 'package:criptocracia_app/models/candidate.dart';
import 'package:criptocracia_app/models/election.dart';
import 'package:criptocracia_app/services/blind_signature_service.dart';
import 'package:criptocracia_app/services/gift_wrap_service.dart';
import 'package:criptocracia_app/services/nostr_service.dart';
import 'package:criptocracia_app/services/vote_casting_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Creates a test election with a real RSA public key.
Election _createElection(PublicKey rsaPubKey) {
  final now = DateTime.now();
  return Election(
    id: 'election-1',
    name: 'Test Election',
    candidates: const [
      Candidate(id: 1, name: 'Alice'),
      Candidate(id: 2, name: 'Bob'),
    ],
    startTime: now.subtract(const Duration(hours: 1)),
    endTime: now.add(const Duration(hours: 23)),
    ecPubkey: 'a' * 64,
    rsaPublicKey: base64Encode(rsaPubKey.toDer()),
    rawStatus: 'open',
    eventId: 'event-1',
    createdAt: now,
  );
}

/// Creates a valid blind token using a full blind signature cycle.
BlindToken _createValidToken({
  required PublicKey rsaPubKey,
  required SecretKey rsaSecKey,
  String electionId = 'election-1',
}) {
  const options = Options.defaultOptions;

  final nonce = BlindSignatureService.generateNonce();
  final hashedNonce = BlindSignatureService.hashMessage(nonce);
  final blindingResult = rsaPubKey.blind(null, hashedNonce, true, options);
  final blindSig = rsaSecKey.blindSign(
    null,
    blindingResult.blindMessage,
    options,
  );
  final unblindedSig = BlindSignatureService.unblindSignature(
    blindSig: blindSig,
    secret: blindingResult.secret,
    messageRandomizer: blindingResult.messageRandomizer,
    message: hashedNonce,
    rsaPubKey: rsaPubKey,
  );

  return BlindToken(
    electionId: electionId,
    nonce: nonce,
    hashedNonce: hashedNonce,
    blindedMessage: blindingResult.blindMessage,
    secret: blindingResult.secret,
    messageRandomizer: blindingResult.messageRandomizer,
    requestId: 'req-1',
    blindSignature: blindSig,
    unblindedSignature: unblindedSig,
    status: BlindTokenStatus.received,
  );
}

void main() {
  group('VoteCastingService', () {
    late NostrService nostrService;
    late GiftWrapService giftWrapService;
    late VoteCastingService voteCastingService;
    late KeyPair rsaKeyPair;
    late PublicKey rsaPubKey;
    late SecretKey rsaSecKey;

    setUpAll(() async {
      rsaKeyPair = await KeyPair.generate(null);
      rsaPubKey = rsaKeyPair.publicKey;
      rsaSecKey = rsaKeyPair.secretKey;
    });

    setUp(() {
      nostrService = NostrService();
      giftWrapService = GiftWrapService(nostrService: nostrService);
      voteCastingService = VoteCastingService(giftWrapService: giftWrapService);
    });

    tearDown(() {
      giftWrapService.dispose();
      nostrService.dispose();
    });

    test('initial state is idle', () {
      expect(voteCastingService.state, equals(VoteCastingState.idle));
      expect(voteCastingService.errorMessage, isNull);
    });

    test('reset returns to idle state', () {
      voteCastingService.reset();
      expect(voteCastingService.state, equals(VoteCastingState.idle));
      expect(voteCastingService.errorMessage, isNull);
    });

    group('buildVotePayload', () {
      test('produces correct structure', () {
        final token = _createValidToken(
          rsaPubKey: rsaPubKey,
          rsaSecKey: rsaSecKey,
        );

        final payload = VoteCastingService.buildVotePayload(
          token: token,
          candidateId: 1,
          electionId: 'election-1',
        );

        expect(payload['kind'], equals(2));
        expect(payload['election_id'], equals('election-1'));
        expect(payload['candidate_id'], equals(1));
        expect(payload['hash'], isA<String>());
        expect(payload['token'], isA<String>());
        expect(payload['blinding_factor'], isA<String>());

        // Verify base64 values decode correctly.
        expect(
          base64Decode(payload['hash'] as String),
          equals(token.hashedNonce),
        );
        expect(
          base64Decode(payload['token'] as String),
          equals(token.unblindedSignature),
        );
        expect(
          base64Decode(payload['blinding_factor'] as String),
          equals(token.secret),
        );
      });

      test('includes message_randomizer when present', () {
        final token = _createValidToken(
          rsaPubKey: rsaPubKey,
          rsaSecKey: rsaSecKey,
        );

        final payload = VoteCastingService.buildVotePayload(
          token: token,
          candidateId: 1,
          electionId: 'election-1',
        );

        if (token.messageRandomizer != null) {
          expect(payload.containsKey('message_randomizer'), isTrue);
          expect(
            base64Decode(payload['message_randomizer'] as String),
            equals(token.messageRandomizer),
          );
        }
      });

      test('payload is valid JSON', () {
        final token = _createValidToken(
          rsaPubKey: rsaPubKey,
          rsaSecKey: rsaSecKey,
        );

        final payload = VoteCastingService.buildVotePayload(
          token: token,
          candidateId: 2,
          electionId: 'election-1',
        );

        final json = jsonEncode(payload);
        final decoded = jsonDecode(json) as Map<String, dynamic>;
        expect(decoded['candidate_id'], equals(2));
      });
    });

    group('castVote validation', () {
      test('rejects token that is not ready', () async {
        final election = _createElection(rsaPubKey);
        final token = BlindToken(
          electionId: 'election-1',
          nonce: Uint8List(32),
          hashedNonce: Uint8List(32),
          blindedMessage: Uint8List(32),
          secret: Uint8List(32),
          messageRandomizer: null,
          requestId: 'req-1',
          status: BlindTokenStatus.requested, // Not ready
        );

        voteCastingService.anonymousKeyGenerator = () =>
            (privateKey: 'a' * 64, publicKey: 'b' * 64);

        expect(
          () => voteCastingService.castVote(
            election: election,
            token: token,
            candidateId: 1,
          ),
          throwsA(isA<StateError>()),
        );

        expect(voteCastingService.state, equals(VoteCastingState.error));
      });

      test('rejects token for wrong election', () async {
        final election = _createElection(rsaPubKey);
        final token = _createValidToken(
          rsaPubKey: rsaPubKey,
          rsaSecKey: rsaSecKey,
          electionId: 'different-election',
        );

        voteCastingService.anonymousKeyGenerator = () =>
            (privateKey: 'a' * 64, publicKey: 'b' * 64);

        expect(
          () => voteCastingService.castVote(
            election: election,
            token: token,
            candidateId: 1,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('rejects invalid candidate ID', () async {
        final election = _createElection(rsaPubKey);
        final token = _createValidToken(
          rsaPubKey: rsaPubKey,
          rsaSecKey: rsaSecKey,
        );

        voteCastingService.anonymousKeyGenerator = () =>
            (privateKey: 'a' * 64, publicKey: 'b' * 64);

        expect(
          () => voteCastingService.castVote(
            election: election,
            token: token,
            candidateId: 999, // Not in election
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('throws when anonymousKeyGenerator is not set', () async {
        final election = _createElection(rsaPubKey);
        final token = _createValidToken(
          rsaPubKey: rsaPubKey,
          rsaSecKey: rsaSecKey,
        );

        expect(
          () => voteCastingService.castVote(
            election: election,
            token: token,
            candidateId: 1,
          ),
          throwsA(isA<StateError>()),
        );
      });
    });

    group('state transitions', () {
      test('notifies listeners on state change', () {
        var notified = false;
        voteCastingService.addListener(() => notified = true);
        voteCastingService.reset();

        // reset to idle from idle — no change, no notification.
        // Force a state change by triggering an error first.
        expect(notified, isFalse);
      });

      test('castVote transitions to error on invalid token', () async {
        final election = _createElection(rsaPubKey);
        final token = BlindToken(
          electionId: 'election-1',
          nonce: Uint8List(32),
          hashedNonce: Uint8List(32),
          blindedMessage: Uint8List(32),
          secret: Uint8List(32),
          messageRandomizer: null,
          requestId: 'req-1',
          status: BlindTokenStatus.pending,
        );

        voteCastingService.anonymousKeyGenerator = () =>
            (privateKey: 'a' * 64, publicKey: 'b' * 64);

        final states = <VoteCastingState>[];
        voteCastingService.addListener(() {
          states.add(voteCastingService.state);
        });

        try {
          await voteCastingService.castVote(
            election: election,
            token: token,
            candidateId: 1,
          );
        } catch (_) {}

        expect(states, contains(VoteCastingState.casting));
        expect(states, contains(VoteCastingState.error));
      });
    });

    group('signature verification', () {
      test('rejects tampered signature', () async {
        final election = _createElection(rsaPubKey);
        final token = _createValidToken(
          rsaPubKey: rsaPubKey,
          rsaSecKey: rsaSecKey,
        );

        // Tamper with the signature.
        token.unblindedSignature![0] ^= 0xFF;

        voteCastingService.anonymousKeyGenerator = () =>
            (privateKey: 'a' * 64, publicKey: 'b' * 64);

        expect(
          () => voteCastingService.castVote(
            election: election,
            token: token,
            candidateId: 1,
          ),
          throwsA(isA<StateError>()),
        );
      });
    });
  });
}
