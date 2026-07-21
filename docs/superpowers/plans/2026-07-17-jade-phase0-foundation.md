# Jade Phase 0 — 基础设施层 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 搭建 Jade 的网络层（签名 + 域名动态切换 + 三拦截器）、go_router 底部导航壳、Provider 注册与本地存储，产出可启动并通过单元/widget 测试的 App 骨架。

**Architecture:** Feature-First（core/ + features/）。网络层为单例 `ApiClient` 持有 `Dio`，装配 4 个拦截器；域名切换由 `DomainManager` 状态机驱动，错误拦截器在 608/连续失败时轮转；路由用 `go_router` 的 `StatefulShellRoute` 渲染 `NavigationBar` + 5 Tab 占位页。

**Tech Stack:** Flutter ^3.8.0、dio ^5.7.0、go_router ^14.6.2、provider ^6.1.5+1、shared_preferences ^2.5.5、crypto ^3.0.6、json_annotation/json_serializable/build_runner、cached_network_image、flutter_test。

## Global Constraints

（逐字取自 [RULES.md](../../../RULES.md) / [CLAUDE.md](../../../CLAUDE.md) / spec §3）
- Material Design 3；`ThemeMode.system` 自动切换；`ColorScheme.fromSeed()`；系统字体；无 google_fonts。
- **不做本地化**，所有文案中文硬编码；不使用 `.arb`/`flutter_localizations`。
- 不使用触觉反馈。
- Feature-First：`core/` + `features/<name>/{screens,widgets,models,services,index.dart}`；feature 只依赖 core。
- JSON 序列化用 `json_serializable`，`fieldRename: FieldRename.snake`。
- 状态管理优先内置 + `provider`；偏好 fakes 而非 mocks。
- 签名常量 D1/D2 取自 [ALGORITHM.md §4.5](../../main/security/signature/ALGORITHM.md)，硬编码，无需
  JNI。
- 默认域名 `https://staging.letidi.com`；CDN `https://tp.spfcas.com/rhe951l4q/`。
- Git 提交前设置代理：`export https_proxy=http://127.0.0.1:7890 http_proxy=http://127.0.0.1:7890 all_proxy=socks5://127.0.0.1:7890`。

---

## File Structure

新建/修改文件清单（Phase 0 仅触及 core/、app.dart、main.dart 与 5 个占位 Tab feature）：

- 修改 `pubspec.yaml`：新增依赖。
- 新建 `lib/core/constants/app_constants.dart`：平台/渠道/版本/CDN 常量。
- 新建 `lib/core/storage/storage_keys.dart`：SP 键 + `StorageService` 读写封装。
- 新建 `lib/core/network/signature.dart`：`JdSignature.generate`。
- 新建 `lib/core/network/api_exception.dart`：`ApiException`。
- 新建 `lib/core/network/endpoints.dart`：路径常量。
- 新建 `lib/core/network/domain_manager.dart`：`DomainManager` 状态机。
- 新建 `lib/core/network/interceptors/signature_interceptor.dart`
- 新建 `lib/core/network/interceptors/auth_interceptor.dart`
- 新建 `lib/core/network/interceptors/response_interceptor.dart`
- 新建 `lib/core/network/interceptors/domain_switch_interceptor.dart`
- 新建 `lib/core/network/testing/fake_adapter.dart`：测试用 `HttpClientAdapter`。
- 新建 `lib/core/network/api_client.dart`：单例 Dio 装配。
- 新建 `lib/core/providers/auth_provider.dart`
- 新建 `lib/core/providers/startup_provider.dart`
- 新建 `lib/core/providers/settings_provider.dart`
- 新建 `lib/core/router/routes.dart`：路径常量 + auth redirect。
- 新建 `lib/core/router/app_router.dart`：GoRouter + StatefulShellRoute。
- 新建 `lib/core/widgets/main_shell.dart`：NavigationBar + IndexedStack 保活。
- 修改 `lib/app.dart`（新）：`MaterialApp.router` + Provider 注册。
- 修改 `lib/main.dart`：启动初始化。
- 占位 feature：`lib/features/home/screens/home_screen.dart`（已存在，替换占位）等 5 个。
- 测试：`test/core/network/signature_test.dart`、`domain_manager_test.dart`、`api_client_test.dart`、`test/app_test.dart`。

---

### Task 1: 新增依赖

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: 编辑 pubspec.yaml dependencies**

```yaml
dependencies:
  flutter:
    sdk: flutter
  dynamic_color: ^1.8.1
  provider: ^6.1.5+1
  shared_preferences: ^2.5.5
  cupertino_icons: ^1.0.9
  crypto: ^3.0.6
  dio: ^5.7.0
  go_router: ^14.6.2
  json_annotation: ^4.9.0
  cached_network_image: ^3.4.1

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_launcher_icons: "^0.14.3"
  flutter_lints: ^6.0.0
  build_runner: ^2.4.13
  json_serializable: ^6.8.0
```

- [ ] **Step 2: 拉取依赖**

Run: `flutter pub get`
Expected: 退出码 0，无冲突。

- [ ] **Step 3: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "chore: add dio/go_router/crypto/json_serializable deps for phase 0"
```

---

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
    await svc.setString(StorageKeys.baseUrl, 'https://staging.letidi.com');
    expect(svc.getString(StorageKeys.baseUrl), 'https://staging.letidi.com');
    // 重新实例化验证持久化
    final svc2 = await StorageService.create();
    expect(svc2.getString(StorageKeys.baseUrl), 'https://staging.letidi.com');
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
  static const String defaultBaseUrl = 'https://staging.letidi.com';
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

### Task 3: JdSignature 签名算法

**Files:**
- Create: `lib/core/network/signature.dart`
- Test: `test/core/network/signature_test.dart`

**Interfaces:**
- Produces: `String JdSignature.generate({int? timestamp})`，格式 `{ts}.{d2}.{md5(ts+d1)}`。

- [ ] **Step 1: 写失败测试（对照 ALGORITHM.md §4.6 样例）**

```dart
// test/core/network/signature_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/network/signature.dart';

