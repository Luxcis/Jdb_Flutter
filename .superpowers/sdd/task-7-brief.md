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

