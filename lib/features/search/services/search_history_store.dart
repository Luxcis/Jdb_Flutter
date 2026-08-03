import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:jade/core/storage/storage_keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SearchHistoryStore extends ChangeNotifier {
  SearchHistoryStore(this._prefs);

  final SharedPreferences _prefs;

  List<String> load() {
    final raw = _prefs.getString(StorageKeys.searchHistory);
    if (raw == null) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List || decoded.any((item) => item is! String)) {
        return const [];
      }
      return List<String>.from(decoded);
    } on FormatException {
      return const [];
    }
  }

  Future<List<String>> save(String query) async {
    final keyword = query.trim();
    if (keyword.isEmpty) return load();
    final history = load().toList()..remove(keyword);
    history.insert(0, keyword);
    final limited = history.take(20).toList(growable: false);
    await _prefs.setString(StorageKeys.searchHistory, jsonEncode(limited));
    notifyListeners();
    return limited;
  }

  Future<void> clear() async {
    await _prefs.remove(StorageKeys.searchHistory);
    notifyListeners();
  }
}
