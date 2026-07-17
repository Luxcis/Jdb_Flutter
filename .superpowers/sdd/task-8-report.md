# Task 8 Report: ResponseInterceptor

## Status: DONE

## Commits Created

- `3d75bd2` — `feat(core/network): add ResponseInterceptor to unwrap envelope`

## Test Summary

3/3 测试通过：

| # | 测试用例 | 结果 |
|---|---------|------|
| 1 | `success==1` 解包 data | PASS |
| 2 | `success==0` 抛 ApiException 且非鉴权不调 onAuthError | PASS |
| 3 | `JWTVerificationError` 触发 onAuthError 并抛异常 | PASS |

## TDD Flow

- **RED**: 仅 `ResponseInterceptor` 未找到（编译错误），符合预期
- **GREEN**: 实现后 3 个用例全部通过

## Implementation Details

- **文件**: `lib/core/network/interceptors/response_interceptor.dart` — 37 行
- **测试文件**: `test/core/network/interceptors/response_interceptor_test.dart` — 60 行
- **关键逻辑**:
  - `success==1` → `response.data = data['data']`，调用 `handler.next(response)`
  - `success==0` → 构造 `ApiException`，通过 `handler.reject(DioException(...))` 拒绝
  - `action==JWTVerificationError` → 调用 `onAuthError` 回调 + reject
  - 非 JWT 错误（如 ParameterInvalid）→ 仅 reject，不调用 `onAuthError`

## Adaptations from Brief

- dio 5.10.0 中 `InterceptorState`/`InterceptorResultType` 未公开导出，`_TestHandler` 改用 `extends ResponseInterceptorHandler` 替代 `implements`
- `reject` 签名适配：dio 5.x 使用 `[bool callFollowingErrorInterceptor]` 位置参数而非命名参数
- `_TestHandler.reject` 抛出 `error.error`（内部 `ApiException`），使 `throwsA(isA<ApiException>())` 断言正确工作
