### Task 2: AppConstants + StorageKeys/StorageService

**Files:**
- Create: `lib/core/constants/app_constants.dart`
- Create: `lib/core/storage/storage_keys.dart`
- Test: `test/core/storage/storage_service_test.dart`

**Interfaces:**
- Produces: `StorageService.getString(key)/setString(key,val)/remove(key)`、`StorageKeys.*` 常量、`AppConstants.*`。

- [ ] **Step 1: 写失败测试**

```dart
// test/core/storage/storage_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jade/core/storage/storage_keys.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('StorageService 读写 baseUrl 并持久化', () async {
    final svc = await StorageService.create();
    expect(svc.getString(StorageKeys.baseUrl), isNull);
    await svc.setString(StorageKeys.baseUrl, 'https://jdforrepam.com');
    expect(svc.getString(StorageKeys.baseUrl), 'https://jdforrepam.com');
    // 重新实例化验证持久化
    final svc2 = await StorageService.create();
    expect(svc2.getString(StorageKeys.baseUrl), 'https://jdforrepam.com');
  });
}
```

- [ ] **Step 2: 运行确认失败**

Run: `flutter test test/core/storage/storage_service_test.dart`
Expected: FAIL（`StorageService` 未定义）。

- [ ] **Step 3: 实现 constants**

```dart
// lib/core/constants/app_constants.dart
class AppConstants {
  const AppConstants._();
  static const String platform = 'android';
  static const String appChannel = 'google';
  static const String appVersion = '1.9.29';
  static const String appVersionNumber = '35';
  static const String defaultBaseUrl = 'https://jdforrepam.com';
  static const String mainDomain = 'https://jdforrepam.com';
  static const String imageCdnBase = 'https://tp.spfcas.com/rhe951l4q/';
  static const int domainFailureThreshold = 3;
}
```

- [ ] **Step 4: 实现 storage**

```dart
// lib/core/storage/storage_keys.dart
import 'package:shared_preferences/shared_preferences.dart';

class StorageKeys {
  const StorageKeys._();
  static const String baseUrl = 'key_baseurl';
  static const String apiDomains = 'key_api_domains';
  static const String token = 'key_token';
  static const String user = 'key_user';
  static const String themeMode = 'key_theme_mode';
  static const String defaultFilterTags = 'key_default_filter_tags';
  static const String searchHistory = 'key_search_history';
  static const String line = 'key_line';
}

class StorageService {
  StorageService._(this._prefs);
  final SharedPreferences _prefs;

  static Future<StorageService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return StorageService._(prefs);
  }

  String? getString(String key) => _prefs.getString(key);
  Future<bool> setString(String key, String value) => _prefs.setString(key, value);
  Future<bool> remove(String key) => _prefs.remove(key);
}
```

- [ ] **Step 5: 运行测试通过**

Run: `flutter test test/core/storage/storage_service_test.dart`
Expected: PASS。

- [ ] **Step 6: Commit**

```bash
git add lib/core/constants/app_constants.dart lib/core/storage/storage_keys.dart test/core/storage/storage_service_test.dart
git commit -m "feat(core): add AppConstants and StorageService with persistence"
```

---

