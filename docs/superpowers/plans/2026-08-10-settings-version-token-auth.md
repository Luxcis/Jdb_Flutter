# Settings Version and Token Authentication Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在实际路由使用的设置页最后显示当前语义版本，并通过五连击入口验证、缓存和启用用户输入的 Bearer Token。

**Architecture:** `ProfileSettingsPage` 继续维护现有 `cells` 列表，并在最后追加版本 `ListTile`。候选 Token 通过请求级认证上下文调用 `/api/v1/users`，验证成功后提取 `UserEntity.user` 并交给现有 `AuthProvider.login()`；验证失败不触发全局登出。版本由 `package_info_plus` 的薄封装读取，Token 弹窗拆为独立 Widget，避免继续扩大 `profile_sub_pages.dart`。

**Tech Stack:** Flutter、Dart 3.8、Provider、Dio、SharedPreferences、`package_info_plus ^8.3.1`、`flutter_test`

## Global Constraints

- 以 `docs/main/api/jdb_api_openapi.json` 为接口唯一依据；`GET /api/v1/users` 解包后是 `UserEntity`，登录用户 Map 位于非空 `user` 字段。
- 版本 Cell 必须是 `ProfileSettingsPage.cells` 最后一行，主标题固定为`当前版本`，副标题只显示`0.7.1`形式的语义版本，不显示构建号。
- 从第一次点击版本 Cell 起 2 秒内完成 5 次点击才打开弹窗；超时或成功触发后计数归零。
- 弹窗必须提示`输入新的认证 Token 将覆盖当前登录信息。`。
- 候选 Token 先验证，成功后才覆盖当前 Token 和用户信息；失败必须保留旧登录状态。
- Token 只用于 Authorization 请求头和会话缓存，不得进入日志、错误文案或测试输出。
- 中文文案直接硬编码；不增加 ARB/l10n，不使用触觉反馈。
- 不修改未被路由使用的 `lib/features/settings/screens/settings_screen.dart` 和 `lib/features/settings/widgets/setting_item.dart`。
- 保留所有无关工作区变更；每次只暂存当前任务列出的文件。

---

## File Map

- Create `lib/core/network/auth_request_context.dart`: 定义请求级候选 Token 和抑制全局认证失效回调的显式上下文。
- Modify `lib/core/network/api_client.dart`: 增加候选 Token GET 入口。
- Modify `lib/core/network/interceptors/auth_interceptor.dart`: 请求级候选 Token 优先于当前会话 Token。
- Modify `lib/core/network/interceptors/response_interceptor.dart`: 候选 Token 验证失败只返回错误，不触发全局登出。
- Modify `lib/core/providers/auth_provider.dart`: 缓存完整写入后再切换内存会话，失败时保留旧会话。
- Create `lib/features/profile/services/token_authentication_service.dart`: 调用 `/api/v1/users` 并提取 `UserEntity.user`。
- Create `lib/features/profile/services/app_version_service.dart`: 读取实际安装包语义版本。
- Create `lib/features/profile/widgets/token_authentication_dialog.dart`: 管理 Token 输入、验证、保存、错误和加载状态。
- Modify `lib/features/profile/screens/profile_sub_pages.dart`: 追加版本 Cell、五连击计数并串接弹窗与 `AuthProvider`。
- Modify `pubspec.yaml` and `pubspec.lock`: 增加兼容当前工具链的 `package_info_plus ^8.3.1`。
- Modify `test/core/network/api_client_test.dart`: 覆盖候选 Token 请求和局部认证错误语义。
- Modify `test/core/providers/auth_provider_test.dart`: 覆盖会话缓存失败回滚。
- Create `test/features/profile/token_authentication_service_test.dart`: 覆盖 `/users` 用户提取和异常响应。
- Modify `test/features/profile/profile_sub_pages_test.dart`: 覆盖版本 Cell、五连击和会话覆盖完整流程。

---

### Task 1: 请求级候选 Token 网络上下文

**Files:**

- Create: `lib/core/network/auth_request_context.dart`
- Modify: `lib/core/network/api_client.dart`
- Modify: `lib/core/network/interceptors/auth_interceptor.dart`
- Modify: `lib/core/network/interceptors/response_interceptor.dart`
- Test: `test/core/network/api_client_test.dart`

**Interfaces:**

- Produces: `ApiClient.getWithCandidateToken(String path, {required String token, Map<String, dynamic>? queryParameters})`
- Produces: `AuthRequestContext.candidateTokenOptions(String token)`
- Produces: `AuthRequestContext.tokenOverride(RequestOptions options)`
- Produces: `AuthRequestContext.suppressesGlobalAuthError(RequestOptions options)`

- [ ] **Step 1: 写入候选 Token 覆盖的失败测试**

在 `test/core/network/api_client_test.dart` 增加：

