// lib/core/providers/settings_provider.dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jade/core/storage/storage_keys.dart';
import 'package:jade/core/utils/github_proxy.dart';

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

  /// 保存 GitHub 代理前缀；在数据边界统一规范化，保证
  /// 「非空代理一定以 / 结尾」，使 buildGitHubUrl 可按 proxy + fullUrl 拼接。
  Future<void> setGithubProxy(String value) async {
    final normalized = normalizeGithubProxy(value.trim());
    _githubProxy = normalized;
    await _prefs.setString(StorageKeys.githubProxy, normalized);
    notifyListeners();
  }
}
