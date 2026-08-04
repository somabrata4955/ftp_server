import 'package:flutter/foundation.dart';

import '../models/server_config_model.dart';
import '../repositories/settings_repository.dart';
import '../services/storage_service.dart';

/// Loads, exposes, and persists [ServerConfigModel]. The [ServerProvider]
/// reads from this provider whenever the server (re)starts so all
/// settings screens edits take effect immediately on the next start.
class SettingsProvider extends ChangeNotifier {
  final SettingsRepository _settingsRepository;
  final StorageService _storageService;

  SettingsProvider(this._settingsRepository, this._storageService) {
    _initialize();
  }

  ServerConfigModel _config = const ServerConfigModel();
  ServerConfigModel get config => _config;

  bool _isLoaded = false;
  bool get isLoaded => _isLoaded;

  Future<void> _initialize() async {
    final defaultRoot = await _storageService.getDefaultRootDirectory();
    _config = await _settingsRepository.loadConfig(defaultRoot: defaultRoot);
    await _storageService.ensureDirectoryExists(_config.rootDirectory);
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> updateConfig(ServerConfigModel newConfig) async {
    _config = newConfig;
    notifyListeners();
    await _settingsRepository.saveConfig(newConfig);
  }

  Future<void> setPort(int port) => updateConfig(_config.copyWith(port: port));

  Future<void> setCredentials(String username, String password) =>
      updateConfig(_config.copyWith(username: username, password: password));

  Future<void> setAnonymousAllowed(bool value) =>
      updateConfig(_config.copyWith(anonymousAllowed: value));

  Future<void> setReadOnly(bool value) =>
      updateConfig(_config.copyWith(readOnly: value));

  Future<void> setShowHiddenFiles(bool value) =>
      updateConfig(_config.copyWith(showHiddenFiles: value));

  Future<void> setAutoStart(bool value) =>
      updateConfig(_config.copyWith(autoStart: value));

  Future<void> setRootDirectory(String path) async {
    await _storageService.ensureDirectoryExists(path);
    await updateConfig(_config.copyWith(rootDirectory: path));
  }
}
