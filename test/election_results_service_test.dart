import 'dart:async';
import 'dart:convert';

import 'package:criptocracia_app/models/candidate.dart';
import 'package:criptocracia_app/models/nostr_event.dart';
import 'package:criptocracia_app/services/election_results_service.dart';
import 'package:criptocracia_app/services/nostr_service.dart';
import 'package:criptocracia_app/services/subscription_manager.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Minimal fakes
// ---------------------------------------------------------------------------

/// Fake SubscriptionManager that returns a controllable stream.
class FakeSubscriptionManager extends SubscriptionManager {
  final Map<String, StreamController<NostrEventModel>> _controllers = {};

  FakeSubscriptionManager() : super(nostrService: _DummyNostrService());

  @override
  Stream<NostrEventModel> subscribe({
    required String name,
    required List filters,
    void Function(NostrEventModel)? onEvent,
  }) {
    final controller = StreamController<NostrEventModel>.broadcast();
    _controllers[name] = controller;

    // Wire up the onEvent callback.
    controller.stream.listen((event) {
      onEvent?.call(event);
    });

    return controller.stream;
  }

  @override
  void close(String name) {
    _controllers[name]?.close();
    _controllers.remove(name);
  }

  /// Emit a fake event into a named subscription.
  void emit(String name, NostrEventModel event) {
    _controllers[name]?.add(event);
  }

  @override
  bool hasSubscription(String name) => _controllers.containsKey(name);
}

/// Minimal NostrService stub (never connects).
class _DummyNostrService extends NostrService {
  @override
  // ignore: must_call_super
  void dispose() {}
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late FakeSubscriptionManager fakeSubManager;
  late _FakeNostrService fakeNostr;
  late ElectionResultsService service;

  const candidates = [
    Candidate(id: 1, name: 'Alice'),
    Candidate(id: 2, name: 'Bob'),
  ];

  setUp(() {
    fakeSubManager = FakeSubscriptionManager();
    fakeNostr = _FakeNostrService(fakeSubManager);
    service = ElectionResultsService(nostrService: fakeNostr);
  });

  tearDown(() {
    service.dispose();
  });

  NostrEventModel makeVoteEvent({
    required int candidateId,
    String id = 'evt',
    String electionId = 'e1',
  }) {
    return NostrEventModel(
      id: id,
      pubkey: 'a' * 64,
      createdAt: DateTime.now(),
      kind: 35001,
      content: jsonEncode({'candidate_id': candidateId}),
      tags: [
        ['e', electionId],
      ],
      sig: '',
    );
  }

  group('ElectionResultsService', () {
    test('getResults returns null before tracking', () {
      expect(service.getResults('e1'), isNull);
    });

    test('isTracking reflects subscription state', () {
      expect(service.isTracking('e1'), isFalse);
      service.startTracking(electionId: 'e1', candidates: candidates);
      expect(service.isTracking('e1'), isTrue);
      service.stopTracking('e1');
      expect(service.isTracking('e1'), isFalse);
    });

    test('tallies votes from incoming events', () async {
      service.startTracking(electionId: 'e1', candidates: candidates);

      const subName = 'election-results-e1';

      // Emit votes.
      fakeSubManager.emit(subName, makeVoteEvent(candidateId: 1, id: 'v1'));
      fakeSubManager.emit(subName, makeVoteEvent(candidateId: 1, id: 'v2'));
      fakeSubManager.emit(subName, makeVoteEvent(candidateId: 2, id: 'v3'));

      // Let microtasks complete.
      await Future<void>.delayed(Duration.zero);

      final results = service.getResults('e1');
      expect(results, isNotNull);
      expect(results!.totalVotes, 3);

      final aliceResult = results.candidateResults.firstWhere(
        (r) => r.candidate.name == 'Alice',
      );
      expect(aliceResult.voteCount, 2);

      final bobResult = results.candidateResults.firstWhere(
        (r) => r.candidate.name == 'Bob',
      );
      expect(bobResult.voteCount, 1);
    });

    test('deduplicates events with same ID', () async {
      service.startTracking(electionId: 'e1', candidates: candidates);

      const subName = 'election-results-e1';
      final event = makeVoteEvent(candidateId: 1, id: 'dup-1');

      fakeSubManager.emit(subName, event);
      fakeSubManager.emit(subName, event);

      await Future<void>.delayed(Duration.zero);

      final results = service.getResults('e1');
      expect(results!.totalVotes, 1);
    });

    test('ignores votes for unknown candidates', () async {
      service.startTracking(electionId: 'e1', candidates: candidates);

      const subName = 'election-results-e1';
      fakeSubManager.emit(
        subName,
        makeVoteEvent(candidateId: 999, id: 'v-bad'),
      );

      await Future<void>.delayed(Duration.zero);

      final results = service.getResults('e1');
      expect(results!.totalVotes, 0);
    });

    test('ignores events with wrong kind', () async {
      service.startTracking(electionId: 'e1', candidates: candidates);

      const subName = 'election-results-e1';
      fakeSubManager.emit(
        subName,
        NostrEventModel(
          id: 'wrong-kind',
          pubkey: 'a' * 64,
          createdAt: DateTime.now(),
          kind: 1, // Not 35001.
          content: jsonEncode({'candidate_id': 1}),
          tags: [],
          sig: '',
        ),
      );

      await Future<void>.delayed(Duration.zero);

      final results = service.getResults('e1');
      expect(results!.totalVotes, 0);
    });

    test('notifies listeners on new vote', () async {
      service.startTracking(electionId: 'e1', candidates: candidates);

      var notified = false;
      service.addListener(() => notified = true);

      const subName = 'election-results-e1';
      fakeSubManager.emit(subName, makeVoteEvent(candidateId: 1, id: 'v1'));

      await Future<void>.delayed(Duration.zero);
      expect(notified, isTrue);
    });

    test('stopAll clears all subscriptions', () {
      service.startTracking(electionId: 'e1', candidates: candidates);
      service.startTracking(
        electionId: 'e2',
        candidates: [const Candidate(id: 10, name: 'X')],
      );

      expect(service.isTracking('e1'), isTrue);
      expect(service.isTracking('e2'), isTrue);

      service.stopAll();

      expect(service.isTracking('e1'), isFalse);
      expect(service.isTracking('e2'), isFalse);
    });
  });
}

/// Fake NostrService that uses our fake SubscriptionManager.
class _FakeNostrService extends NostrService {
  final FakeSubscriptionManager _fakeSubManager;

  _FakeNostrService(this._fakeSubManager);

  @override
  SubscriptionManager get subscriptionManager => _fakeSubManager;

  @override
  // ignore: must_call_super
  void dispose() {}
}
