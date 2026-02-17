# 010 — Secure Storage

## Summary

Hardware-backed encrypted storage for private keys, mnemonics, and
application settings with platform-specific secure enclave integration and
namespace isolation.

## Problem

The original `SecureStorage` implementation stored the Hive AES-256
encryption key in `SharedPreferences`, which is an unencrypted XML file on
Android and an unencrypted plist on iOS. An attacker with file-system access
(rooted device, backup extraction) could recover the encryption key and
decrypt all stored data.

## Architecture

```text
┌─────────────────────────────────────────────┐
│               Application                    │
│  ┌────────────┐   ┌───────────────────────┐ │
│  │ KeyManager  │   │ SettingsService       │ │
│  │ TokenStore  │   │ (relay list, theme…)  │ │
│  └─────┬──────┘   └──────────┬────────────┘ │
│        │ keys namespace       │ settings ns  │
│  ┌─────▼──────┐   ┌──────────▼────────────┐ │
│  │ Hive Box    │   │ Hive Box              │ │
│  │ AES-256     │   │ AES-256               │ │
│  └─────┬──────┘   └──────────┬────────────┘ │
│        │ enc key              │ enc key      │
│  ┌─────▼──────────────────────▼────────────┐ │
│  │      flutter_secure_storage             │ │
│  │  Android Keystore / iOS Keychain        │ │
│  └─────────────────────────────────────────┘ │
└─────────────────────────────────────────────┘
```

### Key storage

Encryption keys for the Hive boxes are now stored via
`flutter_secure_storage`, which delegates to:

| Platform | Backend                      | Hardware-backed |
|----------|------------------------------|-----------------|
| Android  | EncryptedSharedPreferences    | Yes (Keystore)  |
| iOS      | Keychain (first_unlock_this_device) | Yes (Secure Enclave) |

### Namespace isolation

Data is split into two encrypted Hive boxes, each with its own
encryption key:

- **`keys`** — Private keys, mnemonics, blind-signature tokens.
  High-sensitivity material that should only be accessed by
  cryptographic services.
- **`settings`** — Relay URLs, theme preference, EC public key.
  Non-sensitive configuration data.

This means a vulnerability that leaks settings data does not expose
private key material.

### API

```dart
// Mnemonic helpers (always use keys namespace internally)
await SecureStorage.saveMnemonic(mnemonic);
final m = await SecureStorage.loadMnemonic();

// Generic key-value with explicit namespace
await SecureStorage.write(
  key: 'my_key',
  value: 'my_value',
  namespace: StorageNamespace.keys,
);

// Default namespace is settings (backward compatible)
await SecureStorage.write(key: 'theme', value: 'dark');
```

## Migration

Users upgrading from the previous version have their encryption key in
`SharedPreferences` and a single unified Hive box. The migration runs
automatically on first `init()`:

1. **Encryption key migration** — If a key exists in
   `SharedPreferences` (`criptocracia_enc_key`), it is copied to
   `flutter_secure_storage` and deleted from SharedPreferences.
2. **Data migration** — If the legacy Hive box (`criptocracia_secure`)
   exists, its entries are distributed to the appropriate namespace box
   based on key prefixes (`nostr_mnemonic` and `blind_token_*` → keys;
   everything else → settings). The legacy box is then deleted.

Both steps are idempotent and safe to run multiple times.

## Android configuration

`flutter_secure_storage` with `encryptedSharedPreferences: true` requires
`minSdkVersion 23` (Android 6.0+), which is the Flutter default.

## Testing

Tests use `FlutterSecureStorage.setMockInitialValues({})` to mock
the secure enclave in memory, allowing the full
init → write → read → close → reinit cycle to be tested without
platform channels. Key tests:

- Namespace isolation (keys vs settings)
- Encryption keys stored in secure enclave (not SharedPreferences)
- Per-namespace encryption key separation
- Legacy migration from SharedPreferences
- Data persistence across close/reinit cycles

## Files changed

- `lib/services/secure_storage.dart` — Rewritten with namespaces and
  hardware-backed key storage
- `lib/services/token_storage_service.dart` — Uses `StorageNamespace.keys`
- `test/secure_storage_test.dart` — Comprehensive tests with fake secure
  storage
- `pubspec.yaml` — Added `flutter_secure_storage` dependency
