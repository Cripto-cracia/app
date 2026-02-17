/// Application-wide constants for Cripto-cracia.
class AppConstants {
  AppConstants._();

  /// Application name.
  static const String appName = 'Cripto-cracia';

  /// Default Nostr relay URLs.
  static const List<String> defaultRelays = [
    'wss://relay.damus.io',
    'wss://relay.mostro.network',
    'wss://relay.nostr.band',
    'wss://nos.lol',
  ];

  /// NIP event kind for election creation.
  static const int electionEventKind = 35000;

  /// NIP event kind for vote submission.
  static const int voteEventKind = 35001;
}
