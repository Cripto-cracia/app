# 011 — Integration Tests

## Overview

End-to-end integration tests that verify the full anonymous voting flow
by wiring together the blind signature protocol, vote casting, and results
verification against a mock Electoral Commission (EC) server.

## Architecture

```text
┌─────────────────────────────────────────────────────┐
│                Integration Test                     │
│                                                     │
│  ┌───────────┐    ┌──────────────┐    ┌──────────┐  │
│  │  Election  │───▶│ BlindSignature│───▶│   Vote   │  │
│  │ Discovery  │    │   Protocol   │    │ Casting  │  │
│  └───────────┘    └──────────────┘    └──────────┘  │
│        │                │                   │       │
│        ▼                ▼                   ▼       │
│  ┌─────────────────────────────────────────────────┐│
│  │              MockEcServer                       ││
│  │  • Creates elections (Kind 35000)               ││
│  │  • Signs blinded tokens (RSA blind signatures)  ││
│  │  • Receives votes and emits results (Kind 35001)││
│  │  • Tracks issued tokens (double-voting guard)   ││
│  │  • Simulates errors (network, invalid sigs)     ││
│  └─────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────┘
```

## Mock EC Server

Located at `test/helpers/mock_ec_server.dart`, the `MockEcServer` class
simulates a real EC server entirely in-memory:

- **RSA key pair**: Generated once per test suite via `KeyPair.generate()`.
- **Election creation**: Builds `Election` models and corresponding
  Kind 35000 `NostrEventModel` events that the `ElectionService` can parse.
- **Token signing**: Receives blinded messages, signs them with the RSA
  secret key, and returns blind signatures. Tracks issued tokens to
  prevent double-signing.
- **Vote processing**: Validates votes against election candidates and
  emits Kind 35001 events on a stream for results tracking.
- **Error simulation**: Toggle flags for network failures
  (`simulateNetworkFailure`) and invalid signatures
  (`simulateInvalidSignature`).

## Test Coverage

### End-to-end voting flow

| Test | Description |
|------|-------------|
| Election discovery | Parse Kind 35000 event into `Election` model |
| Full flow | Nonce → blind → EC sign → unblind → verify → vote → results |
| Multiple voters | 5 voters cast votes, tallies verified with `ElectionResult` |
| Real-time results | Vote events stream enables live result tracking |

### Error scenarios

| Test | Description |
|------|-------------|
| Double token request | Same blinded message rejected on second request |
| Nonexistent election | Token request for unknown election rejected |
| Network failure | `simulateNetworkFailure` returns null response |
| Invalid signature | Garbage signature fails unblinding/verification |
| Invalid candidate | Vote for nonexistent candidate rejected |
| Missing signature | `buildVotePayload` throws on unsigned token |

### Election lifecycle

| Test | Description |
|------|-------------|
| Status computation | Upcoming, active, finished, canceled statuses |
| RSA key round-trip | Public key survives event serialization |
| Token serialization | `BlindToken` survives JSON round-trip with valid signature |

## Running the Tests

```bash
# Integration tests only
flutter test test/integration_voting_flow_test.dart

# All tests
flutter test
```

## CI

The GitHub Actions workflow at `.github/workflows/integration-tests.yml`
runs the integration tests on every push and pull request. Since the tests
use an in-memory mock server, no external services are required.

## Design Decisions

1. **In-memory mock over HTTP mock**: The `MockEcServer` operates at the
   protocol level (JSON messages + RSA operations) rather than mocking
   HTTP or WebSocket connections. This tests the actual cryptographic
   flow without network complexity.

2. **Real RSA operations**: Tests use `blind_rsa_signatures` for actual
   blind signing, ensuring the cryptographic protocol is correct
   end-to-end.

3. **No Nostr relay dependency**: The mock bypasses Nostr relay
   connections entirely, making tests fast, deterministic, and
   CI-friendly.
