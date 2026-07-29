# 启动域名引导 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (
> recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** 每次应用启动时固定通过 `https://jdforrepam.com` 获取备用域名，成功后使用
`router.go('/home')` 进入首页，并让后续业务请求立即使用新域名；失败时停留加载页并支持手动重试。

**Architecture:** 新建只负责 `/api/v1/startup` 的 `StartupApiClient`，它与会恢复持久化域名、支持轮转的业务
`ApiClient` 完全分离。`StartupProvider` 负责校验和应用备用域名并同步业务客户端，启动页只负责呈现状态和导航，从而让网络、状态、界面三层可以独立测试。

**Tech Stack:** Flutter、Dart 3.8、Provider、Dio、GoRouter、SharedPreferences、flutter_test。

## Global Constraints

- 启动客户端的 `baseUrl` 必须固定为 `AppConstants.fallbackBaseUrl`，当前值为
  `https://jdforrepam.com`。
- 启动请求不得读取历史业务域名，不得安装认证或域名轮转拦截器。
- 成功响应必须包含可解密且 `apiDomains` 非空的备用域名数据。
- 成功前不得进入首页，也不得使用上次保存的业务域名绕过本次启动。
- 失败状态统一显示“启动失败，请检查网络后重试”和“重试”。
- 成功后必须调用 `router.go(AppRoutes.home)`，不能使用 `push`。
- 不新增依赖；中文文案按项目 `RULES.md` 直接硬编码。
- 保留现有业务 `DomainSwitchInterceptor` 的 HTTP 608 轮转能力。

---

## File Structure

- Create `lib/core/network/startup_api_client.dart`: 固定主域启动接口及其可替换抽象。
- Modify `lib/core/providers/startup_provider.dart`: 启动状态、域名校验、持久化与业务客户端同步。
- Create `lib/features/startup/screens/startup_screen.dart`: 加载、失败、重试和成功导航。
- Create `lib/features/startup/index.dart`: 启动 feature 的公开页面入口。
- Modify `lib/core/router/routes.dart`: 声明 `/startup`。
- Modify `lib/core/router/app_router.dart`: 注册启动页并将生产默认初始地址改为 `/startup`。
- Modify `lib/main.dart`: 创建启动客户端，移除 fire-and-forget 启动请求。
- Create `test/core/network/startup_api_client_test.dart`: 固定主域和启动请求参数契约。
- Create `test/core/providers/startup_provider_test.dart`: Provider 成功、失败和防重入状态。
- Create `test/features/startup/startup_screen_test.dart`: 启动页错误重试和 `go` 导航。
- Modify `test/core/router/app_router_auth_test.dart`: 对既有认证测试显式指定 `/home`。
- Modify `test/app_test.dart`: 验证应用入口先渲染启动加载页且不提前显示首页。

---

### Task 1: 固定主域启动请求客户端

**Files:**

- Create: `lib/core/network/startup_api_client.dart`
- Create: `test/core/network/startup_api_client_test.dart`

**Interfaces:**

- Consumes: `AppConstants.fallbackBaseUrl`、`Endpoints.startup`、`SignatureInterceptor`、
  `ResponseLoggingInterceptor`、`ResponseInterceptor`。
- Produces: `abstract interface class StartupApi`，包含 `Future<StartupData> fetchStartup()`；
  `StartupApiClient.create()`；`StartupApiClient.setAdapterForTest(HttpClientAdapter adapter)`。

- [ ] **Step 1: Write the failing fixed-domain contract test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/constants/app_constants.dart';
import 'package:jade/core/network/endpoints.dart';
import 'package:jade/core/network/startup_api_client.dart';
import 'package:jade/core/network/testing/fake_adapter.dart';

