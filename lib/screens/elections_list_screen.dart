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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Elections'),
        actions: [
          PopupMenuButton<ElectionStatus?>(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filter by status',
            onSelected: (status) => setState(() => _filterStatus = status),
            itemBuilder: (_) => [
              const PopupMenuItem(value: null, child: Text('All')),
              const PopupMenuItem(
                value: ElectionStatus.active,
                child: Text('Active'),
              ),
              const PopupMenuItem(
                value: ElectionStatus.upcoming,
                child: Text('Upcoming'),
              ),
              const PopupMenuItem(
                value: ElectionStatus.finished,
                child: Text('Finished'),
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
                    // Placeholder: navigate to election detail (Issue #5).
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Election detail for "${election.name}" '
                          'coming soon.',
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
            'No elections found',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Pull to refresh or check your relay connections.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
          ),
        ],
      ),
    );
  }
}
