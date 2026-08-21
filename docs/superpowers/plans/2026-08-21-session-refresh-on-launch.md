# 进入应用时校验登录会话并刷新用户缓存 实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 每次进入应用（冷启动），若已登录则调用用户信息接口刷新缓存并校验 token；失效则登出并跳转登录页提示重新登录。

**架构：** 新增独立 `SessionRefreshService` 封装"已登录判断 → 调 `/api/v1/users` 校验 → 成功更新缓存 / 鉴权失败登出 / 网络错误保留会话"的决策，返回 `SessionRefreshStatus`；`AuthProvider` 增加 `updateUser()` 刷新会话；`StartupPage` 在 startup 成功后调用该服务并按结果导航；`LoginPage` 识别 `reason=expired` 查询参数显示过期提示。

**技术栈：** Flutter / Dart（null safety）、provider、go_router、dio、shared_preferences、flutter_test。

**设计文档：** `docs/superpowers/specs/2026-08-21-session-refresh-on-launch-design.md`

---

## 文件结构

| 文件 | 职责 |
|------|------|
| 创建 `lib/core/services/session_refresh_service.dart` | `SessionRefreshStatus` 枚举 + `SessionRefreshService` 接口 + `ApiSessionRefreshService` 实现（校验/更新/登出决策） |
| 修改 `lib/core/providers/auth_provider.dart` | 新增 `updateUser(Map<String, dynamic>)`：token 不变、刷新 user、持久化、notify |
| 修改 `lib/features/startup/screens/startup_screen.dart` | startup 成功后调用 refresh，按结果导航 home 或 login?reason=expired |
| 修改 `lib/features/auth/screens/login_screen.dart` | 读取 `reason` 查询参数，`expired` 时显示『登录已过期，请重新登录』 |
| 创建 `test/core/services/session_refresh_service_test.dart` | Service 决策矩阵单测（skipped/success/expired/failure） |
| 修改 `test/core/providers/auth_provider_test.dart` | `updateUser` 行为单测 |
| 修改 `test/features/startup/startup_screen_test.dart` | 启动页按 refresh 结果导航测试 |
| 修改 `test/features/auth/login_screen_test.dart` | `reason=expired` 提示条测试 |

---

## 任务 1：`AuthProvider.updateUser`

**文件：**
- 修改：`lib/core/providers/auth_provider.dart`（在 `logout()` 之后、类结尾 `}` 之前新增方法）
- 测试：`test/core/providers/auth_provider_test.dart`（在 `main()` 内、`logout` 测试之后新增用例）

### 关键知识

- `_persistSession(String, {required String failureMessage})` 已存在，负责权威会话写入 + 失败重载
- 测试中 `_ControlledSharedPreferences` 已有 `setStringKeys` 记录与 `failSessionWrite` / `sessionWriteError` 注入
- `notifyListeners()` 需要 `addListener` 观察

- [ ] **步骤 1：编写失败的测试**

在 `test/core/providers/auth_provider_test.dart` 的 `main()` 中、现有 `logout` 测试之后追加：

```dart
  test('updateUser 保留 token、刷新 user 并持久化', () async {
    final prefs = _ControlledSharedPreferences();
    final auth = await AuthProvider.create(prefs);
    final listener = _RecordingListener();
    auth.addListener(listener.onChanged);
    await auth.login(
      token: 'session-token',
      user: {'id': 1, 'username': 'old-user', 'want_watch_count': 1},
    );
    listener.calls = 0;

    await auth.updateUser({
      'id': 1,
      'username': 'fresh-user',
      'want_watch_count': 5,
      'watched_count': 3,
    });

    expect(auth.token, 'session-token');
    expect(auth.user, {
      'id': 1,
      'username': 'fresh-user',
      'want_watch_count': 5,
      'watched_count': 3,
    });
    expect(auth.isLogged, isTrue);
    expect(listener.calls, 1);
    final storedSession = prefs.getString(_authSessionKey);
    expect(jsonDecode(storedSession!), {
      'token': 'session-token',
      'user': {
        'id': 1,
        'username': 'fresh-user',
        'want_watch_count': 5,
        'watched_count': 3,
      },
    });
  });

  test('updateUser 未登录时为空操作', () async {
    final prefs = _ControlledSharedPreferences();
    final auth = await AuthProvider.create(prefs);

    await auth.updateUser({'id': 1, 'username': 'ghost-user'});

    expect(auth.token, isNull);
    expect(auth.user, isNull);
    expect(prefs.setStringKeys, isEmpty);
  });
```