void main() {
  test('启动请求固定使用 jdforrepam.com 并携带完整参数和签名', () async {
    final adapter = FakeAdapter()
      ..enqueue(Endpoints.startup, {
        'success': 1,
        'data': {'backup_domains_data': 'ciphertext'},
      });
    final client = StartupApiClient.create()
      ..setAdapterForTest(adapter);

    final result = await client.fetchStartup();

    expect(result.backupDomainsData, 'ciphertext');
    final request = adapter.requests.single;
    expect(request.uri.origin, AppConstants.fallbackBaseUrl);
    expect(request.uri.path, Endpoints.startup);
    expect(request.uri.queryParameters, {
      'last_ad_id': '',
      'platform': 'android',
      'app_channel': 'google',
      'app_version': '1.9.29',
      'app_version_number': '35',
    });
    expect(request.headers['jdsignature'], isNotEmpty);
  });
}
```

- [ ] **Step 2: Run the test and verify RED**

Run:

```bash
flutter test test/core/network/startup_api_client_test.dart
```

Expected: FAIL because `startup_api_client.dart` and `StartupApiClient` do not exist.

- [ ] **Step 3: Implement the minimal fixed-domain client**

Create `lib/core/network/startup_api_client.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:jade/core/constants/app_constants.dart';
import 'package:jade/core/models/startup.dart';
import 'package:jade/core/network/endpoints.dart';
import 'package:jade/core/network/interceptors/response_interceptor.dart';
import 'package:jade/core/network/interceptors/response_logging_interceptor.dart';
import 'package:jade/core/network/interceptors/signature_interceptor.dart';

abstract interface class StartupApi {
  Future<StartupData> fetchStartup();
}

class StartupApiClient implements StartupApi {
  StartupApiClient._(this._dio);

  final Dio _dio;

  static StartupApiClient create() {
    final dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.fallbackBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
      ),
    );
    dio.interceptors.addAll([
      SignatureInterceptor(),
      ResponseLoggingInterceptor(),
      ResponseInterceptor(onAuthError: () {}),
    ]);
    return StartupApiClient._(dio);
  }

  @override
  Future<StartupData> fetchStartup() async {
    final response = await _dio.get<Map<String, dynamic>>(
      Endpoints.startup,
      queryParameters: const {
        'last_ad_id': '',
        'platform': 'android',
        'app_channel': 'google',
        'app_version': '1.9.29',
        'app_version_number': '35',
      },
    );
    return StartupData.fromJson(response.data ?? const {});
  }

  void setAdapterForTest(HttpClientAdapter adapter) {
    _dio.httpClientAdapter = adapter;
  }
}
```

- [ ] **Step 4: Format and verify GREEN**

Run:

```bash
dart format lib/core/network/startup_api_client.dart test/core/network/startup_api_client_test.dart
flutter test test/core/network/startup_api_client_test.dart
```

Expected: PASS; recorded request origin is `https://jdforrepam.com`.

- [ ] **Step 5: Commit the fixed-domain client**

```bash
git add lib/core/network/startup_api_client.dart test/core/network/startup_api_client_test.dart
git commit -m "feat: add fixed-domain startup client"
```

---

### Task 2: 启动状态和业务域名同步

**Files:**

- Modify: `lib/core/providers/startup_provider.dart`
- Create: `test/core/providers/startup_provider_test.dart`

**Interfaces:**

- Consumes: `StartupApi.fetchStartup()`、`BackupDomainsDecryptor.decrypt(String)`、
  `DomainManager.applyStartup(BackupDomains)`、`ApiClient.swapBaseUrl(String)`。
- Produces: `enum StartupStatus { idle, loading, success, failure }`；
  `typedef StartupDomainsDecoder = BackupDomains Function(String data)`；
  `StartupProvider.create({required StartupApi startupApi, required ApiClient apiClient, required DomainManager domainManager, StartupDomainsDecoder decoder = BackupDomainsDecryptor.decrypt})`；
  `Future<bool> load()`；`Future<bool> retry()`；`StartupStatus status`；`String? errorMessage`。

- [ ] **Step 1: Write failing Provider success and failure tests**

Create `test/core/providers/startup_provider_test.dart`:

