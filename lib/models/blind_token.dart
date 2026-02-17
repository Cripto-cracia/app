import 'dart:convert';
import 'dart:typed_data';

/// Status of a blind token through its lifecycle.
enum BlindTokenStatus {
  /// Token request is being prepared (nonce generated, message blinded).
  pending,

  /// Blinded message has been sent to the EC, awaiting response.
  requested,

  /// Blind signature received from EC and unblinded successfully.
  received,

  /// Token request failed.
  error,
}

/// A blind token used in the anonymous voting protocol.
///
/// Represents the full lifecycle of a blind signature token:
/// 1. Client generates a random [nonce] and computes SHA-256([nonce]).
/// 2. The hash is blinded with the EC's RSA public key, producing
///    [blindedMessage] and a [secret] (blinding factor).
/// 3. [blindedMessage] is sent to the EC via NIP-59 Gift Wrap.
/// 4. The EC signs and returns [blindSignature].
/// 5. Client unblinds using [secret] to obtain [unblindedSignature].
/// 6. The token ([nonce], [unblindedSignature], [messageRandomizer])
///    is used to cast an anonymous vote.
class BlindToken {
  /// The election this token belongs to.
  final String electionId;

  /// Random nonce (32 bytes) — the secret vote token seed.
  final Uint8List nonce;

  /// SHA-256 hash of [nonce] — the message that was blinded.
  final Uint8List hashedNonce;

  /// The blinded message sent to the EC.
  final Uint8List blindedMessage;

  /// The blinding factor needed to unblind the EC's signature.
  final Uint8List secret;

  /// The message randomizer used during blinding (required for verification).
  final Uint8List? messageRandomizer;

  /// The blind signature received from the EC (before unblinding).
  Uint8List? blindSignature;

  /// The final unblinded signature — the actual voting token.
  Uint8List? unblindedSignature;

  /// Current status of this token.
  BlindTokenStatus status;

  /// Optional error message when [status] is [BlindTokenStatus.error].
  String? errorMessage;

  /// The request ID used to correlate the Gift Wrap request with its response.
  final String requestId;

  BlindToken({
    required this.electionId,
    required this.nonce,
    required this.hashedNonce,
    required this.blindedMessage,
    required this.secret,
    required this.messageRandomizer,
    required this.requestId,
    this.blindSignature,
    this.unblindedSignature,
    this.status = BlindTokenStatus.pending,
    this.errorMessage,
  });

  /// Whether this token is ready to be used for voting.
  bool get isReady =>
      status == BlindTokenStatus.received && unblindedSignature != null;

  /// Serializes to a map for local storage.
  Map<String, dynamic> toMap() => {
    'election_id': electionId,
    'nonce': base64Encode(nonce),
    'hashed_nonce': base64Encode(hashedNonce),
    'blinded_message': base64Encode(blindedMessage),
    'secret': base64Encode(secret),
    if (messageRandomizer != null)
      'message_randomizer': base64Encode(messageRandomizer!),
    if (blindSignature != null)
      'blind_signature': base64Encode(blindSignature!),
    if (unblindedSignature != null)
      'unblinded_signature': base64Encode(unblindedSignature!),
    'status': status.name,
    'request_id': requestId,
    if (errorMessage != null) 'error_message': errorMessage,
  };

  /// Deserializes from a stored map.
  factory BlindToken.fromMap(Map<String, dynamic> map) {
    return BlindToken(
      electionId: map['election_id'] as String,
      nonce: base64Decode(map['nonce'] as String),
      hashedNonce: base64Decode(map['hashed_nonce'] as String),
      blindedMessage: base64Decode(map['blinded_message'] as String),
      secret: base64Decode(map['secret'] as String),
      messageRandomizer: map['message_randomizer'] != null
          ? base64Decode(map['message_randomizer'] as String)
          : null,
      blindSignature: map['blind_signature'] != null
          ? base64Decode(map['blind_signature'] as String)
          : null,
      unblindedSignature: map['unblinded_signature'] != null
          ? base64Decode(map['unblinded_signature'] as String)
          : null,
      status: BlindTokenStatus.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => BlindTokenStatus.pending,
      ),
      requestId: map['request_id'] as String,
      errorMessage: map['error_message'] as String?,
    );
  }

  /// Serializes to JSON string.
  String toJson() => jsonEncode(toMap());

  /// Deserializes from a JSON string.
  factory BlindToken.fromJson(String json) =>
      BlindToken.fromMap(jsonDecode(json) as Map<String, dynamic>);

  @override
  String toString() =>
      'BlindToken(election: $electionId, status: ${status.name})';
}
