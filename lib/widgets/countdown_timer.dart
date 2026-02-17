import 'dart:async';

import 'package:flutter/material.dart';

/// A widget that displays a countdown to a target [DateTime].
///
/// Automatically updates every second and formats the remaining time
/// as "Xd Xh Xm Xs".
class CountdownTimer extends StatefulWidget {
  /// The target date/time to count down to.
  final DateTime targetTime;

  /// Optional prefix text displayed before the countdown.
  final String? prefix;

  /// Text style for the countdown.
  final TextStyle? style;

  const CountdownTimer({
    super.key,
    required this.targetTime,
    this.prefix,
    this.style,
  });

  /// Formats a [Duration] as "Xd Xh Xm Xs".
  static String formatDuration(Duration duration) {
    if (duration.isNegative) return '0s';

    final days = duration.inDays;
    final hours = duration.inHours.remainder(24);
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    final parts = <String>[];
    if (days > 0) parts.add('${days}d');
    if (hours > 0) parts.add('${hours}h');
    if (minutes > 0) parts.add('${minutes}m');
    parts.add('${seconds}s');

    return parts.join(' ');
  }

  @override
  State<CountdownTimer> createState() => _CountdownTimerState();
}

class _CountdownTimerState extends State<CountdownTimer> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remaining = widget.targetTime.difference(DateTime.now());

    if (remaining.isNegative) {
      return Text('Ended', style: widget.style);
    }

    final formatted = CountdownTimer.formatDuration(remaining);
    final text = widget.prefix != null
        ? '${widget.prefix} $formatted'
        : formatted;

    return Text(text, style: widget.style);
  }
}