```dart
test('候选 Token 请求覆盖当前 Token，普通请求仍读取 TokenProvider', () async {
  final prefs = await SharedPreferences.getInstance();
  final provider = _TokenProvider('old-token');
  final api = await ApiClient.create(
    prefs: prefs,
    tokenProvider: provider,
    onAuthError: () {},
  );
  final adapter = FakeAdapter()
    ..enqueue(Endpoints.users, {
      'success': 1,
      'data': {
        'user': {
          'id': 7,
          'username': 'candidate-user',
          'email': 'candidate@example.invalid',
        },
        'banner_type': 'none',
      },
    })
    ..enqueue(Endpoints.moviesRecommend, {
      'success': 1,
      'data': <dynamic>[],
    });
  api.setAdapterForTest(adapter);

  await api.getWithCandidateToken(
    Endpoints.users,
    token: 'candidate-token',
  );
  expect(
    adapter.requests.first.headers['authorization'],
    'Bearer candidate-token',
  );

  provider.token = 'saved-token';
  await api.get(Endpoints.moviesRecommend);
  expect(
    adapter.requests.last.headers['authorization'],
    'Bearer saved-token',
  );
});
```

- [ ] **Step 2: 运行测试并确认按预期失败**

Run:

```bash
flutter test test/core/network/api_client_test.dart --plain-name '候选 Token 请求覆盖当前 Token，普通请求仍读取 TokenProvider'
```

Expected: FAIL，原因是 `ApiClient.getWithCandidateToken` 尚不存在。

- [ ] **Step 3: 实现最小请求级认证上下文**

创建 `lib/core/network/auth_request_context.dart`：

```dart
import 'package:dio/dio.dart';

final class AuthRequestContext {
  const AuthRequestContext._();

  static const _tokenOverrideKey = 'jade.auth.tokenOverride';
  static const _suppressGlobalAuthErrorKey =
      'jade.auth.suppressGlobalAuthError';

  static Options candidateTokenOptions(String token) => Options(
    extra: {
      _tokenOverrideKey: token,
      _suppressGlobalAuthErrorKey: true,
    },
  );

  static String? tokenOverride(RequestOptions options) =>
      options.extra[_tokenOverrideKey] as String?;

  static bool suppressesGlobalAuthError(RequestOptions options) =>
      options.extra[_suppressGlobalAuthErrorKey] == true;
}
```

在 `ApiClient` 增加：

```dart
Future<Response> getWithCandidateToken(
  String path, {
  required String token,
  Map<String, dynamic>? queryParameters,
}) {
  return dio.get(
    path,
    queryParameters: queryParameters,
    options: AuthRequestContext.candidateTokenOptions(token),
  );
}
```

在 `AuthInterceptor.onRequest` 中改为候选 Token 优先：

```dart
final token =
    AuthRequestContext.tokenOverride(options) ?? _tokenProvider.token;
if (token != null && token.isNotEmpty) {
  options.headers['authorization'] = 'Bearer $token';
}
```

- [ ] **Step 4: 运行聚焦测试并确认转绿**

Run:

```bash
flutter test test/core/network/api_client_test.dart --plain-name '候选 Token 请求覆盖当前 Token，普通请求仍读取 TokenProvider'
```

Expected: PASS。

- [ ] **Step 5: 写入候选 Token 失效不全局登出的失败测试**

在同一测试文件增加：

```dart
test('候选 Token 失效不触发全局认证回调', () async {
  final prefs = await SharedPreferences.getInstance();
  var authErrorCalls = 0;
  final api = await ApiClient.create(
    prefs: prefs,
    tokenProvider: _TokenProvider('old-token'),
    onAuthError: () => authErrorCalls++,
  );
  final adapter = FakeAdapter()
    ..enqueue(Endpoints.users, {
      'success': 0,
      'action': 'JWTVerificationError',
      'message': 'Token 无效',
    });
  api.setAdapterForTest(adapter);

  await expectLater(
    () => api.getWithCandidateToken(
      Endpoints.users,
      token: 'invalid-candidate',
    ),
    throwsA(isNotNull),
  );

  expect(authErrorCalls, 0);
});
```

- [ ] **Step 6: 运行测试并确认回调仍被错误触发**

Run:

```bash
flutter test test/core/network/api_client_test.dart --plain-name '候选 Token 失效不触发全局认证回调'
```

Expected: FAIL，`authErrorCalls` 当前为 1。

- [ ] **Step 7: 在 ResponseInterceptor 中尊重局部错误语义**

对 `onResponse` 和 `onError` 中所有 `onAuthError()` 调用增加同一条件：

```dart
final suppressGlobalAuthError =
    AuthRequestContext.suppressesGlobalAuthError(response.requestOptions);
if (_isAuthAction(action) && !suppressGlobalAuthError) {
  onAuthError();
}
```

HTTP 401 分支使用：

```dart
if (response?.statusCode == 401 &&
    !AuthRequestContext.suppressesGlobalAuthError(err.requestOptions)) {
  onAuthError();
}
```

无论是否抑制全局回调，原错误仍必须通过 `handler.reject` 或 `handler.next` 返回调用方。

- [ ] **Step 8: 运行网络相关回归测试**

Run:

```bash
flutter test test/core/network/api_client_test.dart test/core/network/interceptors/signature_auth_interceptor_test.dart test/core/network/interceptors/response_interceptor_test.dart
```

Expected: PASS。

