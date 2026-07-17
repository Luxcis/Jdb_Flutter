### Task 9: DomainSwitchInterceptor

**Files:**
- Create: `lib/core/network/interceptors/domain_switch_interceptor.dart`
- Test: `test/core/network/interceptors/domain_switch_interceptor_test.dart`

**Interfaces:**
- Consumes: `DomainManager`。
- Produces: `DomainSwitchInterceptor`：标准 `Interceptor.onError` → 608 时 `domainManager.rotate()` → `handler.resolve(await dio.fetch(requestOptions.withNewBaseUrl))` 重试一次。内部持有 `Dio` 引用以执行重试 fetch（单次 `retried` 标记防死循环）。

- [ ] **Step 1: 写失败测试**

```dart
// test/core/network/interceptors/domain_switch_interceptor_test.dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jade/core/network/domain_manager.dart';
import 'package:jade/core/network/interceptors/domain_switch_interceptor.dart';
import 'package:jade/core/network/testing/fake_adapter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('608 触发 rotate 并自动重试成功', () async {
    final prefs = await SharedPreferences.getInstance();
    final dm = await DomainManager.load(prefs);
    await dm.applyStartup(BackupDomainsData(
      apiDomains: ['https://jdforrepam.com', 'https://b.com'],
    ));
    final adapter = FakeAdapter();
    // 同路径先返回 608，再返回 200
    adapter.enqueueSequence('/x', [
      {'success': 0, 'action': 'Blocked'},
      {'success': 1, 'data': {'ok': true}},
    ], codes: [608, 200]);
    final dio = Dio(BaseOptions(baseUrl: dm.currentUrl))
      ..httpClientAdapter = adapter;
    final ic = DomainSwitchInterceptor(domainManager: dm, dio: dio);
    var rotated = false;
    ic.onRotated = () => rotated = true;
    // 发起请求触发 608 → 拦截器 rotate → 用新 baseUrl 重试 → 200
    final resp = await dio.get('/x');
    expect(resp.data, {'ok': true});
    expect(rotated, isTrue);
    expect(dm.currentUrl, 'https://b.com');
  });

  test('无备用域名时不重试，handler.next 原错误', () async {
    final prefs = await SharedPreferences.getInstance();
    final dm = await DomainManager.load(prefs); // 无 apiDomains
    final dio = Dio(BaseOptions(baseUrl: dm.currentUrl))
      ..httpClientAdapter = FakeAdapter();
    final ic = DomainSwitchInterceptor(domainManager: dm, dio: dio);
    var errPassed = false;
    final err = DioException(
      requestOptions: RequestOptions(path: '/x'),
      response: Response(requestOptions: RequestOptions(path: '/x'), statusCode: 608),
      type: DioExceptionType.badResponse,
    );
    ic.onError(err, _CaptureHandler(onNext: (e) => errPassed = true));
    // async handler — wait
    await Future.delayed(Duration.zero);
    expect(errPassed, isTrue);
  });
}

class _CaptureHandler implements ErrorInterceptorHandler {
  _CaptureHandler({this.onNext});
  final void Function(DioException)? onNext;
  @override
  void next(DioException err) => onNext?.call(err);
  @override
  void resolve(Response response, {bool followRedirects = true}) {}
  @override
  void reject(DioException error, {bool callFollowingErrorHandler = true}) {}
}
```

- [ ] **Step 2: 运行确认失败**

Run: `flutter test test/core/network/interceptors/domain_switch_interceptor_test.dart`
Expected: FAIL（`DomainSwitchInterceptor` 未定义）。

- [ ] **Step 3: 实现**

```dart
// lib/core/network/interceptors/domain_switch_interceptor.dart
import 'package:dio/dio.dart';
import 'package:jade/core/network/domain_manager.dart';

class DomainSwitchInterceptor extends Interceptor {
  DomainSwitchInterceptor({
    required this.domainManager,
    required this.dio,
  });

  final DomainManager domainManager;
  final Dio dio;
  bool _retried = false;

  /// rotate 回调（设置后用于外部监听，测试用）。
  void Function()? onRotated;

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (_retried || err.response?.statusCode != 608) {
      handler.next(err);
      return;
    }
    final ok = await domainManager.rotate();
    if (!ok) {
      handler.next(err);
      return;
    }
    onRotated?.call();
    _retried = true;
    dio.options.baseUrl = domainManager.currentUrl;
    try {
      final retryReq = err.requestOptions.copyWith(
        baseUrl: domainManager.currentUrl,
        path: err.requestOptions.path,
      );
      final resp = await dio.fetch(retryReq);
      handler.resolve(resp);
    } catch (e) {
      handler.next(DioException(
        requestOptions: err.requestOptions,
        error: e,
        type: DioExceptionType.badResponse,
      ));
    }
  }
}
```

> 注：`copyWith(baseUrl:, path:)` 需确保 dio 5.x 的 `RequestOptions` 支持这两个字段；若不支持，可以 `dio.fetch(err.requestOptions)` 并在 fetch 前改 `err.requestOptions.baseUrl`（dio 5.x 中 `RequestOptions` 是可变对象）。以实现时确认的 API 为准。

- [ ] **Step 4: 运行测试通过**

Run: `flutter test test/core/network/interceptors/domain_switch_interceptor_test.dart`
Expected: PASS（2 个用例）。

- [ ] **Step 5: Commit**

```bash
git add lib/core/network/interceptors/domain_switch_interceptor.dart test/core/network/interceptors/domain_switch_interceptor_test.dart
git commit -m "feat(core/network): add DomainSwitchInterceptor with dio retry"
```

---

