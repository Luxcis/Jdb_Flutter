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
    _token = token;
    _user = user;
    await _prefs.setString(StorageKeys.token, token);
    await _prefs.setString(StorageKeys.user, jsonEncode(user));
    notifyListeners();
  }

  Future<void> logout() async {
    _token = null;
    _user = null;
    await _prefs.remove(StorageKeys.token);
    await _prefs.remove(StorageKeys.user);
    notifyListeners();
  }
}
