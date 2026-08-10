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
    if (prefs.containsKey(StorageKeys.authSession)) {
      final session = jsonDecode(prefs.getString(StorageKeys.authSession)!);
      if (session case {
        'token': final String token,
        'user': final Map user,
      } when token.isNotEmpty) {
        p._token = token;
        p._user = Map<String, dynamic>.from(user);
      }
      return p;
    }

    p._token = prefs.getString(StorageKeys.token);
    final u = prefs.getString(StorageKeys.user);
    p._user = u != null ? jsonDecode(u) as Map<String, dynamic> : null;
    return p;
  }

  Future<void> login({
    required String token,
    required Map<String, dynamic> user,
  }) async {
    await _persistSession(
      jsonEncode({'token': token, 'user': user}),
      failureMessage: 'Failed to persist authenticated session',
    );

    _token = token;
    _user = Map<String, dynamic>.from(user);
    notifyListeners();
    await _removeLegacySession();
  }

  Future<void> _removeLegacySession() async {
    try {
      await _prefs.remove(StorageKeys.token);
    } catch (_) {
      // 权威会话已持久化；legacy 缓存清理采用最大努力策略。
    }
    try {
      await _prefs.remove(StorageKeys.user);
    } catch (_) {
      // 权威会话已持久化；legacy 缓存清理采用最大努力策略。
    }
  }

  Future<void> _persistSession(
    String encodedSession, {
    required String failureMessage,
  }) async {
    late final bool saved;
    try {
      saved = await _prefs.setString(StorageKeys.authSession, encodedSession);
    } catch (error, stackTrace) {
      await _reloadAfterFailedWrite();
      Error.throwWithStackTrace(error, stackTrace);
    }
    if (!saved) {
      await _reloadAfterFailedWrite();
      throw StateError(failureMessage);
    }
  }

  Future<void> _reloadAfterFailedWrite() async {
    try {
      await _prefs.reload();
    } catch (_) {
      // 保留原始持久化错误；reload 仅用于修复 SharedPreferences 本地缓存。
    }
  }

  Future<void> logout() async {
    await _persistSession(
      jsonEncode({'token': null, 'user': null}),
      failureMessage: 'Failed to persist logged-out session',
    );
    _token = null;
    _user = null;
    notifyListeners();
    await _removeLegacySession();
  }
}