- [ ] **Step 9: 提交 Task 1**

```bash
git add lib/core/network/auth_request_context.dart lib/core/network/api_client.dart lib/core/network/interceptors/auth_interceptor.dart lib/core/network/interceptors/response_interceptor.dart test/core/network/api_client_test.dart
git commit -m "feat(auth): support candidate token requests"
```

---

### Task 2: `/api/v1/users` Token 验证服务

**Files:**

- Create: `lib/features/profile/services/token_authentication_service.dart`
- Create: `test/features/profile/token_authentication_service_test.dart`

**Interfaces:**

- Consumes: `ApiClient.getWithCandidateToken(...)`
- Produces: `abstract interface class TokenAuthenticationService`
- Produces: `ApiTokenAuthenticationService(ApiClient api)`
- Produces: `Future<Map<String, dynamic>> TokenAuthenticationService.authenticate(String token)`

- [ ] **Step 1: 写入成功提取 `UserEntity.user` 的失败测试**

创建 `test/features/profile/token_authentication_service_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/endpoints.dart';
import 'package:jade/core/network/testing/fake_adapter.dart';
import 'package:jade/features/profile/services/token_authentication_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

final class _TokenProvider implements TokenProvider {
  @override
  String? token = 'old-token';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('authenticate 调用 users 并返回内层 user', () async {
    final prefs = await SharedPreferences.getInstance();
    final api = await ApiClient.create(
      prefs: prefs,
      tokenProvider: _TokenProvider(),
      onAuthError: () {},
    );
    final adapter = FakeAdapter()
      ..enqueue(Endpoints.users, {
        'success': 1,
        'data': {
          'user': {
            'id': 9,
            'username': 'token-user',
            'email': 'token-user@example.invalid',
            'want_watch_count': 2,
            'watched_count': 3,
          },
          'banner_type': 'none',
        },
      });
    api.setAdapterForTest(adapter);
    final service = ApiTokenAuthenticationService(api);

    final user = await service.authenticate('candidate-token');

    expect(user, {
      'id': 9,
      'username': 'token-user',
      'email': 'token-user@example.invalid',
      'want_watch_count': 2,
      'watched_count': 3,
    });
    expect(adapter.requests.single.path, Endpoints.users);
  });
}
```

- [ ] **Step 2: 运行测试并确认服务不存在**

Run:

```bash
flutter test test/features/profile/token_authentication_service_test.dart
```

Expected: FAIL，原因是 `TokenAuthenticationService` 尚不存在。

- [ ] **Step 3: 实现最小 TokenAuthenticationService**

创建 `lib/features/profile/services/token_authentication_service.dart`：

```dart
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/endpoints.dart';

abstract interface class TokenAuthenticationService {
  Future<Map<String, dynamic>> authenticate(String token);
}

final class ApiTokenAuthenticationService
    implements TokenAuthenticationService {
  const ApiTokenAuthenticationService(this._api);

  final ApiClient _api;

  Future<Map<String, dynamic>> authenticate(String token) async {
    final response = await _api.getWithCandidateToken(
      Endpoints.users,
      token: token,
    );
    final entity = response.data;
    if (entity is Map) {
      final user = entity['user'];
      if (user is Map && user.isNotEmpty) {
        return Map<String, dynamic>.from(user);
      }
    }
    throw const FormatException('用户信息格式无效');
  }
}
```

- [ ] **Step 4: 运行测试并确认转绿**

Run:

```bash
flutter test test/features/profile/token_authentication_service_test.dart
```

Expected: PASS。

- [ ] **Step 5: 增加缺少 `user` 时拒绝认证的回归测试**

在同一文件增加：

```dart
test('authenticate 拒绝缺少 user 的成功响应', () async {
  final prefs = await SharedPreferences.getInstance();
  final api = await ApiClient.create(
    prefs: prefs,
    tokenProvider: _TokenProvider(),
    onAuthError: () {},
  );
  final adapter = FakeAdapter()
    ..enqueue(Endpoints.users, {
      'success': 1,
      'data': {'banner_type': 'none'},
    });
  api.setAdapterForTest(adapter);

  await expectLater(
    () => ApiTokenAuthenticationService(api).authenticate('candidate-token'),
    throwsA(isA<FormatException>()),
  );
});
```

- [ ] **Step 6: 运行服务测试**

Run:

```bash
flutter test test/features/profile/token_authentication_service_test.dart
```

Expected: PASS。

- [ ] **Step 7: 提交 Task 2**

```bash
git add lib/features/profile/services/token_authentication_service.dart test/features/profile/token_authentication_service_test.dart
git commit -m "feat(auth): validate token with current user endpoint"
```

---

### Task 3: 当前版本 Cell

**Files:**

- Modify: `pubspec.yaml`
- Modify: `pubspec.lock`
- Create: `lib/features/profile/services/app_version_service.dart`
- Modify: `lib/features/profile/screens/profile_sub_pages.dart`
- Modify: `test/features/profile/profile_sub_pages_test.dart`

**Interfaces:**

