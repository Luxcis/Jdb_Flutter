// test/core/providers/auth_provider_test.dart
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
}
