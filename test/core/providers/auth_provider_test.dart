// test/core/providers/auth_provider_test.dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jade/core/providers/auth_provider.dart';
import 'package:jade/core/storage/storage_keys.dart';

const _authSessionKey = 'key_auth_session';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('login 以单键持久化完整会话并可在重启后恢复', () async {
    final user = {
      'id': 1,
      'username': 'session-user',
      'roles': ['member', 'reviewer'],
    };
    final prefs = _ControlledSharedPreferences();
    final auth = await AuthProvider.create(prefs);

    await auth.login(token: 'session-token', user: user);

    expect(auth.token, 'session-token');
    expect(auth.user, user);
    expect(auth.isLogged, isTrue);
    expect(prefs.setStringKeys, [_authSessionKey]);
    final storedSession = prefs.getString(_authSessionKey);
    expect(storedSession, isNotNull);
    expect(jsonDecode(storedSession!), {
      'token': 'session-token',
      'user': user,
    });

    final restored = await AuthProvider.create(prefs);
    expect(restored.token, 'session-token');
    expect(restored.user, user);
    expect(restored.isLogged, isTrue);
  });

  test('login 权威会话写入返回 false 时保留旧内存与持久化会话', () async {
    final oldUser = {'id': 1, 'username': 'old-user'};
    final oldSession = jsonEncode({'token': 'old-token', 'user': oldUser});
    final prefs = _ControlledSharedPreferences(
      initialValues: {_authSessionKey: oldSession},
      failSessionWrite: true,
    );
    final auth = await AuthProvider.create(prefs);

    await expectLater(
      () => auth.login(
        token: 'replacement-token',
        user: {'id': 2, 'username': 'replacement-user'},
      ),
      throwsA(isA<StateError>()),
    );

    expect(auth.token, 'old-token');
    expect(auth.user, oldUser);
    expect(prefs.getString(_authSessionKey), oldSession);
  });

  test('login 权威会话写入抛异常时保留旧会话并传播原始异常与堆栈', () async {
    final oldUser = {'id': 1, 'username': 'old-user'};
    const replacementUser = {'id': 2, 'username': 'replacement-user'};
    const originalError = _SessionWriteException('session write failed');
    final originalStackTrace = StackTrace.fromString('session-write-stack');
    final oldSession = jsonEncode({'token': 'old-token', 'user': oldUser});
    final prefs = _ControlledSharedPreferences(
      initialValues: {_authSessionKey: oldSession},
      sessionWriteError: originalError,
      sessionWriteStackTrace: originalStackTrace,
    );
    final auth = await AuthProvider.create(prefs);

    try {
      await auth.login(token: 'replacement-token', user: replacementUser);
      fail('login 应抛出权威会话写入的原始异常');
    } catch (error, stackTrace) {
      expect(error, same(originalError));
      expect(stackTrace.toString(), originalStackTrace.toString());
    }

    expect(auth.token, 'old-token');
    expect(auth.user, oldUser);
    expect(prefs.getString(_authSessionKey), oldSession);
  });

  test('权威会话键缺失时兼容恢复 legacy Token 与 User', () async {
    final legacyUser = {'id': 7, 'username': 'legacy-user'};
    SharedPreferences.setMockInitialValues({
      StorageKeys.token: 'legacy-token',
      StorageKeys.user: jsonEncode(legacyUser),
    });
    final prefs = await SharedPreferences.getInstance();

    final auth = await AuthProvider.create(prefs);

    expect(auth.token, 'legacy-token');
    expect(auth.user, legacyUser);
    expect(auth.isLogged, isTrue);
  });

  test('权威 tombstone 存在时不回退到陈旧 legacy 会话', () async {
    SharedPreferences.setMockInitialValues({
      _authSessionKey: jsonEncode({'token': null, 'user': null}),
      StorageKeys.token: 'stale-legacy-token',
      StorageKeys.user: jsonEncode({'id': 8, 'username': 'stale-user'}),
    });
    final prefs = await SharedPreferences.getInstance();

    final auth = await AuthProvider.create(prefs);

    expect(auth.token, isNull);
    expect(auth.user, isNull);
    expect(auth.isLogged, isFalse);
  });

  test('logout 写入权威 tombstone 并在重启后保持登出', () async {
    SharedPreferences.setMockInitialValues({
      StorageKeys.token: 'stale-legacy-token',
      StorageKeys.user: jsonEncode({'id': 9, 'username': 'stale-user'}),
    });
    final prefs = await SharedPreferences.getInstance();
    final auth = await AuthProvider.create(prefs);
    await auth.login(
      token: 'active-token',
      user: {'id': 10, 'username': 'active-user'},
    );

    await auth.logout();

    expect(auth.token, isNull);
    expect(auth.user, isNull);
    expect(auth.isLogged, isFalse);
    final tombstone = prefs.getString(_authSessionKey);
    expect(tombstone, isNotNull);
    expect(jsonDecode(tombstone!), {'token': null, 'user': null});
    expect(prefs.getString(StorageKeys.token), isNull);
    expect(prefs.getString(StorageKeys.user), isNull);

    final restored = await AuthProvider.create(prefs);
    expect(restored.token, isNull);
    expect(restored.user, isNull);
    expect(restored.isLogged, isFalse);
  });
}

final class _ControlledSharedPreferences implements SharedPreferences {
  _ControlledSharedPreferences({
    Map<String, String> initialValues = const {},
    this.failSessionWrite = false,
    this.sessionWriteError,
    this.sessionWriteStackTrace,
  }) : _values = Map.of(initialValues),
       _persistedValues = Map.of(initialValues);

  final Map<String, String> _values;
  final Map<String, String> _persistedValues;
  final bool failSessionWrite;
  final Object? sessionWriteError;
  final StackTrace? sessionWriteStackTrace;
  final setStringKeys = <String>[];

  @override
  bool containsKey(String key) => _values.containsKey(key);

  @override
  String? getString(String key) => _values[key];

  @override
  Future<bool> setString(String key, String value) async {
    setStringKeys.add(key);
    _values[key] = value;
    if (key == _authSessionKey) {
      if (sessionWriteError case final error?) {
        Error.throwWithStackTrace(
          error,
          sessionWriteStackTrace ?? StackTrace.current,
        );
      }
      if (failSessionWrite) return false;
    }
    _persistedValues[key] = value;
    return true;
  }

  @override
  Future<bool> remove(String key) async {
    _values.remove(key);
    _persistedValues.remove(key);
    return true;
  }

  @override
  Future<void> reload() async {
    _values
      ..clear()
      ..addAll(_persistedValues);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _SessionWriteException implements Exception {
  const _SessionWriteException(this.message);

  final String message;

  @override
  String toString() => 'Session write failed: $message';
}