- Produces: `abstract interface class AppVersionService`
- Produces: `Future<String> AppVersionService.loadVersion()`
- Produces: `PackageAppVersionService`
- Extends: `ProfileSettingsPage({CacheService? cacheService, AppVersionService? appVersionService, TokenAuthenticationService? tokenAuthenticationService})`

- [ ] **Step 1: 添加已确认的兼容依赖**

Run:

```bash
flutter pub add package_info_plus:^8.3.1
```

Expected: `pubspec.yaml` 增加 `package_info_plus: ^8.3.1`，`pubspec.lock` 更新；不得升级无关直接依赖。

- [ ] **Step 2: 写入版本 Cell 的失败测试**

在 `test/features/profile/profile_sub_pages_test.dart` 增加测试用版本服务：

```dart
final class _FixedAppVersionService implements AppVersionService {
  const _FixedAppVersionService(this.version);

  final String version;

  @override
  Future<String> loadVersion() async => version;
}

final class _FailingAppVersionService implements AppVersionService {
  const _FailingAppVersionService();

  @override
  Future<String> loadVersion() => Future.error(StateError('unavailable'));
}
```

增加测试：

```dart
testWidgets('当前版本是 settings cells 最后一行且不显示构建号', (tester) async {
  final subject = await _pumpSettings(
    tester,
    appVersionService: const _FixedAppVersionService('0.7.1'),
  );
  addTearDown(subject.dispose);
  await tester.pumpAndSettle();

  expect(find.text('当前版本'), findsOneWidget);
  expect(find.text('0.7.1'), findsOneWidget);
  expect(find.textContaining('+701'), findsNothing);
  expect(
    tester.getTopLeft(find.text('当前版本')).dy,
    greaterThan(tester.getTopLeft(find.text('清除缓存')).dy),
  );
});

testWidgets('版本读取失败时副标题显示未知', (tester) async {
  final subject = await _pumpSettings(
    tester,
    appVersionService: const _FailingAppVersionService(),
  );
  addTearDown(subject.dispose);
  await tester.pumpAndSettle();

  expect(find.text('当前版本'), findsOneWidget);
  expect(find.text('未知'), findsOneWidget);
});
```

在测试文件中加入完整 helper；它只管理测试对象，不进入生产类：

```dart
Future<
  ({
    AuthProvider auth,
    SharedPreferences prefs,
    void Function() dispose,
  })
>
_pumpSettings(
  WidgetTester tester, {
  required AppVersionService appVersionService,
  TokenAuthenticationService? tokenAuthenticationService,
  String? initialToken,
  Map<String, dynamic>? initialUser,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final settings = await SettingsProvider.create(prefs);
  final theme = await ThemeProvider.create();
  final domainManager = await DomainManager.load(prefs);
  final auth = await AuthProvider.create(prefs);
  if (initialToken != null && initialUser != null) {
    await auth.login(token: initialToken, user: initialUser);
  }

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: theme),
        ChangeNotifierProvider.value(value: domainManager),
        ChangeNotifierProvider.value(value: auth),
      ],
      child: MaterialApp(
        home: ProfileSettingsPage(
          cacheService: _FakeCacheService(),
          appVersionService: appVersionService,
          tokenAuthenticationService: tokenAuthenticationService,
        ),
      ),
    ),
  );

  return (
    auth: auth,
    prefs: prefs,
    dispose: () {
      settings.dispose();
      theme.dispose();
      domainManager.dispose();
      auth.dispose();
    },
  );
}
```

- [ ] **Step 3: 运行测试并确认构造参数或 Cell 缺失**

Run:

```bash
flutter test test/features/profile/profile_sub_pages_test.dart --plain-name '当前版本是 settings cells 最后一行且不显示构建号'
```

Expected: FAIL，原因是版本服务/Cell 尚不存在。

- [ ] **Step 4: 实现版本服务和最后一行 Cell**

创建 `lib/features/profile/services/app_version_service.dart`：

```dart
import 'package:package_info_plus/package_info_plus.dart';

abstract interface class AppVersionService {
  Future<String> loadVersion();
}

final class PackageAppVersionService implements AppVersionService {
  const PackageAppVersionService();

  @override
  Future<String> loadVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return packageInfo.version;
  }
}
```

扩展 `ProfileSettingsPage` 的现有依赖注入构造器：

```dart
const ProfileSettingsPage({
  super.key,
  this.cacheService,
  this.appVersionService,
  this.tokenAuthenticationService,
});

final CacheService? cacheService;
final AppVersionService? appVersionService;
final TokenAuthenticationService? tokenAuthenticationService;
```

在 `_ProfileSettingsPageState` 中：

```dart
late final CacheService _cacheService;
late final AppVersionService _appVersionService;
String _appVersion = '…';

@override
void initState() {
  super.initState();
  _cacheService = widget.cacheService ?? JdbImageCacheService();
  _appVersionService =
      widget.appVersionService ?? const PackageAppVersionService();
  unawaited(_loadCacheSize());
  unawaited(_loadAppVersion());
}

Future<void> _loadAppVersion() async {
  try {
    final version = await _appVersionService.loadVersion();
    if (!mounted) return;
    setState(() => _appVersion = version);
  } catch (_) {
    if (!mounted) return;
    setState(() => _appVersion = '未知');
  }
}
```