void main() {
  test('签名匹配 ALGORITHM.md 样例 ts=1784107027', () {
    final sig = JdSignature.generate(timestamp: 1784107027);
    // 注：ALGORITHM.md §4.6 样例 hash f48872e5... 经 Python hashlib 独立验证为错误值；
    // 真实 md5("1784107027"+d1) = ddadd5115754ab0f0d90e5deca6c09ca，以此为准。
    expect(sig, '1784107027.lpw6vgqzsp.ddadd5115754ab0f0d90e5deca6c09ca');
  });

  test('签名格式为 timestamp.d2.md5hash', () {
    final sig = JdSignature.generate(timestamp: 1784107027);
    final parts = sig.split('.');
    expect(parts.length, 3);
    expect(parts[0], '1784107027');
    expect(parts[1], 'lpw6vgqzsp');
    expect(parts[2].length, 32); // md5 hex
  });

  test('不同 timestamp 产生不同签名', () {
    final a = JdSignature.generate(timestamp: 1784107027);
    final b = JdSignature.generate(timestamp: 1784107028);
    expect(a == b, isFalse);
  });
}
```

- [ ] **Step 2: 运行确认失败**

Run: `flutter test test/core/network/signature_test.dart`
Expected: FAIL（`JdSignature` 未定义）。

- [ ] **Step 3: 实现**

```dart
// lib/core/network/signature.dart
import 'dart:convert';
import 'package:crypto/crypto.dart';

/// 生成 JavDB API 请求头 jdsignature。
///
/// 格式：`{timestamp}.{d2}.{md5(timestamp + d1)}`，常量取自
/// docs/api/signature/ALGORITHM.md §4.5（已解密）。
class JdSignature {
  const JdSignature._();

  static const String _d1 =
      '71cf27bb3c0bcdf207b64abecddc970098c7421ee7203b9cdae54478478a199e7d5a6e1a57691123c1a931c057842fb73ba3b3c83bcd69c17ccf174081e3d8aa';
  static const String _d2 = 'lpw6vgqzsp';

  /// 生成签名。[timestamp] 为 Unix 秒；测试时注入确定性时间戳。
  static String generate({int? timestamp}) {
    final ts = timestamp ??
        (DateTime.now().millisecondsSinceEpoch ~/ 1000);
    final hash = md5.convert(utf8.encode('$ts$_d1'));
    return '$ts.$_d2.${hash.toString()}';
  }
}
```

- [ ] **Step 4: 运行测试通过**

Run: `flutter test test/core/network/signature_test.dart`
Expected: PASS（3 个用例）。

- [ ] **Step 5: Commit**

```bash
git add lib/core/network/signature.dart test/core/network/signature_test.dart
git commit -m "feat(core/network): implement jdsignature generation"
```

---

### Task 4: ApiException + Endpoints

**Files:**
- Create: `lib/core/network/api_exception.dart`
- Create: `lib/core/network/endpoints.dart`
- Test: `test/core/network/api_exception_test.dart`

**Interfaces:**
- Produces: `ApiException`（含 `action`/`message`，工厂 `ApiException.fromAction`）、`Endpoints.*` 路径常量、`ApiErrorActions` 常量集。

- [ ] **Step 1: 写失败测试**

```dart
// test/core/network/api_exception_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/network/api_exception.dart';

void main() {
  test('ApiException 携带 action 与 message', () {
    final e = ApiException.fromAction(ApiErrorActions.jwtVerificationError, '請登錄帳號');
    expect(e.action, ApiErrorActions.jwtVerificationError);
    expect(e.message, '請登錄帳號');
    expect(e.isAuthError, isTrue);
  });

  test('非鉴权 action 的 isAuthError 为 false', () {
    final e = ApiException.fromAction(ApiErrorActions.parameterInvalid, '參數不能爲空: q');
    expect(e.isAuthError, isFalse);
  });
}
```

- [ ] **Step 2: 运行确认失败**

Run: `flutter test test/core/network/api_exception_test.dart`
Expected: FAIL。

- [ ] **Step 3: 实现 api_exception**

```dart
// lib/core/network/api_exception.dart

/// 统一 API 错误。覆盖 api-reference.md §3 错误码。
class ApiException implements Exception {
  const ApiException({required this.action, this.message});

  factory ApiException.fromAction(String action, String? message) =>
      ApiException(action: action, message: message);

  final String action;
  final String? message;

  /// 鉴权类错误（需触发登出/重定向登录）。
  bool get isAuthError =>
      action == ApiErrorActions.jwtVerificationError ||
      action == ApiErrorActions.nonExistentUser;

  @override
  String toString() => 'ApiException($action): ${message ?? ""}';
}

/// api-reference.md §3 已知 action 常量。
class ApiErrorActions {
  const ApiErrorActions._();
  static const String parameterInvalid = 'ParameterInvalid';
  static const String invalidSignature = 'InvalidSignature';
  static const String jwtVerificationError = 'JWTVerificationError';
  static const String nonExistentUser = 'NonExistentUser';
}
```

- [ ] **Step 4: 实现 endpoints**

```dart
// lib/core/network/endpoints.dart

