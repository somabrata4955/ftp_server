import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/app_constants.dart';
import '../models/server_config_model.dart';

/// Persists and loads [ServerConfigModel] using SharedPreferences.
///
/// Isolating persistence behind a repository interface means the
/// providers/controllers never talk to SharedPreferences directly,
/// satisfying the Repository Pattern and making it trivial to swap the
/// storage backend later (e.g. to a database) without touching UI code.
class SettingsRepository {
  Future<ServerConfigModel> loadConfig({required String defaultRoot}) async {
    final prefs = await SharedPreferences.getInstance();
    return ServerConfigModel(
      port: prefs.getInt(AppConstants.prefPort) ?? AppConstants.defaultPort,
      username: prefs.getString(AppConstants.prefUsername) ??
          AppConstants.defaultUsername,
      password: prefs.getString(AppConstants.prefPassword) ??
          AppConstants.defaultPassword,
      anonymousAllowed: prefs.getBool(AppConstants.prefAnonymous) ??
          AppConstants.defaultAnonymousAllowed,
      readOnly:
          prefs.getBool(AppConstants.prefReadOnly) ?? AppConstants.defaultReadOnly,
      showHiddenFiles: prefs.getBool(AppConstants.prefShowHidden) ??
          AppConstants.defaultShowHiddenFiles,
      autoStart:
          prefs.getBool(AppConstants.prefAutoStart) ?? AppConstants.defaultAutoStart,
      rootDirectory: prefs.getString(AppConstants.prefRootDirectory) ?? defaultRoot,
    );
  }

  Future<void> saveConfig(ServerConfigModel config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(AppConstants.prefPort, config.port);
    await prefs.setString(AppConstants.prefUsername, config.username);
    await prefs.setString(AppConstants.prefPassword, config.password);
    await prefs.setBool(AppConstants.prefAnonymous, config.anonymousAllowed);
    await prefs.setBool(AppConstants.prefReadOnly, config.readOnly);
    await prefs.setBool(AppConstants.prefShowHidden, config.showHiddenFiles);
    await prefs.setBool(AppConstants.prefAutoStart, config.autoStart);
    await prefs.setString(AppConstants.prefRootDirectory, config.rootDirectory);
  }

  Future<String> loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.prefThemeMode) ?? 'system';
  }

  Future<void> saveThemeMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.prefThemeMode, mode);
  }
}