把版本 Cell 追加到 `cells` 最后：

```dart
ListTile(
  leading: const Icon(Icons.info_outline),
  title: const Text('当前版本'),
  subtitle: Text(_appVersion),
),
```

- [ ] **Step 5: 运行版本 Cell 测试及已有设置回归**

Run:

```bash
flutter test test/features/profile/profile_sub_pages_test.dart
```

Expected: PASS。

- [ ] **Step 6: 提交 Task 3**

```bash
git add pubspec.yaml pubspec.lock lib/features/profile/services/app_version_service.dart lib/features/profile/screens/profile_sub_pages.dart test/features/profile/profile_sub_pages_test.dart
git commit -m "feat(settings): show current app version"
```

---

### Task 4: AuthProvider 会话写入一致性

**Files:**

- Modify: `lib/core/providers/auth_provider.dart`
- Modify: `test/core/providers/auth_provider_test.dart`

**Interfaces:**

- Preserves: `AuthProvider.login({required String token, required Map<String, dynamic> user})`
- Changes behavior: 仅在 `StorageKeys.user` 与 `StorageKeys.token` 均写入成功后更新内存并通知监听者；任一步失败都抛出 `StateError` 并恢复旧缓存。

- [ ] **Step 1: 写入缓存失败保留旧会话的失败测试**

在 `test/core/providers/auth_provider_test.dart` 增加 `dart:convert` 导入和测试用 preferences：

```dart
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
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}
```

增加测试：

```dart
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
```

- [ ] **Step 2: 运行测试并确认当前实现出现半更新**

Run:

```bash
flutter test test/core/providers/auth_provider_test.dart --plain-name 'login 缓存失败时保留旧内存会话并回滚缓存'
```

Expected: FAIL；当前实现不会因 `setString` 返回 `false` 抛错，并已把内存用户改为新用户。

- [ ] **Step 3: 调整 login 的写入顺序并增加回滚**

在 `AuthProvider.login` 中保存旧缓存值，先写用户、再写 Token；只有两次返回值均为 `true` 才修改 `_token`、`_user` 并 `notifyListeners()`：

```dart
Future<void> login({
  required String token,
  required Map<String, dynamic> user,
}) async {
  final previousToken = _prefs.getString(StorageKeys.token);
  final previousUser = _prefs.getString(StorageKeys.user);
  final encodedUser = jsonEncode(user);

  try {
    final userSaved = await _prefs.setString(StorageKeys.user, encodedUser);
    final tokenSaved =
        userSaved && await _prefs.setString(StorageKeys.token, token);
    if (!userSaved || !tokenSaved) {
      throw StateError('Failed to persist authenticated session');
    }
  } catch (error, stackTrace) {
    await _restoreValue(StorageKeys.user, previousUser);
    await _restoreValue(StorageKeys.token, previousToken);
    Error.throwWithStackTrace(error, stackTrace);
  }

  _token = token;
  _user = Map<String, dynamic>.from(user);
  notifyListeners();
}

Future<void> _restoreValue(String key, String? value) async {
  try {
    if (value == null) {
      await _prefs.remove(key);
    } else {
      await _prefs.setString(key, value);
    }
  } catch (_) {
    // 已保留内存中的旧会话；缓存回滚采用最大努力策略。
  }
}
```

- [ ] **Step 4: 运行 AuthProvider 全部测试**

Run:

```bash
flutter test test/core/providers/auth_provider_test.dart
```

Expected: PASS。

- [ ] **Step 5: 提交 Task 4**

```bash
git add lib/core/providers/auth_provider.dart test/core/providers/auth_provider_test.dart
git commit -m "fix(auth): keep session consistent on cache failure"
```

---

### Task 5: 五连击 Token 弹窗与会话覆盖

**Files:**

- Create: `lib/features/profile/widgets/token_authentication_dialog.dart`
- Modify: `lib/features/profile/screens/profile_sub_pages.dart`
- Modify: `test/features/profile/profile_sub_pages_test.dart`

**Interfaces:**

- Consumes: `TokenAuthenticationService.authenticate(String token)`
- Consumes: `AuthProvider.login({required String token, required Map<String, dynamic> user})`
- Produces: `TokenAuthenticationDialog`
- Produces: `typedef AuthenticateToken = Future<Map<String, dynamic>> Function(String token)`
- Produces: `typedef SaveAuthenticatedSession = Future<void> Function({required String token, required Map<String, dynamic> user})`

- [ ] **Step 1: 写入五连击和超时边界的失败测试**

在 `test/features/profile/profile_sub_pages_test.dart` 增加：

