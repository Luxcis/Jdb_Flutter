### Task 11: Providers（Auth/Startup/Settings）

**Files:**
- Create: `lib/core/providers/auth_provider.dart`
- Create: `lib/core/providers/startup_provider.dart`
- Create: `lib/core/providers/settings_provider.dart`
- Test: `test/core/providers/auth_provider_test.dart`

**Interfaces:**
- `AuthProvider(ChangeNotifier, TokenProvider)`：`token`、`user`(简单 Map)、`login(token,user)`、`logout()`、持久化。
- `StartupProvider`：持有 `ApiClient` 与 `DomainManager`，`fetchStartup()` 调 `/startup` 并 `applyStartup`。
- `SettingsProvider`：默认筛选标签读写。

- [ ] **Step 1: 写失败测试**

```dart
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
```

- [ ] **Step 2: 运行确认失败**

Run: `flutter test test/core/providers/auth_provider_test.dart`
Expected: FAIL。

- [ ] **Step 3: 实现 auth_provider**

```dart
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

  String? get token => _token;
  Map<String, dynamic>? get user => _user;
  bool get isLogged => _token != null && _token!.isNotEmpty;

  static Future<AuthProvider> create(SharedPreferences prefs) async {
    final p = AuthProvider._(prefs);
    p._token = prefs.getString(StorageKeys.token);
    final u = prefs.getString(StorageKeys.user);
    p._user = u != null ? jsonDecode(u) as Map<String, dynamic> : null;
    return p;
  }

  Future<void> login({required String token, required Map<String, dynamic> user}) async {
    _token = token;
    _user = user;
    await _prefs.setString(StorageKeys.token, token);
    await _prefs.setString(StorageKeys.user, jsonEncode(user));
    notifyListeners();
  }

  Future<void> logout() async {
    _token = null;
    _user = null;
    await _prefs.remove(StorageKeys.token);
    await _prefs.remove(StorageKeys.user);
    notifyListeners();
  }
}
```

- [ ] **Step 4: 实现 startup_provider**

```dart
// lib/core/providers/startup_provider.dart
import 'package:flutter/foundation.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/domain_manager.dart';
import 'package:jade/core/network/endpoints.dart';

class StartupProvider extends ChangeNotifier {
  StartupProvider._(this._api, this._dm);
  final ApiClient _api;
  final DomainManager _dm;
  bool _loaded = false;
  bool get loaded => _loaded;

  static StartupProvider create(ApiClient api, DomainManager dm) =>
      StartupProvider._(api, dm);

  /// 调 /startup 拉取并应用域名列表。
  Future<void> fetchStartup() async {
    try {
      final resp = await _api.get(Endpoints.startup, queryParameters: {
        'platform': 'android',
        'app_channel': 'google',
        'app_version': '1.9.29',
        'app_version_number': '35',
      });
      final data = (resp.data as Map?)?['backup_domains_data'] as String?;
      // Phase 0：backup_domains_data 解密暂以纯 Base64 尝试；失败回退主域名。
      final domains = _tryDecodeDomains(data);
      await _dm.applyStartup(domains);
      _loaded = true;
      notifyListeners();
    } catch (_) {
      // 失败保留当前域名，不阻断启动。
    }
  }

  BackupDomainsData _tryDecodeDomains(String? data) {
    // 简化：返回仅含主域名的兜底列表；完整解密在后续阶段。
    return const BackupDomainsData(apiDomains: ['https://jdforrepam.com']);
  }
}
```

- [ ] **Step 5: 实现 settings_provider**

```dart
// lib/core/providers/settings_provider.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jade/core/storage/storage_keys.dart';

class SettingsProvider extends ChangeNotifier {
  SettingsProvider._(this._prefs);
  final SharedPreferences _prefs;
  List<String> _defaultFilterTags = const [];

  List<String> get defaultFilterTags => List.unmodifiable(_defaultFilterTags);

  static Future<SettingsProvider> create(SharedPreferences prefs) async {
    final p = SettingsProvider._(prefs);
    final raw = prefs.getString(StorageKeys.defaultFilterTags);
    if (raw != null) {
      p._defaultFilterTags = List<String>.from(jsonDecode(raw) as List);
    }
    return p;
  }

  Future<void> setDefaultFilterTags(List<String> tags) async {
    _defaultFilterTags = tags;
    await _prefs.setString(StorageKeys.defaultFilterTags, jsonEncode(tags));
    notifyListeners();
  }
}
```

- [ ] **Step 6: 运行测试通过**

Run: `flutter test test/core/providers/auth_provider_test.dart`
Expected: PASS（2 个用例）。

- [ ] **Step 7: Commit**

```bash
git add lib/core/providers/auth_provider.dart lib/core/providers/startup_provider.dart lib/core/providers/settings_provider.dart test/core/providers/auth_provider_test.dart
git commit -m "feat(core/providers): add AuthProvider/StartupProvider/SettingsProvider"
```

---

