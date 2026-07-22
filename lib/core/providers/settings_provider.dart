// lib/core/providers/settings_provider.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jade/core/storage/storage_keys.dart';

class SettingsProvider extends ChangeNotifier {
  SettingsProvider._(this._prefs);
  final SharedPreferences _prefs;
  List<String> _defaultFilterTags = const [];
  bool _blurMovieImages = true;

  List<String> get defaultFilterTags => List.unmodifiable(_defaultFilterTags);
  bool get blurMovieImages => _blurMovieImages;

  static Future<SettingsProvider> create(SharedPreferences prefs) async {
    final p = SettingsProvider._(prefs);
    final raw = prefs.getString(StorageKeys.defaultFilterTags);
    if (raw != null) {
      p._defaultFilterTags = List<String>.from(jsonDecode(raw) as List);
    }
    p._blurMovieImages = prefs.getBool(StorageKeys.blurMovieImages) ?? true;
    return p;
  }

  Future<void> setDefaultFilterTags(List<String> tags) async {
    _defaultFilterTags = tags;
    await _prefs.setString(StorageKeys.defaultFilterTags, jsonEncode(tags));
    notifyListeners();
  }

  Future<void> setBlurMovieImages(bool value) async {
    _blurMovieImages = value;
    await _prefs.setBool(StorageKeys.blurMovieImages, value);
    notifyListeners();
  }
}