```dart
testWidgets('2 秒内第五次点击当前版本才打开 Token 弹窗', (tester) async {
  final subject = await _pumpSettings(
    tester,
    appVersionService: const _FixedAppVersionService('0.7.1'),
  );
  addTearDown(subject.dispose);
  await tester.pumpAndSettle();

  for (var i = 0; i < 4; i++) {
    await tester.tap(find.text('当前版本'));
  }
  await tester.pump();
  expect(find.text('认证 Token'), findsNothing);

  await tester.tap(find.text('当前版本'));
  await tester.pumpAndSettle();
  expect(find.text('认证 Token'), findsOneWidget);
  expect(find.text('输入新的认证 Token 将覆盖当前登录信息。'), findsOneWidget);
});

testWidgets('版本点击超过 2 秒后重新计数', (tester) async {
  final subject = await _pumpSettings(
    tester,
    appVersionService: const _FixedAppVersionService('0.7.1'),
  );
  addTearDown(subject.dispose);
  await tester.pumpAndSettle();

  for (var i = 0; i < 4; i++) {
    await tester.tap(find.text('当前版本'));
  }
  await tester.pump(const Duration(seconds: 2));
  await tester.tap(find.text('当前版本'));
  await tester.pump();

  expect(find.text('认证 Token'), findsNothing);
});
```

- [ ] **Step 2: 运行五连击测试并确认失败**

Run:

```bash
flutter test test/features/profile/profile_sub_pages_test.dart --plain-name '2 秒内第五次点击当前版本才打开 Token 弹窗'
```

Expected: FAIL，弹窗尚不存在。

- [ ] **Step 3: 实现计数窗口和弹窗骨架**

在 `_ProfileSettingsPageState` 增加：

```dart
static const _tokenTapWindow = Duration(seconds: 2);
Timer? _tokenTapTimer;
var _versionTapCount = 0;

void _onVersionTap() {
  if (_versionTapCount == 0) {
    _tokenTapTimer = Timer(_tokenTapWindow, _resetVersionTapCount);
  }
  _versionTapCount++;
  if (_versionTapCount < 5) return;
  _resetVersionTapCount();
  unawaited(_openTokenAuthenticationDialog());
}

void _resetVersionTapCount() {
  _tokenTapTimer?.cancel();
  _tokenTapTimer = null;
  _versionTapCount = 0;
}

@override
void dispose() {
  _tokenTapTimer?.cancel();
  super.dispose();
}
```

把版本 `ListTile` 更新为：

```dart
ListTile(
  leading: const Icon(Icons.info_outline),
  title: const Text('当前版本'),
  subtitle: Text(_appVersion),
  onTap: _onVersionTap,
),
```

创建可被后续 RED 测试继续驱动的最小弹窗
`lib/features/profile/widgets/token_authentication_dialog.dart`：

```dart
import 'package:flutter/material.dart';

typedef AuthenticateToken =
    Future<Map<String, dynamic>> Function(String token);

typedef SaveAuthenticatedSession =
    Future<void> Function({
      required String token,
      required Map<String, dynamic> user,
    });

class TokenAuthenticationDialog extends StatelessWidget {
  const TokenAuthenticationDialog({
    super.key,
    required this.authenticate,
    required this.saveSession,
  });

  final AuthenticateToken authenticate;
  final SaveAuthenticatedSession saveSession;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('认证 Token'),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('输入新的认证 Token 将覆盖当前登录信息。'),
          SizedBox(height: 16),
          TextField(
            decoration: InputDecoration(
              labelText: 'Token',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        const TextButton(onPressed: null, child: Text('确定')),
      ],
    );
  }
}
```

在 `ProfileSettingsPage` 中加入最小打开逻辑：

```dart
Future<void> _openTokenAuthenticationDialog() async {
  final auth = context.read<AuthProvider>();
  final service =
      widget.tokenAuthenticationService ??
      ApiTokenAuthenticationService(ApiClient.instance);
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => TokenAuthenticationDialog(
      authenticate: service.authenticate,
      saveSession: auth.login,
    ),
  );
}
```

- [ ] **Step 4: 运行五连击与超时测试**

Run:

```bash
flutter test test/features/profile/profile_sub_pages_test.dart --plain-name '2 秒内第五次点击当前版本才打开 Token 弹窗'
flutter test test/features/profile/profile_sub_pages_test.dart --plain-name '版本点击超过 2 秒后重新计数'
```

Expected: PASS。

- [ ] **Step 5: 写入验证成功后覆盖会话的失败测试**

增加测试用服务：

```dart
final class _FakeTokenAuthenticationService
    implements TokenAuthenticationService {
  _FakeTokenAuthenticationService({this.user, this.error});

  final Map<String, dynamic>? user;
  final Object? error;
  var calls = 0;
  String? lastToken;

  @override
  Future<Map<String, dynamic>> authenticate(String token) async {
    calls++;
    lastToken = token;
    if (error case final error?) throw error;
    return user!;
  }
}
```

增加成功测试：

