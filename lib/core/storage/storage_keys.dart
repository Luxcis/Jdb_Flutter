import 'package:shared_preferences/shared_preferences.dart';

class StorageKeys {
  const StorageKeys._();
  static const String baseUrl = 'key_baseurl';
  static const String apiDomains = 'key_api_domains';
  static const String authSession = 'key_auth_session';
  static const String token = 'key_token';
  static const String user = 'key_user';
  static const String themeMode = 'key_theme_mode';
  static const String blurMovieImages = 'key_blur_movie_images';
  static const String searchHistory = 'key_search_history';
  static const String magnetSearchHistory = 'key_magnet_search_history';
  static const String line = 'key_line';
  static const String deviceUuid = 'key_device_uuid';
  static const String followingTags = 'key_following_tags';
}

class StorageService {
  StorageService._(this._prefs);
  final SharedPreferences _prefs;

  static Future<StorageService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return StorageService._(prefs);
  }

  String? getString(String key) => _prefs.getString(key);
  Future<bool> setString(String key, String value) =>
      _prefs.setString(key, value);
  Future<bool> remove(String key) => _prefs.remove(key);
}
