# Task 9 Report: DomainSwitchInterceptor

## Status: DONE

## Summary

实现了 `DomainSwitchInterceptor`，在 dio 收到 608 状态码时自动 rotate 域名并重试。

## Files Created

- `lib/core/network/interceptors/domain_switch_interceptor.dart` — 拦截器实现
- `test/core/network/interceptors/domain_switch_interceptor_test.dart` — 2 个测试用例

## Implementation Details

- 继承 `Interceptor`，重写 `onError`
- 608 时调用 `domainManager.rotate()` 切换域名
- 使用 `_retried` 标记防止无限重试
- 通过 `err.requestOptions.copyWith(baseUrl:, path:)` 创建重试请求（dio 5.10.0 支持）
- 重试成功 → `handler.resolve(resp)`，失败 → `handler.next(err)`
- 暴露 `onRotated` 回调用于测试/外部监听

## Test Results

```
00:00 +2: All tests passed!
```

- `608 触发 rotate 并自动重试成功` — 验证 608 响应触发域名轮转、onRotated 回调、新域名重试成功
- `无备用域名时不重试，handler.next 原错误` — 验证无备用域名时直接传递原始错误

## Deviations from Brief

1. `_CaptureHandler` 使用 `extends ErrorInterceptorHandler` 替代 `implements`，因为 `InterceptorState` 在 dio 中被 hide 不对外暴露
2. 测试中显式调用 `dio.interceptors.add(ic)` 将拦截器注册到 dio 实例
3. 测试期望数据从 `{'ok': true}` 改为 `{'success': 1, 'data': {'ok': true}}`，因为单元测试中未注册 ResponseInterceptor，数据不会被解包

## Commit

```
aaa6d28 feat(core/network): add DomainSwitchInterceptor with dio retry
```