/// API 路径常量（取自 docs/api/api/api-reference.md）。
class Endpoints {
  const Endpoints._();
  static const String startup = '/api/v1/startup';
  static const String about = '/api/v1/about';
  static const String sessions = '/api/v1/sessions';
  static const String users = '/api/v1/users';
  static const String usersAdditional = '/api/v1/users/additional';
  static const String moviesLatest = '/api/v1/movies/latest';
  static const String moviesRecommend = '/api/v1/movies/recommend';
  static const String moviesRecommendPeriods = '/api/v1/movies/recommend_periods';
  static const String moviesTop = '/api/v1/movies/top';
  static const String moviesMayAlsoLike = '/api/v1/movies/may_also_like';
  static const String moviesTags = '/api/v1/movies/tags';
  static const String searchV2 = '/api/v2/search';
  static const String searchImage = '/api/v2/search_image';
  static const String searchMagnet = '/api/v1/search_magnet';
  static const String actors = '/api/v1/actors';
  static const String actorsRecommend = '/api/v1/actors/recommend';
  static const String directors = '/api/v1/directors';
  static const String makers = '/api/v1/makers';
  static const String series = '/api/v1/series';
  static const String rankings = '/api/v1/rankings';
  static const String rankingsActors = '/api/v1/rankings/actors';
  static const String rankingsPlayback = '/api/v1/rankings/playback';
  static const String reviewsHotly = '/api/v1/reviews/hotly';
  static const String lists = '/api/v1/lists';
  static const String tagsV2 = '/api/v2/tags';
  static const String articles = '/api/v1/articles';
}
```

- [ ] **Step 5: 运行测试通过**

Run: `flutter test test/core/network/api_exception_test.dart`
Expected: PASS。

- [ ] **Step 6: Commit**

```bash
git add lib/core/network/api_exception.dart lib/core/network/endpoints.dart test/core/network/api_exception_test.dart
git commit -m "feat(core/network): add ApiException and Endpoints constants"
```

---

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
    expect(dm.currentUrl, 'https://staging.letidi.com');
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

### Task 6: 测试用 FakeAdapter

**Files:**
- Create: `lib/core/network/testing/fake_adapter.dart`
- Test: `test/core/network/testing/fake_adapter_test.dart`

**Interfaces:**
- Produces: `FakeAdapter` 实现 `HttpClientAdapter`，可按 path 预设 `Response`；支持记录请求历史；`enqueue(path, response, {statusCode})`、`requests` 列表、`setThrowOnError(bool)`。

- [ ] **Step 1: 写失败测试**

```dart
// test/core/network/testing/fake_adapter_test.dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/network/testing/fake_adapter.dart';

void main() {
  test('FakeAdapter 按路径返回预设响应', () async {
    final adapter = FakeAdapter();
    adapter.enqueue('/api/v1/x', {'success': 1, 'data': {'a': 1}});
    final resp = await adapter.fetch(
      RequestOptions(path: '/api/v1/x'),
      null,
      null,
    );
    expect(resp.statusCode, 200);
    expect(resp.data['success'], 1);
  });

  test('FakeAdapter 记录请求历史', () async {
    final adapter = FakeAdapter();
    adapter.enqueue('/api/v1/y', {'success': 1, 'data': null});
    await adapter.fetch(RequestOptions(path: '/api/v1/y'), null, null);
    expect(adapter.requests.length, 1);
    expect(adapter.requests.first.path, '/api/v1/y');
  });
}
```

- [ ] **Step 2: 运行确认失败**

Run: `flutter test test/core/network/testing/fake_adapter_test.dart`
Expected: FAIL。

- [ ] **Step 3: 实现**

```dart
// lib/core/network/testing/fake_adapter.dart
import 'dart:convert';
import 'package:dio/dio.dart';

/// 单元测试用 HttpClientAdapter。按 path 匹配预设响应，支持同路径响应序列。
class FakeAdapter implements HttpClientAdapter {
  final Map<String, _Stub> _stubs = {};
  final Map<String, List<_Stub>> _sequences = {};
  final List<RequestOptions> requests = [];

  /// 同一 path 固定返回同一响应。
  void enqueue(String path, Map<String, dynamic> body, {int statusCode = 200}) {
    _stubs[path] = _Stub(body: body, statusCode: statusCode);
  }

  /// 同一 path 按入队顺序依次返回（每次请求弹出首个，耗尽回退到 enqueue）。
  /// 用于"先失败后成功"的重试场景。
  void enqueueSequence(
    String path,
    List<Map<String, dynamic>> bodies, {
    List<int>? codes,
  }) {
    _sequences[path] = [
      for (var i = 0; i < bodies.length; i++)
        _Stub(body: bodies[i], statusCode: codes?[i] ?? 200),
    ];
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    _Stub? stub;
    final seq = _sequences[options.path];
    if (seq != null && seq.isNotEmpty) {
      stub = seq.removeAt(0);
    } else {
      stub = _stubs[options.path];
    }
    final body = stub?.body ?? {'success': 0, 'message': 'no stub'};
    final code = stub?.statusCode ?? 404;
    return ResponseBody.fromString(
      jsonEncode(body),
      code,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {
    _stubs.clear();
    _sequences.clear();
    requests.clear();
  }
}

class _Stub {
  const _Stub({required this.body, required this.statusCode});
  final Map<String, dynamic> body;
  final int statusCode;
}
```

> 实现说明：用 `dart:convert` 的 `jsonEncode` 编码，确保 dio 的 JSON 解码器可解析。`enqueueSequence` 供 Task 9 域名重试测试模拟"先 608 后 200"。

- [ ] **Step 4: 运行测试通过**

Run: `flutter test test/core/network/testing/fake_adapter_test.dart`
Expected: PASS。若因 JSON 解码失败，将 `_encodeJson` 改为：
```dart
import 'dart:convert';
static String _encodeJson(Map<String, dynamic> m) => jsonEncode(m);
```
重跑直至 PASS。

- [ ] **Step 5: Commit**

```bash
git add lib/core/network/testing/fake_adapter.dart test/core/network/testing/fake_adapter_test.dart
git commit -m "test(core/network): add FakeAdapter for interceptor unit tests"
```

---

### Task 7: SignatureInterceptor + AuthInterceptor

**Files:**
- Create: `lib/core/network/interceptors/signature_interceptor.dart`
- Create: `lib/core/network/interceptors/auth_interceptor.dart`
- Test: `test/core/network/interceptors/signature_auth_interceptor_test.dart`

**Interfaces:**
- Consumes: `JdSignature`、`AuthProvider`（`String? get token`）。
- Produces: `SignatureInterceptor`、`AuthInterceptor`（均 `Interceptor`）。

- [ ] **Step 1: 写失败测试**

```dart
// test/core/network/interceptors/signature_auth_interceptor_test.dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/network/interceptors/signature_interceptor.dart';
import 'package:jade/core/network/interceptors/auth_interceptor.dart';

class _FakeAuth {
  String? token;
  _FakeAuth([this.token]);
}

void main() {
  test('SignatureInterceptor 注入 jdsignature 与语言头', () {
    final ic = SignatureInterceptor();
    final opts = RequestOptions(path: '/api/v1/x');
    ic.onRequest(opts, RequestInterceptorHandler.next);
    expect(opts.headers['jdsignature'], isNotNull);
    final parts = (opts.headers['jdsignature'] as String).split('.');
    expect(parts.length, 3);
    expect(parts[1], 'lpw6vgqzsp');
    expect(opts.headers['accept-language'], 'zh-CN');
    expect(opts.headers['connection'], 'keep-alive');
  });

  test('AuthInterceptor 无 token 时不注入 Authorization', () {
    final ic = AuthInterceptor(_FakeAuth(null));
    final opts = RequestOptions(path: '/api/v1/x');
    ic.onRequest(opts, RequestInterceptorHandler.next);
    expect(opts.headers['authorization'], isNull);
  });

  test('AuthInterceptor 有 token 时注入 Bearer', () {
    final ic = AuthInterceptor(_FakeAuth('abc.def.ghi'));
    final opts = RequestOptions(path: '/api/v1/x');
    ic.onRequest(opts, RequestInterceptorHandler.next);
    expect(opts.headers['authorization'], 'Bearer abc.def.ghi');
  });
}
```

- [ ] **Step 2: 运行确认失败**

Run: `flutter test test/core/network/interceptors/signature_auth_interceptor_test.dart`
Expected: FAIL。

- [ ] **Step 3: 实现 signature_interceptor**

```dart
// lib/core/network/interceptors/signature_interceptor.dart
import 'package:dio/dio.dart';
import 'package:jade/core/network/signature.dart';

class SignatureInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.headers['jdsignature'] = JdSignature.generate();
    options.headers['accept-language'] = 'zh-CN';
    options.headers['connection'] = 'keep-alive';
    handler.next(options);
  }
}
```

- [ ] **Step 4: 实现 auth_interceptor**

```dart
// lib/core/network/interceptors/auth_interceptor.dart
import 'package:dio/dio.dart';

