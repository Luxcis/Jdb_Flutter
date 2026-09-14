// test/core/providers/auth_provider_test.dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jade/core/providers/auth_provider.dart';
import 'package:jade/core/storage/storage_keys.dart';
import 'package:jade/core/storage/testing/in_memory_secure_store.dart';

const _authSessionKey = 'key_auth_session';

/// 写入抛异常的 SecureValueStore，用于验证写失败路径（前 [successWrites] 次成功）。
class _FailingWriteSecureStore extends InMemorySecureValueStore {
  _FailingWriteSecureStore({this.successWrites = 0});

  var _writes = 0;
  final int successWrites;

  @override
  Future<void> write(String key, String value) async {
    final index = _writes++;
    if (index >= successWrites) {
      throw _SessionWriteException('secure write failed');
    }
    await super.write(key, value);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('login 以单键持久化会话到 secure storage 并可在重启后恢复', () async {
    final user = {
      'id': 1,
      'username': 'session-user',
      'roles': ['member', 'reviewer'],
    };
    final prefs = await SharedPreferences.getInstance();
    final secure = InMemorySecureValueStore();
    final auth = await AuthProvider.create(prefs, secure: secure);

    await auth.login(token: 'session-token', user: user);

    expect(auth.token, 'session-token');
    expect(auth.user, user);
    expect(auth.isLogged, isTrue);
    expect(jsonDecode(secure[_authSessionKey]!), {
      'token': 'session-token',
      'user': user,
    });
    expect(prefs.getString(_authSessionKey), isNull);

    final restored = await AuthProvider.create(prefs, secure: secure);
    expect(restored.token, 'session-token');
    expect(restored.user, user);
    expect(restored.isLogged, isTrue);
  });

  test('旧版本明文会话迁移到 secure storage 并清除明文', () async {
    final user = {'id': 1, 'username': 'legacy-user'};
    SharedPreferences.setMockInitialValues({
      _authSessionKey: jsonEncode({'token': 'legacy-token', 'user': user}),
    });
    final prefs = await SharedPreferences.getInstance();
    final secure = InMemorySecureValueStore();

    final auth = await AuthProvider.create(prefs, secure: secure);

    expect(auth.token, 'legacy-token');
    expect(auth.user, user);
    expect(auth.isLogged, isTrue);
    expect(jsonDecode(secure[_authSessionKey]!), {
      'token': 'legacy-token',
      'user': user,
    });
    expect(prefs.getString(_authSessionKey), isNull);
  });

  test('旧版本明文迁移失败时保留明文，下次启动可重试', () async {
    final user = {'id': 2, 'username': 'legacy-user'};
    SharedPreferences.setMockInitialValues({
      _authSessionKey: jsonEncode({'token': 'legacy-token', 'user': user}),
    });
    final prefs = await SharedPreferences.getInstance();
    final auth = await AuthProvider.create(
      prefs,
      secure: _FailingWriteSecureStore(),
    );

    expect(auth.token, 'legacy-token');
    expect(auth.user, user);
    expect(prefs.getString(_authSessionKey), isNotNull);
  });

  test('权威 tombstone 存在时不回退到陈旧 legacy 会话', () async {
    SharedPreferences.setMockInitialValues({
      _authSessionKey: jsonEncode({'token': null, 'user': null}),
      StorageKeys.token: 'stale-legacy-token',
      StorageKeys.user: jsonEncode({'id': 8, 'username': 'stale-user'}),
    });
    final prefs = await SharedPreferences.getInstance();
    final secure = InMemorySecureValueStore();

    final auth = await AuthProvider.create(prefs, secure: secure);

    expect(auth.token, isNull);
    expect(auth.user, isNull);
    expect(auth.isLogged, isFalse);
    expect(jsonDecode(secure[_authSessionKey]!), {'token': null, 'user': null});
  });

  test('secure 与明文会话键均缺失时兼容恢复 legacy Token 与 User', () async {
    final legacyUser = {'id': 7, 'username': 'legacy-user'};
    SharedPreferences.setMockInitialValues({
      StorageKeys.token: 'legacy-token',
      StorageKeys.user: jsonEncode(legacyUser),
    });
    final prefs = await SharedPreferences.getInstance();
    final secure = InMemorySecureValueStore();

    final auth = await AuthProvider.create(prefs, secure: secure);

    expect(auth.token, 'legacy-token');
    expect(auth.user, legacyUser);
    expect(auth.isLogged, isTrue);
  });

  test('logout 写入权威 tombstone 并在重启后保持登出', () async {
    final prefs = await SharedPreferences.getInstance();
    final secure = InMemorySecureValueStore();
    final auth = await AuthProvider.create(prefs, secure: secure);
    await auth.login(
      token: 'active-token',
      user: {'id': 10, 'username': 'active-user'},
    );

    await auth.logout();

    expect(auth.token, isNull);
    expect(auth.user, isNull);
    expect(auth.isLogged, isFalse);
    expect(jsonDecode(secure[_authSessionKey]!), {'token': null, 'user': null});
    expect(prefs.getString(StorageKeys.token), isNull);
    expect(prefs.getString(StorageKeys.user), isNull);

    final restored = await AuthProvider.create(prefs, secure: secure);
    expect(restored.token, isNull);
    expect(restored.user, isNull);
    expect(restored.isLogged, isFalse);
  });

  test('updateUser 保留 token、刷新 user 并持久化', () async {
    final prefs = await SharedPreferences.getInstance();
    final secure = InMemorySecureValueStore();
    final auth = await AuthProvider.create(prefs, secure: secure);
    final listener = _RecordingListener();
    auth.addListener(listener.onChanged);
    await auth.login(
      token: 'session-token',
      user: {'id': 1, 'username': 'old-user', 'want_watch_count': 1},
    );
    listener.calls = 0;

    await auth.updateUser({
      'id': 1,
      'username': 'fresh-user',
      'want_watch_count': 5,
      'watched_count': 3,
    });

    expect(auth.token, 'session-token');
    expect(auth.user, {
      'id': 1,
      'username': 'fresh-user',
      'want_watch_count': 5,
      'watched_count': 3,
    });
    expect(listener.calls, 1);
    expect(jsonDecode(secure[_authSessionKey]!), {
      'token': 'session-token',
      'user': {
        'id': 1,
        'username': 'fresh-user',
        'want_watch_count': 5,
        'watched_count': 3,
      },
    });
  });

  test('权威会话写入抛异常时保留旧会话并传播原始异常', () async {
    final oldUser = {'id': 1, 'username': 'old-user'};
    final prefs = await SharedPreferences.getInstance();
    // 首次 login 成功落库；随后的写入失败。
    final secure = _FailingWriteSecureStore(successWrites: 1);
    final auth = await AuthProvider.create(prefs, secure: secure);
    await auth.login(token: 'old-token', user: oldUser);

    await expectLater(
      () => auth.login(
        token: 'replacement-token',
        user: {'id': 2, 'username': 'replacement-user'},
      ),
      throwsA(isA<_SessionWriteException>()),
    );

    expect(auth.token, 'old-token');
    expect(auth.user, oldUser);
    expect(jsonDecode(secure[_authSessionKey]!), {
      'token': 'old-token',
      'user': oldUser,
    });
  });

  test('updateUser 未登录时为空操作', () async {
    final prefs = await SharedPreferences.getInstance();
    final secure = InMemorySecureValueStore();
    final auth = await AuthProvider.create(prefs, secure: secure);

    await auth.updateUser({'id': 1, 'username': 'ghost-user'});

    expect(auth.token, isNull);
    expect(auth.user, isNull);
    expect(secure[_authSessionKey], isNull);
  });
}

final class _SessionWriteException implements Exception {
  const _SessionWriteException(this.message);

  final String message;

  @override
  String toString() => 'Session write failed: $message';
}

final class _RecordingListener {
  var calls = 0;
  void onChanged() => calls++;
}
