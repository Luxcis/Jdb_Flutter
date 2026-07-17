# Task 10 Report

**Status:** COMPLETED
**Commits:** `08cfa8c` - feat(core/network): assemble ApiClient with full interceptor chain
**Test summary:** 4/4 pass (get unwrap, get error, JWT onAuthError, token Authorization injection). Full network suite: 25/25 pass.
**Concerns:** `expectLater` used instead of `expect` for JWT async test (flutter_test compatibility). `TokenProvider` moved from auth_interceptor.dart to api_client.dart per brief; AuthInterceptor now accepts `dynamic` to avoid circular import.
**Report path:** /Users/luxcis/data/workspace/Flutter/Jdb_Flutter/.superpowers/sdd/task-10-report.md

---

## Task 10 Fix (Code Review)

**Status:** COMPLETED
**Commit:** `1d45200` - fix(core/network): add swapBaseUrl and restore AuthInterceptor type safety
**Test summary:** 7/7 pass (api_client_test 4 tests + signature_auth_interceptor_test 3 tests).

### Fix Details

1. **Issue 1 (Critical) - Missing `swapBaseUrl(String url)` method**
   - 在 `ApiClient`（`lib/core/network/api_client.dart`）中添加 `void swapBaseUrl(String url)` 方法，方法体为 `dio.options.baseUrl = url;`

2. **Issue 2 (Important) - AuthInterceptor 使用 `dynamic` 类型**
   - `AuthInterceptor` 构造函数参数类型从 `dynamic` 改为 `Object`，并在 initializer list 中做 `is TokenProvider` 运行时检查
   - 存储字段类型改为 `TokenProvider`
   - 从 `api_client.dart` 导入 `TokenProvider`（循环导入在 Dart 中合法，因此处无 `part` 指令）
   - 构造函数体中保留 `assert(tokenProvider is TokenProvider)` 双重保障

3. **Issue 3 - 测试文件更新**
   - `_FakeAuth` 类添加 `implements TokenProvider`，并为 `token` 字段添加 `@override` 注解
   - 新增 `import 'package:jade/core/network/api_client.dart';`

### Concerns
- 循环导入 `auth_interceptor.dart` ↔ `api_client.dart`：当前编译和测试均通过，但如果未来在 `api_client.dart` 中使用 `auth_interceptor.dart` 的编译时常量可能会出现问题。当前无此场景，安全。
