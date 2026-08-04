import 'package:flutter/material.dart';

import '../repositories/settings_repository.dart';

/// Exposes and persists the app's [ThemeMode] (light / dark / system).
class ThemeProvider extends ChangeNotifier {
  final SettingsRepository _settingsRepository;

  ThemeProvider(this._settingsRepository) {
    _load();
  }

  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  Future<void> _load() async {
    final saved = await _settingsRepository.loadThemeMode();
    _themeMode = _fromString(saved);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    await _settingsRepository.saveThemeMode(_toString(mode));
  }

  ThemeMode _fromString(String value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  String _toString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }
}
