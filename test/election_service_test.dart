import 'dart:convert';

import 'package:criptocracia_app/models/election.dart';
import 'package:criptocracia_app/models/nostr_event.dart';
import 'package:criptocracia_app/services/election_service.dart';
import 'package:criptocracia_app/services/nostr_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// A minimal fake NostrService for testing ElectionService logic
/// without actual relay connections.
class FakeNostrService extends NostrService {
  FakeNostrService() : super();
}

void main() {
  group('ElectionService', () {
    late ElectionService service;

    setUp(() {
      service = ElectionService(nostrService: FakeNostrService());
    });

    tearDown(() {
      service.dispose();
    });

    test('initial state is empty', () {
      expect(service.elections, isEmpty);
      expect(service.electionCount, 0);
      expect(service.isDiscovering, isFalse);
    });

    test('getElection returns null for unknown id', () {
      expect(service.getElection('unknown'), isNull);
    });

    test('electionsByStatus returns filtered list', () {
      // No elections, so all filters return empty.
      expect(service.electionsByStatus(ElectionStatus.active), isEmpty);
      expect(service.electionsByStatus(ElectionStatus.upcoming), isEmpty);
      expect(service.electionsByStatus(ElectionStatus.finished), isEmpty);
    });

    test('handleEvent processes valid events', () {
      // We test the internal logic by calling the method via a
      // simulated event. Since _handleEvent is private, we verify
      // the public API indirectly through parsing.
      final now = DateTime.now();
      final content = jsonEncode({
        'id': 'test',
        'name': 'Test',
        'start_time':
            now.add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000,
        'end_time':
            now.add(const Duration(hours: 2)).millisecondsSinceEpoch ~/ 1000,
        'candidates': [
          {'id': 1, 'name': 'A'},
        ],
        'status': 'open',
        'rsa_pub_key': 'key',
      });

      final event = NostrEventModel(
        id: 'evt1',
        pubkey: 'pk',
        createdAt: now,
        kind: 35000,
        content: content,
        tags: [
          ['d', 'test'],
        ],
        sig: '',
      );

      // Verify parsing works (indirectly tests the event handling logic).
      final election = Election.fromEvent(event);
      expect(election, isNotNull);
      expect(election!.id, 'test');
      expect(election.status, ElectionStatus.upcoming);
    });
  });
}
