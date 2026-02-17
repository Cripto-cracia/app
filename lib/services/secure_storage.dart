import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Storage namespace for key isolation.
///
/// Sensitive cryptographic material (private keys, mnemonics) is stored
/// separately from general application settings so that a compromise of
/// one namespace does not expose the other.
enum StorageNamespace {
  /// Private keys, mnemonics, and blind-signature tokens.
  keys,

  /// Non-sensitive settings such as relay lists and theme preferences.
  settings,
}

/// Provides hardware-backed encrypted local storage.
///
/// Architecture:
///   - **Encryption keys** are stored in the platform secure enclave
///     (Android Keystore / iOS Keychain) via `flutter_secure_storage`.
///   - **Data at rest** is encrypted with AES-256 via Hive encrypted boxes.
///   - **Key isolation** keeps cryptographic secrets in a separate Hive box
///     from general application settings.
///   - A **migration path** transparently moves legacy encryption keys from
///     `SharedPreferences` to the secure enclave on first launch after the
///     upgrade.
class SecureStorage {
  SecureStorage._();

  // Box names per namespace
  static const String _keysBoxName = 'criptocracia_keys';
  static const String _settingsBoxName = 'criptocracia_settings';

  // Legacy box name (pre-isolation) — used for migration only
  static const String _legacyBoxName = 'criptocracia_secure';

  // flutter_secure_storage keys for the Hive encryption keys
  static const String _keysEncKeyTag = 'criptocracia_keys_enc_key';
  static const String _settingsEncKeyTag = 'criptocracia_settings_enc_key';

  // Legacy SharedPreferences key — used for migration only
  static const String _legacyEncKeyPref = 'criptocracia_enc_key';

  // Well-known data keys
  static const String _mnemonicKey = 'nostr_mnemonic';

  static Box<String>? _keysBox;
  static Box<String>? _settingsBox;

