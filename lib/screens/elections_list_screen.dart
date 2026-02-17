import 'package:criptocracia_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/election.dart';
import '../services/election_service.dart';
import '../widgets/election_card.dart';

/// Screen displaying discovered elections grouped by status.
class ElectionsListScreen extends StatefulWidget {
  const ElectionsListScreen({super.key});

  @override
  State<ElectionsListScreen> createState() => _ElectionsListScreenState();
}

class _ElectionsListScreenState extends State<ElectionsListScreen> {
  ElectionStatus? _filterStatus;

  @override
  void initState() {
    super.initState();
    // Start discovery once the service is available.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final service = context.read<ElectionService>();
      if (!service.isDiscovering) {
        service.startDiscovery();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.elections),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: l10n.settings,
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
          PopupMenuButton<ElectionStatus?>(
            icon: const Icon(Icons.filter_list),
            tooltip: l10n.filterByStatus,
            onSelected: (status) => setState(() => _filterStatus = status),
            itemBuilder: (_) => [
              PopupMenuItem(value: null, child: Text(l10n.all)),
              PopupMenuItem(
                value: ElectionStatus.active,
                child: Text(l10n.active),
              ),
              PopupMenuItem(
                value: ElectionStatus.upcoming,
                child: Text(l10n.upcoming),
              ),
              PopupMenuItem(
                value: ElectionStatus.finished,
                child: Text(l10n.finished),
              ),
              PopupMenuItem(
                value: ElectionStatus.canceled,
                child: Text(l10n.canceled),
              ),
            ],
          ),
        ],
      ),
      body: Consumer<ElectionService>(
        builder: (context, service, _) {
          final elections = _filterStatus != null
              ? service.electionsByStatus(_filterStatus!)
              : service.elections;

          if (service.isDiscovering && elections.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (elections.isEmpty) {
            return _EmptyState(onRefresh: () => service.refreshElections());
          }

          return RefreshIndicator(
            onRefresh: () async => service.refreshElections(),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: elections.length,
              itemBuilder: (context, index) {
                final election = elections[index];
                return ElectionCard(
                  election: election,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          l10n.electionDetailComingSoon(election.name),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}

/// Displayed when no elections have been discovered.
class _EmptyState extends StatelessWidget {
  final VoidCallback onRefresh;

  const _EmptyState({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.how_to_vote_outlined,
            size: 64,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            l10n.noElectionsFound,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.tapRefreshOrCheckRelays,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh),
            label: Text(l10n.refresh),
          ),
        ],
      ),
    );
  }
}