在文件底部（`_SessionWriteException` 类之后）追加辅助类：

```dart
final class _RecordingListener {
  var calls = 0;
  void onChanged() => calls++;
}
```

- [ ] **步骤 2：运行测试验证失败**

运行：`flutter test test/core/providers/auth_provider_test.dart`
预期：FAIL，报错 "The method 'updateUser' isn't defined"

- [ ] **步骤 3：实现 `updateUser`**

在 `lib/core/providers/auth_provider.dart` 的 `logout()` 方法之后、类末尾 `}` 之前插入：

```dart
  /// 用最新用户信息刷新当前会话（token 不变，写回持久化并通知 UI）。
  ///
  /// 未登录时为空操作（不写持久化、不通知）。
  Future<void> updateUser(Map<String, dynamic> user) async {
    final currentToken = _token;
    if (currentToken == null || currentToken.isEmpty) return;
    await _persistSession(
      jsonEncode({'token': currentToken, 'user': user}),
      failureMessage: 'Failed to persist refreshed session',
    );
    _user = Map<String, dynamic>.from(user);
    notifyListeners();
  }
```

- [ ] **步骤 4：运行测试验证通过**

运行：`flutter test test/core/providers/auth_provider_test.dart`
预期：PASS（原有 + 新增共 8 个用例）

- [ ] **步骤 5：Commit**

```bash
git add lib/core/providers/auth_provider.dart test/core/providers/auth_provider_test.dart
git commit -m "feat(auth): AuthProvider.updateUser 刷新用户缓存且 token 不变"
```

---

## 任务 2：`SessionRefreshService`

**文件：**
- 创建：`lib/core/services/session_refresh_service.dart`
- 测试：`test/core/services/session_refresh_service_test.dart`（新建，目录 `test/core/services/` 需创建）

### 关键知识

- `ApiTokenAuthenticationService.authenticate(token)` 成功返回 `Map<String, dynamic>` user；鉴权失败经 `ResponseInterceptor` reject 为 `DioException(error: ApiException)`；HTTP 401 无 body action 时为纯 `DioException(response.statusCode == 401)`
- `ApiException.isAuthError`：`JWTVerificationError` / `NonExistentUser`
- `AuthProvider.login(token:, user:)` / `logout()` / `isLogged` / `token` / `user`
- 测试用 `SharedPreferences.setMockInitialValues({})` + `AuthProvider.create(prefs)` 构造真实 AuthProvider，注入假 `TokenAuthenticationService`

- [ ] **步骤 1：编写失败的测试**

创建 `test/core/services/session_refresh_service_test.dart`：

```dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/network/api_exception.dart';
import 'package:jade/core/providers/auth_provider.dart';
import 'package:jade/core/services/session_refresh_service.dart';
import 'package:jade/features/profile/services/token_authentication_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

final class _FakeTokenAuthenticationService
    implements TokenAuthenticationService {
  _FakeTokenAuthenticationService(this._onAuthenticate);

  final Future<Map<String, dynamic>> Function(String token) _onAuthenticate;
  int calls = 0;

  @override
  Future<Map<String, dynamic>> authenticate(String token) {
    calls++;
    return _onAuthenticate(token);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<(AuthProvider, _FakeTokenAuthenticationService)>
      _loggedInService({
    required Future<Map<String, dynamic>> Function(String) onAuthenticate,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final auth = await AuthProvider.create(prefs);
    await auth.login(
      token: 'session-token',
      user: {'id': 1, 'username': 'cached-user'},
    );
    final tokenAuthentication = _FakeTokenAuthenticationService(onAuthenticate);
    return (auth, tokenAuthentication);
  }

  test('未登录时返回 skipped 且不调用接口', () async {
    final prefs = await SharedPreferences.getInstance();
    final auth = await AuthProvider.create(prefs);
    final tokenAuthentication = _FakeTokenAuthenticationService(
      (_) => throw StateError('不应调用'),
    );
    final service = ApiSessionRefreshService(
      auth: auth,
      tokenAuthentication: tokenAuthentication,
    );

    final status = await service.refresh();

    expect(status, SessionRefreshStatus.skipped);
    expect(tokenAuthentication.calls, 0);
  });

  test('校验成功时更新用户缓存并返回 success', () async {
    final (auth, tokenAuthentication) = await _loggedInService(
      onAuthenticate: (_) async => {
        'id': 1,
        'username': 'fresh-user',
        'want_watch_count': 7,
      },
    );
    final service = ApiSessionRefreshService(
      auth: auth,
      tokenAuthentication: tokenAuthentication,
    );

    final status = await service.refresh();

    expect(status, SessionRefreshStatus.success);
    expect(tokenAuthentication.calls, 1);
    expect(auth.token, 'session-token');
    expect(auth.user, {
      'id': 1,
      'username': 'fresh-user',
      'want_watch_count': 7,
    });
    expect(auth.isLogged, isTrue);
  });

  test('鉴权失败时登出并返回 expired', () async {
    final (auth, tokenAuthentication) = await _loggedInService(
      onAuthenticate: (_) async =>
          throw const ApiException(action: ApiErrorActions.jwtVerificationError),
    );
    final service = ApiSessionRefreshService(
      auth: auth,
      tokenAuthentication: tokenAuthentication,
    );

    final status = await service.refresh();

    expect(status, SessionRefreshStatus.expired);
    expect(auth.isLogged, isFalse);
    expect(auth.token, isNull);
    expect(auth.user, isNull);
  });

  test('HTTP 401 时登出并返回 expired', () async {
    final (auth, tokenAuthentication) = await _loggedInService(
      onAuthenticate: (_) async => throw DioException(
        requestOptions: RequestOptions(path: '/api/v1/users'),
        response: Response(
          requestOptions: RequestOptions(path: '/api/v1/users'),
          statusCode: 401,
          statusMessage: 'Unauthorized',
        ),
      ),
    );
    final service = ApiSessionRefreshService(
      auth: auth,
      tokenAuthentication: tokenAuthentication,
    );

    final status = await service.refresh();

    expect(status, SessionRefreshStatus.expired);
    expect(auth.isLogged, isFalse);
  });

  test('网络错误时保留会话并返回 failure', () async {
    final (auth, tokenAuthentication) = await _loggedInService(
      onAuthenticate: (_) async => throw DioException(
        requestOptions: RequestOptions(path: '/api/v1/users'),
        type: DioExceptionType.connectionTimeout,
      ),
    );
    final service = ApiSessionRefreshService(
      auth: auth,
      tokenAuthentication: tokenAuthentication,
    );

    final status = await service.refresh();

    expect(status, SessionRefreshStatus.failure);
    expect(auth.isLogged, isTrue);
    expect(auth.token, 'session-token');
  });

  test('非鉴权 ApiException 保留会话并返回 failure', () async {
    final (auth, tokenAuthentication) = await _loggedInService(
      onAuthenticate: (_) async =>
          throw const ApiException(action: ApiErrorActions.parameterInvalid),
    );
    final service = ApiSessionRefreshService(
      auth: auth,
      tokenAuthentication: tokenAuthentication,
    );

    final status = await service.refresh();

    expect(status, SessionRefreshStatus.failure);
    expect(auth.isLogged, isTrue);
  });
}
```

- [ ] **步骤 2：运行测试验证失败**

运行：`flutter test test/core/services/session_refresh_service_test.dart`
预期：FAIL，报错 "Target of URI doesn't exist"（`package:jade/core/services/session_refresh_service.dart` 不存在）

- [ ] **步骤 3：实现 Service**

创建 `lib/core/services/session_refresh_service.dart`：