```dart
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/models/startup.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/domain_manager.dart';
import 'package:jade/core/network/startup_api_client.dart';
import 'package:jade/core/providers/startup_provider.dart';
import 'package:jade/core/storage/storage_keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeStartupApi implements StartupApi {
  _FakeStartupApi(this._responses);

  final List<FutureOr<StartupData> Function()> _responses;
  int calls = 0;

  @override
  Future<StartupData> fetchStartup() async {
    final response = _responses[calls];
    calls += 1;
    return response();
  }
}

Future<({
  StartupProvider provider,
  ApiClient apiClient,
  DomainManager domainManager,
  SharedPreferences prefs,
})> _createSubject(StartupApi startupApi) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(StorageKeys.baseUrl, 'https://old.example');
  await prefs.setStringList(
    StorageKeys.apiDomains,
    ['https://old.example'],
  );
  final domainManager = await DomainManager.load(prefs);
  final apiClient = ApiClient.forTest(
    dio: Dio(BaseOptions(baseUrl: domainManager.currentUrl)),
    domainManager: domainManager,
  );
  final provider = StartupProvider.create(
    startupApi: startupApi,
    apiClient: apiClient,
    domainManager: domainManager,
    decoder: (_) => const BackupDomains(
      apiDomains: ['https://backup.example'],
      imageEndpoint: 'https://images.example',
    ),
  );
  return (
    provider: provider,
    apiClient: apiClient,
    domainManager: domainManager,
    prefs: prefs,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('成功时应用备用域名并同步业务客户端', () async {
    final api = _FakeStartupApi([
      () => const StartupData(backupDomainsData: 'ciphertext'),
    ]);
    final subject = await _createSubject(api);

    final succeeded = await subject.provider.load();

    expect(succeeded, isTrue);
    expect(subject.provider.status, StartupStatus.success);
    expect(subject.domainManager.currentUrl, 'https://backup.example');
    expect(subject.apiClient.dio.options.baseUrl, 'https://backup.example');
    expect(
      subject.prefs.getString(StorageKeys.baseUrl),
      'https://backup.example',
    );
  });

  test('缺少域名数据时失败并保留在启动状态', () async {
    final api = _FakeStartupApi([
      () => const StartupData(),
    ]);
    final subject = await _createSubject(api);

    final succeeded = await subject.provider.load();

    expect(succeeded, isFalse);
    expect(subject.provider.status, StartupStatus.failure);
    expect(
      subject.provider.errorMessage,
      '启动失败，请检查网络后重试',
    );
    expect(subject.apiClient.dio.options.baseUrl, 'https://old.example');
  });

  test('空域名列表时失败且不覆盖历史业务域名', () async {
    final api = _FakeStartupApi([
      () => const StartupData(backupDomainsData: 'ciphertext'),
    ]);
    final subject = await _createSubject(api);
    final provider = StartupProvider.create(
      startupApi: api,
      apiClient: subject.apiClient,
      domainManager: subject.domainManager,
      decoder: (_) => const BackupDomains(apiDomains: []),
    );

    final succeeded = await provider.load();

    expect(succeeded, isFalse);
    expect(provider.status, StartupStatus.failure);
    expect(subject.domainManager.currentUrl, 'https://old.example');
  });

  test('加载期间忽略重复触发', () async {
    final completer = Completer<StartupData>();
    final api = _FakeStartupApi([
      () => completer.future,
    ]);
    final subject = await _createSubject(api);

    final first = subject.provider.load();
    final duplicate = await subject.provider.load();
    completer.complete(
      const StartupData(backupDomainsData: 'ciphertext'),
    );

    expect(duplicate, isFalse);
    expect(await first, isTrue);
    expect(api.calls, 1);
  });
}
```

- [ ] **Step 2: Run the Provider test and verify RED**

Run:

```bash
flutter test test/core/providers/startup_provider_test.dart
```

Expected: FAIL because the current `StartupProvider.create` signature, state enum and `load()` API
do not exist.

- [ ] **Step 3: Implement the minimal Provider state machine**

Replace `lib/core/providers/startup_provider.dart` with:

