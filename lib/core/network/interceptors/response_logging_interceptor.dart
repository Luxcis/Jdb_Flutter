import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class ResponseLoggingInterceptor extends Interceptor {
  ResponseLoggingInterceptor({
    bool? enabled,
    void Function(String message)? output,
  }) : _enabled = enabled ?? kDebugMode,
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
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
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
