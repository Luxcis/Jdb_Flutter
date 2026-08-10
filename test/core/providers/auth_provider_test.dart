// test/core/providers/auth_provider_test.dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jade/core/providers/auth_provider.dart';
import 'package:jade/core/storage/storage_keys.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('login 持久化 token 与 user，isLogged 为 true', () async {
    final prefs = await SharedPreferences.getInstance();
    final auth = await AuthProvider.create(prefs);
    await auth.login(token: 'tok', user: {'id': 1, 'username': 'a'});
    expect(auth.token, 'tok');
    expect(auth.isLogged, isTrue);
    expect(prefs.getString(StorageKeys.token), 'tok');
    // 重启恢复
    final auth2 = await AuthProvider.create(prefs);
    expect(auth2.token, 'tok');
    expect(auth2.isLogged, isTrue);
  });

  test('logout 清空 token/user', () async {
    final prefs = await SharedPreferences.getInstance();
    final auth = await AuthProvider.create(prefs);
    await auth.login(token: 'tok', user: {'id': 1});
    await auth.logout();
    expect(auth.token, isNull);
    expect(auth.isLogged, isFalse);
    expect(prefs.getString(StorageKeys.token), isNull);
  });

  test('login 缓存失败时保留旧内存会话并回滚缓存', () async {
    final oldUser = {'id': 1, 'username': 'old-user'};
    final prefs = _FailingSharedPreferences(
      initialValues: {
        StorageKeys.token: 'old-token',
        StorageKeys.user: jsonEncode(oldUser),
      },
      failKey: StorageKeys.token,
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
    expect(prefs.getString(StorageKeys.token), 'old-token');
    expect(jsonDecode(prefs.getString(StorageKeys.user)!), oldUser);
  });
}

final class _FailingSharedPreferences implements SharedPreferences {
  _FailingSharedPreferences({
    required Map<String, String> initialValues,
    required this.failKey,
  }) : _values = Map.of(initialValues);

  final Map<String, String> _values;
  final String failKey;

  @override
  String? getString(String key) => _values[key];

  @override
  Future<bool> setString(String key, String value) async {
    if (key == failKey) return false;
    _values[key] = value;
    return true;
  }

  @override
  Future<bool> remove(String key) async {
    _values.remove(key);
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
