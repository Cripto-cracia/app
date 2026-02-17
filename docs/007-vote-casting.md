# 007 — Vote Casting with Anonymous Identity

## Overview

Implements the anonymous vote casting protocol. After a voter obtains a blind
signature token (see [006-blind-token-request](006-blind-token-request.md)),
this service handles the final step: casting the vote without revealing the
voter's identity.

## Protocol

```text
┌──────────┐                              ┌────────────┐
│  Voter   │                              │     EC     │
└────┬─────┘                              └─────┬──────┘
     │                                          │
     │  1. Verify unblinded signature           │
     │     against EC RSA public key            │
     │                                          │
     │  2. Generate NEW anonymous               │
     │     Nostr keypair (ephemeral)            │
     │                                          │
     │  3. Build vote payload:                  │
     │     {hash, token, blinding_factor,       │
     │      candidate_id, election_id}          │
     │                                          │
     │  4. NIP-59 Gift Wrap ──────────────────► │
     │     (anonymous key → EC pubkey)          │
     │                                          │
     │  5. Discard anonymous keypair            │
     └──────────────────────────────────────────┘
```

## Unlinkability Guarantees

The voter's real identity cannot be linked to their vote because:

1. **Blind signature**: The EC signed the token without knowing which voter
   it belongs to (the message was blinded during signing).
2. **Ephemeral anonymous keypair**: A brand-new Nostr keypair is generated
   for each vote. It is never used before or after, and is immediately
   discarded after sending.
3. **NIP-59 Gift Wrap**: Three-layer encryption (Rumor → Seal → Wrap) hides
   both content and metadata. The outer wrapper uses yet another ephemeral
   key, so relay operators cannot correlate the sender.

## Vote Payload

```json
{
  "kind": 2,
  "election_id": "f5f7",
  "candidate_id": 1,
  "hash": "<base64 SHA-256 of nonce>",
  "token": "<base64 unblinded signature>",
  "blinding_factor": "<base64 blinding secret>",
  "message_randomizer": "<base64, if present>"
}
```

- `kind: 2` — Vote submission (vs `kind: 1` for token request).
- `hash` — SHA-256 of the original random nonce.
- `token` — The unblinded RSA signature (the voting credential).
- `blinding_factor` — The secret used during blinding, so the EC can
  verify the token independently.
- `message_randomizer` — Required by RSA-PSS verification (included when
  the blinding library produces one).

## Implementation

### `VoteCastingService`

Located at `lib/services/vote_casting_service.dart`.

| Property | Description |
|---|---|
| `state` | Current flow state: `idle`, `casting`, `cast`, `error` |
| `errorMessage` | Human-readable error when in `error` state |
| `anonymousKeyGenerator` | Callback to produce a fresh Nostr keypair |

**Key method:** `castVote({election, token, candidateId})`

1. Validates the token is ready and matches the election.
2. Validates the candidate exists in the election.
3. Verifies the unblinded signature against the EC's RSA public key.
4. Generates a fresh anonymous Nostr keypair via `anonymousKeyGenerator`.
5. Builds the vote payload using `buildVotePayload()`.
6. Sends via `GiftWrapService.sendGiftWrap()` with the anonymous private key.
7. The anonymous keypair goes out of scope and is garbage-collected.

### Integration

Wire `anonymousKeyGenerator` to dart_nostr's key generation:

```dart
voteCastingService.anonymousKeyGenerator = () {
  final keyPair = nostrService.nostr.services.keys.generateKeyPair();
  return (
    privateKey: keyPair.private,
    publicKey: keyPair.public,
  );
};
```

## Testing

Tests in `test/vote_casting_service_test.dart` cover:

- Initial state and reset
- Vote payload structure and JSON serialization
- Token validation (not ready, wrong election)
- Candidate validation (invalid ID)
- Signature verification (tampered signature rejection)
- State transitions through the casting flow
- Missing `anonymousKeyGenerator` error

All tests use real RSA key pairs generated at test time to verify the full
blind signature → vote casting pipeline.

## Event Kind

Votes use `AppConstants.voteEventKind` (35001), distinct from election
discovery events (35000) and inner protocol message kinds.
