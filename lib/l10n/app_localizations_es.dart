// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appName => 'Cripto-cracia';

  @override
  String get welcomeMessage => 'Bienvenido a Cripto-cracia';

  @override
  String get elections => 'Elecciones';

  @override
  String get settings => 'Configuración';

  @override
  String get filterByStatus => 'Filtrar por estado';

  @override
  String get all => 'Todas';

  @override
  String get active => 'Activa';

  @override
  String get upcoming => 'Próxima';

  @override
  String get finished => 'Finalizada';

  @override
  String get canceled => 'Cancelada';

  @override
  String get noElectionsFound => 'No se encontraron elecciones';

  @override
  String get tapRefreshOrCheckRelays =>
      'Toca actualizar o verifica tus conexiones de relays.';

  @override
  String get refresh => 'Actualizar';

  @override
  String electionDetailComingSoon(String name) {
    return 'Detalle de la elección \"$name\" próximamente.';
  }

  @override
  String get election => 'Elección';

  @override
  String get electionNotFound => 'Elección no encontrada.';

  @override
  String get time => 'Tiempo';

  @override
  String get endsIn => 'Finaliza en';

  @override
  String get startsIn => 'Comienza en';

  @override
  String get ended => 'Finalizada';

  @override
  String startLabel(String dateTime) {
    return 'Inicio: $dateTime';
  }

  @override
  String endLabel(String dateTime) {
    return 'Fin: $dateTime';
  }

  @override
  String candidatesCount(int count) {
    return 'Candidatos ($count)';
  }

  @override
  String nCandidates(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count candidatos',
      one: '1 candidato',
    );
    return '$_temp0';
  }

  @override
  String get noCandidatesRegistered => 'No hay candidatos registrados.';

  @override
  String get electoralCommission => 'Comisión Electoral';

  @override
  String get electoralCommissionPublicKey =>
      'Clave Pública de la Comisión Electoral';

  @override
  String get copyEcPubkey => 'Copiar clave pública CE';

  @override
  String get ecPubkeyCopied => 'Clave pública CE copiada al portapapeles';

  @override
  String get vote => 'Votar';

  @override
  String get votingNotStarted => 'La votación aún no ha comenzado';

  @override
  String get electionEnded => 'Esta elección ha finalizado';

  @override
  String get electionCanceled => 'Esta elección fue cancelada';

  @override
  String get selectCandidateToVote => 'Selecciona un candidato para votar';

  @override
  String get votingFlowComingSoon => 'Flujo de votación próximamente.';

  @override
  String get relays => 'Relays';

  @override
  String get noRelaysConfigured => 'No hay relays configurados.';

  @override
  String get addRelay => 'Agregar Relay';

  @override
  String get relayUrlHint => 'wss://relay.example.com';

  @override
  String get relayUrl => 'URL del Relay';

  @override
  String get cancel => 'Cancelar';

  @override
  String get add => 'Agregar';

  @override
  String get invalidRelayUrl =>
      'URL de relay inválida. Debe comenzar con wss:// o ws://';

  @override
  String get relayAlreadyExists => 'El relay ya existe.';

  @override
  String get ecNpubHint => 'npub1...';

  @override
  String get ecNpubLabel => 'npub CE';

  @override
  String get invalidNpubFormat => 'Formato npub inválido';

  @override
  String get ecKeyCleared => 'Clave CE eliminada.';

  @override
  String get ecKeySaved => 'Clave CE guardada.';

  @override
  String get mnemonicBackup => 'Respaldo Mnemónico';

  @override
  String get noMnemonicStored => 'No hay mnemónico almacenado.';

  @override
  String get generateNewMnemonic => 'Generar Nuevo Mnemónico';

  @override
  String get tapToReveal => '(toca para revelar)';

  @override
  String get hide => 'Ocultar';

  @override
  String get reveal => 'Revelar';

  @override
  String get copy => 'Copiar';

  @override
  String get mnemonicCopied => 'Mnemónico copiado al portapapeles.';

  @override
  String get theme => 'Tema';

  @override
  String get system => 'Sistema';

  @override
  String get light => 'Claro';

  @override
  String get dark => 'Oscuro';

  @override
  String get language => 'Idioma';

  @override
  String get english => 'English';

  @override
  String get spanish => 'Español';

  @override
  String candidateId(int id) {
    return 'ID: $id';
  }

  @override
  String get noVotesRecordedYet => 'Aún no se han registrado votos';

  @override
  String get results => 'Resultados';

  @override
  String nVotes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count votos',
      one: '1 voto',
    );
    return '$_temp0';
  }
}
