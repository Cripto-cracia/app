import 'package:criptocracia_app/models/candidate.dart';
import 'package:criptocracia_app/models/election.dart';
import 'package:criptocracia_app/services/election_service.dart';
import 'package:flutter/foundation.dart';

/// Creates a test election with sensible defaults.
Election createTestElection({
  String id = 'test-1',
  String name = 'Test Election',
  List<Candidate>? candidates,
  DateTime? startTime,
  DateTime? endTime,
  String ecPubkey =
      'abc123def456abc123def456abc123def456abc123def456abc123def456abcd',
  String rawStatus = 'open',
}) {
  final now = DateTime.now();
  return Election(
    id: id,
    name: name,
    candidates:
        candidates ??
        const [Candidate(id: 1, name: 'Alice'), Candidate(id: 2, name: 'Bob')],
    startTime: startTime ?? now.subtract(const Duration(hours: 1)),
    endTime: endTime ?? now.add(const Duration(hours: 23)),
    ecPubkey: ecPubkey,
    rsaPublicKey: 'test-rsa-key',
    rawStatus: rawStatus,
    eventId: 'event-$id',
    createdAt: now,
  );
}

/// A fake ElectionService for widget tests.
class FakeElectionService extends ChangeNotifier implements ElectionService {
  final Map<String, Election> _elections = {};

  void addElection(Election election) {
    _elections[election.id] = election;
    notifyListeners();
  }

  @override
  List<Election> get elections {
    final list = _elections.values.toList()
      ..sort((a, b) => b.startTime.compareTo(a.startTime));
    return list;
  }

  @override
  bool get isDiscovering => false;

  @override
  int get electionCount => _elections.length;

  @override
  List<Election> electionsByStatus(ElectionStatus status) =>
      elections.where((e) => e.status == status).toList();

  @override
  Election? getElection(String id) => _elections[id];

  @override
  void startDiscovery() {}

  @override
  void stopDiscovery() {}

  @override
  void refreshElections() {}
}