```dart
import 'package:flutter/foundation.dart';
import 'package:jade/core/models/startup.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/backup_domains_decryptor.dart';
import 'package:jade/core/network/domain_manager.dart';
import 'package:jade/core/network/startup_api_client.dart';

enum StartupStatus { idle, loading, success, failure }

typedef StartupDomainsDecoder = BackupDomains Function(String data);

class StartupProvider extends ChangeNotifier {
  StartupProvider._({
    required StartupApi startupApi,
    required ApiClient apiClient,
    required DomainManager domainManager,
    required StartupDomainsDecoder decoder,
  }) : _startupApi = startupApi,
       _apiClient = apiClient,
       _domainManager = domainManager,
       _decoder = decoder;

  static const String failureMessage = '启动失败，请检查网络后重试';

  final StartupApi _startupApi;
  final ApiClient _apiClient;
  final DomainManager _domainManager;
  final StartupDomainsDecoder _decoder;

  StartupStatus _status = StartupStatus.idle;
  String? _errorMessage;

  StartupStatus get status => _status;
  String? get errorMessage => _errorMessage;

  static StartupProvider create({
    required StartupApi startupApi,
    required ApiClient apiClient,
    required DomainManager domainManager,
    StartupDomainsDecoder decoder = BackupDomainsDecryptor.decrypt,
  }) {
    return StartupProvider._(
      startupApi: startupApi,
      apiClient: apiClient,
      domainManager: domainManager,
      decoder: decoder,
    );
  }

  Future<bool> load() async {
    if (_status == StartupStatus.loading) {
      return false;
    }
    _status = StartupStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final startup = await _startupApi.fetchStartup();
      final encoded = startup.backupDomainsData;
      if (encoded == null || encoded.isEmpty) {
        throw const FormatException('Missing backup_domains_data');
      }
      final domains = _decoder(encoded);
      if (domains.apiDomains.isEmpty) {
        throw const FormatException('Empty apiDomains');
      }
      await _domainManager.applyStartup(domains);
      _apiClient.swapBaseUrl(_domainManager.currentUrl);
      _status = StartupStatus.success;
      notifyListeners();
      return true;
    } catch (_) {
      _status = StartupStatus.failure;
      _errorMessage = failureMessage;
      notifyListeners();
      return false;
    }
  }

  Future<bool> retry() => load();
}
```

- [ ] **Step 4: Format and verify GREEN plus existing domain tests**

Run:

```bash
dart format lib/core/providers/startup_provider.dart test/core/providers/startup_provider_test.dart
flutter test test/core/providers/startup_provider_test.dart test/core/network/domain_manager_test.dart test/core/network/backup_domains_decryptor_test.dart
```

Expected: all tests PASS; the business client and persisted `baseUrl` both equal the first returned
backup domain.

- [ ] **Step 5: Commit the Provider state machine**

```bash
git add lib/core/providers/startup_provider.dart test/core/providers/startup_provider_test.dart
git commit -m "feat: apply startup domains before app entry"
```

---

### Task 3: 启动页、失败重试和 GoRouter 导航

**Files:**

- Create: `lib/features/startup/screens/startup_screen.dart`
- Create: `lib/features/startup/index.dart`
- Modify: `lib/core/router/routes.dart`
- Modify: `lib/core/router/app_router.dart`
- Create: `test/features/startup/startup_screen_test.dart`
- Modify: `test/core/router/app_router_auth_test.dart`

**Interfaces:**

- Consumes: `StartupProvider.load()`、`StartupProvider.retry()`、`StartupProvider.status`、
  `StartupProvider.errorMessage`。
- Produces: `const StartupPage()`；`AppRoutes.startup == '/startup'`；生产 `AppRouter.build()` 默认从
  `/startup` 开始。

- [ ] **Step 1: Write failing loading, retry and navigation Widget tests**

Create `test/features/startup/startup_screen_test.dart`:

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
import 'package:jade/core/providers/startup_provider.dart';
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
    decoder: (_) => const BackupDomains(
      apiDomains: ['https://backup.example'],
    ),
  );
}

