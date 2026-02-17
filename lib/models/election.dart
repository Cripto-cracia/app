import 'dart:convert';

import '../models/nostr_event.dart';
import 'candidate.dart';

/// The status of an election computed from its timing.
enum ElectionStatus {
  /// Voting has not started yet.
  upcoming,

  /// Voting is currently in progress.
  active,

  /// Voting has ended.
  finished,

  /// Election was canceled.
  canceled,
}

/// An election discovered from a Kind 35000 Nostr event.
class Election {
  /// Short hex identifier for the election (e.g. "f5f7").
  final String id;

  /// Human-readable election name.
  final String name;

  /// List of candidates.
  final List<Candidate> candidates;

  /// Unix timestamp when voting begins.
  final DateTime startTime;

  /// Unix timestamp when voting ends.
  final DateTime endTime;

  /// The EC's Nostr public key (hex).
  final String ecPubkey;

  /// The EC's RSA public key (Base64 DER) for blind signature verification.
  final String rsaPublicKey;

  /// Raw status string from the backend event.
  final String rawStatus;

  /// The Nostr event ID this election was parsed from.
  final String eventId;

  /// When this election event was created/updated.
  final DateTime createdAt;

  const Election({
    required this.id,
    required this.name,
    required this.candidates,
    required this.startTime,
    required this.endTime,
    required this.ecPubkey,
    required this.rsaPublicKey,
    required this.rawStatus,
    required this.eventId,
    required this.createdAt,
  });

  /// Computes the election status based on current time and raw status.
  ElectionStatus get status {
    if (rawStatus == 'canceled') return ElectionStatus.canceled;

    final now = DateTime.now();
    if (now.isBefore(startTime)) return ElectionStatus.upcoming;
    if (now.isAfter(endTime)) return ElectionStatus.finished;
    return ElectionStatus.active;
  }

  /// Duration of the election.
  Duration get duration => endTime.difference(startTime);

  /// Parses an [Election] from a Kind 35000 [NostrEventModel].
  ///
  /// Returns `null` if the event content cannot be parsed.
  static Election? fromEvent(NostrEventModel event) {
    try {
      final data = jsonDecode(event.content) as Map<String, dynamic>;

      final candidatesList =
          (data['candidates'] as List?)
              ?.map((c) => Candidate.fromMap(c as Map<String, dynamic>))
              .toList() ??
          [];

      return Election(
        id: data['id'] as String,
        name: data['name'] as String,
        candidates: candidatesList,
        startTime: DateTime.fromMillisecondsSinceEpoch(
          (data['start_time'] as int) * 1000,
        ),
        endTime: DateTime.fromMillisecondsSinceEpoch(
          (data['end_time'] as int) * 1000,
        ),
        ecPubkey: event.pubkey,
        rsaPublicKey: data['rsa_pub_key'] as String? ?? '',
        rawStatus: data['status'] as String? ?? 'open',
        eventId: event.id,
        createdAt: event.createdAt,
      );
    } catch (e) {
      return null;
    }
  }

  /// Serializes to a map for local caching.
  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'candidates': candidates.map((c) => c.toMap()).toList(),
    'start_time': startTime.millisecondsSinceEpoch ~/ 1000,
    'end_time': endTime.millisecondsSinceEpoch ~/ 1000,
    'ec_pubkey': ecPubkey,
    'rsa_pub_key': rsaPublicKey,
    'raw_status': rawStatus,
    'event_id': eventId,
    'created_at': createdAt.millisecondsSinceEpoch ~/ 1000,
  };

  /// Deserializes from a cached map.
  factory Election.fromMap(Map<String, dynamic> map) {
    return Election(
      id: map['id'] as String,
      name: map['name'] as String,
      candidates: (map['candidates'] as List)
          .map((c) => Candidate.fromMap(c as Map<String, dynamic>))
          .toList(),
      startTime: DateTime.fromMillisecondsSinceEpoch(
        (map['start_time'] as int) * 1000,
      ),
      endTime: DateTime.fromMillisecondsSinceEpoch(
        (map['end_time'] as int) * 1000,
      ),
      ecPubkey: map['ec_pubkey'] as String,
      rsaPublicKey: map['rsa_pub_key'] as String,
      rawStatus: map['raw_status'] as String,
      eventId: map['event_id'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (map['created_at'] as int) * 1000,
      ),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Election && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Election(id: $id, name: $name, status: $status)';
}
