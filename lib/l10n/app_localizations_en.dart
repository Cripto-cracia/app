// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Cripto-cracia';

  @override
  String get welcomeMessage => 'Welcome to Cripto-cracia';

  @override
  String get elections => 'Elections';

  @override
  String get settings => 'Settings';

  @override
  String get filterByStatus => 'Filter by status';

  @override
  String get all => 'All';

  @override
  String get active => 'Active';

  @override
  String get upcoming => 'Upcoming';

  @override
  String get finished => 'Finished';

  @override
  String get canceled => 'Canceled';

  @override
  String get noElectionsFound => 'No elections found';

  @override
  String get tapRefreshOrCheckRelays =>
      'Tap refresh or check your relay connections.';

  @override
  String get refresh => 'Refresh';

  @override
  String electionDetailComingSoon(String name) {
    return 'Election detail for \"$name\" coming soon.';
  }

  @override
  String get election => 'Election';

  @override
  String get electionNotFound => 'Election not found.';

  @override
  String get time => 'Time';

  @override
  String get endsIn => 'Ends in';

  @override
  String get startsIn => 'Starts in';

  @override
  String get ended => 'Ended';

  @override
  String startLabel(String dateTime) {
    return 'Start: $dateTime';
  }

  @override
  String endLabel(String dateTime) {
    return 'End: $dateTime';
  }

  @override
  String candidatesCount(int count) {
    return 'Candidates ($count)';
  }

  @override
  String nCandidates(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count candidates',
      one: '1 candidate',
    );
    return '$_temp0';
  }

  @override
  String get noCandidatesRegistered => 'No candidates registered.';

  @override
  String get electoralCommission => 'Electoral Commission';

  @override
  String get electoralCommissionPublicKey => 'Electoral Commission Public Key';

  @override
  String get copyEcPubkey => 'Copy EC pubkey';

  @override
  String get ecPubkeyCopied => 'EC pubkey copied to clipboard';

  @override
  String get vote => 'Vote';

  @override
  String get votingNotStarted => 'Voting has not started yet';

  @override
  String get electionEnded => 'This election has ended';

  @override
  String get electionCanceled => 'This election was canceled';

  @override
  String get selectCandidateToVote => 'Select a candidate to vote';

  @override
  String get votingFlowComingSoon => 'Voting flow coming soon.';

  @override
  String get relays => 'Relays';

  @override
  String get noRelaysConfigured => 'No relays configured.';

  @override
  String get addRelay => 'Add Relay';

  @override
  String get relayUrlHint => 'wss://relay.example.com';

  @override
  String get relayUrl => 'Relay URL';

  @override
  String get cancel => 'Cancel';

  @override
  String get add => 'Add';

  @override
  String get invalidRelayUrl =>
      'Invalid relay URL. Must start with wss:// or ws://';

  @override
  String get relayAlreadyExists => 'Relay already exists.';

  @override
  String get ecNpubHint => 'npub1...';

  @override
  String get ecNpubLabel => 'EC npub';

  @override
  String get invalidNpubFormat => 'Invalid npub format';

  @override
  String get ecKeyCleared => 'EC key cleared.';

  @override
  String get ecKeySaved => 'EC key saved.';

  @override
  String get mnemonicBackup => 'Mnemonic Backup';

  @override
  String get noMnemonicStored => 'No mnemonic stored.';

  @override
  String get generateNewMnemonic => 'Generate New Mnemonic';

  @override
  String get tapToReveal => '(tap to reveal)';

  @override
  String get hide => 'Hide';

  @override
  String get reveal => 'Reveal';

  @override
  String get copy => 'Copy';

  @override
  String get mnemonicCopied => 'Mnemonic copied to clipboard.';

  @override
  String get theme => 'Theme';

  @override
  String get system => 'System';

  @override
  String get light => 'Light';

  @override
  String get dark => 'Dark';

  @override
  String get language => 'Language';

  @override
  String get english => 'English';

  @override
  String get spanish => 'Español';

  @override
  String candidateId(int id) {
    return 'ID: $id';
  }

  @override
  String get noVotesRecordedYet => 'No votes recorded yet';

  @override
  String get results => 'Results';

  @override
  String nVotes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count votes',
      one: '1 vote',
    );
    return '$_temp0';
  }
}