Future<GoRouter> _pumpSubject(
  WidgetTester tester,
  StartupProvider provider,
) async {
  final router = GoRouter(
    initialLocation: '/startup',
    routes: [
      GoRoute(
        path: '/startup',
        builder: (context, state) => const StartupPage(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const Scaffold(
          body: Text('测试首页'),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: provider,
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
    final api = _FakeStartupApi([
      () => completer.future,
    ]);
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
    final router = await _pumpSubject(tester, provider);

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
}
```

Add a failing default-route assertion to `test/core/router/app_router_auth_test.dart`:

```dart
test('生产路由默认从启动页开始', () {
  final router = AppRouter.build();
  addTearDown(router.dispose);

  expect(router.routeInformationProvider.value.uri.path, AppRoutes.startup);
});
```

Change existing authentication tests that currently call `AppRouter.build()` and expect a home
context to:

```dart
final router = AppRouter.build(initialLocation: AppRoutes.home);
```

- [ ] **Step 2: Run the Widget and router tests and verify RED**

Run:

```bash
flutter test test/features/startup/startup_screen_test.dart test/core/router/app_router_auth_test.dart
```

Expected: FAIL because `StartupPage` and `AppRoutes.startup` do not exist and the production default
route remains `/home`.

- [ ] **Step 3: Implement the startup feature UI**

Create `lib/features/startup/screens/startup_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jade/core/providers/startup_provider.dart';
import 'package:jade/core/router/routes.dart';
import 'package:provider/provider.dart';

class StartupPage extends StatefulWidget {
  const StartupPage({super.key});

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
    final succeeded = retry
        ? await provider.retry()
        : await provider.load();
    if (succeeded && mounted) {
      context.go(AppRoutes.home);
    }
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

Create `lib/features/startup/index.dart`:

```dart
export 'screens/startup_screen.dart';
```

- [ ] **Step 4: Register the startup route and default location**

Add to `lib/core/router/routes.dart`:

```dart
static const String startup = '/startup';
```

Import `package:jade/features/startup/index.dart` in
`lib/core/router/app_router.dart`, change the production builder signature,
and register the route:

```dart
static GoRouter build({String initialLocation = AppRoutes.startup}) =>
    _remember(
      GoRouter(
        initialLocation: initialLocation,
        redirect: _redirect,
        routes: _routes,
      ),
    );
```

Place this route before the shell route:

```dart
GoRoute(
  path: AppRoutes.startup,
  builder: (context, state) => const StartupPage(),
),
```

- [ ] **Step 5: Format and verify GREEN**

Run:

```bash
dart format lib/features/startup lib/core/router/routes.dart lib/core/router/app_router.dart test/features/startup/startup_screen_test.dart test/core/router/app_router_auth_test.dart
flutter test test/features/startup/startup_screen_test.dart test/core/router/app_router_auth_test.dart test/core/router/app_router_requirements_test.dart
```

Expected: all tests PASS; retry success leaves `/startup` out of the navigation stack.

- [ ] **Step 6: Commit the startup UI and route**

```bash
git add lib/features/startup lib/core/router/routes.dart lib/core/router/app_router.dart test/features/startup/startup_screen_test.dart test/core/router/app_router_auth_test.dart
git commit -m "feat: gate home behind startup loading page"
```

---

### Task 4: 应用入口接线和端到端启动回归

**Files:**

- Modify: `lib/main.dart`
- Modify: `test/app_test.dart`

**Interfaces:**

- Consumes: `StartupApiClient.create()`、
  `StartupProvider.create({required StartupApi startupApi, required ApiClient apiClient, required DomainManager domainManager, StartupDomainsDecoder decoder = BackupDomainsDecryptor.decrypt})`
  、生产 `AppRouter.build()` 默认启动地址。
- Produces: `mainForTest({StartupApi? startupApi, StartupDomainsDecoder? decoder})`
  ，允许测试阻塞或控制启动请求而不访问公网。

- [ ] **Step 1: Write the failing app-entry loading test**

Replace `test/app_test.dart` with:

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/models/startup.dart';
import 'package:jade/core/network/startup_api_client.dart';
import 'package:jade/main.dart' as app_main;
import 'package:shared_preferences/shared_preferences.dart';

class _PendingStartupApi implements StartupApi {
  final Completer<StartupData> completer = Completer<StartupData>();

  @override
  Future<StartupData> fetchStartup() => completer.future;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('App 启动先显示加载页且不提前渲染首页', (tester) async {
    final startupApi = _PendingStartupApi();

    await app_main.mainForTest(startupApi: startupApi);
    await tester.pump();
    await tester.pump();

    expect(find.byType(app_main.MyApp), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('首页'), findsNothing);
  });
}
```

- [ ] **Step 2: Run the app test and verify RED**

Run:

```bash
flutter test test/app_test.dart
```

Expected: FAIL because `mainForTest` does not accept `startupApi` and the entry point still
fire-and-forgets `fetchStartup()`.

- [ ] **Step 3: Wire the dedicated startup client into the entry point**

Update the relevant signatures and construction in `lib/main.dart`:

```dart
Future<void> mainForTest({
  StartupApi? startupApi,
  StartupDomainsDecoder? decoder,
}) async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    await _buildEntry(
      startupApi: startupApi,
      decoder: decoder,
    ),
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(await _buildEntry());
}

Future<Widget> _buildEntry({
  StartupApi? startupApi,
  StartupDomainsDecoder? decoder,
}) async {
  final prefs = await SharedPreferences.getInstance();
  final themeProvider = await ThemeProvider.create();
  final authProvider = await AuthProvider.create(prefs);
  final settingsProvider = await SettingsProvider.create(prefs);
  final apiClient = await ApiClient.create(
    prefs: prefs,
    tokenProvider: authProvider,
    onAuthError: () {
      unawaited(authProvider.logout());
      AppRouter.goLoginForAuthError();
    },
  );
  final startupProvider = StartupProvider.create(
    startupApi: startupApi ?? StartupApiClient.create(),
    apiClient: apiClient,
    domainManager: apiClient.domainManager,
    decoder: decoder ?? BackupDomainsDecryptor.decrypt,
  );

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

Add these imports to `lib/main.dart`:

```dart
import 'package:jade/core/network/backup_domains_decryptor.dart';
import 'package:jade/core/network/startup_api_client.dart';
```

Delete the old fire-and-forget statement:

```dart
startupProvider.fetchStartup();
```

- [ ] **Step 4: Format and run the focused startup suite**

Run:

```bash
dart format lib/main.dart test/app_test.dart
flutter test test/core/network/startup_api_client_test.dart test/core/providers/startup_provider_test.dart test/features/startup/startup_screen_test.dart test/core/router/app_router_auth_test.dart test/app_test.dart
```

Expected: all focused startup and routing tests PASS.

- [ ] **Step 5: Verify related network regressions and static analysis**

Run:

```bash
flutter test test/core/network/domain_manager_test.dart test/core/network/interceptors/domain_switch_interceptor_test.dart test/core/network/backup_domains_decryptor_test.dart test/api_integration_test.dart
flutter analyze
```

Expected: all related tests PASS and `flutter analyze` reports no issues.

- [ ] **Step 6: Run the complete suite**

Run:

```bash
flutter test
```

Expected: PASS. If pre-existing unrelated tests fail, record exact test names and verify the focused
startup suite remains green before reporting.

- [ ] **Step 7: Commit the app-entry wiring**

```bash
git add lib/main.dart test/app_test.dart
git commit -m "feat: bootstrap domains before entering home"
```

---

## Final Acceptance Checklist

- [ ] Every cold start calls `/api/v1/startup` through `https://jdforrepam.com`.
- [ ] A stored historical domain cannot change the startup request host.
- [ ] Missing, invalid or empty backup-domain data keeps the app on `/startup`.
- [ ] Failure UI contains the exact Chinese copy and a working retry button.
- [ ] Retry success navigates with `go` and cannot pop back to `/startup`.
- [ ] `DomainManager.currentUrl`, persisted `StorageKeys.baseUrl` and business `Dio.baseUrl` all
  equal the first returned backup domain.
- [ ] Existing HTTP 608 domain rotation tests still pass.
- [ ] Focused startup tests, related network tests and `flutter analyze` pass.
