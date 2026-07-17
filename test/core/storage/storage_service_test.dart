import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jade/core/storage/storage_keys.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('StorageService 读写 baseUrl 并持久化', () async {
    final svc = await StorageService.create();
    expect(svc.getString(StorageKeys.baseUrl), isNull);
    await svc.setString(StorageKeys.baseUrl, 'https://staging.letidi.com');
    expect(svc.getString(StorageKeys.baseUrl), 'https://staging.letidi.com');
    // 重新实例化验证持久化
    final svc2 = await StorageService.create();
    expect(svc2.getString(StorageKeys.baseUrl), 'https://staging.letidi.com');
  });
}
