import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';

class ThemeProvider with ChangeNotifier {
  static const _themeModeKey = 'theme-mode-index';
  static final Logger _log = Logger(printer: SimplePrinter());
  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  ThemeProvider._();

  static Future<ThemeProvider> create() async {
    final provider = ThemeProvider._();
    await provider._loadThemePreference();
    return provider;
  }

  void setThemeMode(ThemeMode newMode) {
    if (_themeMode != newMode) {
      _themeMode = newMode;
      notifyListeners();
      unawaited(_saveThemePreference(newMode));
    }
  }

  Future<void> _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final int? themeIndex = prefs.getInt(_themeModeKey);
    if (themeIndex != null &&
        themeIndex >= 0 &&
        themeIndex < ThemeMode.values.length) {
      _themeMode = ThemeMode.values[themeIndex];
      notifyListeners();
    } else {
      _themeMode = ThemeMode.system;
      notifyListeners();
      unawaited(_saveThemePreference(_themeMode));
    }
  }

  Future<void> _saveThemePreference(ThemeMode option) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_themeModeKey, option.index);
    } catch (error, stackTrace) {
      // 持久化失败不阻塞主题切换；记录日志便于排查。
      _log.e('ThemeMode persist failed', error: error, stackTrace: stackTrace);
    }
  }
}
