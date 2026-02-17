import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:blind_rsa_signatures/blind_rsa_signatures.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/foundation.dart';

import '../models/blind_token.dart';
import '../models/election.dart';
import '../models/nostr_event.dart';
import 'gift_wrap_service.dart';
import 'token_storage_service.dart';

/// State of the blind signature request flow.
enum BlindSignatureState {
  /// No request in progress.
  idle,

  /// A token request is being prepared and sent.
  requesting,

  /// A valid token has been received and stored.
  received,

  /// The request failed.
  error,
}

/// Implements the blind RSA signature protocol for anonymous token issuance.
///
/// ## Protocol
///
/// 1. Generate a random 32-byte nonce.
/// 2. Compute `message = SHA-256(nonce)`.
/// 3. Blind `message` with the EC's RSA public key →
///    `(blinded_message, secret, message_randomizer)`.
/// 4. Send `blinded_message` to the EC via NIP-59 Gift Wrap.
/// 5. EC signs and returns `blind_signature` via Gift Wrap.
/// 6. Unblind → `signature` (the voting token).
/// 7. Persist `(nonce, signature, message_randomizer, election_id)`.
class BlindSignatureService extends ChangeNotifier {
  final GiftWrapService _giftWrapService;

  /// Current state of the service.
  BlindSignatureState _state = BlindSignatureState.idle;

  /// Human-readable error message (when [state] is [BlindSignatureState.error]).
  String? _errorMessage;

  /// Subscription on incoming Gift Wrap events.
  StreamSubscription<NostrEventModel>? _responseSubscription;

  /// Pending token awaiting EC response, keyed by request ID.
  final Map<String, BlindToken> _pendingTokens = {};

  /// Completer for awaiting the EC response in [requestBlindToken].
  final Map<String, Completer<BlindToken>> _completers = {};

  /// RSA blind signature options — must match the EC's configuration.
  static const Options _options = Options.defaultOptions; // SHA-384, auto salt

  BlindSignatureService({required GiftWrapService giftWrapService})
    : _giftWrapService = giftWrapService;

  /// Current state.
  BlindSignatureState get state => _state;

  /// Error message (if any).
  String? get errorMessage => _errorMessage;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Executes the full blind token request flow for [election].
  ///
  /// [senderPrivateKey] is the voter's Nostr private key (hex) used to send
  /// the Gift Wrap to the EC.
  ///
  /// Returns the completed [BlindToken] with a valid unblinded signature,
  /// or throws on failure.
  Future<BlindToken> requestBlindToken({
    required Election election,
    required String senderPrivateKey,
  }) async {
    if (rsaKeyResolver == null) {
      throw StateError(
        'rsaKeyResolver must be set before calling requestBlindToken. '
        'Wire it to the ElectionService that caches election data.',
      );
    }

    _setState(BlindSignatureState.requesting);
    _errorMessage = null;

    try {
      // Check if we already have a valid token for this election.
      final existing = await TokenStorageService.getToken(election.id);
      if (existing != null && existing.isReady) {
        _setState(BlindSignatureState.received);
        return existing;
      }

      // 1. Generate nonce and compute hash.
      final nonce = generateNonce();
      final hashedNonce = hashMessage(nonce);

      // 2. Parse the EC's RSA public key from the election data.
      final rsaPubKey = PublicKey.fromDer(base64Decode(election.rsaPublicKey));

      // 3. Blind the hashed nonce.
      final blindingResult = rsaPubKey.blind(null, hashedNonce, true, _options);

      // 4. Build request ID and token model.
      final requestId = _generateRequestId();
      final token = BlindToken(
        electionId: election.id,
        nonce: nonce,
        hashedNonce: hashedNonce,
        blindedMessage: blindingResult.blindMessage,
        secret: blindingResult.secret,
        messageRandomizer: blindingResult.messageRandomizer,
        requestId: requestId,
        status: BlindTokenStatus.requested,
      );

      // Persist the pending token in case the app is interrupted.
      await TokenStorageService.saveToken(token);

      // 5. Register for response before sending to avoid race conditions.
      final completer = Completer<BlindToken>();
      _pendingTokens[requestId] = token;
      _completers[requestId] = completer;

      _ensureListening();

      // 6. Build the protocol message (matches Rust `Message` struct).
      final message = jsonEncode({
        'id': requestId,
        'kind': 1, // Token request
        'payload': base64Encode(blindingResult.blindMessage),
        'election_id': election.id,
      });

      // 7. Send via NIP-59 Gift Wrap to the EC.
      await _giftWrapService.sendGiftWrap(
        recipientPubkey: election.ecPubkey,
        content: message,
        senderPrivateKey: senderPrivateKey,
      );

      debugPrint(
        'BlindSignatureService: Token request sent for election '
        '${election.id} (request $requestId)',
      );

      // 8. Wait for the EC's response (with timeout).
      final completedToken = await completer.future.timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          _pendingTokens.remove(requestId);
          _completers.remove(requestId);
          throw TimeoutException(
            'EC did not respond within 60 seconds',
            const Duration(seconds: 60),
          );
        },
      );