```dart
import 'package:dio/dio.dart';
import 'package:jade/core/network/api_exception.dart';
import 'package:jade/core/providers/auth_provider.dart';
import 'package:jade/features/profile/services/token_authentication_service.dart';

/// 会话刷新结果。
enum SessionRefreshStatus {
  /// 校验成功，缓存已用最新用户信息刷新。
  success,

  /// 鉴权失败（token 过期/用户不存在），会话已登出。
  expired,

  /// 未登录，跳过校验。
  skipped,

  /// 网络或服务端错误，保留原会话。
  failure,
}

/// 进入应用时校验登录会话并刷新用户缓存。
abstract interface class SessionRefreshService {
  /// 校验当前会话；已登录则调用用户信息接口，按结果更新缓存或登出。
  Future<SessionRefreshStatus> refresh();
}

/// 基于 [AuthProvider] 与 [TokenAuthenticationService] 的默认实现。
final class ApiSessionRefreshService implements SessionRefreshService {
  ApiSessionRefreshService({
    required AuthProvider auth,
    required TokenAuthenticationService tokenAuthentication,
  }) : _auth = auth,
       _tokenAuthentication = tokenAuthentication;

  final AuthProvider _auth;
  final TokenAuthenticationService _tokenAuthentication;

  @override
  Future<SessionRefreshStatus> refresh() async {
    final token = _auth.token;
    if (token == null || token.isEmpty) {
      return SessionRefreshStatus.skipped;
    }
    try {
      final user = await _tokenAuthentication.authenticate(token);
      await _auth.updateUser(user);
      return SessionRefreshStatus.success;
    } on ApiException catch (error) {
      if (error.isAuthError) {
        await _auth.logout();
        return SessionRefreshStatus.expired;
      }
      return SessionRefreshStatus.failure;
    } on DioException catch (error) {
      final cause = error.error;
      if (error.response?.statusCode == 401 ||
          (cause is ApiException && cause.isAuthError)) {
        await _auth.logout();
        return SessionRefreshStatus.expired;
      }
      return SessionRefreshStatus.failure;
    } catch (_) {
      return SessionRefreshStatus.failure;
    }
  }
}
```

- [ ] **步骤 4：运行测试验证通过**

运行：`flutter test test/core/services/session_refresh_service_test.dart`
预期：PASS（6 个用例）

- [ ] **步骤 5：Commit**

```bash
git add lib/core/services/session_refresh_service.dart test/core/services/session_refresh_service_test.dart
git commit -m "feat(auth): 新增 SessionRefreshService 校验会话并刷新用户缓存"
```

---

## 任务 3：`StartupPage` 串联校验并导航

**文件：**
- 修改：`lib/features/startup/screens/startup_screen.dart`
- 测试：`test/features/startup/startup_screen_test.dart`

### 关键知识

- 现 `_load()`：`provider.load()` 成功且 mounted → `context.go(AppRoutes.home)`
- 现测试 `_pumpSubject` 只注入 `StartupProvider`；需扩展注入 `AuthProvider` 与假 `SessionRefreshService`，并在路由中加 `/login` 路由
- `AppRoutes.login` = `/login`；登录过期跳转 `'/login?from=%2Fhome&reason=expired'`（`from` 需 `Uri.encodeComponent`）
- `ApiClient.instance` 为单例，仅默认构造（未注入 service）时使用

- [ ] **步骤 1：编写失败的测试**

重写 `test/features/startup/startup_screen_test.dart` 的 `_pumpSubject` 与新增用例（保留原有两个用例，仅扩展 `_pumpSubject` 签名，原有调用处传 `auth: null` 或对应值）：

