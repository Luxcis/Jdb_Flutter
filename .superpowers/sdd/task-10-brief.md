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
  });

  late final Dio dio;
  final DomainManager domainManager;

  static Future<ApiClient> create({
    required SharedPreferences prefs,
    required TokenProvider tokenProvider,
    required void Function() onAuthError,
  }) async {
    final dm = await DomainManager.load(prefs);
    final dio = Dio(BaseOptions(
      baseUrl: dm.currentUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
    ));
    dio.interceptors.addAll([
      SignatureInterceptor(),
      AuthInterceptor(tokenProvider),
      ResponseInterceptor(onAuthError: onAuthError),
      DomainSwitchInterceptor(domainManager: dm, dio: dio),
    ]);
    return ApiClient._(dio: dio, domainManager: dm);
  }

  Future<Response> get(String path, {Map<String, dynamic>? queryParameters}) {
    return dio.get(path, queryParameters: queryParameters);
  }

  Future<Response> post(String path, {dynamic data}) {
    return dio.post(path, data: data);
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

