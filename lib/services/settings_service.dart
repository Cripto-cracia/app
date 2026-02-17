import 'dart:convert';

import 'package:flutter/material.dart';

import '../config/constants.dart';
import '../models/settings.dart';
import 'secure_storage.dart';

/// Manages application settings with local persistence.
///
/// Non-sensitive settings (relay list, theme) are stored via [SecureStorage]
/// generic key-value API. The EC public key is also stored there since it is
/// a configuration secret relevant to vote verification.
class SettingsService extends ChangeNotifier {
  static const String _relayUrlsKey = 'settings_relay_urls';
  static const String _ecPubKeyKey = 'settings_ec_pub_key';
  static const String _themeModeKey = 'settings_theme_mode';
  static const String _localeKey = 'settings_locale';

  AppSettings _settings = const AppSettings();

  /// Current settings snapshot.
  AppSettings get settings => _settings;

  /// Whether the service has been loaded from storage.
  bool _loaded = false;

  /// Whether settings have been loaded from storage.
  bool get loaded => _loaded;

  /// Loads settings from persistent storage.
  ///
  /// If no settings are found, defaults are used (including
  /// [AppConstants.defaultRelays]).
  Future<void> load() async {
    final relayJson = await SecureStorage.read(key: _relayUrlsKey);
    final ecPubKey = await SecureStorage.read(key: _ecPubKeyKey);
    final themeModeStr = await SecureStorage.read(key: _themeModeKey);
    final localeStr = await SecureStorage.read(key: _localeKey);

    List<String> relayUrls;
    if (relayJson != null) {
      try {
        relayUrls = List<String>.from(jsonDecode(relayJson) as List);
      } catch (_) {
        // Corrupted storage — fall back to defaults and clear bad data.
        relayUrls = List<String>.from(AppConstants.defaultRelays);
        await SecureStorage.delete(key: _relayUrlsKey);
      }
    } else {
      relayUrls = List<String>.from(AppConstants.defaultRelays);
    }

    final themeMode = _themeModeFromString(themeModeStr);

    final locale = localeStr != null ? Locale(localeStr) : null;

    _settings = AppSettings(
      relayUrls: relayUrls,
      ecPubKey: ecPubKey,
      themeMode: themeMode,
      locale: locale,
    );
    _loaded = true;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Relay management
  // ---------------------------------------------------------------------------

  /// Adds a relay URL if it is not already present.
  ///
  /// Returns `true` if the relay was added.
  Future<bool> addRelay(String url) async {
    final trimmed = url.trim();
    if (!isValidRelayUrl(trimmed)) return false;
    if (_settings.relayUrls.contains(trimmed)) return false;

    final updated = List<String>.from(_settings.relayUrls)..add(trimmed);
    _settings = _settings.copyWith(relayUrls: updated);
    await _persistRelays();
    notifyListeners();
    return true;
  }

  /// Removes a relay URL.
  ///
  /// Returns `true` if the relay was removed.
  Future<bool> removeRelay(String url) async {
    if (!_settings.relayUrls.contains(url)) return false;

    final updated = List<String>.from(_settings.relayUrls)..remove(url);
    _settings = _settings.copyWith(relayUrls: updated);
    await _persistRelays();
    notifyListeners();
    return true;
  }

  // ---------------------------------------------------------------------------
  // EC public key
  // ---------------------------------------------------------------------------

  /// Sets the Electoral Commission public key (npub format).
  ///
  /// Pass `null` to clear.
  Future<void> setEcPubKey(String? npub) async {
    if (npub != null && npub.trim().isEmpty) {
      npub = null;
    }
    if (npub != null && !isValidNpub(npub.trim())) {
      throw ArgumentError('Invalid npub format');
    }
    final trimmed = npub?.trim();
    if (trimmed == null) {
      _settings = _settings.copyWith(clearEcPubKey: true);
      await SecureStorage.delete(key: _ecPubKeyKey);
    } else {
      _settings = _settings.copyWith(ecPubKey: trimmed);
      await SecureStorage.write(key: _ecPubKeyKey, value: trimmed);
    }
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Theme
  // ---------------------------------------------------------------------------

  /// Sets the app theme mode.
  Future<void> setThemeMode(ThemeMode mode) async {
    _settings = _settings.copyWith(themeMode: mode);
    await SecureStorage.write(
      key: _themeModeKey,
      value: _themeModeToString(mode),
    );
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Locale
  // ---------------------------------------------------------------------------

  /// Supported locales for the application.
  static const List<Locale> supportedLocales = [Locale('en'), Locale('es')];

  /// Sets the app locale. Pass `null` to follow the system locale.
  Future<void> setLocale(Locale? locale) async {
    if (locale == null) {
      _settings = _settings.copyWith(clearLocale: true);
      await SecureStorage.delete(key: _localeKey);
    } else {
      _settings = _settings.copyWith(locale: locale);
      await SecureStorage.write(key: _localeKey, value: locale.languageCode);
    }
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Validation helpers
  // ---------------------------------------------------------------------------

  /// Returns `true` if [url] is a valid WebSocket relay URL.
  static bool isValidRelayUrl(String url) {
    final trimmed = url.trim();
    if (!trimmed.startsWith('wss://') && !trimmed.startsWith('ws://')) {
      return false;
    }
    try {
      final uri = Uri.parse(trimmed);
      return uri.host.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Returns `true` if [npub] has valid npub bech32 format.
  ///
  /// Checks prefix and length (63 characters for a 32-byte key in bech32).
  static bool isValidNpub(String npub) {
    final trimmed = npub.trim().toLowerCase();
    if (!trimmed.startsWith('npub1')) return false;
    // npub bech32 encoding of 32 bytes = 63 chars total
    if (trimmed.length != 63) return false;
    // Check valid bech32 characters after the '1' separator
    final data = trimmed.substring(5);
    const bech32Chars = 'qpzry9x8gf2tvdw0s3jn54khce6mua7l';
    return data.split('').every((c) => bech32Chars.contains(c));
  }

  // ---------------------------------------------------------------------------
  // Internal
  // ---------------------------------------------------------------------------

  Future<void> _persistRelays() async {
    await SecureStorage.write(
      key: _relayUrlsKey,
      value: jsonEncode(_settings.relayUrls),
    );
  }

  static ThemeMode _themeModeFromString(String? value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  static String _themeModeToString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }
}
