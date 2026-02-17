import 'dart:async';

import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter/foundation.dart';

import '../config/constants.dart';
import '../models/candidate.dart';
import '../models/election_result.dart';
import '../models/nostr_event.dart';
import 'nostr_service.dart';

/// Subscribes to Kind 35001 vote events and tallies results in real-time.
///
/// For each election being tracked, maintains a running tally of votes
/// per candidate and exposes the results as [ElectionResult] objects
/// via a [ChangeNotifier] pattern.
class ElectionResultsService extends ChangeNotifier {
  final NostrService _nostrService;

  /// Vote tallies per election: electionId → (candidateId → count).
  final Map<String, Map<int, int>> _tallies = {};

  /// Candidate lists per election for building results.
  final Map<String, List<Candidate>> _candidates = {};

  /// Latest event timestamp per election.
  final Map<String, DateTime> _lastUpdated = {};

  /// Active subscription names for cleanup.
  final Set<String> _activeSubscriptions = {};

  /// Stream subscriptions for cleanup.
  final Map<String, StreamSubscription<NostrEventModel>> _streamSubscriptions =
      {};

  /// Set of processed event IDs per election for deduplication.
  final Map<String, Set<String>> _processedEvents = {};

  ElectionResultsService({required NostrService nostrService})
    : _nostrService = nostrService;

  /// Returns the current results for an election, or null if not tracking.
  ElectionResult? getResults(String electionId) {
    final tallies = _tallies[electionId];
    final candidates = _candidates[electionId];
    if (tallies == null || candidates == null) return null;

    return ElectionResult.fromTallies(
      electionId: electionId,
      tallies: tallies,
      candidates: candidates,
      lastUpdated: _lastUpdated[electionId] ?? DateTime.now(),
    );
  }

  /// Whether results are being tracked for the given election.
  bool isTracking(String electionId) =>
      _activeSubscriptions.contains(_subscriptionName(electionId));

  /// Starts tracking results for an election.
  ///
  /// Subscribes to Kind 35001 events tagged with the election's event ID
  /// and tallies votes per candidate in real-time.
  void startTracking({
    required String electionId,
    required List<Candidate> candidates,
  }) {
    final subName = _subscriptionName(electionId);
    if (_activeSubscriptions.contains(subName)) return;

    _candidates[electionId] = candidates;
    _tallies[electionId] = {};
    _processedEvents[electionId] = {};
    _lastUpdated[electionId] = DateTime.now();

    final filters = [
      NostrFilter(
        kinds: const [AppConstants.voteEventKind],
        // Match events tagged with this election's ID.
        additionalFilters: {
          '#e': [electionId],
        },
      ),
    ];

    final stream = _nostrService.subscriptionManager.subscribe(
      name: subName,
      filters: filters,
      onEvent: (event) => _handleVoteEvent(event, electionId),
    );

    _streamSubscriptions[electionId] = stream.listen((_) {
      // Events handled by the onEvent callback.
    });

    _activeSubscriptions.add(subName);
    notifyListeners();
    debugPrint(
      'ElectionResultsService: Started tracking results for $electionId',
    );
  }

  /// Stops tracking results for an election.
  void stopTracking(String electionId) {
    final subName = _subscriptionName(electionId);
    if (!_activeSubscriptions.contains(subName)) return;

    _streamSubscriptions[electionId]?.cancel();
    _streamSubscriptions.remove(electionId);
    _nostrService.subscriptionManager.close(subName);
    _activeSubscriptions.remove(subName);
    _tallies.remove(electionId);
    _candidates.remove(electionId);
    _lastUpdated.remove(electionId);
    _processedEvents.remove(electionId);

    debugPrint(
      'ElectionResultsService: Stopped tracking results for $electionId',
    );
  }

  /// Stops tracking all elections.
  void stopAll() {
    for (final electionId in _streamSubscriptions.keys.toList()) {
      stopTracking(electionId);
    }
  }

  /// Handles an incoming Kind 35001 vote event.
  void _handleVoteEvent(NostrEventModel event, String electionId) {
    if (event.kind != AppConstants.voteEventKind) return;

    // Deduplicate within this election's tracking.
    final processed = _processedEvents[electionId];
    if (processed == null || processed.contains(event.id)) return;
    processed.add(event.id);

    final candidateId = ElectionResult.parseCandidateId(event);
    if (candidateId == null) {
      debugPrint(
        'ElectionResultsService: Could not parse candidate_id from '
        'event ${event.id}',
      );
      return;
    }

    // Validate that the candidate exists in this election.
    final candidates = _candidates[electionId];
    if (candidates != null && !candidates.any((c) => c.id == candidateId)) {
      debugPrint(
        'ElectionResultsService: Unknown candidate $candidateId in '
        'election $electionId',
      );
      return;
    }

    // Increment the tally.
    final tallies = _tallies[electionId] ??= {};
    tallies[candidateId] = (tallies[candidateId] ?? 0) + 1;
    _lastUpdated[electionId] = event.createdAt;

    notifyListeners();
    debugPrint(
      'ElectionResultsService: Vote for candidate $candidateId in '
      '$electionId (total: ${tallies[candidateId]})',
    );
  }

  /// Generates a subscription name for an election.
  static String _subscriptionName(String electionId) =>
      'election-results-$electionId';

  @override
  void dispose() {
    stopAll();
    super.dispose();
  }
}
