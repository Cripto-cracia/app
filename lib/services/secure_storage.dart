import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provides encrypted local storage for sensitive data such as mnemonics.
///
/// Uses Hive with AES-256 encryption. The encryption key is randomly generated
/// on first launch and persisted via SharedPreferences. Phase 5 will enhance
/// this with device-fingerprint-backed PBKDF2 key derivation.
class SecureStorage {
  SecureStorage._();

  static const String _boxName = 'criptocracia_secure';
  static const String _mnemonicKey = 'nostr_mnemonic';
  static const String _encKeyPref = 'criptocracia_enc_key';

  static Box<String>? _box;

  /// Initialises Hive and opens the encrypted box.
  ///
  /// Must be called once before any read/write operations (typically in
  /// `main()` after `WidgetsFlutterBinding.ensureInitialized()`).
  ///
  /// Pass [path] to skip `Hive.initFlutter()` and use `Hive.init(path)`
  /// instead (useful in tests where no Flutter engine is available).
  static Future<void> init({String? path}) async {
    if (_box != null) return;
    if (path != null) {
      Hive.init(path);
    } else {
      await Hive.initFlutter();
    }
    final key = await _getOrCreateEncryptionKey();
    _box = await Hive.openBox<String>(
      _boxName,
      encryptionCipher: HiveAesCipher(key),
    );
  }

  // ---------------------------------------------------------------------------
  // Mnemonic helpers
  // ---------------------------------------------------------------------------

  /// Saves the mnemonic phrase to encrypted storage.
  static Future<void> saveMnemonic(String mnemonic) async {
    await write(key: _mnemonicKey, value: mnemonic.trim());
  }

  /// Loads the stored mnemonic, or `null` if none exists.
  static Future<String?> loadMnemonic() async {
    return read(key: _mnemonicKey);
  }

  /// Deletes the stored mnemonic.
  static Future<void> deleteMnemonic() async {
    await delete(key: _mnemonicKey);
  }

  /// Returns `true` if a mnemonic is stored.
  static Future<bool> hasMnemonic() async {
    return exists(key: _mnemonicKey);
  }

  // ---------------------------------------------------------------------------
  // Generic key-value API
  // ---------------------------------------------------------------------------

  /// Writes a [value] under [key] to the encrypted box.
  static Future<void> write({
    required String key,
    required String value,
  }) async {
    _ensureOpen();
    await _box!.put(key, value);
  }

  /// Reads the value stored under [key], or `null` if absent.
  static Future<String?> read({required String key}) async {
    _ensureOpen();
    return _box!.get(key);
  }

  /// Deletes the entry for [key].
  static Future<void> delete({required String key}) async {
    _ensureOpen();
    await _box!.delete(key);
  }

  /// Returns `true` if [key] exists in storage.
  static Future<bool> exists({required String key}) async {
    _ensureOpen();
    return _box!.containsKey(key);
  }

  /// Closes the encrypted box. Call on app shutdown if desired.
  static Future<void> close() async {
    await _box?.close();
    _box = null;
  }

  // ---------------------------------------------------------------------------
  // Internal
  // ---------------------------------------------------------------------------

  static void _ensureOpen() {
    if (_box == null || !_box!.isOpen) {
      throw StateError(
        'SecureStorage is not initialised. Call SecureStorage.init() first.',
      );
    }
  }

  /// Returns the encryption key, generating a random one on first launch.
  ///
  /// The key is stored in SharedPreferences. Phase 5 will replace this with
  /// device-fingerprint-backed PBKDF2 key derivation similar to the reference
  /// implementation's approach.
  static Future<Uint8List> _getOrCreateEncryptionKey() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_encKeyPref);
    if (existing != null) {
      return Uint8List.fromList(base64Decode(existing));
    }
    // Generate a cryptographically random 256-bit key.
    final random = Random.secure();
    final key = Uint8List.fromList(
      List<int>.generate(32, (_) => random.nextInt(256)),
    );
    await prefs.setString(_encKeyPref, base64Encode(key));
    return key;
  }
}
