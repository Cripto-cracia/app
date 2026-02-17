# 001 - Project Setup and Core Dependencies

## Overview

Initial project setup for Cripto-cracia, an anonymous voting application built on Nostr with blind RSA signatures. This document explains the project structure and the rationale for each dependency.

## Dependencies

### Cryptography
- **crypto** (`^3.0.6`): Standard hashing algorithms (SHA-256, etc.) used throughout the protocol.
- **elliptic** (`^0.3.11`): Elliptic curve operations needed for Nostr key handling (secp256k1).

### Blind RSA Signatures
- **blind_rsa_signatures** (git: grunch's fork): Core to the anonymous voting protocol. Allows voters to obtain a signature on their vote without revealing the vote content to the signer.

### Nostr Protocol
- **dart_nostr** (`^9.1.1`): Nostr protocol client for connecting to relays, publishing events, and subscribing to event streams.
- **nip59** (git: grunch's fork): NIP-59 Gift Wrap implementation for encrypted, metadata-protected communication between voters and election authorities.

### Key Management
- **bip39** (`^1.0.6`): BIP39 mnemonic seed phrase generation for user-friendly key backup.
- **bech32** (`^0.2.2`): Bech32 encoding for NIP-19 compliant Nostr key representation (npub/nsec).
- **blockchain_utils** (`^3.0.0`): BIP32/BIP44 HD key derivation for deterministic key generation from a single seed.

### State Management
- **provider** (`^6.1.2`): Lightweight, well-established state management solution for Flutter.

### Storage
- **hive** (`^2.2.3`) / **hive_flutter** (`^1.1.0`): Fast, lightweight local database for storing app data (elections, votes, keys).
- **shared_preferences** (`^2.3.3`): Simple key-value storage for app settings.

### Device & App Info
- **device_info_plus** (`^10.1.2`): Device identification for security features.
- **package_info_plus** (`^8.0.2`): App version info for display and diagnostics.

## Project Structure

```text
lib/
  main.dart          - Entry point with Provider setup
  app.dart           - Root MaterialApp widget
  config/
    constants.dart   - App constants (relays, event kinds)
    theme.dart       - Material 3 theme definitions
  models/            - Data models (future phases)
  services/          - Business logic services (future phases)
  screens/
    home_screen.dart - Placeholder home screen
  widgets/           - Reusable widgets (future phases)
```

## CI/CD

GitHub Actions workflow (`.github/workflows/flutter.yml`) runs on every push to `main` and on pull requests:
1. `flutter pub get` - Install dependencies
2. `dart format --set-exit-if-changed .` - Enforce consistent formatting
3. `flutter analyze` - Static analysis
4. `flutter test` - Run all tests

## Linting

Configured via `analysis_options.yaml` with `flutter_lints` as the base, plus additional rules for code quality (trailing commas, const constructors, single quotes, etc.).
