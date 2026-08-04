/// Centralized, immutable constants used across the application.
///
/// Keeping these in one place avoids "magic strings/numbers" scattered
/// through the codebase and makes tuning defaults trivial.
class AppConstants {
  AppConstants._();

  static const String appName = 'WiFi FTP Server';

  // ---- Server defaults -------------------------------------------------
  static const int defaultPort = 2121;
  static const int minPort = 1024;
  static const int maxPort = 65535;

  static const int passiveModePortRangeStart = 50000;
  static const int passiveModePortRangeEnd = 50100;

  static const String defaultUsername = 'ftpuser';
  static const String defaultPassword = 'ftppass';
  static const bool defaultAnonymousAllowed = false;
  static const bool defaultReadOnly = false;
  static const bool defaultShowHiddenFiles = false;
  static const bool defaultAutoStart = false;

  static const int socketReadTimeoutSeconds = 300; // 5 minutes idle timeout
  static const int fileStreamChunkSize = 64 * 1024; // 64 KB chunks

  // ---- Shared preference keys -------------------------------------------
  static const String prefPort = 'pref_port';
  static const String prefUsername = 'pref_username';
  static const String prefPassword = 'pref_password';
  static const String prefAnonymous = 'pref_anonymous';
  static const String prefReadOnly = 'pref_read_only';
  static const String prefShowHidden = 'pref_show_hidden';
  static const String prefAutoStart = 'pref_auto_start';
  static const String prefRootDirectory = 'pref_root_directory';
  static const String prefThemeMode = 'pref_theme_mode';

  // ---- Notification -------------------------------------------------------
  static const String notificationChannelId = 'wifi_ftp_server_channel';
  static const String notificationChannelName = 'FTP Server Status';
  static const String notificationChannelDescription =
      'Shows the running status of the WiFi FTP Server';
  static const int foregroundNotificationId = 4001;

  // ---- History limits ---------------------------------------------------
  static const int maxHistoryEntries = 500;
  static const int maxLogEntries = 1000;
}
