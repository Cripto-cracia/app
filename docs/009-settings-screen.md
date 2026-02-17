# 009 — Settings Screen and EC Configuration

## Overview

The settings screen allows users to configure application preferences
including Nostr relay connections, the Electoral Commission (EC) public key,
mnemonic backup display, and app theme selection. All settings persist
locally using encrypted storage.

## Architecture

### Model

`lib/models/settings.dart` — `AppSettings` is an immutable value object
holding the current configuration:

- `relayUrls` — list of WebSocket relay URLs
- `ecPubKey` — optional EC public key in npub (bech32) format
- `themeMode` — `ThemeMode.system`, `light`, or `dark`

### Service

`lib/services/settings_service.dart` — `SettingsService` extends
`ChangeNotifier` and manages persistence through `SecureStorage`:

- **Relay management:** add/remove with URL validation
  (`wss://` or `ws://` prefix, non-empty host)
- **EC public key:** validated as proper npub format (63 characters,
  `npub1` prefix, valid bech32 charset)
- **Theme mode:** persisted as string (`system`/`light`/`dark`)
- **Defaults:** when no stored relays exist, `AppConstants.defaultRelays`
  are used

### Screen

`lib/screens/settings_screen.dart` — four sections:

1. **Relays** — list with add (dialog) and delete buttons
2. **EC Public Key** — text field with save button and validation feedback
3. **Mnemonic Backup** — tap-to-reveal display with copy button; generates
   new mnemonic if none stored (via `KeyManager`)
4. **Theme** — `SegmentedButton` for system/light/dark selection

### Integration

- `CriptocraciaApp` (`lib/app.dart`) consumes `SettingsService` to apply
  the selected `ThemeMode`
- `SettingsService` is registered as a `ChangeNotifierProvider` in
  `main.dart`
- Navigation: settings icon added to `ElectionsListScreen` app bar,
  route `/settings`

## Data Flow

```text
User action → SettingsScreen widget
  → SettingsService method (addRelay, setThemeMode, etc.)
    → SecureStorage.write (persist)
    → notifyListeners()
      → UI rebuilds via Consumer/Provider
      → CriptocraciaApp rebuilds with new ThemeMode
```

## Validation Rules

| Field     | Rule                                                        |
|-----------|-------------------------------------------------------------|
| Relay URL | Must start with `wss://` or `ws://`; host must be non-empty |
| npub      | 63 chars, `npub1` prefix, valid bech32 characters only      |

## Testing

- `test/settings_model_test.dart` — `AppSettings` equality, `copyWith`
- `test/settings_service_test.dart` — persistence, validation, add/remove
- `test/settings_screen_test.dart` — widget rendering, interaction
