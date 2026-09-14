// lib/core/providers/auth_provider.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/storage/login_credential_store.dart';
import 'package:jade/core/storage/storage_keys.dart';

class AuthProvider extends ChangeNotifier implements TokenProvider {
  AuthProvider._(this._prefs, this._secure);

  final SharedPreferences _prefs;
  final SecureValueStore _secure;
  String? _token;
  Map<String, dynamic>? _user;

  @override
  String? get token => _token;
  Map<String, dynamic>? get user => _user;
  bool get isLogged => _token != null && _token!.isNotEmpty;

  static Future<AuthProvider> create(
    SharedPreferences prefs, {
    required SecureValueStore secure,
  }) async {
    final p = AuthProvider._(prefs, secure);

    String? stored;
    try {
      stored = await secure.read(StorageKeys.authSession);
    } catch (error, stackTrace) {
      // 个别设备上 secure storage 平台层可能抛错；兜底为未登录继续启动。
      debugPrint('AuthProvider secure read failed: $error\n$stackTrace');
    }
    if (stored != null) {
      p._restoreSession(jsonDecode(stored));
      return p;
    }

    final legacySession = p._restoreFromLegacyPrefs();
    if (legacySession != null) {
      await p._migrateToSecure(legacySession);
      return p;
    }

    p._token = prefs.getString(StorageKeys.token);
    final u = prefs.getString(StorageKeys.user);
    p._user = u != null ? jsonDecode(u) as Map<String, dynamic> : null;
    if (p.isLogged) {
      // 更早期版本的 token/user 双键明文会话同样迁移进 secure storage。
      await p._migrateToSecure(
        jsonEncode({'token': p._token, 'user': p._user}),
      );
    }
    return p;
  }

  void _restoreSession(Object? session) {
    if (session case {
      'token': final String token,
      'user': final Map user,
    } when token.isNotEmpty) {
      _token = token;
      _user = Map<String, dynamic>.from(user);
    }
  }

  /// 旧版本明文 authSession 一次性迁移来源：读入内存并返回原文；
  /// 迁移本身由调用方 [create] 统一执行。
  String? _restoreFromLegacyPrefs() {
    if (!_prefs.containsKey(StorageKeys.authSession)) return null;
    final encoded = _prefs.getString(StorageKeys.authSession);
    if (encoded == null) return null;
    _restoreSession(jsonDecode(encoded));
    return encoded;
  }

  /// 迁移采用最大努力策略：失败时保留明文，下次启动重试。
  Future<void> _migrateToSecure(String encodedSession) async {
    try {
      await _secure.write(StorageKeys.authSession, encodedSession);
      await _removeLegacySession();
    } catch (error, stackTrace) {
      debugPrint('AuthProvider legacy session migration failed: $error\n$stackTrace');
    }
  }

  Future<void> login({
    required String token,
    required Map<String, dynamic> user,
  }) async {
    await _persist({'token': token, 'user': user});
    _token = token;
    _user = Map<String, dynamic>.from(user);
    notifyListeners();
    await _removeLegacySession();
  }

  Future<void> _removeLegacySession() async {
    for (final key in [StorageKeys.authSession, StorageKeys.token, StorageKeys.user]) {
      try {
        await _prefs.remove(key);
      } catch (_) {
        // 权威会话已持久化；legacy 缓存清理采用最大努力策略。
      }
    }
  }

  /// 权威会话唯一落点为 secure storage；写入失败时内存态未变更，异常原样传播。
  Future<void> _persist(Map<String, dynamic> session) async {
    await _secure.write(StorageKeys.authSession, jsonEncode(session));
  }

  Future<void> logout() async {
    await _persist({'token': null, 'user': null});
    _token = null;
    _user = null;
    notifyListeners();
    await _removeLegacySession();
  }

  /// 用最新用户信息刷新当前会话（token 不变，写回持久化并通知 UI）。
  ///
  /// 未登录时为空操作（不写持久化、不通知）。
  Future<void> updateUser(Map<String, dynamic> user) async {
    final currentToken = _token;
    if (currentToken == null || currentToken.isEmpty) return;
    await _persist({'token': currentToken, 'user': user});
    _user = Map<String, dynamic>.from(user);
    notifyListeners();
  }
}
