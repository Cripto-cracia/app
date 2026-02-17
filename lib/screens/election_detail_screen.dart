import 'package:criptocracia_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/election.dart';
import '../services/election_service.dart';
import '../widgets/candidate_tile.dart';
import '../widgets/countdown_timer.dart';
import '../widgets/status_badge.dart';

/// Screen displaying full details of a single election.
///
/// Receives an [electionId] and fetches the election from
/// [ElectionService]. Shows name, status, countdown, candidates,
/// EC info, and a vote action button.
class ElectionDetailScreen extends StatefulWidget {
  /// The ID of the election to display.
  final String electionId;

  const ElectionDetailScreen({super.key, required this.electionId});

  @override
  State<ElectionDetailScreen> createState() => _ElectionDetailScreenState();
}

class _ElectionDetailScreenState extends State<ElectionDetailScreen> {
  int? _selectedCandidateId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Consumer<ElectionService>(
      builder: (context, service, _) {
        final election = service.getElection(widget.electionId);

        if (election == null) {
          return Scaffold(
            appBar: AppBar(title: Text(l10n.election)),
            body: Center(child: Text(l10n.electionNotFound)),
          );
        }

        return Scaffold(
          appBar: AppBar(title: Text(election.name)),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildHeader(theme, election),
              const SizedBox(height: 16),
              _buildTimeSection(theme, l10n, election),
              const Divider(height: 32),
              _buildCandidatesSection(theme, l10n, election),
              const Divider(height: 32),
              _buildEcSection(theme, l10n, election),
              const SizedBox(height: 24),
              _buildVoteButton(theme, l10n, election),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(ThemeData theme, Election election) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            election.name,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        StatusBadge(status: election.status),
      ],
    );
  }

  Widget _buildTimeSection(
    ThemeData theme,
    AppLocalizations l10n,
    Election election,
  ) {
    final status = election.status;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.schedule,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(l10n.time, style: theme.textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 12),
            if (status == ElectionStatus.active)
              CountdownTimer(
                targetTime: election.endTime,
                prefix: l10n.endsIn,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              )
            else if (status == ElectionStatus.upcoming)
              CountdownTimer(
                targetTime: election.startTime,
                prefix: l10n.startsIn,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              )
            else
              Text(
                l10n.ended,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            const SizedBox(height: 8),
            Text(
              l10n.startLabel(_formatDateTime(election.startTime)),
              style: theme.textTheme.bodySmall,
            ),
            Text(
              l10n.endLabel(_formatDateTime(election.endTime)),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCandidatesSection(
    ThemeData theme,
    AppLocalizations l10n,
    Election election,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.people,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Text(
              l10n.candidatesCount(election.candidates.length),
              style: theme.textTheme.titleSmall,
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (election.candidates.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              l10n.noCandidatesRegistered,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          ...election.candidates.map(
            (candidate) => CandidateTile(
              candidate: candidate,
              isSelected: _selectedCandidateId == candidate.id,
              onTap: election.status == ElectionStatus.active
                  ? () => setState(() => _selectedCandidateId = candidate.id)
                  : null,
            ),
          ),
      ],
    );
  }

  Widget _buildEcSection(
    ThemeData theme,
    AppLocalizations l10n,
    Election election,
  ) {
    final truncated = election.ecPubkey.length > 16
        ? '${election.ecPubkey.substring(0, 8)}...${election.ecPubkey.substring(election.ecPubkey.length - 8)}'
        : election.ecPubkey;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.verified_user,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.electoralCommission,
                  style: theme.textTheme.titleSmall,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    truncated,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy, size: 18),
                  tooltip: l10n.copyEcPubkey,
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: election.ecPubkey));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.ecPubkeyCopied)),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoteButton(
    ThemeData theme,
    AppLocalizations l10n,
    Election election,
  ) {
    final status = election.status;
    final isActive = status == ElectionStatus.active;

    String? disabledReason;
    if (status == ElectionStatus.upcoming) {
      disabledReason = l10n.votingNotStarted;
    } else if (status == ElectionStatus.finished) {
      disabledReason = l10n.electionEnded;
    } else if (status == ElectionStatus.canceled) {
      disabledReason = l10n.electionCanceled;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: isActive && _selectedCandidateId != null
              ? () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.votingFlowComingSoon)),
                  );
                }
              : null,
          icon: const Icon(Icons.how_to_vote),
          label: Text(l10n.vote),
        ),
        if (disabledReason != null) ...[
          const SizedBox(height: 8),
          Text(
            disabledReason,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        if (isActive && _selectedCandidateId == null) ...[
          const SizedBox(height: 8),
          Text(
            l10n.selectCandidateToVote,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }

  String _formatDateTime(DateTime dt) {
    final month = dt.month.toString().padLeft(2, '0');
    final day = dt.day.toString().padLeft(2, '0');
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '${dt.year}-$month-$day $hour:$minute';
  }
}
