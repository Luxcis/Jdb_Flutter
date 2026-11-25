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

  /// 认证状态版本号：供 GoRouter 的 `refreshListenable` 使用。
  ///
  /// 路由在 `MyApp.initState` 中创建、拿不到 Provider 上下文，因此用进程级
  /// Listenable 桥接登录态变化；每次 [notifyListeners] 时递增以触发路由
  /// redirect 重新求值。
  static final ValueNotifier<int> _authRevision = ValueNotifier<int>(0);

  /// 进程内认证状态变化的 Listenable。
  static Listenable get authRevision => _authRevision;

  @override
  String? get token => _token;
  Map<String, dynamic>? get user => _user;
  bool get isLogged => _token != null && _token!.isNotEmpty;

  void _notifySessionChanged() {
    notifyListeners();
    _authRevision.value = _authRevision.value + 1;
  }

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
      if (!p._restoreEncodedSession(stored, source: 'secure storage')) {
        // 权威会话损坏：删除坏键（连同更早的 legacy 键），按未登录启动。
        await p._discardStoredSession();
      }
      return p;
    }

    final legacy = p._readLegacyPrefsSession();
    if (legacy.present) {
      if (legacy.valid && legacy.encoded != null) {
        await p._migrateToSecure(legacy.encoded!);
      } else {
        await p._discardStoredSession();
      }
      return p;
    }

    p._token = p._readPrefsString(StorageKeys.token);
    final u = p._readPrefsString(StorageKeys.user);
    if (u != null) {
      try {
        final decoded = jsonDecode(u);
        if (decoded is! Map) {
          debugPrint(
            'AuthProvider: legacy user value is not a JSON object; '
            'discarding legacy session.',
          );
          p._token = null;
          p._user = null;
          await p._discardStoredSession();
          return p;
        }
        p._user = Map<String, dynamic>.from(decoded);
      } catch (error, stackTrace) {
        debugPrint(
          'AuthProvider: failed to decode legacy user value: '
          '$error\n$stackTrace',
        );
        p._token = null;
        p._user = null;
        await p._discardStoredSession();
        return p;
      }
    }
    if (p.isLogged) {
      // 更早期版本的 token/user 双键明文会话同样迁移进 secure storage。
      await p._migrateToSecure(
        jsonEncode({'token': p._token, 'user': p._user}),
      );
    }
    return p;
  }

  /// 解析并恢复编码后的会话；畸形 JSON、非对象或字段类型异常时返回 false。
  bool _restoreEncodedSession(String encoded, {required String source}) {
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map) {
        debugPrint(
          'AuthProvider: $source session is not a JSON object; discarding.',
        );
        return false;
      }
      return _restoreSession(decoded);
    } catch (error, stackTrace) {
      debugPrint(
        'AuthProvider: failed to decode $source session: $error\n$stackTrace',
      );
      return false;
    }
  }

  /// 返回会话是否可识别。`{'token': null, 'user': null}` 是合法 tombstone。
  bool _restoreSession(Map session) {
    final token = session['token'];
    final user = session['user'];
    if (token == null && user == null) return true;
    if (token is! String || token.isEmpty) return false;
    if (user != null && user is! Map) return false;
    try {
      final restoredUser = user == null
          ? null
          : Map<String, dynamic>.from(user as Map);
      _token = token;
      _user = restoredUser;
      return true;
    } catch (error, stackTrace) {
      debugPrint(
        'AuthProvider: failed to restore session user: $error\n$stackTrace',
      );
      _token = null;
      _user = null;
      return false;
    }
  }

  /// 旧版本明文 authSession 一次性迁移来源：读入内存并返回原文；
  /// 迁移本身由调用方 [create] 统一执行。
  ({bool present, bool valid, String? encoded}) _readLegacyPrefsSession() {
    try {
      if (!_prefs.containsKey(StorageKeys.authSession)) {
        return (present: false, valid: false, encoded: null);
      }
      final encoded = _prefs.getString(StorageKeys.authSession);
      if (encoded == null) {
        return (present: true, valid: false, encoded: null);
      }
      return (
        present: true,
        valid: _restoreEncodedSession(encoded, source: 'legacy prefs'),
        encoded: encoded,
      );
    } catch (error, stackTrace) {
      // 键存在但类型异常（非 String）同样按损坏会话处理。
      debugPrint(
        'AuthProvider: failed to read legacy session value: '
        '$error\n$stackTrace',
      );
      return (present: true, valid: false, encoded: null);
    }
  }

  String? _readPrefsString(String key) {
    try {
      return _prefs.getString(key);
    } catch (error, stackTrace) {
      debugPrint(
        'AuthProvider: failed to read $key from prefs: $error\n$stackTrace',
      );
      return null;
    }
  }

  /// 删除损坏的会话键：secure 权威键与更早的 prefs 明文键都按最大努力清理，
  /// 避免下次启动再次命中同一坏值或回退到陈旧会话。
  Future<void> _discardStoredSession() async {
    try {
      await _secure.delete(StorageKeys.authSession);
    } catch (error, stackTrace) {
      debugPrint(
        'AuthProvider: failed to delete corrupt secure session: '
        '$error\n$stackTrace',
      );
    }
    await _removeLegacySession();
  }

  /// 迁移采用最大努力策略：失败时保留明文，下次启动重试。
  Future<void> _migrateToSecure(String encodedSession) async {
    try {
      await _secure.write(StorageKeys.authSession, encodedSession);
      await _removeLegacySession();
    } catch (error, stackTrace) {
      debugPrint(
        'AuthProvider legacy session migration failed: $error\n$stackTrace',
      );
    }
  }

  Future<void> login({
    required String token,
    required Map<String, dynamic> user,
  }) async {
    await _persist({'token': token, 'user': user});
    _token = token;
    _user = Map<String, dynamic>.from(user);
    _notifySessionChanged();
    await _removeLegacySession();
  }

  Future<void> _removeLegacySession() async {
    for (final key in [
      StorageKeys.authSession,
      StorageKeys.token,
      StorageKeys.user,
    ]) {
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

  /// 退出登录：先清空内存并通知（保证界面进入未登录态），再 best-effort
  /// 写 tombstone。持久化失败只记录日志，不向调用方传播。
  Future<void> logout() async {
    _token = null;
    _user = null;
    _notifySessionChanged();
    try {
      await _persist({'token': null, 'user': null});
    } catch (error, stackTrace) {
      debugPrint('AuthProvider logout persist failed: $error\n$stackTrace');
    }
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
    _notifySessionChanged();
  }
}