```dart
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jade/core/models/startup.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/domain_manager.dart';
import 'package:jade/core/network/startup_api_client.dart';
import 'package:jade/core/providers/auth_provider.dart';
import 'package:jade/core/providers/startup_provider.dart';
import 'package:jade/core/services/session_refresh_service.dart';
import 'package:jade/features/startup/screens/startup_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeStartupApi implements StartupApi {
  _FakeStartupApi(this.responses);

  final List<FutureOr<StartupData> Function()> responses;
  int calls = 0;

  @override
  Future<StartupData> fetchStartup() async {
    final response = responses[calls];
    calls += 1;
    return response();
  }
}

final class _FakeSessionRefreshService implements SessionRefreshService {
  _FakeSessionRefreshService(this._result);

  final Future<SessionRefreshStatus> Function() _result;
  int calls = 0;

  @override
  Future<SessionRefreshStatus> refresh() {
    calls++;
    return _result();
  }
}

Future<StartupProvider> _createProvider(StartupApi startupApi) async {
  final prefs = await SharedPreferences.getInstance();
  final domainManager = await DomainManager.load(prefs);
  final apiClient = ApiClient.forTest(
    dio: Dio(BaseOptions(baseUrl: domainManager.currentUrl)),
    domainManager: domainManager,
  );
  return StartupProvider.create(
    startupApi: startupApi,
    apiClient: apiClient,
    domainManager: domainManager,
    decoder: (_) => const BackupDomains(apiDomains: ['https://backup.example']),
  );
}

Future<GoRouter> _pumpSubject(
  WidgetTester tester,
  StartupProvider provider, {
  AuthProvider? auth,
  SessionRefreshService? sessionRefreshService,
}) async {
  final router = GoRouter(
    initialLocation: '/startup',
    routes: [
      GoRoute(
        path: '/startup',
        builder: (context, state) => StartupPage(
          sessionRefreshService: sessionRefreshService,
        ),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const Scaffold(body: Text('测试首页')),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const Scaffold(body: Text('测试登录页')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: provider),
        if (auth != null) ChangeNotifierProvider.value(value: auth),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  return router;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('首次显示只发起一次请求并展示加载指示器', (tester) async {
    final completer = Completer<StartupData>();
    final api = _FakeStartupApi([() => completer.future]);
    final provider = await _createProvider(api);

    await _pumpSubject(tester, provider);
    await tester.pump();
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('测试首页'), findsNothing);
    expect(api.calls, 1);
  });

  testWidgets('失败后显示提示和重试按钮，重试成功后 go 到首页', (tester) async {
    final api = _FakeStartupApi([
      () => throw DioException(
        requestOptions: RequestOptions(path: '/api/v1/startup'),
      ),
      () => const StartupData(backupDomainsData: 'ciphertext'),
    ]);
    final provider = await _createProvider(api);
    // 注入未登录的 AuthProvider：重试成功后 _refreshSessionThenNavigate
    // 会 context.read<AuthProvider>()，未登录分支直接 go 首页。
    final prefs = await SharedPreferences.getInstance();
    final auth = await AuthProvider.create(prefs);
    final router = await _pumpSubject(tester, provider, auth: auth);

    await tester.pumpAndSettle();
    expect(find.text('启动失败，请检查网络后重试'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
    expect(router.state.uri.path, '/startup');

    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();

    expect(api.calls, 2);
    expect(router.state.uri.path, '/home');
    expect(find.text('测试首页'), findsOneWidget);
    expect(router.canPop(), isFalse);
  });

  testWidgets('已登录且校验成功时 go 首页', (tester) async {
    final api = _FakeStartupApi([
      () => const StartupData(backupDomainsData: 'ciphertext'),
    ]);
    final provider = await _createProvider(api);
    final prefs = await SharedPreferences.getInstance();
    final auth = await AuthProvider.create(prefs);
    await auth.login(
      token: 'session-token',
      user: {'id': 1, 'username': 'cached-user'},
    );
    final refresh = _FakeSessionRefreshService(
      () async => SessionRefreshStatus.success,
    );

    final router = await _pumpSubject(
      tester,
      provider,
      auth: auth,
      sessionRefreshService: refresh,
    );
    await tester.pumpAndSettle();

    expect(refresh.calls, 1);
    expect(router.state.uri.path, '/home');
  });

  testWidgets('校验过期时 go 登录页并带 reason=expired', (tester) async {
    final api = _FakeStartupApi([
      () => const StartupData(backupDomainsData: 'ciphertext'),
    ]);
    final provider = await _createProvider(api);
    final prefs = await SharedPreferences.getInstance();
    final auth = await AuthProvider.create(prefs);
    await auth.login(
      token: 'session-token',
      user: {'id': 1, 'username': 'cached-user'},
    );
    final refresh = _FakeSessionRefreshService(
      () async => SessionRefreshStatus.expired,
    );

    final router = await _pumpSubject(
      tester,
      provider,
      auth: auth,
      sessionRefreshService: refresh,
    );
    await tester.pumpAndSettle();

    expect(refresh.calls, 1);
    expect(router.state.uri.path, '/login');
    expect(router.state.uri.queryParameters['reason'], 'expired');
  });

  testWidgets('校验网络失败时保留会话并 go 首页', (tester) async {
    final api = _FakeStartupApi([
      () => const StartupData(backupDomainsData: 'ciphertext'),
    ]);
    final provider = await _createProvider(api);
    final prefs = await SharedPreferences.getInstance();
    final auth = await AuthProvider.create(prefs);
    await auth.login(
      token: 'session-token',
      user: {'id': 1, 'username': 'cached-user'},
    );
    final refresh = _FakeSessionRefreshService(
      () async => SessionRefreshStatus.failure,
    );

    final router = await _pumpSubject(
      tester,
      provider,
      auth: auth,
      sessionRefreshService: refresh,
    );
    await tester.pumpAndSettle();

    expect(refresh.calls, 1);
    expect(auth.isLogged, isTrue);
    expect(router.state.uri.path, '/home');
  });

  testWidgets('未登录时不调用校验直接 go 首页', (tester) async {
    final api = _FakeStartupApi([
      () => const StartupData(backupDomainsData: 'ciphertext'),
    ]);
    final provider = await _createProvider(api);
    final prefs = await SharedPreferences.getInstance();
    final auth = await AuthProvider.create(prefs);
    final refresh = _FakeSessionRefreshService(
      () async => SessionRefreshStatus.skipped,
    );

    final router = await _pumpSubject(
      tester,
      provider,
      auth: auth,
      sessionRefreshService: refresh,
    );
    await tester.pumpAndSettle();

    expect(refresh.calls, 0);
    expect(router.state.uri.path, '/home');
  });
}
```