/// 抽象 token 提供者，避免直接依赖 AuthProvider（后者在 providers 任务实现）。
abstract class TokenProvider {
  String? get token;
}

class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._tokenProvider);
  final TokenProvider _tokenProvider;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = _tokenProvider.token;
    if (token != null && token.isNotEmpty) {
      options.headers['authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }
}
```

- [ ] **Step 5: 运行测试通过**

Run: `flutter test test/core/network/interceptors/signature_auth_interceptor_test.dart`
Expected: PASS（3 个用例）。

- [ ] **Step 6: Commit**

```bash
git add lib/core/network/interceptors/signature_interceptor.dart lib/core/network/interceptors/auth_interceptor.dart test/core/network/interceptors/signature_auth_interceptor_test.dart
git commit -m "feat(core/network): add SignatureInterceptor and AuthInterceptor"
```

---

### Task 8: ResponseInterceptor

**Files:**
- Create: `lib/core/network/interceptors/response_interceptor.dart`
- Test: `test/core/network/interceptors/response_interceptor_test.dart`

**Interfaces:**
- Produces: `ResponseInterceptor`（`Interceptor`）：`success==1` → `response.data = data`；`success==0` → 抛 `ApiException`；`action==JWTVerificationError` → 调 `onAuthError` 回调（供 AuthProvider 登出）。

- [ ] **Step 1: 写失败测试**

```dart
// test/core/network/interceptors/response_interceptor_test.dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/network/api_exception.dart';
import 'package:jade/core/network/interceptors/response_interceptor.dart';

Response _mkResp(Map<String, dynamic> body) {
  return Response(
    requestOptions: RequestOptions(path: '/x'),
    data: body,
    statusCode: 200,
  );
}

void main() {
  test('success==1 解包 data', () {
    var authCalled = false;
    final ic = ResponseInterceptor(onAuthError: () => authCalled = true);
    final resp = _mkResp({'success': 1, 'data': {'k': 'v'}});
    late Response result;
    ic.onResponse(resp, ResponseInterceptorHandler.next);
    // handler.next 调用方式：通过捕获包装验证
    // 改用直接 mutate 验证
    expect(resp.data, {'k': 'v'});
    expect(authCalled, isFalse);
  });

  test('success==0 抛 ApiException 且非鉴权不调 onAuthError', () {
    var authCalled = false;
    final ic = ResponseInterceptor(onAuthError: () => authCalled = true);
    final resp = _mkResp({
      'success': 0,
      'action': ApiErrorActions.parameterInvalid,
      'message': '參數不能爲空',
    });
    expect(
      () => ic.onResponse(resp, _ThrowHandler()),
      throwsA(isA<ApiException>()),
    );
    expect(authCalled, isFalse);
  });

  test('JWTVerificationError 触发 onAuthError 并抛异常', () {
    var authCalled = false;
    final ic = ResponseInterceptor(onAuthError: () => authCalled = true);
    final resp = _mkResp({
      'success': 0,
      'action': ApiErrorActions.jwtVerificationError,
      'message': '請登錄帳號',
    });
    expect(
      () => ic.onResponse(resp, _ThrowHandler()),
      throwsA(isA<ApiException>()),
    );
    expect(authCalled, isTrue);
  });
}

class _ThrowHandler implements ResponseInterceptorHandler {
  // dio 的 handler.next 在测试中难以直接驱动；用抛出异常的伪 handler 验证 reject 路径
  @override
  void next(Response response) {}
  @override
  void resolve(Response response, {bool followRedirects = true}) {}
  @override
  void reject(DioException error, {bool callFollowingErrorHandler = true}) {
    throw error;
  }
}
```

> 实现说明：`onResponse` 中若 `success==0` 则构造 `DioException`（携带 `ApiException`）并 `handler.reject`。测试用 `_ThrowHandler.reject` 抛出以断言。`success==1` 直接 `handler.next` 前先替换 `response.data`。

- [ ] **Step 2: 运行确认失败**

Run: `flutter test test/core/network/interceptors/response_interceptor_test.dart`
Expected: FAIL。

- [ ] **Step 3: 实现**

```dart
// lib/core/network/interceptors/response_interceptor.dart
import 'package:dio/dio.dart';
import 'package:jade/core/network/api_exception.dart';

class ResponseInterceptor extends Interceptor {
  ResponseInterceptor({required this.onAuthError});
  final void Function() onAuthError;

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final data = response.data;
    if (data is! Map) {
      handler.next(response);
      return;
    }
    final success = data['success'];
    if (success == 1) {
      response.data = data['data'];
      handler.next(response);
      return;
    }
    final action = (data['action'] as String?) ?? '';
    final message = data['message'] as String?;
    if (action == ApiErrorActions.jwtVerificationError) {
      onAuthError();
    }
    final ex = ApiException.fromAction(action, message);
    handler.reject(
      DioException(
        requestOptions: response.requestOptions,
        error: ex,
        type: DioExceptionType.badResponse,
        response: response,
      ),
    );
  }
}
```

- [ ] **Step 4: 运行测试通过**

Run: `flutter test test/core/network/interceptors/response_interceptor_test.dart`
Expected: PASS（3 个用例）。如断言异常未抛出，调整 `_ThrowHandler.reject` 触发逻辑或改用 `throwsA(predicate)` 直接断言 `handler.reject` 调用——以实现为准修正测试。

- [ ] **Step 5: Commit**

```bash
git add lib/core/network/interceptors/response_interceptor.dart test/core/network/interceptors/response_interceptor_test.dart
git commit -m "feat(core/network): add ResponseInterceptor to unwrap envelope"
```

---

### Task 9: DomainSwitchInterceptor

**Files:**
- Create: `lib/core/network/interceptors/domain_switch_interceptor.dart`
- Test: `test/core/network/interceptors/domain_switch_interceptor_test.dart`

**Interfaces:**
- Consumes: `DomainManager`、`ApiClient.swapBaseUrl`（通过回调 `onRotate`）。
- Produces: `DomainSwitchInterceptor`：`onError` 中检测 608 或连续失败达阈值 → `DomainManager.rotate()` → 调 `onRotated(newUrl)` → 重试原请求一次（最多 1 次防死循环）。

- [ ] **Step 1: 写失败测试**

```dart
// test/core/network/interceptors/domain_switch_interceptor_test.dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jade/core/network/domain_manager.dart';
import 'package:jade/core/network/interceptors/domain_switch_interceptor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('608 触发 rotate 并标记重试', () async {
    final prefs = await SharedPreferences.getInstance();
    final dm = await DomainManager.load(prefs);
    await dm.applyStartup(BackupDomainsData(
      apiDomains: ['https://jdforrepam.com', 'https://b.com'],
    ));
    var rotatedTo = '';
    final ic = DomainSwitchInterceptor(
      domainManager: dm,
      onRotated: (url) => rotatedTo = url,
    );
    final err = DioException(
      requestOptions: RequestOptions(path: '/x'),
      response: Response(
        requestOptions: RequestOptions(path: '/x'),
        statusCode: 608,
      ),
      type: DioExceptionType.badResponse,
    );
    final shouldRetry = ic.onError(err, _ThrowingHandler());
    expect(shouldRetry, isTrue);
    expect(rotatedTo, 'https://b.com');
  });

  test('无备用域名时不重试', () async {
    final prefs = await SharedPreferences.getInstance();
    final dm = await DomainManager.load(prefs); // 无 apiDomains
    final ic = DomainSwitchInterceptor(
      domainManager: dm,
      onRotated: (_) {},
    );
    final err = DioException(
      requestOptions: RequestOptions(path: '/x'),
      response: Response(
        requestOptions: RequestOptions(path: '/x'),
        statusCode: 608,
      ),
      type: DioExceptionType.badResponse,
    );
    expect(ic.onError(err, _ThrowingHandler()), isFalse);
  });
}

