import 'dart:async';

import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter/foundation.dart';

import '../config/constants.dart';
import '../models/nostr_event.dart';
import '../models/relay_config.dart';
import 'subscription_manager.dart';

/// Overall connection state of the Nostr service.
enum NostrConnectionState {
  /// Not connected to any relay.
  disconnected,

  /// Connecting to relays.
  connecting,

  /// Connected to at least one relay.
  connected,

  /// Reconnecting after a connection loss.
  reconnecting,
}

/// Core Nostr connectivity service.
///
/// Manages relay connections, event publishing, and subscriptions.
/// Uses [ChangeNotifier] for Provider-based state management.
class NostrService extends ChangeNotifier {
  /// The underlying dart_nostr instance.
  final Nostr _nostr;

  /// Current relay configurations.
  final List<RelayConfig> _relays = [];

  /// Current connection state.
  NostrConnectionState _connectionState = NostrConnectionState.disconnected;

  /// Stream controller for connection state changes.
  final StreamController<NostrConnectionState> _connectionStateController =
      StreamController<NostrConnectionState>.broadcast();

  /// Subscription manager for event subscriptions.
  late final SubscriptionManager _subscriptionManager;

  /// Whether the service has been initialized.
  bool _initialized = false;

  /// Reconnection attempt count (for exponential backoff).
  int _reconnectAttempts = 0;

  /// Maximum reconnection delay in seconds.
  static const int _maxReconnectDelay = 120;

  /// Base reconnection delay in seconds.
  static const int _baseReconnectDelay = 2;

  /// Timer for reconnection attempts.
  Timer? _reconnectTimer;

  /// Creates a new [NostrService] with an optional custom [Nostr] instance.
  NostrService({Nostr? nostrInstance})
    : _nostr = nostrInstance ?? Nostr.instance {
    _subscriptionManager = SubscriptionManager(nostrService: this);
  }

  /// Current connection state.
  NostrConnectionState get connectionState => _connectionState;

  /// Stream of connection state changes.
  Stream<NostrConnectionState> get connectionStateStream =>
      _connectionStateController.stream;

  /// Whether the service is connected to at least one relay.
  bool get isConnected => _connectionState == NostrConnectionState.connected;

  /// Current relay configurations (unmodifiable).
  List<RelayConfig> get relays => List.unmodifiable(_relays);

  /// The subscription manager.
  SubscriptionManager get subscriptionManager => _subscriptionManager;

  /// Whether the service has been initialized.
  bool get initialized => _initialized;

  /// The underlying Nostr instance (for advanced usage).
  Nostr get nostr => _nostr;

  /// Initializes the Nostr service and connects to default relays.
  ///
  /// Must be called before using any other methods.
  Future<void> initialize() async {
    if (_initialized) return;

    // Set up relay configurations from defaults.
    for (final url in AppConstants.defaultRelays) {
      _relays.add(RelayConfig(url: url));
    }

    await _connect();
    _initialized = true;
  }

  /// Connects to all configured relays.
  Future<void> _connect() async {
    _setConnectionState(NostrConnectionState.connecting);

    final relayUrls = _relays.map((r) => r.url).toList();

    try {
      await _nostr.services.relays.init(
        relaysUrl: relayUrls,
        onRelayListening: _onRelayListening,
        onRelayConnectionError: _onRelayConnectionError,
        onRelayConnectionDone: _onRelayConnectionDone,
        lazyListeningToRelays: false,
        retryOnError: true,
        retryOnClose: true,
      );

      _reconnectAttempts = 0;
      _setConnectionState(NostrConnectionState.connected);
    } catch (e) {
      debugPrint('NostrService: Failed to connect to relays: $e');
      _setConnectionState(NostrConnectionState.disconnected);
      _scheduleReconnect();
    }
  }

  /// Called when a relay connection is established.
  void _onRelayListening(
    String relayUrl,
    dynamic receivedData,
    dynamic relayWebSocket,
  ) {
    final index = _relays.indexWhere((r) => r.url == relayUrl);
    if (index != -1) {
      _relays[index].status = RelayConnectionStatus.connected;
      notifyListeners();
    }
    debugPrint('NostrService: Connected to $relayUrl');
  }

  /// Called when a relay connection encounters an error.
  void _onRelayConnectionError(
    String relayUrl,
    Object? error,
    dynamic relayWebSocket,
  ) {
    final index = _relays.indexWhere((r) => r.url == relayUrl);
    if (index != -1) {
      _relays[index].status = RelayConnectionStatus.disconnected;
      notifyListeners();
    }
    debugPrint('NostrService: Error on $relayUrl: $error');

    // Check if all relays are disconnected.
    if (_relays.every((r) => r.status == RelayConnectionStatus.disconnected)) {
      _setConnectionState(NostrConnectionState.disconnected);
      _scheduleReconnect();
    }
  }

  /// Called when a relay connection is closed.
  void _onRelayConnectionDone(String relayUrl, dynamic relayWebSocket) {
    final index = _relays.indexWhere((r) => r.url == relayUrl);
    if (index != -1) {
      _relays[index].status = RelayConnectionStatus.disconnected;
      notifyListeners();
    }
    debugPrint('NostrService: Disconnected from $relayUrl');
  }

