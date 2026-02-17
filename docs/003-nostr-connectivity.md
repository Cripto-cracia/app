# 003 — Nostr Connectivity and Relay Management

## Overview

This document describes the Nostr connectivity layer for Cripto-cracia, implementing relay management, event subscriptions, and NIP-59 Gift Wrap encrypted messaging.

## Architecture

```
┌──────────────────────────────────────────────┐
│                    UI Layer                   │
│              (Provider/Consumer)              │
├──────────────┬───────────────┬───────────────┤
│ NostrService │ Subscription  │  GiftWrap     │
│              │   Manager     │   Service     │
├──────────────┴───────────────┴───────────────┤
│              dart_nostr / nip59               │
├──────────────────────────────────────────────┤
│           WebSocket (Relay Network)           │
└──────────────────────────────────────────────┘
```

### Components

1. **NostrService** (`lib/services/nostr_service.dart`) — Core connectivity layer using `dart_nostr`. Manages relay connections, publishes events, and exposes connection state via `ChangeNotifier` and streams.

2. **SubscriptionManager** (`lib/services/subscription_manager.dart`) — Named subscription lifecycle management with event deduplication and automatic re-subscription on reconnection.

3. **GiftWrapService** (`lib/services/gift_wrap_service.dart`) — NIP-59 Gift Wrap send/receive using the `nip59` package. Provides encrypted messaging with three-layer encryption (Rumor → Seal → Wrap).

### Models

- **RelayConfig** (`lib/models/relay_config.dart`) — Relay URL, read/write flags, and connection status.
- **NostrEventModel** (`lib/models/nostr_event.dart`) — App-layer event model decoupled from `dart_nostr` internals.

## Design Decisions

### Why a separate NostrEventModel?

The `dart_nostr` package's `NostrEvent` uses nullable fields and is tightly coupled to wire format. `NostrEventModel` provides a cleaner API with non-nullable fields, tag helpers, and serialization for local storage.

### Connection State Management

The service exposes connection state via:
- `connectionState` getter (synchronous)
- `connectionStateStream` (async stream for UI binding)
- `ChangeNotifier` (for Provider integration)

States: `disconnected → connecting → connected` with automatic `reconnecting` on failure.

### Exponential Backoff

Reconnection uses exponential backoff starting at 2 seconds, doubling each attempt, capped at 120 seconds. The counter resets on successful connection.

### Event Deduplication

The `SubscriptionManager` tracks seen event IDs (up to 10,000) and drops duplicates. This handles the common case of receiving the same event from multiple relays.

### NIP-59 Integration

The `GiftWrapService` wraps the `nip59` package's static API, providing:
- `sendGiftWrap()` — Creates and publishes a gift-wrapped event
- `unwrappedEvents` stream — Automatically decrypts incoming wraps
- `decryptEvent()` — Manual decryption for cached events

### Offline Handling

- Services initialize gracefully when relays are unreachable
- Auto-reconnection ensures connectivity is restored when network returns
- Future integration with Hive will cache events for offline access
- The UI can observe `connectionState` to show offline indicators

## Integration with Key Management (PR #14)

This layer is designed to be compatible with the KeyManager from PR #14:

```dart
final keyPair = await keyManager.getKeyPair();
giftWrapService.sendGiftWrap(
  recipientPubkey: recipientPubkey,
  content: content,
  senderPrivateKey: keyPair.privateKeyHex,
);
```

## Future Work

- Persist relay list in Hive storage
- NIP-65 relay list metadata support
- Event caching for offline access
- Relay health monitoring and scoring
- Per-relay read/write filtering for subscriptions
