# Task 7 Report: SignatureInterceptor + AuthInterceptor

## Status: DONE

## What was implemented

创建了两个 interceptor 文件和一个测试文件：

| File | Description |
|------|-------------|
| `lib/core/network/interceptors/signature_interceptor.dart` | `SignatureInterceptor extends Interceptor`，在 `onRequest` 中注入 `jdsignature`（`JdSignature.generate()`）、`accept-language: zh-CN`、`connection: keep-alive` |
| `lib/core/network/interceptors/auth_interceptor.dart` | `AuthInterceptor extends Interceptor`，通过 `TokenProvider` 抽象类获取 token，非空时注入 `Authorization: Bearer {token}` |
| `test/core/network/interceptors/signature_auth_interceptor_test.dart` | 3 个测试用例，使用 `_FakeAuth implements TokenProvider` 进行测试 |

## TDD Evidence

### RED phase
```
EXIT_CODE=1
Error when reading 'lib/core/network/interceptors/signature_interceptor.dart': No such file or directory
Error when reading 'lib/core/network/interceptors/auth_interceptor.dart': No such file or directory
Type 'TokenProvider' not found.
Method not found: 'SignatureInterceptor'.
Method not found: 'AuthInterceptor'.
```
编译失败 —— 两个实现文件不存在，符合预期。

### GREEN phase
```
EXIT_CODE=0
00:00 +0: SignatureInterceptor 注入 jdsignature 与语言头
00:00 +1: AuthInterceptor 无 token 时不注入 Authorization
00:00 +2: AuthInterceptor 有 token 时注入 Bearer
00:00 +3: All tests passed!
```
3/3 全部通过，输出干净。

## Files changed

- `lib/core/network/interceptors/signature_interceptor.dart` — 新增
- `lib/core/network/interceptors/auth_interceptor.dart` — 新增
- `test/core/network/interceptors/signature_auth_interceptor_test.dart` — 新增

## Commit

- **SHA:** `81520df`
- **Subject:** `feat(core/network): add SignatureInterceptor and AuthInterceptor`

## Concerns

1. **dio API 差异**: brief 中的测试使用了 `RequestInterceptorHandler.next`（静态引用），但 dio 5.x 中 `next` 是实例方法。修正为 `RequestInterceptorHandler()` 实例化后传入。这不是逻辑变更，仅修正了 dio API 调用方式。

2. **`_FakeAuth` 补充 `implements TokenProvider`**: brief 中的 `_FakeAuth` 未显式实现 `TokenProvider`，在 Dart 中会导致类型不匹配。根据任务描述中 "The test uses a `_FakeAuth` class that implements `TokenProvider` for testing" 的说明，添加了 `implements TokenProvider`。

3. 没有修改任何 `.superpowers/` 或其他无关文件，仅 staged 了 3 个目标文件。
