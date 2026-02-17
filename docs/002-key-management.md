# 002 – Key Management: BIP39 Mnemonic Generation and NIP-06 Derivation

## Overview

Cripto-cracia derives Nostr identity keys from a BIP39 mnemonic seed phrase.
This gives users a portable, human-readable backup (12 or 24 words) that can
reproduce the same key pair on any device.

## Derivation Chain

```
BIP39 Mnemonic (12/24 words)
        │
        ▼
BIP39 Seed (512 bits / 64 bytes)
        │
        ▼
BIP32 Master Key (SLIP-10 secp256k1)
        │
        ▼  m / 44' / 1237' / 0' / 0 / 0
NIP-06 Child Key
        │
        ├──► Private Key (32 bytes hex)  ──► nsec (bech32, NIP-19)
        │
        └──► Public Key  (32 bytes, x-only secp256k1)  ──► npub (bech32, NIP-19)
```

### Derivation Path: `m/44'/1237'/0'/0/0`

| Level | Value  | Meaning |
|-------|--------|---------|
| Purpose | 44'  | BIP-44 multi-account hierarchy |
| Coin type | 1237' | Nostr (registered in SLIP-44) |
| Account | 0' | First account (hardened) |
| Change | 0 | External chain |
| Index | 0 | First key |

This follows the [NIP-06](https://github.com/nostr-protocol/nips/blob/master/06.md)
specification for deterministic Nostr key derivation.

## Architecture

### `KeyManager` (`lib/services/key_manager.dart`)

Pure, stateless utility class — no I/O, no side effects.

| Method | Description |
|--------|-------------|
| `generateMnemonic({strength})` | Returns a new BIP39 mnemonic (12 or 24 words) |
| `validateMnemonic(mnemonic)` | Checks BIP39 validity |
| `deriveNostrKeys(mnemonic)` | Returns a `NostrKeyPair` with all encodings |
| `encodeBech32(hrp, data)` | Encodes raw bytes as bech32 (npub/nsec) |
| `decodeBech32(encoded)` | Decodes bech32 back to HRP + bytes |

### `NostrKeyPair` (`lib/models/key_pair.dart`)

Immutable value object holding:

- `privateKeyHex` / `publicKeyHex` — 32-byte hex strings
- `npub` / `nsec` — NIP-19 bech32 encodings
- `mnemonic` — the source phrase
- `mnemonicWords` / `wordCount` — convenience getters

### `SecureStorage` (`lib/services/secure_storage.dart`)

Encrypted local persistence using Hive + AES-256.

| Method | Description |
|--------|-------------|
| `init()` | Opens the encrypted Hive box (call once at startup) |
| `saveMnemonic(mnemonic)` | Stores the mnemonic |
| `loadMnemonic()` | Retrieves the stored mnemonic (nullable) |
| `deleteMnemonic()` | Removes the mnemonic |
| `hasMnemonic()` | Checks existence |
| `write/read/delete/exists` | Generic key-value API |
| `close()` | Closes the box |

## Security Considerations

1. **Mnemonic is the root secret.** Anyone with the 12/24 words controls the
   identity. The app stores it in an AES-256 encrypted Hive box.

2. **Current key derivation is static-salt.** Phase 5 will add
   device-fingerprint-backed PBKDF2 key derivation (similar to the reference
   `SecureStorageService`) for stronger at-rest protection.

3. **Private keys stay in memory only during use.** `NostrKeyPair` is
   immutable; callers should avoid persisting hex keys separately.

4. **No network calls.** `KeyManager` is fully offline — it never transmits
   keys or mnemonics.

## Dependencies

| Package | Purpose |
|---------|---------|
| `bip39` | Mnemonic generation and validation |
| `blockchain_utils` | BIP32 SLIP-10 secp256k1 HD key derivation |
| `elliptic` | secp256k1 public key computation |
| `bech32` | NIP-19 npub/nsec encoding |
| `hive` / `hive_flutter` | Encrypted local storage |
| `crypto` | SHA-256 for storage key derivation |

## Testing

Tests are in `test/key_manager_test.dart` and `test/secure_storage_test.dart`.

Key test scenarios:
- Valid 12/24-word mnemonic generation
- Deterministic derivation (same mnemonic → same keys)
- bech32 round-trip encoding/decoding
- Secure storage save/load/delete cycle
- Error handling for invalid inputs
