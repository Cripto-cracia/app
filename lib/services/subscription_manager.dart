import 'dart:async';

import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter/foundation.dart';

import '../models/nostr_event.dart';
import 'nostr_service.dart';

/// Metadata for a managed subscription.
class _SubscriptionInfo {
  final String name;
  final List<NostrFilter> filters;
  final void Function(NostrEventModel)? onEvent;
  NostrEventsStream? stream;
  StreamController<NostrEventModel>? controller;

  _SubscriptionInfo({
    required this.name,
    required this.filters,
    this.onEvent,
    this.stream,
    this.controller,
  });
}

/// Manages Nostr event subscriptions with deduplication and lifecycle control.
///
/// Provides named subscriptions that can be created, closed, and
/// automatically re-established on reconnection.
class SubscriptionManager {
  /// Reference to the parent NostrService.
  final NostrService nostrService;

  /// Active subscriptions indexed by name.
  final Map<String, _SubscriptionInfo> _subscriptions = {};

  /// Set of seen event IDs for deduplication.
  final Set<String> _seenEventIds = {};

  /// Stream controller for all deduplicated events across subscriptions.
  final StreamController<NostrEventModel> _eventController =
      StreamController<NostrEventModel>.broadcast();

  /// Maximum number of event IDs to track for deduplication.
  static const int _maxSeenEvents = 10000;

  /// Creates a [SubscriptionManager] bound to a [NostrService].
  SubscriptionManager({required this.nostrService});

  /// Stream of all deduplicated events from all subscriptions.
  Stream<NostrEventModel> get eventStream => _eventController.stream;

  /// List of active subscription names.
  List<String> get activeSubscriptions => _subscriptions.keys.toList();

  /// Whether a subscription with the given name exists.
  bool hasSubscription(String name) => _subscriptions.containsKey(name);

  /// Creates a named subscription with the given filters.
  ///
  /// If a subscription with the same name already exists, it is closed first.
  /// The [onEvent] callback is called for each deduplicated event.
  ///
  /// Returns a [Stream<NostrEventModel>] for this specific subscription.
  Stream<NostrEventModel> subscribe({
    required String name,
    required List<NostrFilter> filters,
    void Function(NostrEventModel)? onEvent,
  }) {
    // Close existing subscription with same name.
    if (_subscriptions.containsKey(name)) {
      close(name);
    }

    final controller = StreamController<NostrEventModel>.broadcast();

    final eventsStream = nostrService.subscribe(filters: filters);

    final info = _SubscriptionInfo(
      name: name,
      filters: filters,
      onEvent: onEvent,
      stream: eventsStream,
      controller: controller,
    );

    _subscriptions[name] = info;

    // Listen and deduplicate.
    eventsStream.stream.listen(
      (event) {
        final eventId = event.id;
        if (eventId == null || _seenEventIds.contains(eventId)) return;

        _addSeenEvent(eventId);

        final model = NostrService.toEventModel(event);

        // Emit on subscription-specific stream.
        if (!controller.isClosed) {
          controller.add(model);
        }

        // Emit on global stream.
        if (!_eventController.isClosed) {
          _eventController.add(model);
        }

        // Call the callback.
        onEvent?.call(model);
      },
      onError: (Object error) {
        debugPrint(
          'SubscriptionManager: Error on subscription "$name": $error',
        );
      },
    );

    return controller.stream;
  }

  /// Closes a named subscription.
  void close(String name) {
    final info = _subscriptions.remove(name);
    if (info != null) {
      info.stream?.close();
      info.controller?.close();
      debugPrint('SubscriptionManager: Closed subscription "$name"');
    }
  }

  /// Closes all active subscriptions.
  void closeAll() {
    for (final name in _subscriptions.keys.toList()) {
      close(name);
    }
  }

  /// Re-subscribes all active subscriptions.
  ///
  /// Called after a reconnection to re-establish event streams.
  void resubscribeAll() {
    final entries = Map<String, _SubscriptionInfo>.from(_subscriptions);
    debugPrint(
      'SubscriptionManager: Re-subscribing ${entries.length} subscriptions',
    );

    for (final entry in entries.entries) {
      subscribe(
        name: entry.key,
        filters: entry.value.filters,
        onEvent: entry.value.onEvent,
      );
    }
  }

  /// Tracks a seen event ID for deduplication.
  void _addSeenEvent(String eventId) {
    _seenEventIds.add(eventId);

    // Prune if too large (remove oldest entries by clearing half).
    if (_seenEventIds.length > _maxSeenEvents) {
      final toRemove = _seenEventIds.take(_maxSeenEvents ~/ 2).toList();
      _seenEventIds.removeAll(toRemove);
    }
  }

  /// Clears the deduplication cache.
  void clearDeduplicationCache() {
    _seenEventIds.clear();
  }

  /// Disposes of all resources.
  void dispose() {
    closeAll();
    _eventController.close();
  }
}
