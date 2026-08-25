// lib/core/providers/settings_provider.dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jade/core/storage/storage_keys.dart';

class SettingsProvider extends ChangeNotifier {
  SettingsProvider._(this._prefs);
  final SharedPreferences _prefs;
  bool _blurMovieImages = true;
  String _githubProxy = '';

  bool get blurMovieImages => _blurMovieImages;
  String get githubProxy => _githubProxy;

  static Future<SettingsProvider> create(SharedPreferences prefs) async {
    final p = SettingsProvider._(prefs);
    p._blurMovieImages = prefs.getBool(StorageKeys.blurMovieImages) ?? true;
    p._githubProxy = prefs.getString(StorageKeys.githubProxy) ?? '';
    return p;
  }

  Future<void> setBlurMovieImages(bool value) async {
    _blurMovieImages = value;
    await _prefs.setBool(StorageKeys.blurMovieImages, value);
    notifyListeners();
  }

  Future<void> setGithubProxy(String value) async {
    _githubProxy = value;
    await _prefs.setString(StorageKeys.githubProxy, value);
    notifyListeners();
  }
}
