import '../models/blind_token.dart';
import 'secure_storage.dart';

/// Persists [BlindToken]s in encrypted local storage, keyed by election ID.
///
/// Uses [SecureStorage] (Hive + AES-256) so that token material never
/// touches unencrypted disk.
class TokenStorageService {
  TokenStorageService._();

  /// Storage key prefix for blind tokens.
  static const String _prefix = 'blind_token_';

  /// Returns the storage key for a given [electionId].
  static String _key(String electionId) => '$_prefix$electionId';

  /// Saves a [BlindToken] for the given election, overwriting any previous one.
  static Future<void> saveToken(BlindToken token) async {
    await SecureStorage.write(
      key: _key(token.electionId),
      value: token.toJson(),
    );
  }

  /// Loads the [BlindToken] for [electionId], or `null` if none exists.
  static Future<BlindToken?> getToken(String electionId) async {
    final json = await SecureStorage.read(key: _key(electionId));
    if (json == null) return null;
    try {
      return BlindToken.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  /// Returns `true` if a token exists for [electionId].
  static Future<bool> hasToken(String electionId) async {
    return SecureStorage.exists(key: _key(electionId));
  }

  /// Deletes the token for [electionId].
  static Future<void> deleteToken(String electionId) async {
    await SecureStorage.delete(key: _key(electionId));
  }

  /// Returns all stored blind tokens.
  ///
  /// Iterates through known keys in secure storage. This is a convenience
  /// method for listing tokens across elections.
  static Future<List<BlindToken>> getAllTokens(List<String> electionIds) async {
    final tokens = <BlindToken>[];
    for (final id in electionIds) {
      final token = await getToken(id);
      if (token != null) tokens.add(token);
    }
    return tokens;
  }
}
