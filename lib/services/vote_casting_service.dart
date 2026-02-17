import 'dart:convert';

import 'package:blind_rsa_signatures/blind_rsa_signatures.dart';
import 'package:flutter/foundation.dart';

import '../config/constants.dart';
import '../models/blind_token.dart';
import '../models/election.dart';
import 'blind_signature_service.dart';
import 'gift_wrap_service.dart';

/// State of the vote casting flow.
enum VoteCastingState {
  /// No vote in progress.
  idle,

  /// Vote is being prepared and sent.
  casting,

  /// Vote was successfully cast.
  cast,

  /// Vote casting failed.
  error,
}

/// Implements the anonymous vote casting protocol.
///
/// ## Protocol
///
/// 1. Retrieve the blind token for the election.
/// 2. Verify the unblinded signature against the EC's RSA public key.
/// 3. Generate a NEW anonymous Nostr keypair (unlinkable to the voter).
/// 4. Build vote payload: `{hash, token, blinding_factor, candidate_id}`.
/// 5. Send via NIP-59 Gift Wrap using the anonymous key → EC pubkey.
/// 6. Discard the anonymous keypair (ephemeral, single-use).
///
/// The voter's real identity is never associated with the vote because:
/// - The blind signature hides which token was signed.
/// - The anonymous keypair is freshly generated and immediately discarded.
/// - NIP-59 Gift Wrap hides the sender's metadata.
class VoteCastingService extends ChangeNotifier {
  final GiftWrapService _giftWrapService;

  /// Current state of the service.
  VoteCastingState _state = VoteCastingState.idle;

  /// Human-readable error message (when [state] is [VoteCastingState.error]).
  String? _errorMessage;

  /// Callback to generate an anonymous Nostr keypair.
  ///
  /// Returns a record of `(privateKeyHex, publicKeyHex)`.
  /// Must be set before calling [castVote]. Defaults to using dart_nostr's
  /// key generation via the NostrService instance.
  ({String privateKey, String publicKey}) Function()? anonymousKeyGenerator;

  VoteCastingService({required GiftWrapService giftWrapService})
    : _giftWrapService = giftWrapService;

  /// Current state.
  VoteCastingState get state => _state;

  /// Error message (if any).
  String? get errorMessage => _errorMessage;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Casts an anonymous vote for [candidateId] in the given [election].
  ///
  /// [token] must be a fully completed [BlindToken] with a valid unblinded
  /// signature (i.e. `token.isReady == true`).
  ///
  /// The vote is sent via NIP-59 Gift Wrap using a freshly generated anonymous
  /// Nostr keypair that is not linked to the voter's identity.
  ///
  /// Throws if the token is invalid, the signature fails verification, or the
  /// Gift Wrap send fails.
  Future<void> castVote({
    required Election election,
    required BlindToken token,
    required int candidateId,
  }) async {
    _setState(VoteCastingState.casting);
    _errorMessage = null;

    try {
      // 1. Validate preconditions.
      _validateToken(token, election);
      _validateCandidate(candidateId, election);

      // 2. Verify the unblinded signature against the EC's RSA public key.
      final rsaPubKey = PublicKey.fromDer(base64Decode(election.rsaPublicKey));
      final isValid = BlindSignatureService.verifyToken(
        message: token.hashedNonce,
        signature: token.unblindedSignature!,
        messageRandomizer: token.messageRandomizer,
        rsaPubKey: rsaPubKey,
      );

      if (!isValid) {
        throw StateError(
          'Unblinded signature failed verification against EC public key',
        );
      }

      // 3. Generate a NEW anonymous Nostr keypair.
      final anonymousKeys = _generateAnonymousKeypair();

      // 4. Build the vote payload.
      final votePayload = buildVotePayload(
        token: token,
        candidateId: candidateId,
        electionId: election.id,
      );

      // 5. Send via NIP-59 Gift Wrap using the anonymous key.
      await _giftWrapService.sendGiftWrap(
        recipientPubkey: election.ecPubkey,
        content: jsonEncode(votePayload),
        senderPrivateKey: anonymousKeys.privateKey,
        kind: AppConstants.voteEventKind,
      );

      debugPrint(
        'VoteCastingService: Vote cast for candidate $candidateId '
        'in election ${election.id} using anonymous key '
        '${anonymousKeys.publicKey.substring(0, 8)}...',
      );

      // 6. Anonymous keypair is discarded (goes out of scope).
      _setState(VoteCastingState.cast);
    } catch (e) {
      _errorMessage = e.toString();
      _setState(VoteCastingState.error);
      rethrow;
    }
  }

  /// Resets the service back to idle state.
  void reset() {
    _setState(VoteCastingState.idle);
    _errorMessage = null;
  }

  // ---------------------------------------------------------------------------
  // Vote payload
  // ---------------------------------------------------------------------------

  /// Builds the vote payload map.
  ///
  /// Exposed as a static method for testing.
  static Map<String, dynamic> buildVotePayload({
    required BlindToken token,
    required int candidateId,
    required String electionId,
  }) {
    if (token.unblindedSignature == null) {
      throw ArgumentError(
        'Token must have an unblinded signature. '
        'Ensure the token is in "ready" status before calling buildVotePayload.',
      );
    }

    return {
      'kind': 2, // Vote submission
      'election_id': electionId,
      'candidate_id': candidateId,
      'hash': base64Encode(token.hashedNonce),
      'token': base64Encode(token.unblindedSignature!),
      'blinding_factor': base64Encode(token.secret),
      if (token.messageRandomizer != null)
        'message_randomizer': base64Encode(token.messageRandomizer!),
    };
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  /// Validates that the token is ready and belongs to the election.
  void _validateToken(BlindToken token, Election election) {
    if (!token.isReady) {
      throw StateError(
        'Token is not ready for voting (status: ${token.status.name})',
      );
    }
    if (token.electionId != election.id) {
      throw ArgumentError(
        'Token election ID (${token.electionId}) does not match '
        'election ID (${election.id})',
      );
    }
  }

  /// Validates that the candidate exists in the election.
  void _validateCandidate(int candidateId, Election election) {
    final exists = election.candidates.any((c) => c.id == candidateId);
    if (!exists) {
      throw ArgumentError(
        'Candidate $candidateId not found in election ${election.id}',
      );
    }
  }

  /// Generates a fresh anonymous Nostr keypair.
  ({String privateKey, String publicKey}) _generateAnonymousKeypair() {
    if (anonymousKeyGenerator != null) {
      return anonymousKeyGenerator!();
    }
    // Use dart_nostr's key generation via the gift wrap service's nostr instance.
    // This generates a completely new keypair unlinked to any identity.
    throw StateError(
      'anonymousKeyGenerator must be set before calling castVote. '
      'Wire it to generate a fresh Nostr keypair via dart_nostr.',
    );
  }

  // ---------------------------------------------------------------------------
  // State management
  // ---------------------------------------------------------------------------

  void _setState(VoteCastingState newState) {
    if (_state == newState) return;
    _state = newState;
    notifyListeners();
  }
}
