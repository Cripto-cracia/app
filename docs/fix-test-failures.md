# Fix: Pre-existing Test Failures on main

## Summary

Three tests were failing on `main`. All fixes were in test code only — no production code was changed.

## Failures and Fixes

### 1. `settings_service_test.dart` — `setEcPubKey saves valid npub`

**Root cause:** The hardcoded test npub was 64 characters long, but `isValidNpub()` requires exactly 63 characters (5-char `npub1` prefix + 58-char bech32 data = 63 total for a 32-byte public key).

**Fix:** Replaced the npub with a correctly-sized 63-character string using valid bech32 characters.

### 2. `vote_casting_service_test.dart` — `notifies listeners on state change`

**Root cause:** The test called `castVote()` with a pending (not-ready) token to trigger an error state transition. However, `castVote()` transitions to error state *and then rethrows* the exception. The test did not catch the rethrown `StateError`, causing the test itself to fail.

**Fix:** Wrapped the `castVote()` call in a `try/catch` block for `StateError`, since the exception is expected behavior when the token is not ready.

### 3. `home_screen_test.dart` — `CriptocraciaApp can be instantiated and renders`

**Root cause:** `CriptocraciaApp` uses `Consumer<SettingsService>` in its build method, but the test only provided an `ElectionService` provider. The missing `SettingsService` provider caused a `ProviderNotFoundException`.

**Fix:** Added `SecureStorage` initialization (setUp/tearDown) and wrapped the widget in a `MultiProvider` that supplies both `ElectionService` and `SettingsService`.