  /// Schedules a reconnection attempt with exponential backoff.
  void _scheduleReconnect() {
    _reconnectTimer?.cancel();

    final delay = _calculateBackoff();
    debugPrint(
      'NostrService: Scheduling reconnect in ${delay}s '
      '(attempt ${_reconnectAttempts + 1})',
    );

    _setConnectionState(NostrConnectionState.reconnecting);

    _reconnectTimer = Timer(Duration(seconds: delay), () async {
      _reconnectAttempts++;
      await _connect();

      // Re-subscribe after successful reconnection.
      if (_connectionState == NostrConnectionState.connected) {
        _subscriptionManager.resubscribeAll();
      }
    });
  }

  /// Calculates exponential backoff delay.
  int _calculateBackoff() {
    final delay = _baseReconnectDelay * (1 << _reconnectAttempts);
    return delay.clamp(0, _maxReconnectDelay);
  }

  /// Adds a relay to the configuration.
  ///
  /// If already connected, attempts to connect to the new relay.
  Future<void> addRelay(
    String url, {
    bool read = true,
    bool write = true,
  }) async {
    if (_relays.any((r) => r.url == url)) return;

    _relays.add(RelayConfig(url: url, read: read, write: write));
    notifyListeners();

    // Reconnect with the updated relay list if already initialized.
    if (_initialized) {
      await _reconnectWithUpdatedRelays();
    }
  }

  /// Removes a relay from the configuration.
  Future<void> removeRelay(String url) async {
    _relays.removeWhere((r) => r.url == url);
    notifyListeners();

    if (_initialized) {
      await _reconnectWithUpdatedRelays();
    }
  }

  /// Disconnects and reconnects with the current relay list.
  Future<void> _reconnectWithUpdatedRelays() async {
    try {
      await disconnect();
      await _connect();
      if (_connectionState == NostrConnectionState.connected) {
        _subscriptionManager.resubscribeAll();
      }
    } catch (e) {
      debugPrint('NostrService: Error reconnecting with updated relays: $e');
    }
  }

  /// Publishes a signed event to all write-enabled relays.
  ///
  /// Returns the published [NostrEvent].
  Future<NostrEvent> publishEvent({
    required int kind,
    required String content,
    required NostrKeyPairs keyPairs,
    List<List<String>>? tags,
  }) async {
    final event = NostrEvent.fromPartialData(
      kind: kind,
      content: content,
      keyPairs: keyPairs,
      tags: tags,
    );

    await _nostr.services.relays.sendEventToRelays(event);
    return event;
  }

  /// Publishes a pre-built event to all write-enabled relays.
  Future<void> sendEvent(NostrEvent event) async {
    await _nostr.services.relays.sendEventToRelays(event);
  }

  /// Starts a streaming subscription for events matching the given filters.
  ///
  /// Returns a [NostrEventsStream] that can be listened to for incoming events.
  NostrEventsStream subscribe({
    required List<NostrFilter> filters,
    String? subscriptionId,
  }) {
    final request = NostrRequest(
      filters: filters,
      subscriptionId: subscriptionId,
    );

    return _nostr.services.relays.startEventsSubscription(request: request);
  }

  /// Performs a one-time query for events matching the given filters.
  ///
  /// Waits for EOSE (End of Stored Events) from relays before returning.
  Future<List<NostrEvent>> query({
    required List<NostrFilter> filters,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final request = NostrRequest(filters: filters);

    try {
      final events = await _nostr.services.relays.startEventsSubscriptionAsync(
        request: request,
        timeout: timeout,
      );
      return events;
    } catch (e) {
      debugPrint('NostrService: Query failed: $e');
      return [];
    }
  }

  /// Converts a [NostrEvent] to a [NostrEventModel].
  static NostrEventModel toEventModel(NostrEvent event) {
    return NostrEventModel(
      id: event.id ?? '',
      pubkey: event.pubkey,
      createdAt: event.createdAt ?? DateTime.now(),
      kind: event.kind ?? 0,
      content: event.content ?? '',
      tags: event.tags ?? [],
      sig: event.sig ?? '',
      subscriptionId: event.subscriptionId,
    );
  }

  /// Updates the connection state and notifies listeners.
  void _setConnectionState(NostrConnectionState state) {
    if (_connectionState == state) return;
    _connectionState = state;
    _connectionStateController.add(state);
    notifyListeners();
  }

  /// Disconnects from all relays.
  Future<void> disconnect() async {
    _reconnectTimer?.cancel();
    _subscriptionManager.closeAll();

    try {
      await _nostr.services.relays.disconnectFromRelays();
    } catch (e) {
      debugPrint('NostrService: Error during disconnect: $e');
    }

    for (final relay in _relays) {
      relay.status = RelayConnectionStatus.disconnected;
    }

    _setConnectionState(NostrConnectionState.disconnected);
  }

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    _connectionStateController.close();
    _subscriptionManager.dispose();
    disconnect();
    super.dispose();
  }
}