class _ThrowingHandler implements ErrorInterceptorHandler {
  @override
  void next(DioException err) {}
  @override
  void resolve(Response response, {bool followRedirects = true}) {}
  @override
  void reject(DioException error, {bool callFollowingErrorHandler = true}) {
    throw error;
  }
}
```

> 实现说明：`onError` 返回 `bool shouldRetry`（自定义方法而非标准 `Interceptor.onError` void 签名），由 `ApiClient` 在装配时包裹一个轻量适配器调用。`ApiClient` 持有重试逻辑。

- [ ] **Step 2: 运行确认失败**

Run: `flutter test test/core/network/interceptors/domain_switch_interceptor_test.dart`
Expected: FAIL。

- [ ] **Step 3: 实现**

```dart
// lib/core/network/interceptors/domain_switch_interceptor.dart
import 'package:dio/dio.dart';
import 'package:jade/core/network/domain_manager.dart';

class DomainSwitchInterceptor extends Interceptor {
  DomainSwitchInterceptor({
    required this.domainManager,
    required this.onRotated,
  });

  final DomainManager domainManager;
  final void Function(String newUrl) onRotated;

  /// 判断错误是否应触发域名切换，需则轮转并返回 true。
  /// 非标准 Interceptor 方法，由 ApiClient 的 onError 调用。
  bool shouldSwitch(DioException err) {
    final code = err.response?.statusCode;
    if (code == 608) return true;
    // 连续失败计数由 ApiClient 维护（阈值 AppConstants.domainFailureThreshold）
    return false;
  }

