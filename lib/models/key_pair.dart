import 'package:flutter/foundation.dart';

/// Represents a Nostr key pair with both hex and bech32 encodings.
@immutable
class NostrKeyPair {
  /// Creates a [NostrKeyPair] with all required fields.
  const NostrKeyPair({
    required this.privateKeyHex,
    required this.publicKeyHex,
    required this.npub,
    required this.nsec,
    required this.mnemonic,
  });

  /// The private key as a 64-character hex string (32 bytes).
  final String privateKeyHex;

  /// The public key (x-only) as a 64-character hex string (32 bytes).
  final String publicKeyHex;

  /// The public key encoded as NIP-19 bech32 `npub`.
  final String npub;

  /// The private key encoded as NIP-19 bech32 `nsec`.
  final String nsec;

  /// The BIP39 mnemonic phrase used to derive this key pair.
  final String mnemonic;

  /// Returns the mnemonic as a list of individual words.
  List<String> get mnemonicWords => mnemonic.split(' ');

  /// Returns the number of words in the mnemonic (12 or 24).
  int get wordCount => mnemonicWords.length;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NostrKeyPair &&
          runtimeType == other.runtimeType &&
          privateKeyHex == other.privateKeyHex &&
          publicKeyHex == other.publicKeyHex;

  @override
  int get hashCode => privateKeyHex.hashCode ^ publicKeyHex.hashCode;

  @override
  String toString() => 'NostrKeyPair(npub: $npub)';
}
