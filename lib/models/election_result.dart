import 'dart:convert';

import '../models/nostr_event.dart';
import 'candidate.dart';

/// Vote tally for a single candidate.
class CandidateResult {
  /// The candidate.
  final Candidate candidate;

  /// Number of votes received.
  final int voteCount;

  /// Percentage of total votes (0.0 – 100.0).
  final double percentage;

  const CandidateResult({
    required this.candidate,
    required this.voteCount,
    required this.percentage,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CandidateResult &&
          runtimeType == other.runtimeType &&
          candidate == other.candidate &&
          voteCount == other.voteCount;

  @override
  int get hashCode => Object.hash(candidate, voteCount);

  @override
  String toString() =>
      'CandidateResult(${candidate.name}: $voteCount votes, '
      '${percentage.toStringAsFixed(1)}%)';
}

/// Aggregated election results parsed from Kind 35001 events.
class ElectionResult {
  /// The election ID these results belong to.
  final String electionId;

  /// Per-candidate results sorted by vote count (descending).
  final List<CandidateResult> candidateResults;

  /// Total number of votes tallied.
  final int totalVotes;

  /// Timestamp of the latest result event processed.
  final DateTime lastUpdated;

  const ElectionResult({
    required this.electionId,
    required this.candidateResults,
    required this.totalVotes,
    required this.lastUpdated,
  });

  /// The leading candidate, or null if no votes.
  CandidateResult? get leader =>
      candidateResults.isNotEmpty && candidateResults.first.voteCount > 0
      ? candidateResults.first
      : null;

  /// Builds an [ElectionResult] from a vote tally map and candidate list.
  ///
  /// [tallies] maps candidate ID → vote count.
  /// [candidates] is the full candidate list from the election.
  factory ElectionResult.fromTallies({
    required String electionId,
    required Map<int, int> tallies,
    required List<Candidate> candidates,
    required DateTime lastUpdated,
  }) {
    final totalVotes = tallies.values.fold<int>(0, (sum, v) => sum + v);

    final results = candidates.map((candidate) {
      final count = tallies[candidate.id] ?? 0;
      final pct = totalVotes > 0 ? (count / totalVotes) * 100.0 : 0.0;
      return CandidateResult(
        candidate: candidate,
        voteCount: count,
        percentage: pct,
      );
    }).toList()..sort((a, b) => b.voteCount.compareTo(a.voteCount));

    return ElectionResult(
      electionId: electionId,
      candidateResults: results,
      totalVotes: totalVotes,
      lastUpdated: lastUpdated,
    );
  }

  /// Parses a candidate ID from a Kind 35001 vote event.
  ///
  /// The event content is expected to be a JSON object with a
  /// `candidate_id` field (integer).
  ///
  /// Returns `null` if parsing fails.
  static int? parseCandidateId(NostrEventModel event) {
    try {
      final data = jsonDecode(event.content) as Map<String, dynamic>;
      final rawId = data['candidate_id'];
      if (rawId is int) return rawId;
      if (rawId is String) return int.tryParse(rawId);
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Extracts the election ID from a Kind 35001 vote event.
  ///
  /// Looks for an `e` tag first (NIP convention), then falls back to
  /// `election_id` in the JSON content.
  static String? parseElectionId(NostrEventModel event) {
    // Try 'e' tag first (references the election event).
    final eTag = event.getFirstTagValue('e');
    if (eTag != null && eTag.isNotEmpty) return eTag;

    // Fall back to content field.
    try {
      final data = jsonDecode(event.content) as Map<String, dynamic>;
      return data['election_id'] as String?;
    } catch (_) {
      return null;
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ElectionResult &&
          runtimeType == other.runtimeType &&
          electionId == other.electionId &&
          totalVotes == other.totalVotes;

  @override
  int get hashCode => Object.hash(electionId, totalVotes);

  @override
  String toString() =>
      'ElectionResult(election: $electionId, '
      'totalVotes: $totalVotes, '
      'candidates: ${candidateResults.length})';
}
