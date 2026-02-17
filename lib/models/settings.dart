import 'package:flutter/material.dart';

/// Application settings model.
class AppSettings {
  /// Relay URLs for Nostr connectivity.
  final List<String> relayUrls;

  /// Electoral Commission public key (npub format).
  final String? ecPubKey;

  /// App theme mode.
  final ThemeMode themeMode;

  /// User-selected locale (null = follow system).
  final Locale? locale;

  const AppSettings({
    this.relayUrls = const [],
    this.ecPubKey,
    this.themeMode = ThemeMode.system,
    this.locale,
  });

  /// Creates a copy with optional overrides.
  AppSettings copyWith({
    List<String>? relayUrls,
    String? ecPubKey,
    bool clearEcPubKey = false,
    ThemeMode? themeMode,
    Locale? locale,
    bool clearLocale = false,
  }) {
    return AppSettings(
      relayUrls: relayUrls ?? this.relayUrls,
      ecPubKey: clearEcPubKey ? null : (ecPubKey ?? this.ecPubKey),
      themeMode: themeMode ?? this.themeMode,
      locale: clearLocale ? null : (locale ?? this.locale),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppSettings &&
          runtimeType == other.runtimeType &&
          _listEquals(relayUrls, other.relayUrls) &&
          ecPubKey == other.ecPubKey &&
          themeMode == other.themeMode &&
          locale == other.locale;

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(relayUrls), ecPubKey, themeMode, locale);

  static bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