```dart
testWidgets('Token 验证成功后覆盖并持久化完整登录状态', (tester) async {
  final service = _FakeTokenAuthenticationService(
    user: {
      'id': 10,
      'username': 'replacement-user',
      'email': 'replacement@example.invalid',
    },
  );
  final subject = await _pumpSettings(
    tester,
    initialToken: 'old-token',
    initialUser: {'id': 1, 'username': 'old-user'},
    appVersionService: const _FixedAppVersionService('0.7.1'),
    tokenAuthenticationService: service,
  );
  addTearDown(subject.dispose);
  await tester.pumpAndSettle();

  for (var i = 0; i < 5; i++) {
    await tester.tap(find.text('当前版本'));
  }
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField), '  replacement-token  ');
  await tester.tap(find.text('确定'));
  await tester.pumpAndSettle();

  expect(service.calls, 1);
  expect(service.lastToken, 'replacement-token');
  expect(subject.auth.token, 'replacement-token');
  expect(subject.auth.user?['username'], 'replacement-user');
  expect(
    subject.prefs.getString(StorageKeys.token),
    'replacement-token',
  );
  expect(find.text('认证 Token'), findsNothing);
  expect(find.text('认证 Token 已更新'), findsOneWidget);
});
```

`_pumpSettings` 的返回 record 至少包含：

```dart
({
  AuthProvider auth,
  SharedPreferences prefs,
  void Function() dispose,
})
```

- [ ] **Step 6: 写入验证失败保留旧会话的失败测试**

```dart
testWidgets('Token 验证失败时保留旧登录状态并允许重试', (tester) async {
  final service = _FakeTokenAuthenticationService(
    error: const ApiException(
      action: ApiErrorActions.jwtVerificationError,
      message: 'Token 无效',
    ),
  );
  final subject = await _pumpSettings(
    tester,
    initialToken: 'old-token',
    initialUser: {'id': 1, 'username': 'old-user'},
    appVersionService: const _FixedAppVersionService('0.7.1'),
    tokenAuthenticationService: service,
  );
  addTearDown(subject.dispose);
  await tester.pumpAndSettle();

  for (var i = 0; i < 5; i++) {
    await tester.tap(find.text('当前版本'));
  }
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField), 'invalid-token');
  await tester.tap(find.text('确定'));
  await tester.pumpAndSettle();

  expect(find.text('认证 Token'), findsOneWidget);
  expect(find.text('Token 无效'), findsOneWidget);
  expect(subject.auth.token, 'old-token');
  expect(subject.auth.user?['username'], 'old-user');
  expect(subject.prefs.getString(StorageKeys.token), 'old-token');
});
```

- [ ] **Step 7: 实现弹窗验证、保存与错误状态**

把 `TokenAuthenticationDialog` 改为 `StatefulWidget`，增加
`package:jade/core/network/api_exception.dart` 导入并保留以下公共签名：

```dart
typedef AuthenticateToken =
    Future<Map<String, dynamic>> Function(String token);

typedef SaveAuthenticatedSession =
    Future<void> Function({
      required String token,
      required Map<String, dynamic> user,
    });

class TokenAuthenticationDialog extends StatefulWidget {
  const TokenAuthenticationDialog({
    super.key,
    required this.authenticate,
    required this.saveSession,
  });

  final AuthenticateToken authenticate;
  final SaveAuthenticatedSession saveSession;

  @override
  State<TokenAuthenticationDialog> createState() =>
      _TokenAuthenticationDialogState();
}
```

State 创建和释放输入控制器：

```dart
class _TokenAuthenticationDialogState
    extends State<TokenAuthenticationDialog> {
  final _controller = TextEditingController();
  var _loading = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
```

提交逻辑必须按顺序执行：

```dart
Future<void> _submit() async {
  final token = _controller.text.trim();
  if (token.isEmpty || _loading) return;
  setState(() {
    _loading = true;
    _error = null;
  });

  late final Map<String, dynamic> user;
  try {
    user = await widget.authenticate(token);
  } on ApiException catch (error) {
    _showError(error.message ?? 'Token 验证失败，请重试');
    return;
  } catch (_) {
    _showError('Token 验证失败，请重试');
    return;
  }

  try {
    await widget.saveSession(token: token, user: user);
  } catch (_) {
    _showError('保存失败，请重试');
    return;
  }

  if (mounted) Navigator.pop(context, true);
}

void _showError(String message) {
  if (!mounted) return;
  setState(() {
    _loading = false;
    _error = message;
  });
}
```

Widget 树使用以下实现：

```dart
@override
Widget build(BuildContext context) {
  return PopScope(
    canPop: !_loading,
    child: AlertDialog(
      title: const Text('认证 Token'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('输入新的认证 Token 将覆盖当前登录信息。'),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            enabled: !_loading,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration: const InputDecoration(
              labelText: 'Token',
              border: OutlineInputBorder(),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _error!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context, false),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('确定'),
        ),
      ],
    ),
  );
}
}
```

加载期间：

- `确定`和`取消`按钮均不可重复点击；
- 显示 20×20、`strokeWidth: 2` 的 `CircularProgressIndicator`；
- `PopScope.canPop` 为 `false`；
- 不显示或记录 Token。

在 `ProfileSettingsPage` 中：

```dart
Future<void> _openTokenAuthenticationDialog() async {
  final auth = context.read<AuthProvider>();
  final service =
      widget.tokenAuthenticationService ??
      ApiTokenAuthenticationService(ApiClient.instance);
  final updated = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => TokenAuthenticationDialog(
      authenticate: service.authenticate,
      saveSession: auth.login,
    ),
  );
  if (updated == true && mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('认证 Token 已更新')),
    );
  }
}
```

