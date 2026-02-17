import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:blind_rsa_signatures/blind_rsa_signatures.dart';
import 'package:criptocracia_app/config/constants.dart';
import 'package:criptocracia_app/models/candidate.dart';
import 'package:criptocracia_app/models/election.dart';
import 'package:criptocracia_app/models/nostr_event.dart';

/// A mock Electoral Commission (EC) server for integration tests.
///
/// Simulates the full EC server behavior:
/// - Publishes election announcements (Kind 35000)
/// - Processes blind token requests and returns blind signatures
/// - Receives votes and publishes results (Kind 35001)
/// - Tracks issued tokens to prevent double-voting
///
/// This is an in-memory mock that does not use real Nostr relays.
/// Instead, it processes messages directly through method calls,
/// and the test wiring connects it to the service layer via
/// stream controllers.
class MockEcServer {
  /// RSA key pair used for blind signatures.
  final KeyPair rsaKeyPair;

  /// The EC's Nostr public key (hex).
  final String ecPubkey;

  /// Elections published by this EC.
  final Map<String, Election> _elections = {};

  /// Set of blinded messages already signed (prevents double-signing).
  final Set<String> _issuedTokens = {};

  /// Votes received, keyed by election ID.
  final Map<String, List<Map<String, dynamic>>> _votes = {};

  /// Stream controller for outgoing events (responses to the voter).
  final StreamController<NostrEventModel> _outgoingEvents =
      StreamController<NostrEventModel>.broadcast();

  /// Stream controller for vote events (Kind 35001).
  final StreamController<NostrEventModel> _voteEvents =
      StreamController<NostrEventModel>.broadcast();

  /// Whether to simulate network failures on the next request.
  bool simulateNetworkFailure = false;

  /// Whether to return an invalid signature on the next request.
  bool simulateInvalidSignature = false;

  /// Delay before responding to requests (simulates network latency).
  Duration responseDelay = Duration.zero;

  /// Creates a [MockEcServer] with a pre-generated RSA key pair.
  MockEcServer({
    required this.rsaKeyPair,
    this.ecPubkey =
        'ec00000000000000000000000000000000000000000000000000000000000001',
  });

  /// Stream of outgoing events (gift-wrap responses to the voter).
  Stream<NostrEventModel> get outgoingEvents => _outgoingEvents.stream;

  /// Stream of vote events (Kind 35001) for results tracking.
  Stream<NostrEventModel> get voteEvents => _voteEvents.stream;

  /// The EC's RSA public key as Base64-encoded DER.
  String get rsaPublicKeyBase64 => base64Encode(rsaKeyPair.publicKey.toDer());

  /// All elections published by this EC.
  List<Election> get elections => _elections.values.toList();

  /// Votes received for an election.
  List<Map<String, dynamic>> votesForElection(String electionId) =>
      _votes[electionId] ?? [];

  /// Total number of issued tokens across all elections.
  int get issuedTokenCount => _issuedTokens.length;

  // ---------------------------------------------------------------------------
  // Election management
  // ---------------------------------------------------------------------------

  /// Creates and publishes an election.
  ///
  /// Returns the [Election] object and a corresponding [NostrEventModel]
  /// (Kind 35000) that the election service can parse.
  ({Election election, NostrEventModel event}) createElection({
    required String id,
    required String name,
    required List<Candidate> candidates,
    required DateTime startTime,
    required DateTime endTime,
    String rawStatus = 'open',
  }) {
    final now = DateTime.now();
    final eventId = 'event-$id';

    final election = Election(
      id: id,
      name: name,
      candidates: candidates,
      startTime: startTime,
      endTime: endTime,
      ecPubkey: ecPubkey,
      rsaPublicKey: rsaPublicKeyBase64,
      rawStatus: rawStatus,
      eventId: eventId,
      createdAt: now,
    );

    _elections[id] = election;

    final eventContent = jsonEncode({
      'id': id,
      'name': name,
      'candidates': candidates.map((c) => c.toMap()).toList(),
      'start_time': startTime.millisecondsSinceEpoch ~/ 1000,
      'end_time': endTime.millisecondsSinceEpoch ~/ 1000,
      'rsa_pub_key': rsaPublicKeyBase64,
      'status': rawStatus,
    });

    final event = NostrEventModel(
      id: eventId,
      pubkey: ecPubkey,
      createdAt: now,
      kind: AppConstants.electionEventKind,
      content: eventContent,
      tags: [
        ['d', id],
      ],
      sig: 'mock-sig-$eventId',
    );

    return (election: election, event: event);
  }

