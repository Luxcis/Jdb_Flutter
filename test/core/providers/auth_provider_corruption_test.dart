// test/core/providers/auth_provider_corruption_test.dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/providers/auth_provider.dart';
import 'package:jade/core/storage/storage_keys.dart';
import 'package:jade/core/storage/testing/in_memory_secure_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// delete 抛异常的 secure store：验证坏键清理失败也不阻断启动。
class _FailingDeleteSecureStore extends InMemorySecureValueStore {
  @override
  Future<void> delete(String key) async {
    await super.delete(key);
    throw StateError('secure delete failed');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<SharedPreferences> prefsWith(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    return SharedPreferences.getInstance();
  }

  test('secure 会话为畸形 JSON 时删除坏键并按未登录启动', () async {
    final secure = InMemorySecureValueStore();
    await secure.write(StorageKeys.authSession, '{not-json');
    final prefs = await prefsWith({
      StorageKeys.token: 'stale-token',
      StorageKeys.user: jsonEncode({'id': 9, 'username': 'stale-user'}),
    });

    final auth = await AuthProvider.create(prefs, secure: secure);

    expect(auth.isLogged, isFalse);
    expect(auth.token, isNull);
    expect(auth.user, isNull);
    expect(secure[StorageKeys.authSession], isNull);
    expect(prefs.getString(StorageKeys.authSession), isNull);
    expect(prefs.getString(StorageKeys.token), isNull);
    expect(prefs.getString(StorageKeys.user), isNull);
  });

  test('secure 会话为合法 JSON 但非对象时删除坏键并按未登录启动', () async {
    final secure = InMemorySecureValueStore();
    await secure.write(StorageKeys.authSession, jsonEncode([1, 2, 3]));
    final prefs = await prefsWith({});

    final auth = await AuthProvider.create(prefs, secure: secure);

    expect(auth.isLogged, isFalse);
    expect(secure[StorageKeys.authSession], isNull);
  });

  test('secure 会话为对象但 token/user 类型异常时删除坏键', () async {
    final secure = InMemorySecureValueStore();
    await secure.write(
      StorageKeys.authSession,
      jsonEncode({'token': 123, 'user': 'not-a-map'}),
    );
    final prefs = await prefsWith({});

    final auth = await AuthProvider.create(prefs, secure: secure);

    expect(auth.isLogged, isFalse);
    expect(auth.token, isNull);
    expect(auth.user, isNull);
    expect(secure[StorageKeys.authSession], isNull);
  });

  test('secure 坏键删除失败也不阻断启动', () async {
    final secure = _FailingDeleteSecureStore();
    await secure.write(StorageKeys.authSession, 'broken');
    final prefs = await prefsWith({});

    final auth = await AuthProvider.create(prefs, secure: secure);

    expect(auth.isLogged, isFalse);
  });

  test('旧版 prefs authSession 为畸形 JSON 时删除坏键并按未登录启动', () async {
    final prefs = await prefsWith({
      StorageKeys.authSession: '{broken-legacy-session',
      StorageKeys.token: 'stale-token',
      StorageKeys.user: jsonEncode({'id': 9, 'username': 'stale-user'}),
    });
    final secure = InMemorySecureValueStore();

    final auth = await AuthProvider.create(prefs, secure: secure);

    expect(auth.isLogged, isFalse);
    expect(secure[StorageKeys.authSession], isNull);
    expect(prefs.getString(StorageKeys.authSession), isNull);
    expect(prefs.getString(StorageKeys.token), isNull);
    expect(prefs.getString(StorageKeys.user), isNull);
  });

  test('旧版 prefs authSession 为合法 JSON 但非对象时删除坏键', () async {
    final prefs = await prefsWith({
      StorageKeys.authSession: jsonEncode('plain-string'),
    });
    final secure = InMemorySecureValueStore();

    final auth = await AuthProvider.create(prefs, secure: secure);

    expect(auth.isLogged, isFalse);
    expect(prefs.getString(StorageKeys.authSession), isNull);
  });

  test('旧版 prefs user 为畸形 JSON 时删除双键并按未登录启动', () async {
    final prefs = await prefsWith({
      StorageKeys.token: 'legacy-token',
      StorageKeys.user: '{broken-user',
    });
    final secure = InMemorySecureValueStore();

    final auth = await AuthProvider.create(prefs, secure: secure);

    expect(auth.isLogged, isFalse);
    expect(auth.token, isNull);
    expect(auth.user, isNull);
    expect(prefs.getString(StorageKeys.token), isNull);
    expect(prefs.getString(StorageKeys.user), isNull);
    expect(secure[StorageKeys.authSession], isNull);
  });

  test('旧版 prefs user 为合法 JSON 但非对象时删除双键', () async {
    final prefs = await prefsWith({
      StorageKeys.token: 'legacy-token',
      StorageKeys.user: jsonEncode([1, 2]),
    });
    final secure = InMemorySecureValueStore();

    final auth = await AuthProvider.create(prefs, secure: secure);

    expect(auth.isLogged, isFalse);
    expect(prefs.getString(StorageKeys.token), isNull);
    expect(prefs.getString(StorageKeys.user), isNull);
  });

  test('畸形 secure 会话不会回退到旧版明文会话', () async {
    final secure = InMemorySecureValueStore();
    await secure.write(StorageKeys.authSession, 'broken');
    final prefs = await prefsWith({
      StorageKeys.authSession: jsonEncode({
        'token': 'legacy-token',
        'user': {'id': 1, 'username': 'legacy-user'},
      }),
    });

    final auth = await AuthProvider.create(prefs, secure: secure);

    expect(auth.isLogged, isFalse);
    expect(prefs.getString(StorageKeys.authSession), isNull);
  });

  test('正常 secure 会话与 tombstone 行为不受容错改动影响', () async {
    final secure = InMemorySecureValueStore();
    await secure.write(
      StorageKeys.authSession,
      jsonEncode({
        'token': 'valid-token',
        'user': {'id': 1, 'username': 'valid-user'},
      }),
    );
    final prefs = await prefsWith({});

    final restored = await AuthProvider.create(prefs, secure: secure);

    expect(restored.token, 'valid-token');
    expect(restored.user, {'id': 1, 'username': 'valid-user'});
    expect(restored.isLogged, isTrue);

    final tombstoneSecure = InMemorySecureValueStore();
    await tombstoneSecure.write(
      StorageKeys.authSession,
      jsonEncode({'token': null, 'user': null}),
    );
    final tombstone = await AuthProvider.create(
      await prefsWith({}),
      secure: tombstoneSecure,
    );
    expect(tombstone.isLogged, isFalse);
    expect(tombstoneSecure[StorageKeys.authSession], isNotNull);
  });
}
