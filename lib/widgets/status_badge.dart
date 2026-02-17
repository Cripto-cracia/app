import 'package:flutter/material.dart';

import '../models/election.dart';

/// A color-coded badge indicating election status.
class StatusBadge extends StatelessWidget {
  /// The election status to display.
  final ElectionStatus status;

  const StatusBadge({super.key, required this.status});

  /// Returns the label and color for the given [status].
  static (String, Color) labelAndColor(ElectionStatus status) {
    return switch (status) {
      ElectionStatus.active => ('Active', Colors.green),
      ElectionStatus.upcoming => ('Upcoming', Colors.orange),
      ElectionStatus.finished => ('Finished', Colors.grey),
      ElectionStatus.canceled => ('Canceled', Colors.red),
    };
  }

  @override
  Widget build(BuildContext context) {
    final (label, color) = labelAndColor(status);

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