      _setState(BlindSignatureState.received);
      return completedToken;
    } catch (e) {
      _errorMessage = e.toString();
      _setState(BlindSignatureState.error);
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Public — cryptographic helpers (exposed for testing and vote casting)
  // ---------------------------------------------------------------------------

  /// Generates a cryptographically random 32-byte nonce.
  static Uint8List generateNonce() {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(32, (_) => random.nextInt(256)),
    );
  }

  /// Computes SHA-256 of [data].
  static Uint8List hashMessage(Uint8List data) {
    final digest = crypto.sha256.convert(data);
    return Uint8List.fromList(digest.bytes);
  }

  /// Unblinds the EC's blind signature using the blinding [secret].
  ///
  /// Also verifies that the resulting signature is valid.
  static Uint8List unblindSignature({
    required Uint8List blindSig,
    required Uint8List secret,
    required Uint8List? messageRandomizer,
    required Uint8List message,
    required PublicKey rsaPubKey,
  }) {
    final signature = rsaPubKey.finalize(
      blindSig,
      secret,
      messageRandomizer,
      message,
      _options,
    );
    return signature.bytes;
  }

  /// Verifies an unblinded signature against the original message.
  static bool verifyToken({
    required Uint8List message,
    required Uint8List signature,
    required Uint8List? messageRandomizer,
    required PublicKey rsaPubKey,
  }) {
    try {
      final sig = Signature(signature);
      return sig.verify(rsaPubKey, messageRandomizer, message, _options);
    } catch (_) {
      return false;
    }
  }

  /// The RSA blind signature options used by this service.
  ///
  /// Exposed so that vote-casting code can use the same options.
  static Options get options => _options;

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  /// Generates a short random request ID for correlating request/response.
  static String _generateRequestId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  // ---------------------------------------------------------------------------
  // Gift Wrap response handling
  // ---------------------------------------------------------------------------

  /// Ensures we are listening for incoming Gift Wrap responses.
  void _ensureListening() {
    if (_responseSubscription != null) return;
    _responseSubscription = _giftWrapService.unwrappedEvents.listen(
      _handleResponse,
    );
  }

  /// Processes an incoming Gift Wrap event that may contain the EC's blind
  /// signature response.
  Future<void> _handleResponse(NostrEventModel event) async {
    try {
      final data = jsonDecode(event.content) as Map<String, dynamic>;

      // Must be a token response (kind 1).
      if (data['kind'] != 1) return;

      final requestId = data['id'] as String?;
      if (requestId == null) return;

      final token = _pendingTokens.remove(requestId);
      final completer = _completers.remove(requestId);
      if (token == null || completer == null) return;

      // Inner try/catch: the completer has already been removed from the map,
      // so any error during processing must be forwarded to the caller.
      try {
        final payloadB64 = data['payload'] as String;
        final blindSig = base64Decode(payloadB64);

        // Resolve the RSA public key to unblind.
        final rsaPubKey = await _resolveRsaPubKey(token.electionId);
        if (rsaPubKey == null) {
          token.status = BlindTokenStatus.error;
          token.errorMessage = 'Could not resolve RSA public key';
          await TokenStorageService.saveToken(token);
          completer.completeError(
            StateError('Could not resolve RSA public key for unblinding'),
          );
          return;
        }

        // Unblind and verify.
        final unblindedSig = unblindSignature(
          blindSig: blindSig,
          secret: token.secret,
          messageRandomizer: token.messageRandomizer,
          message: token.hashedNonce,
          rsaPubKey: rsaPubKey,
        );

        token
          ..blindSignature = blindSig
          ..unblindedSignature = unblindedSig
          ..status = BlindTokenStatus.received;

        await TokenStorageService.saveToken(token);
        completer.complete(token);

        debugPrint(
          'BlindSignatureService: Token received and verified for election '
          '${token.electionId}',
        );
      } catch (e) {
        token.status = BlindTokenStatus.error;
        token.errorMessage = e.toString();
        await TokenStorageService.saveToken(token);
        if (!completer.isCompleted) {
          completer.completeError(e);
        }
        rethrow;
      }
    } catch (e) {
      debugPrint('BlindSignatureService: Error handling response: $e');
    }
  }

  /// Resolves the EC's RSA public key for a given election.
  ///
  /// Uses [rsaKeyResolver] which must be set by the caller (typically wired
  /// to the [ElectionService] that caches election data).
  Future<PublicKey?> _resolveRsaPubKey(String electionId) async {
    return rsaKeyResolver?.call(electionId);
  }

  /// Callback to resolve the EC's RSA [PublicKey] from an election ID.
  ///
  /// Must be set before calling [requestBlindToken], typically by wiring
  /// it to the ElectionService that caches election data.
  Future<PublicKey?> Function(String electionId)? rsaKeyResolver;

  // ---------------------------------------------------------------------------
  // State management
  // ---------------------------------------------------------------------------

  void _setState(BlindSignatureState newState) {
    if (_state == newState) return;
    _state = newState;
    notifyListeners();
  }

  @override
  void dispose() {
    _responseSubscription?.cancel();
    // Complete any pending requests with an error.
    for (final completer in _completers.values) {
      if (!completer.isCompleted) {
        completer.completeError(StateError('Service disposed'));
      }
    }
    _pendingTokens.clear();
    _completers.clear();
    super.dispose();
  }
}
