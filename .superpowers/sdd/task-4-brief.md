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

