# 008 — Real-time Election Results Display

## Overview

This feature adds real-time election result tracking by subscribing to
Kind 35001 vote events and displaying tallied results with visual bars.

## Architecture

```text
Kind 35001 Events (Nostr Relays)
        │
        ▼
SubscriptionManager
        │
        ▼
ElectionResultsService        ◄── tallies votes per candidate
        │
        ▼
ElectionResult model          ◄── percentages, sorting, leader
        │
        ▼
ElectionResultsWidget         ◄── horizontal bar chart UI
```

## Components

### ElectionResult Model (`lib/models/election_result.dart`)

- **CandidateResult** — vote count + percentage for a single candidate.
- **ElectionResult** — aggregated results for an election, built from tallies.
- Static helpers to parse `candidate_id` and `election_id` from Kind 35001
  event content and tags.
- Factory constructor `fromTallies()` computes percentages and sorts by
  descending vote count.

### ElectionResultsService (`lib/services/election_results_service.dart`)

- Extends `ChangeNotifier` for Provider/Riverpod integration.
- `startTracking(electionId, candidates)` subscribes to Kind 35001 events
  filtered by `#e` tag matching the election ID.
- Maintains per-election tallies and deduplicates events by ID.
- Validates candidate IDs against the known candidate list.
- `getResults(electionId)` returns the current `ElectionResult` snapshot.
- `stopTracking()` / `stopAll()` for cleanup.

### ElectionResultsWidget (`lib/widgets/election_results_widget.dart`)

- Stateless widget that renders an `ElectionResult`.
- Displays horizontal `LinearProgressIndicator` bars colored per candidate.
- Shows candidate name, vote count, and percentage.
- Trophy icon for the leading candidate.
- Empty state when no votes are recorded.
- Singular/plural vote label.

## Event Format

Kind 35001 vote events are expected to have:

- An `e` tag referencing the election ID.
- JSON content with at least `candidate_id` (integer or string).

```json
{
  "candidate_id": 1
}
```

## Real-time Updates

The service uses `SubscriptionManager.subscribe()` which provides a
persistent Nostr subscription. As new vote events arrive from relays,
they are tallied immediately and `notifyListeners()` triggers UI
rebuilds via the standard Provider/ChangeNotifier pattern.

## Tests

- **`test/election_result_model_test.dart`** — percentage computation,
  zero-vote edge cases, parsing from events, equality.
- **`test/election_results_service_test.dart`** — tally accumulation,
  deduplication, unknown candidate rejection, listener notification.
- **`test/election_results_widget_test.dart`** — empty state, candidate
  names/counts/percentages, leader icon, progress bars.
