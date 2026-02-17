import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Provides encrypted local storage for sensitive data such as mnemonics.
///
/// Uses Hive with AES-256 encryption. The encryption key is derived from
/// a static salt (to be enhanced with device-specific keys in Phase 5).
class SecureStorage {
  SecureStorage._();

  static const String _boxName = 'criptocracia_secure';
  static const String _mnemonicKey = 'nostr_mnemonic';
  static const String _keySalt = 'criptocracia_secure_v1';

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
    final key = _deriveEncryptionKey();
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

  /// Derives a 256-bit encryption key from the static salt.
  ///
  /// Phase 5 will replace this with device-fingerprint-backed key derivation
  /// similar to the reference implementation's PBKDF2 + device ID approach.
  static Uint8List _deriveEncryptionKey() {
    final bytes = utf8.encode(_keySalt);
    final hash = sha256.convert(bytes);
    return Uint8List.fromList(hash.bytes);
  }
}
