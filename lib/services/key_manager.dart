import 'dart:typed_data';

import 'package:bip39/bip39.dart' as bip39;
import 'package:blockchain_utils/bip/bip/bip32/bip32.dart';
import 'package:elliptic/elliptic.dart';
import 'package:bech32/bech32.dart';

import '../models/key_pair.dart';

/// Manages Nostr key generation and derivation following NIP-06.
///
/// Uses the BIP39 → BIP32/BIP44 → NIP-06 derivation chain:
///   1. Generate BIP39 mnemonic (12 or 24 words)
///   2. Convert mnemonic to 512-bit seed
///   3. Derive child key at path m/44'/1237'/0'/0/0
///   4. Extract 32-byte private key
///   5. Compute secp256k1 x-only public key
///   6. Encode as npub/nsec using bech32 (NIP-19)
class KeyManager {
  KeyManager._();

  /// NIP-06 derivation path for Nostr keys.
  static const String derivationPath = "m/44'/1237'/0'/0/0";

  // ---------------------------------------------------------------------------
  // Mnemonic
  // ---------------------------------------------------------------------------

  /// Generates a BIP39 mnemonic phrase.
  ///
  /// [strength] controls word count: 128 → 12 words, 256 → 24 words.
  static String generateMnemonic({int strength = 128}) {
    if (strength != 128 && strength != 256) {
      throw ArgumentError('Strength must be 128 (12 words) or 256 (24 words)');
    }
    return bip39.generateMnemonic(strength: strength);
  }

  /// Returns `true` if [mnemonic] is a valid BIP39 mnemonic.
  static bool validateMnemonic(String mnemonic) {
    return bip39.validateMnemonic(mnemonic.trim());
  }

  // ---------------------------------------------------------------------------
  // Key derivation
  // ---------------------------------------------------------------------------

  /// Derives a full [NostrKeyPair] from the given BIP39 [mnemonic].
  ///
  /// Throws [ArgumentError] if the mnemonic is invalid.
  static NostrKeyPair deriveNostrKeys(String mnemonic) {
    final trimmed = mnemonic.trim();
    if (!validateMnemonic(trimmed)) {
      throw ArgumentError('Invalid BIP39 mnemonic');
    }

    final privateKeyBytes = _derivePrivateKeyBytes(trimmed);
    final privateKeyHex = _bytesToHex(privateKeyBytes);

    final publicKeyBytes = _computePublicKey(privateKeyBytes);
    final publicKeyHex = _bytesToHex(publicKeyBytes);

    return NostrKeyPair(
      privateKeyHex: privateKeyHex,
      publicKeyHex: publicKeyHex,
      npub: encodeBech32('npub', publicKeyBytes),
      nsec: encodeBech32('nsec', privateKeyBytes),
      mnemonic: trimmed,
    );
  }

  // ---------------------------------------------------------------------------
  // Bech32 encoding / decoding (NIP-19)
  // ---------------------------------------------------------------------------

  /// Encodes raw [data] bytes with the given bech32 [hrp] (`npub` or `nsec`).
  static String encodeBech32(String hrp, Uint8List data) {
    final fiveBit = _convertBits(data, 8, 5, pad: true);
    return bech32.encode(Bech32(hrp, fiveBit));
  }

  /// Decodes a bech32 string and returns the HRP and data bytes.
  static ({String hrp, Uint8List data}) decodeBech32(String encoded) {
    final result = bech32.decode(encoded);
    final data = Uint8List.fromList(
      _convertBits(result.data, 5, 8, pad: false),
    );
    return (hrp: result.hrp, data: data);
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Derives the 32-byte private key from [mnemonic] using NIP-06 path.
  static Uint8List _derivePrivateKeyBytes(String mnemonic) {
    final seed = bip39.mnemonicToSeed(mnemonic);
    final masterKey = Bip32Slip10Secp256k1.fromSeed(seed);

    // m / 44' / 1237' / 0' / 0 / 0
    final derived = masterKey
        .childKey(Bip32KeyIndex.hardenIndex(44))
        .childKey(Bip32KeyIndex.hardenIndex(1237))
        .childKey(Bip32KeyIndex.hardenIndex(0))
        .childKey(Bip32KeyIndex(0))
        .childKey(Bip32KeyIndex(0));

    final raw = Uint8List.fromList(derived.privateKey.raw);
    if (raw.length != 32) {
      throw StateError('Expected 32-byte private key, got ${raw.length} bytes');
    }
    return raw;
  }

  /// Computes the x-only secp256k1 public key from a 32-byte [privateKey].
  static Uint8List _computePublicKey(Uint8List privateKey) {
    final ec = getSecp256k1();
    final hex = _bytesToHex(privateKey);
    final pubKey = PrivateKey.fromHex(ec, hex).publicKey;
    final xHex = pubKey.X.toRadixString(16).padLeft(64, '0');
    return _hexToBytes(xHex);
  }

  /// Converts between bit groups (used for bech32 5-bit ↔ 8-bit conversion).
  static List<int> _convertBits(
    List<int> data,
    int fromBits,
    int toBits, {
    required bool pad,
  }) {
    var acc = 0;
    var bits = 0;
    final result = <int>[];
    final maxV = (1 << toBits) - 1;

    for (final value in data) {
      acc = (acc << fromBits) | value;
      bits += fromBits;
      while (bits >= toBits) {
        bits -= toBits;
        result.add((acc >> bits) & maxV);
      }
    }

    if (pad) {
      if (bits > 0) {
        result.add((acc << (toBits - bits)) & maxV);
      }
    } else {
      if (bits >= fromBits) {
        throw const FormatException('Invalid padding in bech32 data');
      }
      if (((acc << (toBits - bits)) & maxV) != 0) {
        throw const FormatException('Non-zero padding in bech32 data');
      }
    }

    return result;
  }

  static String _bytesToHex(Uint8List bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  static Uint8List _hexToBytes(String hex) {
    final result = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < hex.length; i += 2) {
      result[i ~/ 2] = int.parse(hex.substring(i, i + 2), radix: 16);
    }
    return result;
  }
}
