# Debug Response Logging Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (
> recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为统一 Dio 客户端增加仅在 Debug 模式启用的响应日志，输出请求参数、响应结果和原始响应内容。

**Architecture:** 新增独立 `ResponseLoggingInterceptor`，在业务 `ResponseInterceptor`
解包前读取原始响应，并通过请求级标记避免业务异常进入错误链时重复记录。`ApiClient.create`
负责统一装配，现有鉴权、响应转换和域名切换逻辑保持不变。

**Tech Stack:** Dart 3.8、Flutter foundation、Dio 5、logger 2.7、flutter_test。

## Global Constraints

- 仅在 Debug 模式默认启用；Release/Profile 默认禁用。
- 使用 `logger` 包作为响应日志打印工具。
- 输出请求方法、URI、查询参数、请求体、HTTP 状态或 Dio 错误类型、结果和原始响应内容。
- 不输出请求头、Authorization Token 或 Cookie。
- 每次实际 Dio 请求尝试最多输出一条响应日志。
- Body 使用紧凑 JSON 字符串；超长响应内容不再按固定 800 字符硬切块；Logger 输出拼接后应保留完整响应内容。
- 按用户要求跳过 Git 提交步骤，并保留现有未跟踪文件。

---

### Task 1: 实现可测试的响应日志拦截器

**Files:**

- Create: `lib/core/network/interceptors/response_logging_interceptor.dart`
- Test: `test/core/network/interceptors/response_logging_interceptor_test.dart`

**Interfaces:**

- Consumes: Dio `RequestOptions`、`Response`、`DioException` 和 Flutter `kDebugMode`、`debugPrint`。
- Produces: `ResponseLoggingInterceptor({bool? enabled, void Function(String message)? output})`。

- [x] **Step 1: 编写失败测试**

创建测试处理器，分别捕获 `handler.next(response)` 与 `handler.next(error)`；覆盖以下行为：

```dart

final logs = <String>[];
final interceptor = ResponseLoggingInterceptor(
  enabled: true,
  output: logs.add,
);
final options = RequestOptions(
  path: '/movies',
  baseUrl: 'https://example.test',
  method: 'POST',
  queryParameters: {'page': 1},
  data: {'type': 'latest'},
);
final response = Response<dynamic>(
  requestOptions: options,
  statusCode: 200,
  data: {'success': 1, 'data': {'id': '1'}},
);

interceptor.onResponse
(response, handler);

expect
(
logs, hasLength(1));
expect(logs.single, contains('Query: {"page":1}'));
expect(logs.single, contains('Request Body: {"type":"latest"}'));
expect(logs.single, contains('Result: SUCCESS'));
expect(logs.single, contains('Body: {"success":1,"data":{"id":"1"}}')
);
```

另行断言业务 `success: 0` 输出 `ERROR`、连接错误输出 Dio 错误类型与“无响应内容”、`enabled: false`
无输出，以及同一 `RequestOptions` 从 `onResponse` 进入 `onError` 时日志数量仍为一。还需断言同一请求选项重新进入
`onRequest` 后会清除已记录标记，使重试结果能够产生新日志。

- [x] **Step 2: 运行测试并确认 RED**

Run: `flutter test test/core/network/interceptors/response_logging_interceptor_test.dart`

Expected: FAIL，提示 `response_logging_interceptor.dart` 或 `ResponseLoggingInterceptor` 不存在。

- [x] **Step 3: 写入最小实现**

实现以下结构：

```dart
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class ResponseLoggingInterceptor extends Interceptor {
  ResponseLoggingInterceptor({
    bool? enabled,
    void Function(String message)? output,
  })
      : _enabled = enabled ?? kDebugMode,
        _output = output ?? debugPrint;

  static const _loggedKey = 'response_logging_interceptor.logged';

  final bool _enabled;
  final void Function(String message) _output;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra[_loggedKey] = false;
    handler.next(options);
  }

  @override
  void onResponse(Response<dynamic> response,
      ResponseInterceptorHandler handler,) {
    _log(
      options: response.requestOptions,
      status: '${response.statusCode ?? 'UNKNOWN'}',
      result: _isBusinessFailure(response.data) ? 'ERROR' : 'SUCCESS',
      responseBody: response.data,
    );
    response.requestOptions.extra[_loggedKey] = true;
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.requestOptions.extra[_loggedKey] != true) {
      _log(
        options: err.requestOptions,
        status: err.response?.statusCode?.toString() ?? err.type.name,
        result: 'ERROR',
        responseBody: err.response?.data,
      );
      err.requestOptions.extra[_loggedKey] = true;
    }
    handler.next(err);
  }

  bool _isBusinessFailure(Object? data) =>
      data is Map && data.containsKey('success') && data['success'] != 1;

  void _log({
    required RequestOptions options,
    required String status,
    required String result,
    required Object? responseBody,
  }) {
    if (!_enabled) return;
    try {
      _output(
        '[HTTP RESPONSE]\n'
            'Method: ${options.method}\n'
            'URI: ${options.uri}\n'
            'Query: ${_format(options.queryParameters, empty: '{}')}\n'
            'Request Body: ${_format(options.data, empty: '无请求内容')}\n'
            'Status: $status\n'
            'Result: $result\n'
            'Body: ${_format(responseBody, empty: '无响应内容')}',
      );
    } catch (_) {
      // 调试日志不得改变请求结果。
    }
  }

  String _format(Object? value, {required String empty}) {
    if (value == null) return empty;
    if (value is Map || value is List) {
      try {
        return jsonEncode(value);
      } catch (_) {
        return value.toString();
      }
    }
    return value.toString();
  }
}
```

