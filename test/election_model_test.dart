import 'dart:convert';

import 'package:criptocracia_app/models/candidate.dart';
import 'package:criptocracia_app/models/election.dart';
import 'package:criptocracia_app/models/nostr_event.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Candidate', () {
    test('fromMap creates a candidate', () {
      final candidate = Candidate.fromMap({'id': 1, 'name': 'Alice'});
      expect(candidate.id, 1);
      expect(candidate.name, 'Alice');
    });

    test('toMap serializes correctly', () {
      const candidate = Candidate(id: 2, name: 'Bob');
      expect(candidate.toMap(), {'id': 2, 'name': 'Bob'});
    });

    test('equality is based on id', () {
      const a = Candidate(id: 1, name: 'Alice');
      const b = Candidate(id: 1, name: 'Alice v2');
      expect(a, equals(b));
    });
  });

  group('Election', () {
    late NostrEventModel event;
    final now = DateTime.now();
    final startInFuture = now.add(const Duration(hours: 1));
    final endInFuture = now.add(const Duration(hours: 2));

    NostrEventModel makeEvent({
      required int startTime,
      required int endTime,
      String status = 'open',
    }) {
      final content = jsonEncode({
        'id': 'abcd',
        'name': 'Test Election',
        'start_time': startTime,
        'end_time': endTime,
        'candidates': [
          {'id': 1, 'name': 'Alice'},
          {'id': 2, 'name': 'Bob'},
        ],
        'status': status,
        'rsa_pub_key': 'MIIBIjAN...',
      });

      return NostrEventModel(
        id: 'event123',
        pubkey: 'ec_pubkey_hex',
        createdAt: now,
        kind: 35000,
        content: content,
        tags: [
          ['d', 'abcd'],
          ['expiration', '9999999999'],
        ],
        sig: 'sig_hex',
      );
    }

    test('fromEvent parses a valid Kind 35000 event', () {
      event = makeEvent(
        startTime: startInFuture.millisecondsSinceEpoch ~/ 1000,
        endTime: endInFuture.millisecondsSinceEpoch ~/ 1000,
      );

      final election = Election.fromEvent(event);
      expect(election, isNotNull);
      expect(election!.id, 'abcd');
      expect(election.name, 'Test Election');
      expect(election.candidates.length, 2);
      expect(election.ecPubkey, 'ec_pubkey_hex');
      expect(election.rsaPublicKey, 'MIIBIjAN...');
      expect(election.eventId, 'event123');
    });

    test('fromEvent returns null for invalid content', () {
      final badEvent = NostrEventModel(
        id: 'bad',
        pubkey: 'pk',
        createdAt: now,
        kind: 35000,
        content: 'not json',
        tags: [],
        sig: '',
      );

      expect(Election.fromEvent(badEvent), isNull);
    });

    test('status is upcoming when start is in the future', () {
      event = makeEvent(
        startTime:
            now.add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000,
        endTime:
            now.add(const Duration(hours: 2)).millisecondsSinceEpoch ~/ 1000,
      );
      final election = Election.fromEvent(event)!;
      expect(election.status, ElectionStatus.upcoming);
    });

    test('status is active when now is between start and end', () {
      event = makeEvent(
        startTime:
            now.subtract(const Duration(hours: 1)).millisecondsSinceEpoch ~/
            1000,
        endTime:
            now.add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000,
      );
      final election = Election.fromEvent(event)!;
      expect(election.status, ElectionStatus.active);
    });

    test('status is finished when end is in the past', () {
      event = makeEvent(
        startTime:
            now.subtract(const Duration(hours: 2)).millisecondsSinceEpoch ~/
            1000,
        endTime:
            now.subtract(const Duration(hours: 1)).millisecondsSinceEpoch ~/
            1000,
      );
      final election = Election.fromEvent(event)!;
      expect(election.status, ElectionStatus.finished);
    });

    test('status is canceled when raw status is canceled', () {
      event = makeEvent(
        startTime:
            now.subtract(const Duration(hours: 1)).millisecondsSinceEpoch ~/
            1000,
        endTime:
            now.add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000,
        status: 'canceled',
      );
      final election = Election.fromEvent(event)!;
      expect(election.status, ElectionStatus.canceled);
    });

    test('toMap and fromMap round-trip correctly', () {
      event = makeEvent(
        startTime: startInFuture.millisecondsSinceEpoch ~/ 1000,
        endTime: endInFuture.millisecondsSinceEpoch ~/ 1000,
      );
      final original = Election.fromEvent(event)!;
      final map = original.toMap();
      final restored = Election.fromMap(map);

      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.candidates.length, original.candidates.length);
      expect(restored.ecPubkey, original.ecPubkey);
      expect(restored.rsaPublicKey, original.rsaPublicKey);
    });

    test('equality is based on id', () {
      event = makeEvent(
        startTime: startInFuture.millisecondsSinceEpoch ~/ 1000,
        endTime: endInFuture.millisecondsSinceEpoch ~/ 1000,
      );
      final a = Election.fromEvent(event)!;
      final b = Election.fromEvent(event)!;
      expect(a, equals(b));
    });
  });
}