- [ ] **Step 8: 增加空值和重复提交回归**

新增两个测试：

```dart
testWidgets('空 Token 不发起验证', (tester) async {
  final service = _FakeTokenAuthenticationService(user: {'id': 1});
  final subject = await _pumpSettings(
    tester,
    appVersionService: const _FixedAppVersionService('0.7.1'),
    tokenAuthenticationService: service,
  );
  addTearDown(subject.dispose);
  await tester.pumpAndSettle();
  for (var i = 0; i < 5; i++) {
    await tester.tap(find.text('当前版本'));
  }
  await tester.pumpAndSettle();

  await tester.enterText(find.byType(TextField), '   ');
  await tester.tap(find.text('确定'));
  await tester.pump();

  expect(service.calls, 0);
  expect(find.text('认证 Token'), findsOneWidget);
});
```

增加保存失败测试，直接渲染真实弹窗并让保存边界抛错：

```dart
testWidgets('会话保存失败时弹窗保留且不显示成功状态', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: TokenAuthenticationDialog(
        authenticate: (_) async => {
          'id': 1,
          'username': 'token-user',
        },
        saveSession: ({required token, required user}) async {
          throw StateError('storage unavailable');
        },
      ),
    ),
  );

  await tester.enterText(find.byType(TextField), 'candidate-token');
  await tester.tap(find.text('确定'));
  await tester.pumpAndSettle();

  expect(find.text('认证 Token'), findsOneWidget);
  expect(find.text('保存失败，请重试'), findsOneWidget);
  expect(find.text('认证 Token 已更新'), findsNothing);
});
```

增加受控服务：

```dart
final class _CompletingTokenAuthenticationService
    implements TokenAuthenticationService {
  final completer = Completer<Map<String, dynamic>>();
  var calls = 0;

  @override
  Future<Map<String, dynamic>> authenticate(String token) {
    calls++;
    return completer.future;
  }
}
```

增加重复提交测试：

```dart
testWidgets('验证期间阻止重复提交', (tester) async {
  final service = _CompletingTokenAuthenticationService();
  final subject = await _pumpSettings(
    tester,
    appVersionService: const _FixedAppVersionService('0.7.1'),
    tokenAuthenticationService: service,
  );
  addTearDown(subject.dispose);
  await tester.pumpAndSettle();
  for (var i = 0; i < 5; i++) {
    await tester.tap(find.text('当前版本'));
  }
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField), 'candidate-token');

  await tester.tap(find.text('确定'));
  await tester.tap(find.text('确定'));
  await tester.pump();

  expect(service.calls, 1);
  expect(find.byType(CircularProgressIndicator), findsOneWidget);
  service.completer.complete({'id': 1, 'username': 'token-user'});
  await tester.pumpAndSettle();
});
```

- [ ] **Step 9: 运行设置页、认证服务和 Provider 回归**

Run:

```bash
flutter test test/features/profile/profile_sub_pages_test.dart test/features/profile/token_authentication_service_test.dart test/core/providers/auth_provider_test.dart
```

Expected: PASS，且测试输出不包含候选 Token 的实际值。

- [ ] **Step 10: 提交 Task 4**

```bash
git add lib/features/profile/widgets/token_authentication_dialog.dart lib/features/profile/screens/profile_sub_pages.dart test/features/profile/profile_sub_pages_test.dart
git commit -m "feat(settings): authenticate with version cell token entry"
```

---

## Final Verification

- [ ] 格式化所有本计划修改的 Dart 文件：

```bash
dart format lib/core/network/auth_request_context.dart lib/core/network/api_client.dart lib/core/network/interceptors/auth_interceptor.dart lib/core/network/interceptors/response_interceptor.dart lib/core/providers/auth_provider.dart lib/features/profile/services/app_version_service.dart lib/features/profile/services/token_authentication_service.dart lib/features/profile/widgets/token_authentication_dialog.dart lib/features/profile/screens/profile_sub_pages.dart test/core/network/api_client_test.dart test/core/providers/auth_provider_test.dart test/features/profile/token_authentication_service_test.dart test/features/profile/profile_sub_pages_test.dart
```

- [ ] 运行全部聚焦测试：

```bash
flutter test test/core/network/api_client_test.dart test/core/network/interceptors/signature_auth_interceptor_test.dart test/core/network/interceptors/response_interceptor_test.dart test/core/providers/auth_provider_test.dart test/features/profile/token_authentication_service_test.dart test/features/profile/profile_sub_pages_test.dart
```

- [ ] 运行完整测试：

```bash
flutter test --reporter compact
```

- [ ] 运行静态分析：

```bash
flutter analyze
```

- [ ] 检查补丁完整性与工作区范围：

```bash
git diff --check
git status --short
git log --oneline -5
```

Expected:

- 所有测试通过；
- `flutter analyze` 输出 `No issues found!`；
- `git diff --check` 无输出；
- 仅存在本计划范围内的提交或用户原有变更；
- 不主动推送远端。
