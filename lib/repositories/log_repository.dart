import '../core/constants/app_constants.dart';
import '../core/utils/logger.dart';
import '../models/log_entry_model.dart';

/// Buffers [LogEntryModel]s emitted via [AppLogger] so the Logs screen can
/// display and auto-scroll through them, capped to avoid unbounded memory
/// growth on long-running servers.
class LogRepository {
  final List<LogEntryModel> _entries = [];

  List<LogEntryModel> getAll() => List.unmodifiable(_entries);

  void add(AppLogRecord record) {
    _entries.add(LogEntryModel.fromRecord(record));
    if (_entries.length > AppConstants.maxLogEntries) {
      _entries.removeAt(0);
    }
  }

  void clear() => _entries.clear();
}