- [x] **Step 4: 运行聚焦测试并确认 GREEN**

Run: `flutter test test/core/network/interceptors/response_logging_interceptor_test.dart`

Expected: PASS，所有日志格式、禁用和去重用例通过。

### Task 2: 在 ApiClient 中统一装配

**Files:**

- Modify: `lib/core/network/api_client.dart`
- Modify: `test/core/network/api_client_test.dart`

**Interfaces:**

- Consumes: Task 1 的 `ResponseLoggingInterceptor`。
- Produces: `ApiClient.create` 创建的 Dio 拦截器链在 `ResponseInterceptor` 前包含一个
  `ResponseLoggingInterceptor`。

- [x] **Step 1: 编写失败测试**

在 `api_client_test.dart` 中创建客户端后检查拦截器存在且顺序正确：

```dart

final loggingIndex = api.dio.interceptors.indexWhere(
      (interceptor) => interceptor is ResponseLoggingInterceptor,
);
final responseIndex = api.dio.interceptors.indexWhere(
      (interceptor) => interceptor is ResponseInterceptor,
);

expect(loggingIndex, isNonNegative);

expect(responseIndex, greaterThan(loggingIndex));
```

- [x] **Step 2: 运行测试并确认 RED**

Run: `flutter test test/core/network/api_client_test.dart`

Expected: FAIL，`loggingIndex` 为 `-1`。

- [x] **Step 3: 注册日志拦截器**

在 `api_client.dart` 导入新文件，并将拦截器加入现有链：

```dart
dio.interceptors.addAll
([SignatureInterceptor(),
AuthInterceptor(tokenProvider),
ResponseLoggingInterceptor(),
ResponseInterceptor(onAuthError: onAuthError),
DomainSwitchInterceptor(domainManager: dm, dio: dio),
]
);
```

- [x] **Step 4: 运行网络层回归测试**

Run:
`flutter test test/core/network/interceptors/response_logging_interceptor_test.dart test/core/network/api_client_test.dart test/core/network/interceptors/response_interceptor_test.dart test/core/network/interceptors/domain_switch_interceptor_test.dart`

Expected: PASS，日志装配与现有响应、鉴权、域名切换行为均正常。

### Task 3: 格式化与全量验证

**Files:**

- Verify: `lib/core/network/interceptors/response_logging_interceptor.dart`
- Verify: `lib/core/network/api_client.dart`
- Verify: `test/core/network/interceptors/response_logging_interceptor_test.dart`
- Verify: `test/core/network/api_client_test.dart`

**Interfaces:**

- Consumes: Task 1 与 Task 2 的最终代码。
- Produces: 格式化、静态分析和完整回归测试证据。

- [x] **Step 1: 格式化变更文件**

Run:
`dart format lib/core/network/interceptors/response_logging_interceptor.dart lib/core/network/api_client.dart test/core/network/interceptors/response_logging_interceptor_test.dart test/core/network/api_client_test.dart`

Expected: 命令退出码为 0。

- [x] **Step 2: 运行静态分析**

Run: `flutter analyze`

Expected: `No issues found!`

- [x] **Step 3: 运行完整测试**

Run: `flutter test`

Expected: 全部测试通过，失败数为 0。

### Task 4: 使用 Logger 优化日志可读性

**Files:**

- Modify: `lib/core/network/interceptors/response_logging_interceptor.dart`
- Modify: `test/core/network/interceptors/response_logging_interceptor_test.dart`
- Modify: `pubspec.yaml`
- Modify: `pubspec.lock`

**Interfaces:**

- Consumes: `logger` 包的 `Logger`、`PrettyPrinter`、`LogFilter`、`LogOutput`。
- Produces: Debug-only 的 pretty JSON 响应日志输出。

- [x] **Step 1: 添加 Logger 依赖**

Run: `flutter pub add logger`

Expected: `pubspec.yaml` 增加 `logger: ^2.7.0`，`pubspec.lock` 锁定 `logger 2.7.0`。

- [x] **Step 2: 编写 Logger 输出回归测试并确认 RED**

调整日志测试，要求输出为 Logger 多行 pretty JSON，包含 `HTTP RESPONSE`、请求参数、响应结果和响应内容；超长响应不再出现固定
800 字符切块。

Run: `flutter test test/core/network/interceptors/response_logging_interceptor_test.dart`

Expected: FAIL，旧实现仍输出单个手写字符串，长响应仍出现 800 字符切块。

- [x] **Step 3: 改为 Logger 输出**

将 `ResponseLoggingInterceptor` 改为通过 `Logger.d(String)` 输出字段行，`Body` 使用 `jsonEncode` 紧凑
JSON 字符串。配置
`PrettyPrinter(methodCount: 0, errorMethodCount: 0, lineLength: 120, colors: false, printEmojis: false, noBoxingByDefault: true)`
，并用自定义 `LogOutput` 将 Logger 输出行写入 `debugPrint`。

- [x] **Step 5: 保留自定义输出分段**

让自定义 `LogOutput` 在默认 `debugPrint(wrapWidth: 1200)` 输出时保留较宽折行；测试注入 writer 也复用
1200 rune 分段，验证长响应拼接后仍完整。

- [x] **Step 4: 运行聚焦测试并确认 GREEN**

Run: `flutter test test/core/network/interceptors/response_logging_interceptor_test.dart`

Expected: PASS，Logger 格式、禁用、去重、重试和长响应测试全部通过。