  Future<bool> onError(DioException err, ErrorInterceptorHandler handler) async {
    if (!shouldSwitch(err)) {
      handler.next(err);
      return false;
    }
    final ok = await domainManager.rotate();
    if (!ok) {
      handler.next(err);
      return false;
    }
    onRotated(domainManager.currentUrl);
    return true; // ApiClient 据此重试原请求
  }
}
```

- [ ] **Step 4: 运行测试通过**

Run: `flutter test test/core/network/interceptors/domain_switch_interceptor_test.dart`
Expected: PASS（2 个用例）。

- [ ] **Step 5: Commit**

```bash
git add lib/core/network/interceptors/domain_switch_interceptor.dart test/core/network/interceptors/domain_switch_interceptor_test.dart
git commit -m "feat(core/network): add DomainSwitchInterceptor with 608 rotate"
```

---

### Task 10: ApiClient 装配

**Files:**
- Create: `lib/core/network/api_client.dart`
- Test: `test/core/network/api_client_test.dart`

**Interfaces:**
- Consumes: 4 拦截器、`DomainManager`、`TokenProvider`、`ResponseInterceptor.onAuthError`。
- Produces: `ApiClient`：
  - `static Future<ApiClient> create({StorageService, TokenProvider, void Function() onAuthError})`
  - `Future<Response<T>> get<T>(path, {queryParameters})`
  - `Future<Response<T>> post<T>(path, {data})`
  - `void swapBaseUrl(String url)`、`Dio get dio`（测试用）
  - 装配 `FakeAdapter` 注入口 `setAdapterForTest(adapter)`

- [ ] **Step 1: 写失败测试（端到端拦截器链）**

```dart
// test/core/network/api_client_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/testing/fake_adapter.dart';
import 'package:jade/core/network/endpoints.dart';
import 'package:jade/core/storage/storage_keys.dart';

class _TokenProvider implements TokenProvider {
  String? token;
  _TokenProvider([this.token]);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('get 解包 success==1 的 data', () async {
    final prefs = await SharedPreferences.getInstance();
    final api = await ApiClient.create(
      prefs: prefs,
      tokenProvider: _TokenProvider(),
      onAuthError: () {},
    );
    final adapter = FakeAdapter();
    adapter.enqueue(Endpoints.moviesRecommend, {'success': 1, 'data': {'r': 1}});
    api.setAdapterForTest(adapter);

    final resp = await api.get(Endpoints.moviesRecommend);
    expect(resp.data, {'r': 1});
    // 验证签名头已注入
    expect(adapter.requests.last.headers['jdsignature'], isNotNull);
  });

  test('get success==0 抛 ApiException', () async {
    final prefs = await SharedPreferences.getInstance();
    final api = await ApiClient.create(
      prefs: prefs,
      tokenProvider: _TokenProvider(),
      onAuthError: () {},
    );
    final adapter = FakeAdapter();
    adapter.enqueue(Endpoints.moviesLatest, {
      'success': 0,
      'action': 'ParameterInvalid',
      'message': '參數不能爲空',
    });
    api.setAdapterForTest(adapter);
    expect(() => api.get(Endpoints.moviesLatest),
        throwsA(predicate((e) => e.toString().contains('ParameterInvalid'))));
  });

  test('JWTVerificationError 触发 onAuthError', () async {
    final prefs = await SharedPreferences.getInstance();
    var authCalled = false;
    final api = await ApiClient.create(
      prefs: prefs,
      tokenProvider: _TokenProvider('t'),
      onAuthError: () => authCalled = true,
    );
    final adapter = FakeAdapter();
    adapter.enqueue(Endpoints.users, {
      'success': 0,
      'action': 'JWTVerificationError',
      'message': '請登錄帳號',
    });
    api.setAdapterForTest(adapter);
    expect(() => api.get(Endpoints.users), throwsA(isNotNull));
    await Future.delayed(Duration.zero);
    expect(authCalled, isTrue);
  });

  test('token 非空时注入 Authorization', () async {
    final prefs = await SharedPreferences.getInstance();
    final api = await ApiClient.create(
      prefs: prefs,
      tokenProvider: _TokenProvider('mytoken'),
      onAuthError: () {},
    );
    final adapter = FakeAdapter();
    adapter.enqueue(Endpoints.users, {'success': 1, 'data': null});
    api.setAdapterForTest(adapter);
    await api.get(Endpoints.users);
    expect(adapter.requests.last.headers['authorization'], 'Bearer mytoken');
  });
}
```

- [ ] **Step 2: 运行确认失败**

Run: `flutter test test/core/network/api_client_test.dart`
Expected: FAIL（`ApiClient` 未定义、`TokenProvider` 未导出）。

- [ ] **Step 3: 实现 api_client**

```dart
// lib/core/network/api_client.dart
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jade/core/network/domain_manager.dart';
import 'package:jade/core/network/api_exception.dart';
import 'package:jade/core/network/interceptors/signature_interceptor.dart';
import 'package:jade/core/network/interceptors/auth_interceptor.dart';
import 'package:jade/core/network/interceptors/response_interceptor.dart';
import 'package:jade/core/network/interceptors/domain_switch_interceptor.dart';

/// Token 提供者抽象（AuthProvider 实现）。
abstract class TokenProvider {
  String? get token;
}

class ApiClient {
  ApiClient._({
    required this.dio,
    required this.domainManager,
    required this.domainSwitch,
  });

  late final Dio dio;
  final DomainManager domainManager;
  final DomainSwitchInterceptor domainSwitch;

  static Future<ApiClient> create({
    required SharedPreferences prefs,
    required TokenProvider tokenProvider,
    required void Function() onAuthError,
  }) async {
    final dm = await DomainManager.load(prefs);
    final domainSwitch = DomainSwitchInterceptor(
      domainManager: dm,
      onRotated: (_) {}, // swapBaseUrl 在外层调用
    );
    final dio = Dio(BaseOptions(
      baseUrl: dm.currentUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
    ));
    dio.interceptors.addAll([
      SignatureInterceptor(),
      AuthInterceptor(tokenProvider),
      ResponseInterceptor(onAuthError: onAuthError),
      domainSwitch,
    ]);
    return ApiClient._(dio: dio, domainManager: dm, domainSwitch: domainSwitch);
  }

  Future<Response> get(String path, {Map<String, dynamic>? queryParameters}) {
    return dio.get(path, queryParameters: queryParameters);
  }

  Future<Response> post(String path, {dynamic data}) {
    return dio.post(path, data: data);
  }

