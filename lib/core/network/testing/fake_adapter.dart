// lib/core/network/testing/fake_adapter.dart
import 'dart:convert';
import 'package:dio/dio.dart';

/// 单元测试用 HttpClientAdapter。按 path 匹配预设响应，支持同路径响应序列。
class FakeAdapter implements HttpClientAdapter {
  final Map<String, _Stub> _stubs = {};
  final Map<String, List<_Stub>> _sequences = {};
  final Map<String, _ThrowStub> _throwSequences = {};
  final List<RequestOptions> requests = [];
  Duration responseDelay = Duration.zero;

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

  /// 同一 path 前 [count] 次请求抛 [error]，之后正常返回 enqueue 响应。
  /// 用于模拟连接级错误（如 `Connection reset by peer`）。
  void throwFirst(
    String path,
    Object error, {
    int count = 1,
  }) {
    _throwSequences[path] = _ThrowStub(error: error, remaining: count);
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (responseDelay > Duration.zero) {
      await Future<void>.delayed(responseDelay);
    }
    final throwStub = _throwSequences[options.path];
    if (throwStub != null && throwStub.remaining > 0) {
      throwStub.remaining--;
      throw throwStub.error;
    }
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
    _throwSequences.clear();
    requests.clear();
  }
}

class _Stub {
  const _Stub({required this.body, required this.statusCode});
  final Map<String, dynamic> body;
  final int statusCode;
}

class _ThrowStub {
  _ThrowStub({required this.error, required this.remaining});
  final Object error;
  int remaining;
}
