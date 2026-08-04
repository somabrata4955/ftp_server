import '../core/constants/app_constants.dart';

/// Immutable value object describing how the FTP server should run.
///
/// Produced/consumed by [SettingsRepository] and read by
/// [FtpServerService] when starting the server.
class ServerConfigModel {
  final int port;
  final String username;
  final String password;
  final bool anonymousAllowed;
  final bool readOnly;
  final bool showHiddenFiles;
  final bool autoStart;
  final String rootDirectory;

  const ServerConfigModel({
    this.port = AppConstants.defaultPort,
    this.username = AppConstants.defaultUsername,
    this.password = AppConstants.defaultPassword,
    this.anonymousAllowed = AppConstants.defaultAnonymousAllowed,
    this.readOnly = AppConstants.defaultReadOnly,
    this.showHiddenFiles = AppConstants.defaultShowHiddenFiles,
    this.autoStart = AppConstants.defaultAutoStart,
    this.rootDirectory = '',
  });

  ServerConfigModel copyWith({
    int? port,
    String? username,
    String? password,
    bool? anonymousAllowed,
    bool? readOnly,
    bool? showHiddenFiles,
    bool? autoStart,
    String? rootDirectory,
  }) {
    return ServerConfigModel(
      port: port ?? this.port,
      username: username ?? this.username,
      password: password ?? this.password,
      anonymousAllowed: anonymousAllowed ?? this.anonymousAllowed,
      readOnly: readOnly ?? this.readOnly,
      showHiddenFiles: showHiddenFiles ?? this.showHiddenFiles,
      autoStart: autoStart ?? this.autoStart,
      rootDirectory: rootDirectory ?? this.rootDirectory,
    );
  }
}
