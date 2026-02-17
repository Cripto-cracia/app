/// Configuration model for a Nostr relay connection.
class RelayConfig {
  /// The WebSocket URL of the relay (e.g., 'wss://relay.damus.io').
  final String url;

  /// Whether to read events from this relay.
  final bool read;

  /// Whether to write (publish) events to this relay.
  final bool write;

  /// Current connection status of the relay.
  RelayConnectionStatus status;

  RelayConfig({
    required this.url,
    this.read = true,
    this.write = true,
    this.status = RelayConnectionStatus.disconnected,
  });

  /// Creates a copy with optional overrides.
  RelayConfig copyWith({
    String? url,
    bool? read,
    bool? write,
    RelayConnectionStatus? status,
  }) {
    return RelayConfig(
      url: url ?? this.url,
      read: read ?? this.read,
      write: write ?? this.write,
      status: status ?? this.status,
    );
  }

  /// Serializes to a map for storage.
  Map<String, dynamic> toMap() => {'url': url, 'read': read, 'write': write};

  /// Deserializes from a map.
  factory RelayConfig.fromMap(Map<String, dynamic> map) => RelayConfig(
    url: map['url'] as String,
    read: map['read'] as bool? ?? true,
    write: map['write'] as bool? ?? true,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RelayConfig &&
          runtimeType == other.runtimeType &&
          url == other.url;

  @override
  int get hashCode => url.hashCode;

  @override
  String toString() =>
      'RelayConfig(url: $url, read: $read, write: $write, '
      'status: $status)';
}

/// Connection status of a relay.
enum RelayConnectionStatus {
  /// Not connected.
  disconnected,

  /// Attempting to connect.
  connecting,

  /// Successfully connected.
  connected,

  /// Reconnecting after a disconnect.
  reconnecting,
}
