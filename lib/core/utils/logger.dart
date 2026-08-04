import 'dart:developer' as developer;

/// Log severity levels used throughout the app.
enum LogLevel { info, warning, error, success }

/// A single emitted log line, timestamped at creation.
class AppLogRecord {
  final DateTime timestamp;
  final LogLevel level;
  final String message;

  AppLogRecord({
    required this.timestamp,
    required this.level,
    required this.message,
  });
}

/// Signature for anyone who wants to be notified of new log records
/// (e.g. the [LogProvider] which feeds the Logs screen).
typedef LogSink = void Function(AppLogRecord record);

/// A tiny, dependency-free logging facility.
///
/// The FTP server and its services call [AppLogger.log] to report activity.
/// Any number of sinks (UI providers, file writers, etc.) can subscribe via
/// [addSink]. This decouples the networking layer from the presentation
/// layer, keeping the architecture clean.
class AppLogger {
  AppLogger._();

  static final List<LogSink> _sinks = [];

  static void addSink(LogSink sink) {
    _sinks.add(sink);
  }

  static void removeSink(LogSink sink) {
    _sinks.remove(sink);
  }

  static void log(String message, {LogLevel level = LogLevel.info}) {
    final record = AppLogRecord(
      timestamp: DateTime.now(),
      level: level,
      message: message,
    );
    developer.log(message, name: 'WiFiFTPServer');
    for (final sink in List<LogSink>.from(_sinks)) {
      sink(record);
    }
  }

  static void info(String message) => log(message, level: LogLevel.info);
  static void warning(String message) => log(message, level: LogLevel.warning);
  static void error(String message) => log(message, level: LogLevel.error);
  static void success(String message) => log(message, level: LogLevel.success);
}
