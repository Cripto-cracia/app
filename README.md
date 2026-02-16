# Criptocracia App

Mobile voter client for the **Criptocracia** decentralized e-voting system.

Criptocracia enables fraud-resistant, publicly auditable elections where even the Electoral Commission (EC) cannot link a vote to a voter — while still preventing double voting. Built for contexts where trust in central authorities is limited.

> ⚠️ **Experimental** — This project has not been reviewed by a cryptographer and is not production-ready.

## How It Works

Criptocracia uses **blind RSA signatures** to guarantee voter anonymity while preventing fraud:

1. **Token Request** — The voter generates a random nonce, hashes it, blinds the hash using the EC's RSA public key, and sends the blinded hash to the EC via encrypted Nostr messages (NIP-59 Gift Wrap).
2. **Blind Signature** — The EC verifies the voter is authorized, signs the blinded hash *without seeing its contents*, and returns the blind signature. The voter is then removed from the eligible list (preventing double voting).
3. **Anonymous Vote** — The voter unblinds the signature, verifies it, generates a **new anonymous Nostr keypair**, and casts the vote using this unlinkable identity. The vote includes the hash, token, blinding factor, and candidate selection.
4. **Verification** — The EC verifies the token signature, checks the hash hasn't been used before, records the vote, and publishes updated tallies. At no point can the EC link the vote back to the original voter.

The app connects to an Electoral Commission (EC) server from the [`criptocracia`](https://github.com/Cripto-cracia/criptocracia) repository.

## Tech Stack

- **Flutter** — Cross-platform mobile framework
- **Nostr** — Decentralized communication protocol (NIP-59 Gift Wrap for encrypted messaging)
- **Blind RSA Signatures** — Cryptographic voter anonymity
- **BIP39 / NIP-06** — Mnemonic-based key derivation for Nostr identities

### Nostr Event Kinds

| Kind | Purpose |
|------|---------|
| **35000** | Election announcements (addressable events with election details, candidates, RSA public key) |
| **35001** | Election results (real-time vote tallies per candidate) |
| **NIP-59** | All voter ↔ EC private communication (token requests, vote casting) |

## Roadmap

### Phase 1: Foundation
- Project setup and core dependencies
- BIP39 mnemonic generation and NIP-06 key derivation
- Nostr relay connectivity and NIP-59 Gift Wrap support

### Phase 2: Election Discovery
- Fetch and display elections from Kind 35000 events
- Election list with status (upcoming / active / finished)
- Election detail screen with candidate information

### Phase 3: Blind Signature Protocol
- Blind token request flow (nonce → hash → blind → send → receive signature)
- Vote casting with anonymous Nostr identity
- Full unlinkability between voter and vote

### Phase 4: Results & UX
- Real-time results display from Kind 35001 events
- Visual charts and vote tallies
- Settings screen and EC configuration
- Multi-language support (English / Spanish)

### Phase 5: Security Hardening
- Hardware-backed secure storage for keys and mnemonics
- Integration tests against EC server
- Security audit and code review

## Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (stable channel)
- A running Electoral Commission instance from [`criptocracia`](https://github.com/Cripto-cracia/criptocracia)

## Build & Run

```bash
# Clone the repository
git clone https://github.com/Cripto-cracia/app.git
cd app

# Install dependencies
flutter pub get

# Run on connected device or emulator
flutter run
```

## Related Repositories

- [`criptocracia`](https://github.com/Cripto-cracia/criptocracia) — Electoral Commission server (Rust) and terminal voter client
- [`criptocracia-app`](https://github.com/Cripto-cracia/criptocracia-app) — Previous Flutter client (superseded by this repo)

## License

[MIT](LICENSE)