  // ---------------------------------------------------------------------------
  // Blind token request handling
  // ---------------------------------------------------------------------------

  /// Processes a blind token request message (as the EC would).
  ///
  /// Expects a JSON message with:
  /// - `id`: request ID
  /// - `kind`: 1 (token request)
  /// - `payload`: Base64-encoded blinded message
  /// - `election_id`: the election ID
  ///
  /// Returns a response [NostrEventModel] containing the blind signature,
  /// or null if the request should be rejected.
  Future<NostrEventModel?> handleTokenRequest(String messageJson) async {
    if (responseDelay > Duration.zero) {
      await Future<void>.delayed(responseDelay);
    }

    if (simulateNetworkFailure) {
      return null;
    }

    final data = jsonDecode(messageJson) as Map<String, dynamic>;
    final requestId = data['id'] as String;
    final kind = data['kind'] as int;
    final payloadB64 = data['payload'] as String;
    final electionId = data['election_id'] as String;

    if (kind != 1) return null;

    // Check that the election exists.
    if (!_elections.containsKey(electionId)) {
      return _buildErrorResponse(requestId, 'Election not found');
    }

    // Prevent double token issuance.
    final tokenKey = '$electionId:$payloadB64';
    if (_issuedTokens.contains(tokenKey)) {
      return _buildErrorResponse(requestId, 'Token already issued');
    }

    // Sign the blinded message.
    final blindedMessage = base64Decode(payloadB64);
    Uint8List blindSig;

    if (simulateInvalidSignature) {
      // Return garbage bytes instead of a valid signature.
      blindSig = Uint8List.fromList(List.filled(256, 0));
    } else {
      blindSig = rsaKeyPair.secretKey.blindSign(
        null,
        blindedMessage,
        Options.defaultOptions,
      );
    }

    _issuedTokens.add(tokenKey);

    final response = NostrEventModel(
      id: 'response-$requestId',
      pubkey: ecPubkey,
      createdAt: DateTime.now(),
      kind: 1,
      content: jsonEncode({
        'id': requestId,
        'kind': 1,
        'payload': base64Encode(blindSig),
      }),
      tags: [],
      sig: 'mock-sig-response-$requestId',
    );

    if (!_outgoingEvents.isClosed) {
      _outgoingEvents.add(response);
    }

    return response;
  }

  // ---------------------------------------------------------------------------
  // Vote handling
  // ---------------------------------------------------------------------------

  /// Processes a vote submission.
  ///
  /// Validates the token's blind signature against the EC's RSA public key,
  /// then records the vote and emits a Kind 35001 event.
  ///
  /// Returns `true` if the vote was accepted, `false` otherwise.
  bool handleVote(String voteJson, {String? electionId}) {
    final data = jsonDecode(voteJson) as Map<String, dynamic>;
    final eId = electionId ?? data['election_id'] as String;
    final candidateId = data['candidate_id'] as int;

    // Validate that the election exists.
    if (!_elections.containsKey(eId)) return false;

    // Validate candidate.
    final election = _elections[eId]!;
    if (!election.candidates.any((c) => c.id == candidateId)) return false;

    // Record the vote.
    _votes.putIfAbsent(eId, () => []);
    _votes[eId]!.add(data);

    // Emit a Kind 35001 event for results tracking.
    final voteEvent = NostrEventModel(
      id: 'vote-${_votes[eId]!.length}-$eId',
      pubkey: ecPubkey,
      createdAt: DateTime.now(),
      kind: AppConstants.voteEventKind,
      content: jsonEncode({'candidate_id': candidateId}),
      tags: [
        ['e', eId],
      ],
      sig: 'mock-vote-sig',
    );

    if (!_voteEvents.isClosed) {
      _voteEvents.add(voteEvent);
    }

    return true;
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  NostrEventModel _buildErrorResponse(String requestId, String error) {
    return NostrEventModel(
      id: 'error-$requestId',
      pubkey: ecPubkey,
      createdAt: DateTime.now(),
      kind: 1,
      content: jsonEncode({
        'id': requestId,
        'kind': 0, // Error kind
        'error': error,
      }),
      tags: [],
      sig: 'mock-sig-error-$requestId',
    );
  }

  /// Disposes of resources.
  void dispose() {
    _outgoingEvents.close();
    _voteEvents.close();
  }
}
