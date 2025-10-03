import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/logging_service.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeProvider() {
    _initialise();
  }

  static const _prefsKey = 'theme_mode';

  ThemeMode _themeMode = ThemeMode.system;
  bool _isInitialised = false;

  ThemeMode get themeMode => _themeMode;
  bool get isInitialised => _isInitialised;

  Future<void> _initialise() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_prefsKey);
      if (stored != null) {
        switch (stored) {
          case 'dark':
            _themeMode = ThemeMode.dark;
            break;
          case 'light':
            _themeMode = ThemeMode.light;
            break;
          default:
            _themeMode = ThemeMode.system;
            break;
        }
      }
    } catch (error) {
      LoggingService().warning('Failed to load theme preference', error);
    } finally {
      _isInitialised = true;
      notifyListeners();
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      String value;
      switch (mode) {
        case ThemeMode.dark:
          value = 'dark';
          break;
        case ThemeMode.light:
          value = 'light';
          break;
        case ThemeMode.system:
          value = 'system';
          break;
      }
      await prefs.setString(_prefsKey, value);
    } catch (error) {
      LoggingService().warning('Failed to persist theme preference', error);
    }
  }
}
