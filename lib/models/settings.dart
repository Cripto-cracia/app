import 'package:flutter/material.dart';

/// Application settings model.
class AppSettings {
  /// Relay URLs for Nostr connectivity.
  final List<String> relayUrls;

  /// Electoral Commission public key (npub format).
  final String? ecPubKey;

  /// App theme mode.
  final ThemeMode themeMode;

  const AppSettings({
    this.relayUrls = const [],
    this.ecPubKey,
    this.themeMode = ThemeMode.system,
  });

  /// Creates a copy with optional overrides.
  AppSettings copyWith({
    List<String>? relayUrls,
    String? ecPubKey,
    bool clearEcPubKey = false,
    ThemeMode? themeMode,
  }) {
    return AppSettings(
      relayUrls: relayUrls ?? this.relayUrls,
      ecPubKey: clearEcPubKey ? null : (ecPubKey ?? this.ecPubKey),
      themeMode: themeMode ?? this.themeMode,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppSettings &&
          runtimeType == other.runtimeType &&
          _listEquals(relayUrls, other.relayUrls) &&
          ecPubKey == other.ecPubKey &&
          themeMode == other.themeMode;

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(relayUrls), ecPubKey, themeMode);

  static bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
