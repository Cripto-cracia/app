# 006 — Blind Token Request Flow

## Overview

This document describes the blind RSA signature protocol used to request
anonymous voting tokens from the Electoral Commission (EC). The protocol
ensures that:

- The EC **cannot link** a token to the voter who requested it.
- Each authorized voter receives **exactly one** token per election.
- The token can be verified by anyone with the EC's RSA public key.

## Protocol Flow

```
Voter                                    EC (Electoral Commission)
  │                                        │
  │  1. Generate nonce (32 bytes)          │
  │  2. h = SHA-256(nonce)                 │
  │  3. (blinded_h, secret, rand)          │
  │     = blind(h, EC_RSA_PubKey)          │
  │                                        │
  │  4. ─── Gift Wrap {                    │
  │         kind: 1,                       │
  │         payload: base64(blinded_h),    │
  │         election_id: "f5f7"            │
  │     } ──────────────────────────────►  │
  │                                        │  5. Verify voter is authorized
  │                                        │  6. blind_sig = RSA_sign(blinded_h)
  │                                        │  7. Remove voter from authorized list
  │                                        │
  │  ◄────────── Gift Wrap {               │
  │              kind: 1,                  │
  │              payload: base64(blind_sig)│
  │          } ────────────────────────────│
  │                                        │
  │  8. sig = unblind(blind_sig, secret)   │
  │  9. verify(h, sig, rand, PubKey)       │
  │ 10. Store: nonce, sig, rand,           │
  │     election_id                        │
  │                                        │
```

## Message Format

Token request and response messages use JSON matching the backend's
`Message` struct:

```json
{
  "id": "<request-id>",
  "kind": 1,
  "payload": "<base64-encoded data>",
  "election_id": "<4-char hex id>"
}
```

- **Request payload**: Base64-encoded blinded message bytes
- **Response payload**: Base64-encoded blind signature bytes

## Cryptographic Details

| Parameter      | Value                                |
|----------------|--------------------------------------|
| RSA key size   | 2048 bits (minimum)                  |
| Hash function  | SHA-384 (blind signature padding)    |
| PSS salt       | Auto (hash output size)              |
| Nonce size     | 32 bytes (256 bits)                  |
| Nonce hash     | SHA-256                              |
| Randomizer     | 32 bytes (used in blinding)          |

The blind signature scheme uses RSA-PSS padding with SHA-384 internally
(via `Options.defaultOptions` in `blind_rsa_signatures`). The nonce is
hashed with SHA-256 to produce the message that gets blinded.

## Components

### `BlindSignatureService`

Core service implementing the protocol. Exposes:

- `requestBlindToken(election, senderPrivateKey)` — full flow
- `generateNonce()` / `hashMessage()` — crypto primitives
- `unblindSignature()` / `verifyToken()` — token operations
- State: `idle` → `requesting` → `received` | `error`

### `BlindToken` Model

Stores all data needed for the token lifecycle:

- `nonce`, `hashedNonce` — the secret and its hash
- `blindedMessage`, `secret`, `messageRandomizer` — blinding artifacts
- `blindSignature` — EC's response (before unblinding)
- `unblindedSignature` — the final voting token
- `status` — lifecycle state

### `TokenStorageService`

Encrypted persistence via `SecureStorage` (Hive + AES-256).
One token per election, keyed by election ID.

## Vote Casting (Future)

The stored token is used to cast an anonymous vote:

```
payload = base64(h) : base64(sig) : base64(rand) : candidate_id
```

Sent via NIP-59 Gift Wrap using a **fresh anonymous Nostr keypair**,
making it unlinkable to the original voter identity.

## Security Considerations

- The nonce and blinding secret **never leave the device** unencrypted.
- The blinded message reveals nothing about the nonce to the EC.
- The unblinded signature cannot be linked to the blinding session.
- Token storage uses AES-256 encryption at rest.
- NIP-59 Gift Wrap provides end-to-end encryption in transit.
