import 'package:criptocracia_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../models/candidate.dart';

/// A list tile displaying a candidate's name and ID.
///
/// Supports selection state for future voting flow.
class CandidateTile extends StatelessWidget {
  /// The candidate to display.
  final Candidate candidate;

  /// Whether this candidate is currently selected.
  final bool isSelected;

  /// Called when the tile is tapped.
  final VoidCallback? onTap;

  const CandidateTile({
    super.key,
    required this.candidate,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return ListTile(
      leading: Icon(
        isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: isSelected ? theme.colorScheme.primary : null,
      ),
      title: Text(
        candidate.name,
        style: theme.textTheme.bodyLarge?.copyWith(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      subtitle: Text(
        l10n.candidateId(candidate.id),
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      onTap: onTap,
      selected: isSelected,
    );
  }
}
