### Task 5: DomainManager 域名状态机

**Files:**
- Create: `lib/core/network/domain_manager.dart`
- Test: `test/core/network/domain_manager_test.dart`

**Interfaces:**
- Produces: `DomainManager(ChangeNotifier)`：
  - `String currentUrl`、`List<String> apiDomains`、`bool isOnMainDomain`
  - `static Future<DomainManager> load(StorageService)`：从 SP 恢复，缺省 `AppConstants.defaultBaseUrl`
  - `Future<void> applyStartup(BackupDomains)`：写入新域名列表
  - `Future<bool> rotate()`：轮转到下一个域名，持久化，返回是否成功
  - `String toJson()`/`fromJson` 持久化
- Consumes: `StorageService`、`StorageKeys`、`AppConstants`。

> 注：`BackupDomains` 模型本应在数据模型阶段实现；Phase 0 先用一个最小结构体 `BackupDomainsData`（apiDomains 字段）。完整模型在后续阶段补 json_serializable。

- [ ] **Step 1: 写失败测试**

```dart
// test/core/network/domain_manager_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jade/core/storage/storage_keys.dart';
import 'package:jade/core/network/domain_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('load 缺省返回 staging 域名', () async {
    final prefs = await SharedPreferences.getInstance();
    final dm = await DomainManager.load(prefs);
    expect(dm.currentUrl, 'https://jdforrepam.com');
    expect(dm.apiDomains, isEmpty);
  });

  test('load 从 SP 恢复已存域名', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(StorageKeys.baseUrl, 'https://jdforrepam.com');
    await prefs.setStringList(StorageKeys.apiDomains,
        ['https://jdforrepam.com', 'https://backup1.com']);
    final dm = await DomainManager.load(prefs);
    expect(dm.currentUrl, 'https://jdforrepam.com');
    expect(dm.apiDomains.length, 2);
  });

  test('applyStartup 写入并持久化主域名', () async {
    final prefs = await SharedPreferences.getInstance();
    final dm = await DomainManager.load(prefs);
    await dm.applyStartup(BackupDomainsData(
      apiDomains: ['https://jdforrepam.com', 'https://backup1.com'],
    ));
    expect(dm.currentUrl, 'https://jdforrepam.com');
    expect(dm.isOnMainDomain, isTrue);
    expect(prefs.getString(StorageKeys.baseUrl), 'https://jdforrepam.com');
  });

  test('rotate 顺序轮转并回到首个', () async {
    final prefs = await SharedPreferences.getInstance();
    final dm = await DomainManager.load(prefs);
    await dm.applyStartup(BackupDomainsData(
      apiDomains: ['https://jdforrepam.com', 'https://b.com', 'https://c.com'],
    ));
    expect(dm.currentUrl, 'https://jdforrepam.com');
    await dm.rotate();
    expect(dm.currentUrl, 'https://b.com');
    await dm.rotate();
    expect(dm.currentUrl, 'https://c.com');
    await dm.rotate();
    expect(dm.currentUrl, 'https://jdforrepam.com');
  });

  test('rotate 无备用域名返回 false', () async {
    final prefs = await SharedPreferences.getInstance();
    final dm = await DomainManager.load(prefs);
    expect(await dm.rotate(), isFalse);
  });

  test('离开主域名时 isOnMainDomain 为 false', () async {
    final prefs = await SharedPreferences.getInstance();
    final dm = await DomainManager.load(prefs);
    await dm.applyStartup(BackupDomainsData(
      apiDomains: ['https://jdforrepam.com', 'https://b.com'],
    ));
    await dm.rotate();
    expect(dm.isOnMainDomain, isFalse);
  });
}
```

- [ ] **Step 2: 运行确认失败**

Run: `flutter test test/core/network/domain_manager_test.dart`
Expected: FAIL。

- [ ] **Step 3: 实现**

```dart
// lib/core/network/domain_manager.dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jade/core/constants/app_constants.dart';
import 'package:jade/core/storage/storage_keys.dart';

/// 最小域名数据结构（Phase 0 用；后续阶段替换为完整 json_serializable 模型）。
class BackupDomainsData {
  const BackupDomainsData({required this.apiDomains});
  final List<String> apiDomains;
}

/// 域名动态切换状态机。参见 spec §3.3。
class DomainManager extends ChangeNotifier {
  DomainManager._({required this._prefs}) {
    _currentUrl = AppConstants.defaultBaseUrl;
    _apiDomains = const [];
  }

  final SharedPreferences _prefs;

  late String _currentUrl;
  List<String> _apiDomains = const [];
  int _index = 0;

  String get currentUrl => _currentUrl;
  List<String> get apiDomains => List.unmodifiable(_apiDomains);
  bool get isOnMainDomain => _currentUrl == AppConstants.mainDomain;

  /// 启动加载：SP 有则恢复，否则默认 staging。
  static Future<DomainManager> load(SharedPreferences prefs) async {
    final dm = DomainManager._(prefs: prefs);
    final stored = prefs.getStringList(StorageKeys.apiDomains);
    final url = prefs.getString(StorageKeys.baseUrl);
    if (stored != null && stored.isNotEmpty) {
      dm._apiDomains = List<String>.from(stored);
      dm._index = 0;
      dm._currentUrl = url ?? stored.first;
    } else {
      dm._currentUrl = url ?? AppConstants.defaultBaseUrl;
    }
    return dm;
  }

  /// 写入 startup 接口返回的域名列表，主域名落首位并持久化。
  Future<void> applyStartup(BackupDomainsData data) async {
    _apiDomains = List<String>.from(data.apiDomains);
    _index = 0;
    _currentUrl = _apiDomains.isNotEmpty ? _apiDomains.first : _currentUrl;
    await _persist();
    notifyListeners();
  }

  /// 轮转到下一个备用域名。返回 false 表示无可用备用域名。
  Future<bool> rotate() async {
    if (_apiDomains.length <= 1) return false;
    _index = (_index + 1) % _apiDomains.length;
    _currentUrl = _apiDomains[_index];
    await _persist();
    notifyListeners();
    return true;
  }

  Future<void> _persist() async {
    await _prefs.setString(StorageKeys.baseUrl, _currentUrl);
    await _prefs.setStringList(StorageKeys.apiDomains, _apiDomains);
  }
}
```

- [ ] **Step 4: 运行测试通过**

Run: `flutter test test/core/network/domain_manager_test.dart`
Expected: PASS（6 个用例）。

- [ ] **Step 5: Commit**

```bash
git add lib/core/network/domain_manager.dart test/core/network/domain_manager_test.dart
git commit -m "feat(core/network): add DomainManager state machine with persistence"
```

---

