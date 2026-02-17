# 012 — Multi-language Support (EN/ES)

## Overview

The app now supports English and Spanish locales using Flutter's built-in
internationalization system (`flutter_localizations` + ARB files).

## Architecture

### Localization Files

```text
lib/l10n/
├── app_en.arb              # English translations (template)
├── app_es.arb              # Spanish translations
├── app_localizations.dart  # Generated: delegates & AppLocalizations class
├── app_localizations_en.dart
└── app_localizations_es.dart
```

ARB (Application Resource Bundle) files are the source of truth.
Running `flutter gen-l10n` (or `flutter pub get` with `generate: true`
in `pubspec.yaml`) regenerates the Dart classes.

### Configuration

- `l10n.yaml` at project root defines generation options.
- `pubspec.yaml` has `generate: true` under `flutter:` and depends on
  `flutter_localizations` and `intl`.

### Locale Selection

The `AppSettings` model includes an optional `locale` field. When `null`,
the app follows the device/system locale. Users can override it from the
**Settings** screen via a segmented button (System / English / Español).

The selected locale is persisted through `SettingsService` using secure
storage, so it survives app restarts.

### Integration in `MaterialApp`

`CriptocraciaApp` passes the following to `MaterialApp`:

- `localizationsDelegates: AppLocalizations.localizationsDelegates`
- `supportedLocales: AppLocalizations.supportedLocales`
- `locale:` from `SettingsService.settings.locale` (nullable)

### Usage in Widgets

All user-facing strings are accessed through `AppLocalizations.of(context)`:

```dart
final l10n = AppLocalizations.of(context);
Text(l10n.elections); // "Elections" or "Elecciones"
Text(l10n.nVotes(5)); // "5 votes" or "5 votos"
```

### Pluralization

ICU message syntax is used for pluralized strings:

- `nVotes` — "1 vote" / "5 votes" (EN), "1 voto" / "5 votos" (ES)
- `nCandidates` — "1 candidate" / "3 candidates" (EN/ES)

### Screens & Widgets Updated

- `HomeScreen`
- `ElectionsListScreen`
- `ElectionDetailScreen`
- `SettingsScreen` (+ new language section)
- `ElectionCard`
- `StatusBadge`
- `CandidateTile`
- `ElectionResultsWidget`

## Testing

- `test/l10n_test.dart` — verifies both locales load correctly, pluralization
  works, and exactly two locales are supported.
- All existing widget tests updated with localization delegates in their
  `MaterialApp` wrappers.

## Adding a New Language

1. Create `lib/l10n/app_XX.arb` with all keys from `app_en.arb`.
2. Run `flutter gen-l10n`.
3. Add the new `Locale` to `SettingsService.supportedLocales`.
4. Add a segment in `_LanguageSection` on the settings screen.
