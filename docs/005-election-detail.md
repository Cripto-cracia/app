# 005 - Election Detail Screen

## Overview

The election detail screen displays comprehensive information about a single election, including its status, countdown timer, candidate list, Electoral Commission (EC) information, and a vote action button.

## Components

### ElectionDetailScreen (`lib/screens/election_detail_screen.dart`)

Main screen widget that receives an `electionId` parameter and fetches the election from `ElectionService` via Provider. Sections:

- **Header**: Election name + color-coded status badge
- **Time section**: Countdown timer (active/upcoming) or "Ended" label, with start/end timestamps
- **Candidates section**: List of candidates with radio-button selection (enabled only for active elections)
- **EC section**: Truncated EC pubkey with copy-to-clipboard button
- **Vote button**: Enabled when election is active and a candidate is selected; shows contextual disabled reasons

### StatusBadge (`lib/widgets/status_badge.dart`)

Reusable color-coded badge widget extracted from `ElectionCard`. Maps `ElectionStatus` to label + color:
- Active → green
- Upcoming → amber/orange
- Finished → grey
- Canceled → red

### CountdownTimer (`lib/widgets/countdown_timer.dart`)

Self-updating countdown widget that ticks every second. Formats remaining time as "Xd Xh Xm Xs". Shows "Ended" when the target time has passed. Accepts an optional prefix string.

### CandidateTile (`lib/widgets/candidate_tile.dart`)

List tile for a single candidate showing name, ID, and a radio button for selection state. Prepared for future voting flow integration.

## Navigation

`ElectionsListScreen` navigates to `ElectionDetailScreen` on card tap, passing the election ID. The detail screen uses `Consumer<ElectionService>` to reactively display data.

## Dependencies

- Builds on models from Issue #4 (Election, Candidate)
- Uses `provider` for state management
- No new package dependencies

## Future Work

- Voting flow implementation (Issue #6) will connect to the Vote button
- "Has voted" state tracking to disable re-voting
