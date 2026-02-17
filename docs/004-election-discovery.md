# 004 — Election Discovery from Kind 35000 Events

## Overview

This PR implements election discovery by subscribing to Kind 35000
addressable Nostr events published by Electoral Commission (EC) servers.
Elections are parsed, cached in-memory, and displayed in a filterable list UI.

## Kind 35000 Event Format

The EC publishes election announcements as Kind 35000 addressable events.
The event content is a JSON object:

```json
{
  "id": "f5f7",
  "name": "Libertad 2024",
  "start_time": 1746611643,
  "end_time": 1746615243,
  "candidates": [
    { "id": 1, "name": "Donkey 🫏" },
    { "id": 2, "name": "Rat 🐀" }
  ],
  "status": "open",
  "rsa_pub_key": "MIIBIjAN..."
}
```

Tags: `["d", "<election_id>"]`, `["expiration", "<unix_timestamp>"]`.

Status values from backend: `open`, `in-progress`, `finished`, `canceled`.

## Architecture

### Models

- **`Candidate`** — Simple value object with `id` (int) and `name`.
- **`Election`** — Parsed from Kind 35000 events. Contains all election
  metadata. `ElectionStatus` is computed client-side from `startTime`,
  `endTime`, and `rawStatus` (canceled overrides time-based status).

### Services

- **`ElectionService`** — A `ChangeNotifier` that subscribes to Kind 35000
  events via `SubscriptionManager`, parses them into `Election` models,
  deduplicates by election ID (keeping the newest event), and exposes
  filtering/sorting methods.

### UI

- **`ElectionsListScreen`** — Shows elections in a scrollable list with
  pull-to-refresh. Supports status filtering via a popup menu. Shows a
  loading indicator during initial discovery and an empty state with a
  refresh button when no elections are found.
- **`ElectionCard`** — Material card with election name, color-coded status
  badge, start time, and candidate count.

### Provider Integration

`NostrService` and `ElectionService` are registered in `MultiProvider`
in `main.dart`. The elections list screen is set as the app home.

## Status Computation

| Condition | Status |
|-----------|--------|
| `rawStatus == "canceled"` | `canceled` |
| `now < startTime` | `upcoming` |
| `now > endTime` | `finished` |
| otherwise | `active` |

## Files Changed

| File | Description |
|------|-------------|
| `lib/models/candidate.dart` | Candidate model |
| `lib/models/election.dart` | Election model with parsing and status |
| `lib/services/election_service.dart` | Election discovery service |
| `lib/screens/elections_list_screen.dart` | Election list UI |
| `lib/widgets/election_card.dart` | Election card widget |
| `lib/main.dart` | Added providers |
| `lib/app.dart` | Set ElectionsListScreen as home |
| `test/election_model_test.dart` | Model tests |
| `test/election_service_test.dart` | Service tests |
| `test/elections_list_screen_test.dart` | Widget tests |
| `test/home_screen_test.dart` | Updated for new home screen |

## Next Steps

- Issue #5: Election detail screen with candidate list and voting flow
- Results display from Kind 35001 events
- Local persistence of discovered elections
