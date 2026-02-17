import 'package:criptocracia_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../models/election.dart';

/// A color-coded badge indicating election status.
class StatusBadge extends StatelessWidget {
  /// The election status to display.
  final ElectionStatus status;

  const StatusBadge({super.key, required this.status});

  /// Returns the color for the given [status].
  static Color colorFor(ElectionStatus status) {
    return switch (status) {
      ElectionStatus.active => Colors.green,
      ElectionStatus.upcoming => Colors.orange,
      ElectionStatus.finished => Colors.grey,
      ElectionStatus.canceled => Colors.red,
    };
  }

  /// Returns the localized label for the given [status].
  static String labelFor(AppLocalizations l10n, ElectionStatus status) {
    return switch (status) {
      ElectionStatus.active => l10n.active,
      ElectionStatus.upcoming => l10n.upcoming,
      ElectionStatus.finished => l10n.finished,
      ElectionStatus.canceled => l10n.canceled,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final label = labelFor(l10n, status);
    final color = colorFor(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
