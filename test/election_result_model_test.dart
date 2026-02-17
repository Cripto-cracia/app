import 'dart:convert';

import 'package:criptocracia_app/models/candidate.dart';
import 'package:criptocracia_app/models/election_result.dart';
import 'package:criptocracia_app/models/nostr_event.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final candidates = [
    const Candidate(id: 1, name: 'Alice'),
    const Candidate(id: 2, name: 'Bob'),
    const Candidate(id: 3, name: 'Charlie'),
  ];

  group('ElectionResult.fromTallies', () {
    test('computes percentages correctly', () {
      final result = ElectionResult.fromTallies(
        electionId: 'e1',
        tallies: {1: 60, 2: 30, 3: 10},
        candidates: candidates,
        lastUpdated: DateTime(2025),
      );

      expect(result.totalVotes, 100);
      expect(result.candidateResults.length, 3);
      // Sorted by vote count descending.
      expect(result.candidateResults[0].candidate.name, 'Alice');
      expect(result.candidateResults[0].percentage, 60.0);
      expect(result.candidateResults[1].candidate.name, 'Bob');
      expect(result.candidateResults[1].percentage, 30.0);
      expect(result.candidateResults[2].candidate.name, 'Charlie');
      expect(result.candidateResults[2].percentage, 10.0);
    });

    test('handles zero votes', () {
      final result = ElectionResult.fromTallies(
        electionId: 'e1',
        tallies: {},
        candidates: candidates,
        lastUpdated: DateTime(2025),
      );

      expect(result.totalVotes, 0);
      for (final cr in result.candidateResults) {
        expect(cr.voteCount, 0);
        expect(cr.percentage, 0.0);
      }
    });

    test('handles missing candidate tallies', () {
      final result = ElectionResult.fromTallies(
        electionId: 'e1',
        tallies: {1: 5},
        candidates: candidates,
        lastUpdated: DateTime(2025),
      );

      expect(result.totalVotes, 5);
      expect(result.leader!.candidate.name, 'Alice');
      expect(result.leader!.percentage, 100.0);
    });

    test('leader returns null when no votes', () {
      final result = ElectionResult.fromTallies(
        electionId: 'e1',
        tallies: {},
        candidates: candidates,
        lastUpdated: DateTime(2025),
      );

      expect(result.leader, isNull);
    });
  });

  group('ElectionResult.parseCandidateId', () {
    test('parses integer candidate_id', () {
      final event = _makeVoteEvent({'candidate_id': 2});
      expect(ElectionResult.parseCandidateId(event), 2);
    });

    test('parses string candidate_id', () {
      final event = _makeVoteEvent({'candidate_id': '3'});
      expect(ElectionResult.parseCandidateId(event), 3);
    });

    test('returns null for missing candidate_id', () {
      final event = _makeVoteEvent({'foo': 'bar'});
      expect(ElectionResult.parseCandidateId(event), isNull);
    });

    test('returns null for invalid content', () {
      final event = NostrEventModel(
        id: 'evt1',
        pubkey: 'a' * 64,
        createdAt: DateTime(2025),
        kind: 35001,
        content: 'not json',
        tags: [],
        sig: '',
      );
      expect(ElectionResult.parseCandidateId(event), isNull);
    });
  });

  group('ElectionResult.parseElectionId', () {
    test('extracts from e tag', () {
      final event = NostrEventModel(
        id: 'evt1',
        pubkey: 'a' * 64,
        createdAt: DateTime(2025),
        kind: 35001,
        content: '{}',
        tags: [
          ['e', 'election-123'],
        ],
        sig: '',
      );
      expect(ElectionResult.parseElectionId(event), 'election-123');
    });

    test('falls back to content election_id', () {
      final event = _makeVoteEvent({'election_id': 'e-456'});
      expect(ElectionResult.parseElectionId(event), 'e-456');
    });

    test('returns null when not found', () {
      final event = _makeVoteEvent({'foo': 'bar'});
      expect(ElectionResult.parseElectionId(event), isNull);
    });
  });

  group('CandidateResult', () {
    test('equality by candidate and voteCount', () {
      const a = CandidateResult(
        candidate: Candidate(id: 1, name: 'Alice'),
        voteCount: 10,
        percentage: 50.0,
      );
      const b = CandidateResult(
        candidate: Candidate(id: 1, name: 'Alice'),
        voteCount: 10,
        percentage: 50.0,
      );
      expect(a, equals(b));
    });

    test('toString includes name and count', () {
      const cr = CandidateResult(
        candidate: Candidate(id: 1, name: 'Alice'),
        voteCount: 10,
        percentage: 50.0,
      );
      expect(cr.toString(), contains('Alice'));
      expect(cr.toString(), contains('10'));
    });
  });
}

NostrEventModel _makeVoteEvent(Map<String, dynamic> content) {
  return NostrEventModel(
    id: 'evt1',
    pubkey: 'a' * 64,
    createdAt: DateTime(2025),
    kind: 35001,
    content: jsonEncode(content),
    tags: [],
    sig: '',
  );
}
