import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/network/testing/fake_adapter.dart';

/// Reads the full response body from a [ResponseBody.stream] and decodes as JSON.
Future<Map<String, dynamic>> _readBody(ResponseBody resp) async {
  final bytes = await resp.stream.fold<List<int>>(
    <int>[],
    (prev, chunk) => prev..addAll(chunk),
  );
  return jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
}

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
    final data = await _readBody(resp);
    expect(data['success'], 1);
  });

  test('FakeAdapter 记录请求历史', () async {
    final adapter = FakeAdapter();
    adapter.enqueue('/api/v1/y', {'success': 1, 'data': null});
    await adapter.fetch(RequestOptions(path: '/api/v1/y'), null, null);
    expect(adapter.requests.length, 1);
    expect(adapter.requests.first.path, '/api/v1/y');
  });
}
