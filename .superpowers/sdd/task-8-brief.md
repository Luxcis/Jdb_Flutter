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