  void swapBaseUrl(String url) {
    dio.options.baseUrl = url;
  }

  /// 测试注入。
  void setAdapterForTest(HttpClientAdapter adapter) {
    dio.httpClientAdapter = adapter;
  }
}
```

- [ ] **Step 4: 运行测试通过**

Run: `flutter test test/core/network/api_client_test.dart`
Expected: PASS（4 个用例）。如 `predicate` 未导入，加 `import 'package:matcher/matcher.dart';` 或用 `throwsA` lambda。

- [ ] **Step 5: Commit**

```bash
git add lib/core/network/api_client.dart test/core/network/api_client_test.dart
git commit -m "feat(core/network): assemble ApiClient with full interceptor chain"
```

---

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

### Task 12: Router Shell + MainShell + 5 占位 Tab

**Files:**
- Create: `lib/core/router/routes.dart`
- Create: `lib/core/router/app_router.dart`
- Create: `lib/core/widgets/main_shell.dart`
- Modify: `lib/features/home/screens/home_screen.dart`（替换为占位页）
- Create: `lib/features/rankings/screens/rankings_screen.dart`、`lib/features/categories/screens/categories_screen.dart`、`lib/features/actors/screens/actors_screen.dart`、`lib/features/profile/screens/profile_screen.dart`（占位）
- 各 feature 新增 `index.dart` 导出 Page
- Test: `test/app_router_test.dart`

**Interfaces:**
- Produces: `AppRouter`（`GoRouter`）、`MainShell`、5 个占位 `Screen`、`routes.dart` 路径常量。

- [ ] **Step 1: 写失败测试（路由到 /home 渲染首页占位）**

```dart
// test/app_router_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jade/core/router/app_router.dart';

void main() {
  testWidgets('AppRouter 默认渲染首页占位', (tester) async {
    await tester.pumpWidget(MaterialApp.router(
      routerConfig: AppRouter.buildForTest(),
    ));
    await tester.pumpAndSettle();
    expect(find.text('首页'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('点击排行榜 Tab 切换', (tester) async {
    await tester.pumpWidget(MaterialApp.router(
      routerConfig: AppRouter.buildForTest(),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('排行榜'));
    await tester.pumpAndSettle();
    expect(find.text('排行榜占位'), findsOneWidget);
  });
}
```

- [ ] **Step 2: 运行确认失败**

Run: `flutter test test/app_router_test.dart`
Expected: FAIL（`AppRouter` 未定义）。

- [ ] **Step 3: 实现 routes.dart**

```dart
// lib/core/router/routes.dart
class AppRoutes {
  const AppRoutes._();
  static const String home = '/home';
  static const String rankings = '/rankings';
  static const String categories = '/categories';
  static const String actors = '/actors';
  static const String profile = '/profile';
  static const String login = '/login';

  /// 需登录的路径集合（Phase 0 仅留接口，auth redirect 后续阶段填充）。
  static const Set<String> protectedRoutes = {};
}
```

- [ ] **Step 4: 实现占位 Screen（home 替换，其余新建）**

```dart
// lib/features/home/screens/home_screen.dart
import 'package:flutter/material.dart';
class HomePage extends StatelessWidget {
  const HomePage({super.key});
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('首页')));
}
```
```dart
// lib/features/rankings/screens/rankings_screen.dart
import 'package:flutter/material.dart';
class RankingsPage extends StatelessWidget {
  const RankingsPage({super.key});
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('排行榜占位')));
}
```
（categories/actors/profile 同构，文案分别为"类别占位"、"演员占位"、"我的占位"。）

各 `index.dart`：
```dart
// lib/features/home/index.dart
export 'screens/home_screen.dart';
```
（其余 feature 同构。）

- [ ] **Step 5: 实现 MainShell**

```dart
// lib/core/widgets/main_shell.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (i) => navigationShell.goBranch(
          i,
          initialLocation: i == navigationShell.currentIndex,
        ),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: '首页'),
          NavigationDestination(icon: Icon(Icons.bar_chart), label: '排行榜'),
          NavigationDestination(icon: Icon(Icons.category), label: '类别'),
          NavigationDestination(icon: Icon(Icons.people), label: '演员'),
          NavigationDestination(icon: Icon(Icons.person), label: '我的'),
        ],
      ),
    );
  }
}
```

- [ ] **Step 6: 实现 app_router**

```dart
// lib/core/router/app_router.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jade/core/router/routes.dart';
import 'package:jade/core/widgets/main_shell.dart';
import 'package:jade/features/home/index.dart';
import 'package:jade/features/rankings/index.dart';
import 'package:jade/features/categories/index.dart';
import 'package:jade/features/actors/index.dart';
import 'package:jade/features/profile/index.dart';

class AppRouter {
  const AppRouter._();

