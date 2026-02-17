import 'package:criptocracia_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/key_manager.dart';
import '../services/secure_storage.dart';
import '../services/settings_service.dart';

/// Settings screen for configuring relays, EC public key, mnemonic backup,
/// app theme, and language.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: Consumer<SettingsService>(
        builder: (context, service, _) {
          if (!service.loaded) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            children: [
              _RelaySection(service: service),
              const Divider(),
              _EcPubKeySection(service: service),
              const Divider(),
              const _MnemonicSection(),
              const Divider(),
              _ThemeSection(service: service),
              const Divider(),
              _LanguageSection(service: service),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Relay management section
// ---------------------------------------------------------------------------

class _RelaySection extends StatelessWidget {
  const _RelaySection({required this.service});

  final SettingsService service;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final relays = service.settings.relayUrls;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n.relays, style: Theme.of(context).textTheme.titleMedium),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () => _showAddRelayDialog(context),
              ),
            ],
          ),
        ),
        if (relays.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(l10n.noRelaysConfigured),
          ),
        ...relays.map(
          (url) => ListTile(
            leading: const Icon(Icons.dns),
            title: Text(url, style: const TextStyle(fontSize: 14)),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => service.removeRelay(url),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showAddRelayDialog(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.addRelay),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: l10n.relayUrlHint,
            labelText: l10n.relayUrl,
          ),
          keyboardType: TextInputType.url,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: Text(l10n.add),
          ),
        ],
      ),
    );
    if (result != null && result.trim().isNotEmpty) {
      if (!SettingsService.isValidRelayUrl(result)) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l10n.invalidRelayUrl)));
        }
        return;
      }
      final added = await service.addRelay(result);
      if (!added && context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.relayAlreadyExists)));
      }
    }
  }
}

// ---------------------------------------------------------------------------
// EC public key section
// ---------------------------------------------------------------------------

class _EcPubKeySection extends StatefulWidget {
  const _EcPubKeySection({required this.service});

  final SettingsService service;

  @override
  State<_EcPubKeySection> createState() => _EcPubKeySectionState();
}

class _EcPubKeySectionState extends State<_EcPubKeySection> {
  late TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.service.settings.ecPubKey ?? '',
    );
  }

  @override
  void didUpdateWidget(_EcPubKeySection oldWidget) {
    super.didUpdateWidget(oldWidget);
    final current = widget.service.settings.ecPubKey ?? '';
    if (_controller.text != current) {
      _controller.text = current;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.electoralCommissionPublicKey,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _controller,
            decoration: InputDecoration(
              hintText: l10n.ecNpubHint,
              labelText: l10n.ecNpubLabel,
              errorText: _errorText,
              suffixIcon: IconButton(
                icon: const Icon(Icons.save),
                onPressed: _save,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final value = _controller.text.trim();
    if (value.isEmpty) {
      await widget.service.setEcPubKey(null);
      setState(() => _errorText = null);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.ecKeyCleared)));
      }
      return;
    }
    if (!SettingsService.isValidNpub(value)) {
      setState(() => _errorText = l10n.invalidNpubFormat);
      return;
    }
    await widget.service.setEcPubKey(value);
    setState(() => _errorText = null);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.ecKeySaved)));
    }
  }
}

// ---------------------------------------------------------------------------
// Mnemonic backup section
// ---------------------------------------------------------------------------

class _MnemonicSection extends StatefulWidget {
  const _MnemonicSection();

  @override
  State<_MnemonicSection> createState() => _MnemonicSectionState();
}

class _MnemonicSectionState extends State<_MnemonicSection> {
  String? _mnemonic;
  bool _revealed = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadMnemonic();
  }

  Future<void> _loadMnemonic() async {
    final mnemonic = await SecureStorage.loadMnemonic();
    if (mounted) {
      setState(() {
        _mnemonic = mnemonic;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.mnemonicBackup,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (_loading)
            const CircularProgressIndicator()
          else if (_mnemonic == null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.noMnemonicStored),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _generateMnemonic,
                  child: Text(l10n.generateNewMnemonic),
                ),
              ],
            )
          else ...[
            GestureDetector(
              onTap: () => setState(() => _revealed = !_revealed),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _revealed ? _mnemonic! : '${'•' * 24} ${l10n.tapToReveal}',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton.icon(
                  icon: Icon(
                    _revealed ? Icons.visibility_off : Icons.visibility,
                  ),
                  label: Text(_revealed ? l10n.hide : l10n.reveal),
                  onPressed: () => setState(() => _revealed = !_revealed),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.copy),
                  label: Text(l10n.copy),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _mnemonic!));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.mnemonicCopied)),
                    );
                  },
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _generateMnemonic() async {
    final mnemonic = KeyManager.generateMnemonic();
    await SecureStorage.saveMnemonic(mnemonic);
    if (mounted) {
      setState(() {
        _mnemonic = mnemonic;
        _revealed = true;
      });
    }
  }
}

// ---------------------------------------------------------------------------
// Theme section
// ---------------------------------------------------------------------------

class _ThemeSection extends StatelessWidget {
  const _ThemeSection({required this.service});

  final SettingsService service;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final themeMode = service.settings.themeMode;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.theme, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<ThemeMode>(
            segments: [
              ButtonSegment(
                value: ThemeMode.system,
                label: Text(l10n.system),
                icon: const Icon(Icons.settings_brightness),
              ),
              ButtonSegment(
                value: ThemeMode.light,
                label: Text(l10n.light),
                icon: const Icon(Icons.light_mode),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                label: Text(l10n.dark),
                icon: const Icon(Icons.dark_mode),
              ),
            ],
            selected: {themeMode},
            onSelectionChanged: (selected) {
              service.setThemeMode(selected.first);
            },
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Language section
// ---------------------------------------------------------------------------

class _LanguageSection extends StatelessWidget {
  const _LanguageSection({required this.service});

  final SettingsService service;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final currentLocale = service.settings.locale;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.language, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<Locale?>(
            segments: [
              ButtonSegment<Locale?>(
                value: null,
                label: Text(l10n.system),
                icon: const Icon(Icons.language),
              ),
              ButtonSegment<Locale?>(
                value: const Locale('en'),
                label: Text(l10n.english),
              ),
              ButtonSegment<Locale?>(
                value: const Locale('es'),
                label: Text(l10n.spanish),
              ),
            ],
            selected: {currentLocale},
            onSelectionChanged: (selected) {
              service.setLocale(selected.first);
            },
          ),
        ],
      ),
    );
  }
}
