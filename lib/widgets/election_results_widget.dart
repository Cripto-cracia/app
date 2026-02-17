import 'package:criptocracia_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../models/election_result.dart';

/// Displays election results with horizontal bar charts and percentages.
///
/// Updates automatically when new [ElectionResult] data is provided.
class ElectionResultsWidget extends StatelessWidget {
  /// The election results to display.
  final ElectionResult results;

  /// Optional colors for the candidate bars. Cycles through the list.
  final List<Color>? barColors;

  const ElectionResultsWidget({
    super.key,
    required this.results,
    this.barColors,
  });

  static const List<Color> _defaultColors = [
    Color(0xFF1976D2), // Blue
    Color(0xFFD32F2F), // Red
    Color(0xFF388E3C), // Green
    Color(0xFFF57C00), // Orange
    Color(0xFF7B1FA2), // Purple
    Color(0xFF0097A7), // Teal
    Color(0xFFC2185B), // Pink
    Color(0xFF455A64), // Blue Grey
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final colors = barColors ?? _defaultColors;

    if (results.totalVotes == 0) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(
                Icons.how_to_vote_outlined,
                size: 48,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.noVotesRecordedYet,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.bar_chart,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(l10n.results, style: theme.textTheme.titleSmall),
                const Spacer(),
                Text(
                  l10n.nVotes(results.totalVotes),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...results.candidateResults.asMap().entries.map((entry) {
              final index = entry.key;
              final result = entry.value;
              final color = colors[index % colors.length];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _CandidateResultBar(
                  result: result,
                  color: color,
                  isLeader: index == 0 && result.voteCount > 0,
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

/// A single candidate's result bar showing name, count, percentage, and a
/// horizontal progress bar.
class _CandidateResultBar extends StatelessWidget {
  final CandidateResult result;
  final Color color;
  final bool isLeader;

  const _CandidateResultBar({
    required this.result,
    required this.color,
    required this.isLeader,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fraction = result.percentage / 100.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (isLeader)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Icon(Icons.emoji_events, size: 16, color: color),
              ),
            Expanded(
              child: Text(
                result.candidate.name,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: isLeader ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            Text(
              '${result.voteCount}',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 52,
              child: Text(
                '${result.percentage.toStringAsFixed(1)}%',
                textAlign: TextAlign.right,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: fraction,
            backgroundColor: color.withValues(alpha: 0.12),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }
}