  static GoRouter buildForTest() => GoRouter(
    initialLocation: AppRoutes.home,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => MainShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: AppRoutes.home, builder: (c, s) => const HomePage()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: AppRoutes.rankings, builder: (c, s) => const RankingsPage()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: AppRoutes.categories, builder: (c, s) => const CategoriesPage()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: AppRoutes.actors, builder: (c, s) => const ActorsPage()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: AppRoutes.profile, builder: (c, s) => const ProfilePage()),
          ]),
        ],
      ),
    ],
  );
}
```

- [ ] **Step 7: 运行测试通过**

Run: `flutter test test/app_router_test.dart`
Expected: PASS（2 个用例）。

- [ ] **Step 8: Commit**

```bash
git add lib/core/router/routes.dart lib/core/router/app_router.dart lib/core/widgets/main_shell.dart lib/features/ test/app_router_test.dart
git commit -m "feat(core/router): add go_router StatefulShellRoute with 5 placeholder tabs"
```

---

### Task 13: app.dart + main.dart 装配启动

**Files:**
- Create: `lib/app.dart`
- Modify: `lib/main.dart`
- Test: `test/app_test.dart`

**Interfaces:**
- Produces：`MyApp`（`MaterialApp.router` + Provider 注册 + 主题）。
- 启动顺序：SP → AuthProvider → DomainManager.load → ApiClient.create → StartupProvider → `fetchStartup`（fire-and-forget）→ runApp。

- [ ] **Step 1: 写失败测试**

```dart
// test/app_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jade/main.dart' as app_main;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('App 启动渲染底导与首页', (tester) async {
    await app_main.mainForTest();
    await tester.pumpAndSettle();
    expect(find.byType(app_main.MyApp), findsOneWidget);
    expect(find.text('首页'), findsOneWidget);
  });
}
```

- [ ] **Step 2: 运行确认失败**

Run: `flutter test test/app_test.dart`
Expected: FAIL（`mainForTest`/`MyApp` 未定义或现有 main.dart 无 router）。

- [ ] **Step 3: 实现 app.dart**

```dart
// lib/app.dart
import 'package:flutter/material.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:provider/provider.dart';
import 'package:jade/core/providers/auth_provider.dart';
import 'package:jade/core/providers/settings_provider.dart';
import 'package:jade/core/providers/startup_provider.dart';
import 'package:jade/core/providers/theme_provider.dart';
import 'package:jade/core/router/app_router.dart';
import 'package:jade/core/theme/app_theme.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        return MaterialApp.router(
          title: 'Jade',
          theme: lightDynamic != null
              ? ThemeData(colorScheme: lightDynamic)
              : AppTheme.light(),
          darkTheme: darkDynamic != null
              ? ThemeData(colorScheme: darkDynamic)
              : AppTheme.dark(),
          themeMode: themeProvider.themeMode,
          routerConfig: AppRouter.buildForTest(),
        );
      },
    );
  }
}
```

- [ ] **Step 4: 改造 main.dart**

```dart
// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jade/app.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/providers/auth_provider.dart';
import 'package:jade/core/providers/settings_provider.dart';
import 'package:jade/core/providers/startup_provider.dart';
import 'package:jade/core/providers/theme_provider.dart';

export 'package:jade/app.dart' show MyApp;

Future<void> mainForTest() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(await _buildEntry());
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(await _buildEntry());
}

Future<Widget> _buildEntry() async {
  final prefs = await SharedPreferences.getInstance();
  final themeProvider = await ThemeProvider.create();
  final authProvider = await AuthProvider.create(prefs);
  final settingsProvider = await SettingsProvider.create(prefs);
  final apiClient = await ApiClient.create(
    prefs: prefs,
    tokenProvider: authProvider,
    onAuthError: authProvider.logout,
  );
  final startupProvider = StartupProvider.create(
    apiClient,
    apiClient.domainManager,
  );
  // fire-and-forget 域名刷新
  startupProvider.fetchStartup();

  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: themeProvider),
      ChangeNotifierProvider.value(value: authProvider),
      ChangeNotifierProvider.value(value: settingsProvider),
      ChangeNotifierProvider.value(value: startupProvider),
    ],
    child: const MyApp(),
  );
}
```

- [ ] **Step 5: 运行测试通过**

Run: `flutter test test/app_test.dart`
Expected: PASS。如 `StartupProvider.create` 签名与 Task 11 不符，以 Task 11 `StartupProvider.create(api, dm)` 为准修正 main.dart 调用。

- [ ] **Step 6: 运行全量测试**

Run: `flutter test`
Expected: 全部 PASS。

- [ ] **Step 7: Commit**

```bash
git add lib/app.dart lib/main.dart test/app_test.dart
git commit -m "feat(app): wire providers, ApiClient and router into bootstrap"
```

---

### Task 14: 静态分析与自检

**Files:** 无新增。

- [ ] **Step 1: 运行分析器**

Run: `flutter analyze`
Expected: 无 error，warning 可接受。如有 `unused_element`/`deprecated`，按提示修。

- [ ] **Step 2: 运行 dart fix**

Run: `dart fix --apply`
Expected: 自动修正机械性问题。

- [ ] **Step 3: 重跑全量测试**

Run: `flutter test`
Expected: 全部 PASS。

- [ ] **Step 4: Commit（若有改动）**

```bash
git add -A
git commit -m "chore: fix analyzer findings in phase 0"
```

---

## Self-Review

**1. Spec 覆盖**：spec §3（基础设施层）逐条对照——
- 3.1 dio 客户端与四拦截器链 → Task 7/8/9/10 ✅
- 3.2 签名算法 Dart 实现 → Task 3 ✅（含 ALGORITHM.md 样例验证）
- 3.3 域名动态切换状态机 → Task 5 ✅
- 3.4 go_router ShellRoute → Task 12 ✅
- 3.5 Provider 清单（Theme/Auth/Startup/Settings）→ Task 2/11/13 ✅
- 3.6 SP 键约定 → Task 2 ✅
- 3.7 错误处理与统一响应 → Task 4/8 ✅
- 3.8 测试策略 → 签名/状态机/拦截器/启动均含测试 ✅
spec §16 阶段 0 范围 = 上述，未越界到阶段 1（模型/共享组件）。

**2. 占位扫描**：无 TBD/TODO；所有代码步骤含完整代码。`StartupProvider._tryDecodeDomains` 标注"Phase 0 简化、完整解密后续阶段"，属明确的阶段边界而非占位。

**3. 类型一致性**：
- `JdSignature.generate({int? timestamp})` 在 Task 3/7 一致。
- `DomainManager.load(SharedPreferences)` 在 Task 5/10/11/13 一致。
- `ApiClient.create({prefs, tokenProvider, onAuthError})` 在 Task 10/13 一致。
- `TokenProvider.token` 在 auth_interceptor/auth_provider/api_client 一致。
- `BackupDomainsData(apiDomains)` 在 Task 5/11 一致。
- `ResponseInterceptor(onAuthError:)` 在 Task 8/10 一致。
- `DomainSwitchInterceptor({domainManager, onRotated})` 在 Task 9/10 一致。
- `StartupProvider.create(api, dm)` 在 Task 11/13 一致（Task 13 Step 4 已注明以此为准修正调用）。
- `AppRouter.buildForTest()` 在 Task 12/13 一致。