- [ ] **步骤 2：运行测试验证失败**

运行：`flutter test test/features/startup/startup_screen_test.dart`
预期：FAIL，编译错误 "The named parameter 'sessionRefreshService' isn't defined"

- [ ] **步骤 3：实现 StartupPage 串联**

修改 `lib/features/startup/screens/startup_screen.dart` 为：

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/providers/auth_provider.dart';
import 'package:jade/core/providers/startup_provider.dart';
import 'package:jade/core/router/routes.dart';
import 'package:jade/core/services/session_refresh_service.dart';
import 'package:jade/features/profile/services/token_authentication_service.dart';
import 'package:provider/provider.dart';

class StartupPage extends StatefulWidget {
  const StartupPage({super.key, this.sessionRefreshService});

  final SessionRefreshService? sessionRefreshService;

  @override
  State<StartupPage> createState() => _StartupPageState();
}

class _StartupPageState extends State<StartupPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
    });
  }

  Future<void> _load({bool retry = false}) async {
    final provider = context.read<StartupProvider>();
    final succeeded = retry ? await provider.retry() : await provider.load();
    if (!succeeded || !mounted) return;
    await _refreshSessionThenNavigate();
  }

  Future<void> _refreshSessionThenNavigate() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isLogged) {
      context.go(AppRoutes.home);
      return;
    }
    final service =
        widget.sessionRefreshService ??
        ApiSessionRefreshService(
          auth: auth,
          tokenAuthentication: ApiTokenAuthenticationService(
            ApiClient.instance,
          ),
        );
    final status = await service.refresh();
    if (!mounted) return;
    if (status == SessionRefreshStatus.expired) {
      context.go(
        '${AppRoutes.login}?from=${Uri.encodeComponent(AppRoutes.home)}&reason=expired',
      );
      return;
    }
    context.go(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    final startup = context.watch<StartupProvider>();
    final failed = startup.status == StartupStatus.failure;
    return Scaffold(
      body: Center(
        child: failed
            ? Column(
                mainAxisSize: MainAxisSize.min,
                spacing: 16,
                children: [
                  Text(
                    startup.errorMessage ?? StartupProvider.failureMessage,
                    textAlign: TextAlign.center,
                  ),
                  FilledButton(
                    onPressed: () => _load(retry: true),
                    child: const Text('重试'),
                  ),
                ],
              )
            : const CircularProgressIndicator(),
      ),
    );
  }
}
```

- [ ] **步骤 4：运行测试验证通过**

运行：`flutter test test/features/startup/startup_screen_test.dart`
预期：PASS（6 个用例）

- [ ] **步骤 5：Commit**

```bash
git add lib/features/startup/screens/startup_screen.dart test/features/startup/startup_screen_test.dart
git commit -m "feat(startup): 启动页校验会话，过期跳转登录页提示重新登录"
```

---

## 任务 4：`LoginPage` 显示登录过期提示

**文件：**
- 修改：`lib/features/auth/screens/login_screen.dart`
- 测试：`test/features/auth/login_screen_test.dart`

### 关键知识

- `LoginPage.build` 中 `final from = GoRouterState.of(context).uri.queryParameters['from'] ?? '';` 已存在，同样方式读 `reason`
- 提示条放在 `if (hasFrom)` 的 '请登录后继续' 文本之后、第一个 `TextField` 之前
- `_pumpLogin` 的 `initialLocation: '/login'` 需支持带查询参数的变体

- [ ] **步骤 1：编写失败的测试**

在 `test/features/auth/login_screen_test.dart` 的 `main()` 内追加：

```dart
  testWidgets('reason=expired 时显示登录过期提示条', (tester) async {
    final store = _MemoryLoginCredentialStore();
    await _pumpLogin(tester, credentialStore: store, initialLocation: '/login?reason=expired');

    expect(find.text('登录已过期，请重新登录'), findsOneWidget);
  });

  testWidgets('无 reason 参数时不显示登录过期提示条', (tester) async {
    final store = _MemoryLoginCredentialStore();
    await _pumpLogin(tester, credentialStore: store);

    expect(find.text('登录已过期，请重新登录'), findsNothing);
  });
