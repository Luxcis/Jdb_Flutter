// lib/core/providers/auth_provider.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/storage/storage_keys.dart';

class AuthProvider extends ChangeNotifier implements TokenProvider {
  AuthProvider._(this._prefs);

  final SharedPreferences _prefs;
  String? _token;
  Map<String, dynamic>? _user;

  @override
  String? get token => _token;
  Map<String, dynamic>? get user => _user;
  bool get isLogged => _token != null && _token!.isNotEmpty;

  static Future<AuthProvider> create(SharedPreferences prefs) async {
    final p = AuthProvider._(prefs);
    p._token = prefs.getString(StorageKeys.token);
    final u = prefs.getString(StorageKeys.user);
    p._user = u != null ? jsonDecode(u) as Map<String, dynamic> : null;
    return p;
  }

  Future<void> login({
    required String token,
    required Map<String, dynamic> user,
  }) async {
    final previousToken = _prefs.getString(StorageKeys.token);
    final previousUser = _prefs.getString(StorageKeys.user);
    final encodedUser = jsonEncode(user);

    try {
      final userSaved = await _prefs.setString(StorageKeys.user, encodedUser);
      final tokenSaved =
          userSaved && await _prefs.setString(StorageKeys.token, token);
      if (!userSaved || !tokenSaved) {
        throw StateError('Failed to persist authenticated session');
      }
    } catch (error, stackTrace) {
      await _restoreValue(StorageKeys.user, previousUser);
      await _restoreValue(StorageKeys.token, previousToken);
      Error.throwWithStackTrace(error, stackTrace);
    }

    _token = token;
    _user = Map<String, dynamic>.from(user);
    notifyListeners();
  }

  Future<void> _restoreValue(String key, String? value) async {
    try {
      if (value == null) {
        await _prefs.remove(key);
      } else {
        await _prefs.setString(key, value);
      }
    } catch (_) {
      // 已保留内存中的旧会话；缓存回滚采用最大努力策略。
    }
  }

  Future<void> logout() async {
    _token = null;
    _user = null;
    await _prefs.remove(StorageKeys.token);
    await _prefs.remove(StorageKeys.user);
    notifyListeners();
  }
}
