### Task 6: 测试用 FakeAdapter

**Files:**
- Create: `lib/core/network/testing/fake_adapter.dart`
- Test: `test/core/network/testing/fake_adapter_test.dart`

**Interfaces:**
- Produces: `FakeAdapter` 实现 `HttpClientAdapter`，可按 path 预设 `Response`；支持记录请求历史；`enqueue(path, response, {statusCode})`、`requests` 列表、`setThrowOnError(bool)`。

- [ ] **Step 1: 写失败测试**

```dart
// test/core/network/testing/fake_adapter_test.dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/network/testing/fake_adapter.dart';

void main() {
  test('FakeAdapter 按路径返回预设响应', () async {
    final adapter = FakeAdapter();
    adapter.enqueue('/api/v1/x', {'success': 1, 'data': {'a': 1}});
    final resp = await adapter.fetch(
      RequestOptions(path: '/api/v1/x'),
      null,
      null,
    );
    expect(resp.statusCode, 200);
    expect(resp.data['success'], 1);
  });

  test('FakeAdapter 记录请求历史', () async {
    final adapter = FakeAdapter();
    adapter.enqueue('/api/v1/y', {'success': 1, 'data': null});
    await adapter.fetch(RequestOptions(path: '/api/v1/y'), null, null);
    expect(adapter.requests.length, 1);
    expect(adapter.requests.first.path, '/api/v1/y');
  });
}
```

- [ ] **Step 2: 运行确认失败**

Run: `flutter test test/core/network/testing/fake_adapter_test.dart`
Expected: FAIL。

- [ ] **Step 3: 实现**

```dart
// lib/core/network/testing/fake_adapter.dart
import 'dart:convert';
import 'package:dio/dio.dart';

/// 单元测试用 HttpClientAdapter。按 path 匹配预设响应，支持同路径响应序列。
class FakeAdapter implements HttpClientAdapter {
  final Map<String, _Stub> _stubs = {};
  final Map<String, List<_Stub>> _sequences = {};
  final List<RequestOptions> requests = [];

  /// 同一 path 固定返回同一响应。
  void enqueue(String path, Map<String, dynamic> body, {int statusCode = 200}) {
    _stubs[path] = _Stub(body: body, statusCode: statusCode);
  }

  /// 同一 path 按入队顺序依次返回（每次请求弹出首个，耗尽回退到 enqueue）。
  /// 用于"先失败后成功"的重试场景。
  void enqueueSequence(
    String path,
    List<Map<String, dynamic>> bodies, {
    List<int>? codes,
  }) {
    _sequences[path] = [
      for (var i = 0; i < bodies.length; i++)
        _Stub(body: bodies[i], statusCode: codes?[i] ?? 200),
    ];
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    _Stub? stub;
    final seq = _sequences[options.path];
    if (seq != null && seq.isNotEmpty) {
      stub = seq.removeAt(0);
    } else {
      stub = _stubs[options.path];
    }
    final body = stub?.body ?? {'success': 0, 'message': 'no stub'};
    final code = stub?.statusCode ?? 404;
    return ResponseBody.fromString(
      jsonEncode(body),
      code,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {
    _stubs.clear();
    _sequences.clear();
    requests.clear();
  }
}

class _Stub {
  const _Stub({required this.body, required this.statusCode});
  final Map<String, dynamic> body;
  final int statusCode;
}
```

> 实现说明：用 `dart:convert` 的 `jsonEncode` 编码，确保 dio 的 JSON 解码器可解析。`enqueueSequence` 供 Task 9 域名重试测试模拟"先 608 后 200"。

- [ ] **Step 4: 运行测试通过**

Run: `flutter test test/core/network/testing/fake_adapter_test.dart`
Expected: PASS。若因 JSON 解码失败，将 `_encodeJson` 改为：
```dart
import 'dart:convert';
static String _encodeJson(Map<String, dynamic> m) => jsonEncode(m);
```
重跑直至 PASS。

- [ ] **Step 5: Commit**

```bash
git add lib/core/network/testing/fake_adapter.dart test/core/network/testing/fake_adapter_test.dart
git commit -m "test(core/network): add FakeAdapter for interceptor unit tests"
```

---

