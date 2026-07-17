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
