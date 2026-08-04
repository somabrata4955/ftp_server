import '../core/utils/validators.dart';
import '../models/server_config_model.dart';
import '../providers/server_provider.dart';
import '../providers/settings_provider.dart';

/// Mediates between the Settings [View] and [SettingsProvider], applying
/// validation before persisting so invalid state (e.g. a bad port) never
/// reaches the repository.
class SettingsController {
  final SettingsProvider settingsProvider;
  final ServerProvider serverProvider;

  SettingsController(this.settingsProvider, this.serverProvider);

  ServerConfigModel get config => settingsProvider.config;

  String? validatePort(String? value) => Validators.validatePort(value);

  String? validateUsername(String? value) =>
      Validators.validateUsername(value, anonymous: config.anonymousAllowed);

  String? validatePassword(String? value) =>
      Validators.validatePassword(value, anonymous: config.anonymousAllowed);

  Future<void> savePort(String value) async {
    final port = int.parse(value.trim());
    await settingsProvider.setPort(port);
    _syncRunningServerIfIdle();
  }

  Future<void> saveCredentials(String username, String password) async {
    await settingsProvider.setCredentials(username, password);
    _syncRunningServerIfIdle();
  }

  Future<void> toggleAnonymous(bool value) async {
    await settingsProvider.setAnonymousAllowed(value);
    _syncRunningServerIfIdle();
  }

  Future<void> toggleReadOnly(bool value) async {
    await settingsProvider.setReadOnly(value);
    _syncRunningServerIfIdle();
  }

  Future<void> toggleShowHidden(bool value) async {
    await settingsProvider.setShowHiddenFiles(value);
    _syncRunningServerIfIdle();
  }

  Future<void> toggleAutoStart(bool value) async {
    await settingsProvider.setAutoStart(value);
  }

  Future<void> changeRootDirectory(String path) async {
    await settingsProvider.setRootDirectory(path);
    _syncRunningServerIfIdle();
  }

  /// Live-appliable settings (read-only, hidden files) are pushed straight
  /// to the running server; port/credential changes require a restart,
  /// which the view surfaces via [ServerProvider.isRunning].
  void _syncRunningServerIfIdle() {
    serverProvider.applyLatestConfig(settingsProvider.config);
  }
}
