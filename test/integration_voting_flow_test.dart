import 'dart:convert';
import 'dart:typed_data';

import 'package:blind_rsa_signatures/blind_rsa_signatures.dart';
import 'package:criptocracia_app/config/constants.dart';
import 'package:criptocracia_app/models/blind_token.dart';
import 'package:criptocracia_app/models/candidate.dart';
import 'package:criptocracia_app/models/election.dart';
import 'package:criptocracia_app/models/election_result.dart';
import 'package:criptocracia_app/models/nostr_event.dart';
import 'package:criptocracia_app/services/blind_signature_service.dart';
import 'package:criptocracia_app/services/vote_casting_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/mock_ec_server.dart';

/// Integration tests for the full voting flow.
///
/// These tests wire together the blind signature protocol, vote casting,
/// and results verification using a [MockEcServer] that simulates the
/// Electoral Commission's behavior. No real Nostr relays are used.
///
/// ## Flow tested
///
/// 1. EC publishes an election (Kind 35000)
/// 2. Voter discovers the election and requests a blind token
/// 3. EC signs the blinded message and returns it
/// 4. Voter unblinds the signature to obtain a valid token
/// 5. Voter casts a vote using an anonymous identity
/// 6. EC receives the vote and publishes results (Kind 35001)
/// 7. Results are tallied and verified
void main() {
  late KeyPair rsaKeyPair;
  late MockEcServer ecServer;

  setUpAll(() async {
    rsaKeyPair = await KeyPair.generate(null);
  });

  setUp(() {
    ecServer = MockEcServer(rsaKeyPair: rsaKeyPair);
  });

  tearDown(() {
    ecServer.dispose();
  });

  group('End-to-end voting flow', () {
    late Election election;

    setUp(() {
      final now = DateTime.now();
      final result = ecServer.createElection(
        id: 'election-001',
        name: 'Presidential Election 2025',
        candidates: const [
          Candidate(id: 1, name: 'Alice'),
          Candidate(id: 2, name: 'Bob'),
          Candidate(id: 3, name: 'Charlie'),
        ],
        startTime: now.subtract(const Duration(hours: 1)),
        endTime: now.add(const Duration(hours: 23)),
      );
      election = result.election;
    });

    test('discover election from Kind 35000 event', () {
      final result = ecServer.createElection(
        id: 'election-disc',
        name: 'Discovery Test',
        candidates: const [
          Candidate(id: 1, name: 'X'),
          Candidate(id: 2, name: 'Y'),
        ],
        startTime: DateTime.now().subtract(const Duration(hours: 1)),
        endTime: DateTime.now().add(const Duration(hours: 23)),
      );

      // Verify the event can be parsed back into an Election.
      final parsed = Election.fromEvent(result.event);
      expect(parsed, isNotNull);
      expect(parsed!.id, equals('election-disc'));
      expect(parsed.name, equals('Discovery Test'));
      expect(parsed.candidates, hasLength(2));
      expect(parsed.ecPubkey, equals(ecServer.ecPubkey));
      expect(parsed.rsaPublicKey, equals(ecServer.rsaPublicKeyBase64));
      expect(parsed.status, equals(ElectionStatus.active));
    });

    test(
      'full flow: request token → unblind → cast vote → verify results',
      () async {
        // Step 1: Generate nonce and blind the message.
        final nonce = BlindSignatureService.generateNonce();
        final hashedNonce = BlindSignatureService.hashMessage(nonce);
        final rsaPubKey = PublicKey.fromDer(
          base64Decode(election.rsaPublicKey),
        );
        const options = Options.defaultOptions;

        final blindingResult = rsaPubKey.blind(
          null,
          hashedNonce,
          true,
          options,
        );

        // Step 2: Build the token request message.
        const requestId = 'test-request-001';
        final requestMessage = jsonEncode({
          'id': requestId,
          'kind': 1,
          'payload': base64Encode(blindingResult.blindMessage),
          'election_id': election.id,
        });

        // Step 3: EC processes the request and returns a blind signature.
        final response = await ecServer.handleTokenRequest(requestMessage);
        expect(response, isNotNull);

        final responseData =
            jsonDecode(response!.content) as Map<String, dynamic>;
        expect(responseData['id'], equals(requestId));
        final blindSig = base64Decode(responseData['payload'] as String);

        // Step 4: Unblind the signature.
        final unblindedSig = BlindSignatureService.unblindSignature(
          blindSig: blindSig,
          secret: blindingResult.secret,
          messageRandomizer: blindingResult.messageRandomizer,
          message: hashedNonce,
          rsaPubKey: rsaPubKey,
        );

        // Step 5: Verify the token.
        final isValid = BlindSignatureService.verifyToken(
          message: hashedNonce,
          signature: unblindedSig,
          messageRandomizer: blindingResult.messageRandomizer,
          rsaPubKey: rsaPubKey,
        );
        expect(isValid, isTrue);

        // Step 6: Build a BlindToken for vote casting.
        final token = BlindToken(
          electionId: election.id,
          nonce: nonce,
          hashedNonce: hashedNonce,
          blindedMessage: blindingResult.blindMessage,
          secret: blindingResult.secret,
          messageRandomizer: blindingResult.messageRandomizer,
          requestId: requestId,
          blindSignature: blindSig,
          unblindedSignature: unblindedSig,
          status: BlindTokenStatus.received,
        );

        expect(token.isReady, isTrue);

        // Step 7: Build the vote payload.
        final votePayload = VoteCastingService.buildVotePayload(
          token: token,
          candidateId: 1,
          electionId: election.id,
        );

        expect(votePayload['kind'], equals(2));
        expect(votePayload['election_id'], equals(election.id));
        expect(votePayload['candidate_id'], equals(1));
        expect(votePayload['hash'], isNotEmpty);
        expect(votePayload['token'], isNotEmpty);
        expect(votePayload['blinding_factor'], isNotEmpty);

        // Step 8: EC receives and validates the vote.
        final voteAccepted = ecServer.handleVote(
          jsonEncode(votePayload),
          electionId: election.id,
        );
        expect(voteAccepted, isTrue);

        // Step 9: Verify results.
        final votes = ecServer.votesForElection(election.id);
        expect(votes, hasLength(1));
        expect(votes.first['candidate_id'], equals(1));
      },
    );

    test(
      'multiple voters cast votes and results are tallied correctly',
      () async {
        final rsaPubKey = PublicKey.fromDer(
          base64Decode(election.rsaPublicKey),
        );

        // Simulate 5 voters: 3 for Alice (id=1), 2 for Bob (id=2).
        final voteCandidates = [1, 1, 2, 1, 2];

        for (var i = 0; i < voteCandidates.length; i++) {
          final nonce = BlindSignatureService.generateNonce();
          final hashedNonce = BlindSignatureService.hashMessage(nonce);
          const options = Options.defaultOptions;

          final blindingResult = rsaPubKey.blind(
            null,
            hashedNonce,
            true,
            options,
          );

          final requestMessage = jsonEncode({
            'id': 'request-$i',
            'kind': 1,
            'payload': base64Encode(blindingResult.blindMessage),
            'election_id': election.id,
          });

          final response = await ecServer.handleTokenRequest(requestMessage);
          expect(response, isNotNull, reason: 'Voter $i should get a response');

          final responseData =
              jsonDecode(response!.content) as Map<String, dynamic>;
          final blindSig = base64Decode(responseData['payload'] as String);

          final unblindedSig = BlindSignatureService.unblindSignature(
            blindSig: blindSig,
            secret: blindingResult.secret,
            messageRandomizer: blindingResult.messageRandomizer,
            message: hashedNonce,
            rsaPubKey: rsaPubKey,
          );

          final token = BlindToken(
            electionId: election.id,
            nonce: nonce,
            hashedNonce: hashedNonce,
            blindedMessage: blindingResult.blindMessage,
            secret: blindingResult.secret,
            messageRandomizer: blindingResult.messageRandomizer,
            requestId: 'request-$i',
            blindSignature: blindSig,
            unblindedSignature: unblindedSig,
            status: BlindTokenStatus.received,
          );

          final votePayload = VoteCastingService.buildVotePayload(
            token: token,
            candidateId: voteCandidates[i],
            electionId: election.id,
          );

          ecServer.handleVote(jsonEncode(votePayload), electionId: election.id);
        }

        // Verify tallies.
        final votes = ecServer.votesForElection(election.id);
        expect(votes, hasLength(5));
        expect(ecServer.issuedTokenCount, equals(5));

        // Build results using the ElectionResult model.
        final tallies = <int, int>{};
        for (final vote in votes) {
          final cid = vote['candidate_id'] as int;
          tallies[cid] = (tallies[cid] ?? 0) + 1;
        }

        final results = ElectionResult.fromTallies(
          electionId: election.id,
          tallies: tallies,
          candidates: election.candidates,
          lastUpdated: DateTime.now(),
        );

        expect(results.totalVotes, equals(5));
        expect(results.leader, isNotNull);
        expect(results.leader!.candidate.name, equals('Alice'));
        expect(results.leader!.voteCount, equals(3));

        // Verify percentages.
        final aliceResult = results.candidateResults.firstWhere(
          (r) => r.candidate.id == 1,
        );
        expect(aliceResult.percentage, equals(60.0));

        final bobResult = results.candidateResults.firstWhere(
          (r) => r.candidate.id == 2,
        );
        expect(bobResult.percentage, equals(40.0));

        final charlieResult = results.candidateResults.firstWhere(
          (r) => r.candidate.id == 3,
        );
        expect(charlieResult.voteCount, equals(0));
        expect(charlieResult.percentage, equals(0.0));
      },
    );

    test('vote events stream enables real-time results tracking', () async {
      final rsaPubKey = PublicKey.fromDer(base64Decode(election.rsaPublicKey));

      // Collect vote events from the EC.
      final receivedEvents = <NostrEventModel>[];
      final subscription = ecServer.voteEvents.listen(receivedEvents.add);

      // Cast two votes.
      for (final candidateId in [1, 2]) {
        final nonce = BlindSignatureService.generateNonce();
        final hashedNonce = BlindSignatureService.hashMessage(nonce);
        const options = Options.defaultOptions;
        final blindingResult = rsaPubKey.blind(
          null,
          hashedNonce,
          true,
          options,
        );

        final response = await ecServer.handleTokenRequest(
          jsonEncode({
            'id': 'stream-req-$candidateId',
            'kind': 1,
            'payload': base64Encode(blindingResult.blindMessage),
            'election_id': election.id,
          }),
        );

        final responseData =
            jsonDecode(response!.content) as Map<String, dynamic>;
        final blindSig = base64Decode(responseData['payload'] as String);

        final unblindedSig = BlindSignatureService.unblindSignature(
          blindSig: blindSig,
          secret: blindingResult.secret,
          messageRandomizer: blindingResult.messageRandomizer,
          message: hashedNonce,
          rsaPubKey: rsaPubKey,
        );

        final token = BlindToken(
          electionId: election.id,
          nonce: nonce,
          hashedNonce: hashedNonce,
          blindedMessage: blindingResult.blindMessage,
          secret: blindingResult.secret,
          messageRandomizer: blindingResult.messageRandomizer,
          requestId: 'stream-req-$candidateId',
          blindSignature: blindSig,
          unblindedSignature: unblindedSig,
          status: BlindTokenStatus.received,
        );

        final votePayload = VoteCastingService.buildVotePayload(
          token: token,
          candidateId: candidateId,
          electionId: election.id,
        );

        ecServer.handleVote(jsonEncode(votePayload), electionId: election.id);
      }

      // Allow stream events to propagate.
      await Future<void>.delayed(Duration.zero);

      expect(receivedEvents, hasLength(2));
      expect(receivedEvents[0].kind, equals(AppConstants.voteEventKind));
      expect(receivedEvents[1].kind, equals(AppConstants.voteEventKind));

      // Verify the events can be parsed for results.
      final cid1 = ElectionResult.parseCandidateId(receivedEvents[0]);
      final cid2 = ElectionResult.parseCandidateId(receivedEvents[1]);
      expect(cid1, equals(1));
      expect(cid2, equals(2));

      // Verify election ID from tags.
      final eid1 = ElectionResult.parseElectionId(receivedEvents[0]);
      expect(eid1, equals(election.id));

      await subscription.cancel();
    });
  });

  group('Error scenarios', () {
    late Election election;

    setUp(() {
      final now = DateTime.now();
      final result = ecServer.createElection(
        id: 'election-err',
        name: 'Error Test Election',
        candidates: const [
          Candidate(id: 1, name: 'Alice'),
          Candidate(id: 2, name: 'Bob'),
        ],
        startTime: now.subtract(const Duration(hours: 1)),
        endTime: now.add(const Duration(hours: 23)),
      );
      election = result.election;
    });

    test(
      'double token request with same blinded message is rejected',
      () async {
        final nonce = BlindSignatureService.generateNonce();
        final hashedNonce = BlindSignatureService.hashMessage(nonce);
        final rsaPubKey = PublicKey.fromDer(
          base64Decode(election.rsaPublicKey),
        );

        final blindingResult = rsaPubKey.blind(
          null,
          hashedNonce,
          true,
          Options.defaultOptions,
        );

        final payload = base64Encode(blindingResult.blindMessage);
        final request1 = jsonEncode({
          'id': 'dup-1',
          'kind': 1,
          'payload': payload,
          'election_id': election.id,
        });

        // First request succeeds.
        final response1 = await ecServer.handleTokenRequest(request1);
        expect(response1, isNotNull);
        final data1 = jsonDecode(response1!.content) as Map<String, dynamic>;
        expect(data1.containsKey('error'), isFalse);

        // Second request with the same blinded message is rejected.
        final request2 = jsonEncode({
          'id': 'dup-2',
          'kind': 1,
          'payload': payload,
          'election_id': election.id,
        });
        final response2 = await ecServer.handleTokenRequest(request2);
        expect(response2, isNotNull);
        final data2 = jsonDecode(response2!.content) as Map<String, dynamic>;
        expect(data2['error'], equals('Token already issued'));
      },
    );

    test('token request for nonexistent election is rejected', () async {
      final request = jsonEncode({
        'id': 'no-election',
        'kind': 1,
        'payload': base64Encode(Uint8List(256)),
        'election_id': 'nonexistent',
      });

      final response = await ecServer.handleTokenRequest(request);
      expect(response, isNotNull);
      final data = jsonDecode(response!.content) as Map<String, dynamic>;
      expect(data['error'], equals('Election not found'));
    });

    test('network failure returns null response', () async {
      ecServer.simulateNetworkFailure = true;

      final request = jsonEncode({
        'id': 'net-fail',
        'kind': 1,
        'payload': base64Encode(Uint8List(256)),
        'election_id': election.id,
      });

      final response = await ecServer.handleTokenRequest(request);
      expect(response, isNull);
    });

    test('invalid signature fails verification', () async {
      ecServer.simulateInvalidSignature = true;

      final nonce = BlindSignatureService.generateNonce();
      final hashedNonce = BlindSignatureService.hashMessage(nonce);
      final rsaPubKey = PublicKey.fromDer(base64Decode(election.rsaPublicKey));

      final blindingResult = rsaPubKey.blind(
        null,
        hashedNonce,
        true,
        Options.defaultOptions,
      );

      final request = jsonEncode({
        'id': 'invalid-sig',
        'kind': 1,
        'payload': base64Encode(blindingResult.blindMessage),
        'election_id': election.id,
      });

      final response = await ecServer.handleTokenRequest(request);
      expect(response, isNotNull);

      final responseData =
          jsonDecode(response!.content) as Map<String, dynamic>;
      final blindSig = base64Decode(responseData['payload'] as String);

      // Unblinding should fail or produce an invalid signature.
      expect(
        () => BlindSignatureService.unblindSignature(
          blindSig: blindSig,
          secret: blindingResult.secret,
          messageRandomizer: blindingResult.messageRandomizer,
          message: hashedNonce,
          rsaPubKey: rsaPubKey,
        ),
        throwsA(anything),
      );
    });

    test('vote for invalid candidate is rejected', () {
      final votePayload = jsonEncode({
        'kind': 2,
        'election_id': election.id,
        'candidate_id': 999,
        'hash': base64Encode(Uint8List(32)),
        'token': base64Encode(Uint8List(32)),
        'blinding_factor': base64Encode(Uint8List(32)),
      });

      final accepted = ecServer.handleVote(
        votePayload,
        electionId: election.id,
      );
      expect(accepted, isFalse);
    });

    test('vote for nonexistent election is rejected', () {
      final votePayload = jsonEncode({
        'kind': 2,
        'election_id': 'nonexistent',
        'candidate_id': 1,
        'hash': base64Encode(Uint8List(32)),
        'token': base64Encode(Uint8List(32)),
        'blinding_factor': base64Encode(Uint8List(32)),
      });

      final accepted = ecServer.handleVote(votePayload);
      expect(accepted, isFalse);
    });

    test('vote payload requires unblinded signature', () {
      final token = BlindToken(
        electionId: election.id,
        nonce: Uint8List(32),
        hashedNonce: Uint8List(32),
        blindedMessage: Uint8List(32),
        secret: Uint8List(32),
        messageRandomizer: null,
        requestId: 'no-sig',
        status: BlindTokenStatus.requested,
      );

      expect(
        () => VoteCastingService.buildVotePayload(
          token: token,
          candidateId: 1,
          electionId: election.id,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('Election lifecycle', () {
    test('upcoming election has correct status', () {
      final now = DateTime.now();
      final result = ecServer.createElection(
        id: 'upcoming',
        name: 'Upcoming Election',
        candidates: const [Candidate(id: 1, name: 'Alice')],
        startTime: now.add(const Duration(hours: 1)),
        endTime: now.add(const Duration(hours: 25)),
      );

      expect(result.election.status, equals(ElectionStatus.upcoming));
    });

    test('finished election has correct status', () {
      final now = DateTime.now();
      final result = ecServer.createElection(
        id: 'finished',
        name: 'Finished Election',
        candidates: const [Candidate(id: 1, name: 'Alice')],
        startTime: now.subtract(const Duration(hours: 25)),
        endTime: now.subtract(const Duration(hours: 1)),
      );

      expect(result.election.status, equals(ElectionStatus.finished));
    });

    test('canceled election has correct status', () {
      final now = DateTime.now();
      final result = ecServer.createElection(
        id: 'canceled',
        name: 'Canceled Election',
        candidates: const [Candidate(id: 1, name: 'Alice')],
        startTime: now.subtract(const Duration(hours: 1)),
        endTime: now.add(const Duration(hours: 23)),
        rawStatus: 'canceled',
      );

      expect(result.election.status, equals(ElectionStatus.canceled));
    });

    test('RSA public key round-trips through election event', () {
      final result = ecServer.createElection(
        id: 'rsa-roundtrip',
        name: 'RSA Test',
        candidates: const [Candidate(id: 1, name: 'Alice')],
        startTime: DateTime.now().subtract(const Duration(hours: 1)),
        endTime: DateTime.now().add(const Duration(hours: 23)),
      );

      // Parse the event back.
      final parsed = Election.fromEvent(result.event);
      expect(parsed, isNotNull);

      // Verify the RSA key can be used for blinding.
      final rsaPubKey = PublicKey.fromDer(base64Decode(parsed!.rsaPublicKey));
      final testMessage = BlindSignatureService.hashMessage(
        BlindSignatureService.generateNonce(),
      );
      final blindResult = rsaPubKey.blind(
        null,
        testMessage,
        true,
        Options.defaultOptions,
      );
      expect(blindResult.blindMessage, isNotEmpty);
    });
  });

  group('Token serialization round-trip', () {
    test('BlindToken survives JSON round-trip', () async {
      final nonce = BlindSignatureService.generateNonce();
      final hashedNonce = BlindSignatureService.hashMessage(nonce);
      final rsaPubKey = rsaKeyPair.publicKey;
      const options = Options.defaultOptions;

      final blindingResult = rsaPubKey.blind(null, hashedNonce, true, options);
      final blindSig = rsaKeyPair.secretKey.blindSign(
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

      final original = BlindToken(
        electionId: 'test-election',
        nonce: nonce,
        hashedNonce: hashedNonce,
        blindedMessage: blindingResult.blindMessage,
        secret: blindingResult.secret,
        messageRandomizer: blindingResult.messageRandomizer,
        requestId: 'ser-test',
        blindSignature: blindSig,
        unblindedSignature: unblindedSig,
        status: BlindTokenStatus.received,
      );

      // Round-trip through JSON.
      final json = original.toJson();
      final restored = BlindToken.fromJson(json);

      expect(restored.electionId, equals(original.electionId));
      expect(restored.nonce, equals(original.nonce));
      expect(restored.hashedNonce, equals(original.hashedNonce));
      expect(restored.unblindedSignature, equals(original.unblindedSignature));
      expect(restored.isReady, isTrue);

      // The restored token's signature should still verify.
      final isValid = BlindSignatureService.verifyToken(
        message: restored.hashedNonce,
        signature: restored.unblindedSignature!,
        messageRandomizer: restored.messageRandomizer,
        rsaPubKey: rsaPubKey,
      );
      expect(isValid, isTrue);
    });
  });
}
