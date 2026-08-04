import 'package:flutter/material.dart';

import '../../core/utils/logger.dart';
import '../../models/log_entry_model.dart';

/// Renders a single timestamped log line, color-coded by [LogLevel].
class LogListItem extends StatelessWidget {
  final LogEntryModel entry;

  const LogListItem({super.key, required this.entry});

  Color _colorFor(LogLevel level, BuildContext context) {
    switch (level) {
      case LogLevel.error:
        return Theme.of(context).colorScheme.error;
      case LogLevel.warning:
        return Colors.orange;
      case LogLevel.success:
        return Colors.green;
      case LogLevel.info:
        return Theme.of(context).colorScheme.onSurfaceVariant;
    }
  }

  IconData _iconFor(LogLevel level) {
    switch (level) {
      case LogLevel.error:
        return Icons.error_outline;
      case LogLevel.warning:
        return Icons.warning_amber_outlined;
      case LogLevel.success:
        return Icons.check_circle_outline;
      case LogLevel.info:
        return Icons.info_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(entry.level, context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            entry.formattedTime,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(fontFamily: 'monospace', color: Colors.grey),
          ),
          const SizedBox(width: 8),
          Icon(_iconFor(entry.level), size: 14, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              entry.message,
              style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: color),
            ),
          ),
        ],
      ),
    );
  }
}
