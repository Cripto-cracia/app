import 'dart:async';

import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter/foundation.dart';

import '../config/constants.dart';
import '../models/election.dart';
import '../models/nostr_event.dart';
import 'nostr_service.dart';

/// Discovers and manages elections from Kind 35000 Nostr events.
///
/// Subscribes to election announcement events via [SubscriptionManager],
/// parses them into [Election] models, and exposes them as a
/// [ChangeNotifier] for Provider-based state management.
class ElectionService extends ChangeNotifier {
  /// Reference to the Nostr connectivity service.
  final NostrService _nostrService;

  /// In-memory cache of discovered elections keyed by election ID.
  final Map<String, Election> _elections = {};

  /// Whether the service is currently discovering elections.
  bool _isDiscovering = false;

  /// Subscription name used with the SubscriptionManager.
  static const String _subscriptionName = 'election-discovery';

  /// Stream subscription for election events.
  StreamSubscription<NostrEventModel>? _eventSubscription;

  /// Creates an [ElectionService] bound to a [NostrService].
  ElectionService({required NostrService nostrService})
    : _nostrService = nostrService;

  /// All discovered elections sorted by start time (newest first).
  List<Election> get elections {
    final list = _elections.values.toList()
      ..sort((a, b) => b.startTime.compareTo(a.startTime));
    return list;
  }

  /// Whether the service is currently discovering elections.
  bool get isDiscovering => _isDiscovering;

  /// Number of discovered elections.
  int get electionCount => _elections.length;

  /// Returns elections filtered by status.
  List<Election> electionsByStatus(ElectionStatus status) {
    return elections.where((e) => e.status == status).toList();
  }

  /// Returns a single election by its ID, or null.
  Election? getElection(String id) => _elections[id];

  /// Starts discovering elections from configured relays.
  ///
  /// Subscribes to Kind 35000 events and processes incoming elections.
  void startDiscovery() {
    if (_isDiscovering) return;
    _isDiscovering = true;
    notifyListeners();

    final filters = [
      const NostrFilter(kinds: [AppConstants.electionEventKind]),
    ];

    final stream = _nostrService.subscriptionManager.subscribe(
      name: _subscriptionName,
      filters: filters,
      onEvent: _handleEvent,
    );

    _eventSubscription = stream.listen((_) {
      // Events are handled by the onEvent callback.
    });

    debugPrint('ElectionService: Started election discovery');
  }

  /// Stops discovering elections.
  void stopDiscovery() {
    if (!_isDiscovering) return;

    _eventSubscription?.cancel();
    _eventSubscription = null;
    _nostrService.subscriptionManager.close(_subscriptionName);

    _isDiscovering = false;
    notifyListeners();
    debugPrint('ElectionService: Stopped election discovery');
  }

  /// Refreshes elections by restarting the subscription.
  void refreshElections() {
    stopDiscovery();
    _elections.clear();
    notifyListeners();
    startDiscovery();
  }

  /// Handles an incoming Kind 35000 event.
  void _handleEvent(NostrEventModel event) {
    if (event.kind != AppConstants.electionEventKind) return;

    final election = Election.fromEvent(event);
    if (election == null) {
      debugPrint(
        'ElectionService: Failed to parse election from event ${event.id}',
      );
      return;
    }

    // Only update if this event is newer than what we have.
    final existing = _elections[election.id];
    if (existing != null && existing.createdAt.isAfter(election.createdAt)) {
      return;
    }

    _elections[election.id] = election;
    notifyListeners();
    debugPrint(
      'ElectionService: Discovered election "${election.name}" '
      '(${election.id})',
    );
  }

  @override
  void dispose() {
    stopDiscovery();
    super.dispose();
  }
}
