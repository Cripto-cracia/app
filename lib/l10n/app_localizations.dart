import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
  ];

  /// Application name
  ///
  /// In en, this message translates to:
  /// **'Cripto-cracia'**
  String get appName;

  /// Home screen welcome message
  ///
  /// In en, this message translates to:
  /// **'Welcome to Cripto-cracia'**
  String get welcomeMessage;

  /// Elections screen title
  ///
  /// In en, this message translates to:
  /// **'Elections'**
  String get elections;

  /// Settings screen title
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// Tooltip for filter button
  ///
  /// In en, this message translates to:
  /// **'Filter by status'**
  String get filterByStatus;

  /// Filter option: all elections
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// Election status: active
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get active;

  /// Election status: upcoming
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get upcoming;

  /// Election status: finished
  ///
  /// In en, this message translates to:
  /// **'Finished'**
  String get finished;

  /// Election status: canceled
  ///
  /// In en, this message translates to:
  /// **'Canceled'**
  String get canceled;

  /// Empty state title
  ///
  /// In en, this message translates to:
  /// **'No elections found'**
  String get noElectionsFound;

  /// Empty state subtitle
  ///
  /// In en, this message translates to:
  /// **'Tap refresh or check your relay connections.'**
  String get tapRefreshOrCheckRelays;

  /// Refresh button label
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// Snackbar when tapping an election card
  ///
  /// In en, this message translates to:
  /// **'Election detail for \"{name}\" coming soon.'**
  String electionDetailComingSoon(String name);

  /// Generic election title
  ///
  /// In en, this message translates to:
  /// **'Election'**
  String get election;

  /// Shown when election ID is invalid
  ///
  /// In en, this message translates to:
  /// **'Election not found.'**
  String get electionNotFound;

  /// Time section header
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get time;

  /// Countdown prefix for active elections
  ///
  /// In en, this message translates to:
  /// **'Ends in'**
  String get endsIn;

  /// Countdown prefix for upcoming elections
  ///
  /// In en, this message translates to:
  /// **'Starts in'**
  String get startsIn;

  /// Label for ended elections
  ///
  /// In en, this message translates to:
  /// **'Ended'**
  String get ended;

  /// Start date/time label
  ///
  /// In en, this message translates to:
  /// **'Start: {dateTime}'**
  String startLabel(String dateTime);

  /// End date/time label
  ///
  /// In en, this message translates to:
  /// **'End: {dateTime}'**
  String endLabel(String dateTime);

  /// Candidates section header with count
  ///
  /// In en, this message translates to:
  /// **'Candidates ({count})'**
  String candidatesCount(int count);

  /// Number of candidates in election card
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 candidate} other{{count} candidates}}'**
  String nCandidates(int count);

  /// Shown when election has no candidates
  ///
  /// In en, this message translates to:
  /// **'No candidates registered.'**
  String get noCandidatesRegistered;

  /// EC section header
  ///
  /// In en, this message translates to:
  /// **'Electoral Commission'**
  String get electoralCommission;

  /// EC public key section title in settings
  ///
  /// In en, this message translates to:
  /// **'Electoral Commission Public Key'**
  String get electoralCommissionPublicKey;

  /// Tooltip for copy EC pubkey button
  ///
  /// In en, this message translates to:
  /// **'Copy EC pubkey'**
  String get copyEcPubkey;

  /// Snackbar after copying EC pubkey
  ///
  /// In en, this message translates to:
  /// **'EC pubkey copied to clipboard'**
  String get ecPubkeyCopied;

  /// Vote button label
  ///
  /// In en, this message translates to:
  /// **'Vote'**
  String get vote;

  /// Disabled vote button reason
  ///
  /// In en, this message translates to:
  /// **'Voting has not started yet'**
  String get votingNotStarted;

  /// Disabled vote button reason
  ///
  /// In en, this message translates to:
  /// **'This election has ended'**
  String get electionEnded;

  /// Disabled vote button reason
  ///
  /// In en, this message translates to:
  /// **'This election was canceled'**
  String get electionCanceled;

  /// Hint when no candidate selected
  ///
  /// In en, this message translates to:
  /// **'Select a candidate to vote'**
  String get selectCandidateToVote;

  /// Placeholder snackbar for vote action
  ///
  /// In en, this message translates to:
  /// **'Voting flow coming soon.'**
  String get votingFlowComingSoon;

  /// Relays section title
  ///
  /// In en, this message translates to:
  /// **'Relays'**
  String get relays;

  /// Shown when relay list is empty
  ///
  /// In en, this message translates to:
  /// **'No relays configured.'**
  String get noRelaysConfigured;

  /// Add relay dialog title
  ///
  /// In en, this message translates to:
  /// **'Add Relay'**
  String get addRelay;

  /// Hint text for relay URL input
  ///
  /// In en, this message translates to:
  /// **'wss://relay.example.com'**
  String get relayUrlHint;

  /// Label for relay URL input
  ///
  /// In en, this message translates to:
  /// **'Relay URL'**
  String get relayUrl;

  /// Cancel button label
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Add button label
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// Error message for invalid relay URL
  ///
  /// In en, this message translates to:
  /// **'Invalid relay URL. Must start with wss:// or ws://'**
  String get invalidRelayUrl;

  /// Error message for duplicate relay
  ///
  /// In en, this message translates to:
  /// **'Relay already exists.'**
  String get relayAlreadyExists;

  /// Hint text for EC npub input
  ///
  /// In en, this message translates to:
  /// **'npub1...'**
  String get ecNpubHint;

  /// Label for EC npub input
  ///
  /// In en, this message translates to:
  /// **'EC npub'**
  String get ecNpubLabel;

  /// Error message for invalid npub
  ///
  /// In en, this message translates to:
  /// **'Invalid npub format'**
  String get invalidNpubFormat;

  /// Snackbar after clearing EC key
  ///
  /// In en, this message translates to:
  /// **'EC key cleared.'**
  String get ecKeyCleared;

  /// Snackbar after saving EC key
  ///
  /// In en, this message translates to:
  /// **'EC key saved.'**
  String get ecKeySaved;

  /// Mnemonic section title
  ///
  /// In en, this message translates to:
  /// **'Mnemonic Backup'**
  String get mnemonicBackup;

  /// Shown when no mnemonic exists
  ///
  /// In en, this message translates to:
  /// **'No mnemonic stored.'**
  String get noMnemonicStored;

  /// Button to generate mnemonic
  ///
  /// In en, this message translates to:
  /// **'Generate New Mnemonic'**
  String get generateNewMnemonic;

  /// Hint on hidden mnemonic
  ///
  /// In en, this message translates to:
  /// **'(tap to reveal)'**
  String get tapToReveal;

  /// Hide button label
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get hide;

  /// Reveal button label
  ///
  /// In en, this message translates to:
  /// **'Reveal'**
  String get reveal;

  /// Copy button label
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// Snackbar after copying mnemonic
  ///
  /// In en, this message translates to:
  /// **'Mnemonic copied to clipboard.'**
  String get mnemonicCopied;

  /// Theme section title
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// System theme option
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get system;

  /// Light theme option
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get light;

  /// Dark theme option
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get dark;

  /// Language section title
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// English language name
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// Spanish language name
  ///
  /// In en, this message translates to:
  /// **'Español'**
  String get spanish;

  /// Candidate ID label
  ///
  /// In en, this message translates to:
  /// **'ID: {id}'**
  String candidateId(int id);

  /// Shown when election has no votes
  ///
  /// In en, this message translates to:
  /// **'No votes recorded yet'**
  String get noVotesRecordedYet;

  /// Results section title
  ///
  /// In en, this message translates to:
  /// **'Results'**
  String get results;

  /// Vote count with pluralization
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 vote} other{{count} votes}}'**
  String nVotes(int count);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