```

将 `_pumpLogin` 签名改为 `Future<({AuthProvider auth, FakeAdapter adapter, GoRouter router})> _pumpLogin(WidgetTester tester, {required LoginCredentialStore credentialStore, Map<String, dynamic>? response, bool settle = true, String initialLocation = '/login'})`，并把 `initialLocation: '/login'` 处改为 `initialLocation: initialLocation`。

- [ ] **步骤 2：运行测试验证失败**

运行：`flutter test test/features/auth/login_screen_test.dart`
预期：FAIL，`find.text('登录已过期，请重新登录')` findsNothing

- [ ] **步骤 3：实现提示条**

修改 `lib/features/auth/screens/login_screen.dart` 的 `build` 方法：在 `final hasFrom = from.isNotEmpty;` 之后新增 `reason` 读取，并在 '请登录后继续' 的 `if (hasFrom) Padding` 块之后、`TextField`（邮箱）之前插入提示条：

```dart
    final reason = GoRouterState.of(context).uri.queryParameters['reason'];
    final sessionExpired = reason == 'expired';
```

```dart
              if (sessionExpired)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    '登录已过期，请重新登录',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
```

- [ ] **步骤 4：运行测试验证通过**

运行：`flutter test test/features/auth/login_screen_test.dart`
预期：PASS（原有 + 新增共 9 个用例）

- [ ] **步骤 5：Commit**

```bash
git add lib/features/auth/screens/login_screen.dart test/features/auth/login_screen_test.dart
git commit -m "feat(auth): 登录页识别 reason=expired 显示登录过期提示"
```

---

## 任务 5：全量验证

- [ ] **步骤 1：运行全部相关测试**

运行：`flutter test test/core/providers/auth_provider_test.dart test/core/services/session_refresh_service_test.dart test/features/startup/startup_screen_test.dart test/features/auth/login_screen_test.dart`
预期：全部 PASS

- [ ] **步骤 2：运行静态分析**

运行：`flutter analyze`
预期：No issues found（或仅与本次改动无关的既有告警）

- [ ] **步骤 3：运行全量测试确认无回归**

运行：`flutter test`
预期：全部 PASS

- [ ] **步骤 4：Commit（如有遗漏改动）**

```bash
git status
git add -A
git commit -m "chore: session refresh 全量验证"
```

（若 `git status` 无未提交改动则跳过本步）
