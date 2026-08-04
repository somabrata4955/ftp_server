import '../core/utils/logger.dart';

/// UI-facing representation of a log line (wraps [AppLogRecord]).
class LogEntryModel {
  final DateTime timestamp;
  final LogLevel level;
  final String message;

  LogEntryModel({
    required this.timestamp,
    required this.level,
    required this.message,
  });

  factory LogEntryModel.fromRecord(AppLogRecord record) => LogEntryModel(
        timestamp: record.timestamp,
        level: record.level,
        message: record.message,
      );

  String get formattedTime {
    final t = timestamp;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }
}