  /// Platform secure storage backed by Android Keystore / iOS Keychain.
  ///
  /// Uses `EncryptedSharedPreferences` on Android (backed by Android Keystore)
  /// and Keychain with `first_unlock_this_device` accessibility on iOS
  /// (backed by the Secure Enclave where available).
  static const FlutterSecureStorage _secureKeyStore = FlutterSecureStorage(
    aOptions: AndroidOptions(),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  /// Initialises Hive and opens the encrypted boxes.
  ///
  /// Must be called once before any read/write operations (typically in
  /// `main()` after `WidgetsFlutterBinding.ensureInitialized()`).
  ///
  /// Pass [path] to skip `Hive.initFlutter()` and use `Hive.init(path)`
  /// instead (useful in tests where no Flutter engine is available).
  static Future<void> init({String? path}) async {
    if (_keysBox != null && _settingsBox != null) return;

    if (path != null) {
      Hive.init(path);
    } else {
      await Hive.initFlutter();
    }

    // Migrate legacy encryption key from SharedPreferences to secure enclave
    await _migrateLegacyEncryptionKey();

    // Migrate legacy data from unified box to namespace-specific boxes
    await _migrateLegacyData(path: path);

    final keysEncKey = await _getOrCreateEncryptionKey(_keysEncKeyTag);
    final settingsEncKey = await _getOrCreateEncryptionKey(_settingsEncKeyTag);

    _keysBox = await Hive.openBox<String>(
      _keysBoxName,
      encryptionCipher: HiveAesCipher(keysEncKey),
    );
    _settingsBox = await Hive.openBox<String>(
      _settingsBoxName,
      encryptionCipher: HiveAesCipher(settingsEncKey),
    );
  }

  // ---------------------------------------------------------------------------
  // Mnemonic helpers (always in keys namespace)
  // ---------------------------------------------------------------------------

  /// Saves the mnemonic phrase to encrypted storage.
  static Future<void> saveMnemonic(String mnemonic) async {
    await write(
      key: _mnemonicKey,
      value: mnemonic.trim(),
      namespace: StorageNamespace.keys,
    );
  }

  /// Loads the stored mnemonic, or `null` if none exists.
  static Future<String?> loadMnemonic() async {
    return read(key: _mnemonicKey, namespace: StorageNamespace.keys);
  }

  /// Deletes the stored mnemonic.
  static Future<void> deleteMnemonic() async {
    await delete(key: _mnemonicKey, namespace: StorageNamespace.keys);
  }

  /// Returns `true` if a mnemonic is stored.
  static Future<bool> hasMnemonic() async {
    return exists(key: _mnemonicKey, namespace: StorageNamespace.keys);
  }

  // ---------------------------------------------------------------------------
  // Generic key-value API
  // ---------------------------------------------------------------------------

  /// Writes a [value] under [key] to the encrypted box for [namespace].
  ///
  /// Defaults to [StorageNamespace.settings] for backward compatibility with
  /// callers that do not specify a namespace.
  static Future<void> write({
    required String key,
    required String value,
    StorageNamespace namespace = StorageNamespace.settings,
  }) async {
    final box = _boxFor(namespace);
    await box.put(key, value);
  }

  /// Reads the value stored under [key], or `null` if absent.
  static Future<String?> read({
    required String key,
    StorageNamespace namespace = StorageNamespace.settings,
  }) async {
    final box = _boxFor(namespace);
    return box.get(key);
  }

  /// Deletes the entry for [key].
  static Future<void> delete({
    required String key,
    StorageNamespace namespace = StorageNamespace.settings,
  }) async {
    final box = _boxFor(namespace);
    await box.delete(key);
  }

  /// Returns `true` if [key] exists in storage.
  static Future<bool> exists({
    required String key,
    StorageNamespace namespace = StorageNamespace.settings,
  }) async {
    final box = _boxFor(namespace);
    return box.containsKey(key);
  }

  /// Closes all encrypted boxes. Call on app shutdown if desired.
  static Future<void> close() async {
    await _keysBox?.close();
    await _settingsBox?.close();
    _keysBox = null;
    _settingsBox = null;
  }

  // ---------------------------------------------------------------------------
  // Internal
  // ---------------------------------------------------------------------------

  static Box<String> _boxFor(StorageNamespace namespace) {
    final box = namespace == StorageNamespace.keys ? _keysBox : _settingsBox;
    if (box == null || !box.isOpen) {
      throw StateError(
        'SecureStorage is not initialised. Call SecureStorage.init() first.',
      );
    }
    return box;
  }

  /// Returns the encryption key for the given [tag], creating one if needed.
  ///
  /// The key is stored in the platform secure enclave (Android Keystore /
  /// iOS Keychain) via `flutter_secure_storage`, ensuring that it is
  /// hardware-backed where the device supports it.
  static Future<Uint8List> _getOrCreateEncryptionKey(String tag) async {
    final existing = await _secureKeyStore.read(key: tag);
    if (existing != null) {
      return Uint8List.fromList(base64Decode(existing));
    }
    final random = Random.secure();
    final key = Uint8List.fromList(
      List<int>.generate(32, (_) => random.nextInt(256)),
    );
    await _secureKeyStore.write(key: tag, value: base64Encode(key));
    return key;
  }

  /// Migrates the legacy encryption key from `SharedPreferences` to the
  /// secure enclave.
  ///
  /// This runs only once: if the old key exists in SharedPreferences it is
  /// copied to `flutter_secure_storage` under the keys-namespace tag and
  /// then deleted from SharedPreferences.
  static Future<void> _migrateLegacyEncryptionKey() async {
    final prefs = await SharedPreferences.getInstance();
    final legacyKey = prefs.getString(_legacyEncKeyPref);
    if (legacyKey == null) return;

    // Store the legacy key as the keys-namespace encryption key so that the
    // old data box can be decrypted after migration.
    final existingInSecure = await _secureKeyStore.read(key: _keysEncKeyTag);
    if (existingInSecure == null) {
      await _secureKeyStore.write(key: _keysEncKeyTag, value: legacyKey);
    }

    await prefs.remove(_legacyEncKeyPref);
  }

  /// Migrates data from the legacy unified Hive box to the new
  /// namespace-specific boxes.
  ///
  /// Sensitive keys (mnemonic, blind tokens) go to the keys box; everything
  /// else goes to the settings box.
  static Future<void> _migrateLegacyData({String? path}) async {
    // Only migrate if the legacy box exists on disk
    if (!await _legacyBoxExists()) return;

    // We need the keys-namespace encryption key (which is the legacy key
    // after _migrateLegacyEncryptionKey moved it).
    final encKeyB64 = await _secureKeyStore.read(key: _keysEncKeyTag);
    if (encKeyB64 == null) return;

    final encKey = Uint8List.fromList(base64Decode(encKeyB64));

    Box<String> legacyBox;
    try {
      legacyBox = await Hive.openBox<String>(
        _legacyBoxName,
        encryptionCipher: HiveAesCipher(encKey),
      );
    } catch (_) {
      // Cannot open legacy box — skip migration
      return;
    }

    if (legacyBox.isEmpty) {
      await legacyBox.close();
      return;
    }

    // Prepare namespace boxes with fresh or migrated keys
    final keysEncKey = await _getOrCreateEncryptionKey(_keysEncKeyTag);
    final settingsEncKey = await _getOrCreateEncryptionKey(_settingsEncKeyTag);

    final keysBox = await Hive.openBox<String>(
      _keysBoxName,
      encryptionCipher: HiveAesCipher(keysEncKey),
    );
    final settingsBox = await Hive.openBox<String>(
      _settingsBoxName,
      encryptionCipher: HiveAesCipher(settingsEncKey),
    );

    // Keys that belong in the sensitive namespace
    const sensitiveKeyPrefixes = ['nostr_mnemonic', 'blind_token_'];

    for (final key in legacyBox.keys.cast<String>()) {
      final value = legacyBox.get(key);
      if (value == null) continue;

      final isSensitive = sensitiveKeyPrefixes.any(
        (prefix) => key.startsWith(prefix),
      );

      if (isSensitive) {
        if (!keysBox.containsKey(key)) {
          await keysBox.put(key, value);
        }
      } else {
        if (!settingsBox.containsKey(key)) {
          await settingsBox.put(key, value);
        }
      }
    }

    // Clear and close the legacy box
    await legacyBox.deleteFromDisk();

    // Close the boxes — init() will reopen them
    await keysBox.close();
    await settingsBox.close();
  }

  /// Checks whether the legacy Hive box file exists.
  static Future<bool> _legacyBoxExists() async {
    try {
      return Hive.boxExists(_legacyBoxName);
    } catch (_) {
      return false;
    }
  }
}
