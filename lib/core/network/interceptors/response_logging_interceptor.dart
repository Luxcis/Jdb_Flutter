import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:jade/core/network/auth_request_context.dart';
import 'package:logger/logger.dart';

class ResponseLoggingInterceptor extends Interceptor {
  ResponseLoggingInterceptor({
    bool? enabled,
    void Function(String message)? output,
  }) : _enabled = enabled ?? kDebugMode,
       _logger = Logger(
         filter: DevelopmentFilter(),
         printer: PrettyPrinter(
           methodCount: 0,
           errorMethodCount: 0,
           lineLength: 120,
           colors: false,
           printEmojis: false,
           noBoxingByDefault: true,
         ),
         output: _ResponseLogOutput(output),
         level: Level.debug,
       );

  static const _loggedKey = 'response_logging_interceptor.logged';
  static const _redactedResponseBody = '[REDACTED_SECRET]';

  final bool _enabled;
  final Logger _logger;

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
      _logger.d(
        'HTTP RESPONSE\n'
        'Method: ${options.method}\n'
        'URI: ${options.uri}\n'
        'Query: ${_compactJson(options.queryParameters, empty: '{}')}\n'
        'Request Body: ${_compactJson(options.data, empty: '无请求内容')}\n'
        'Status: $status\n'
        'Result: $result\n'
        'Body: ${AuthRequestContext.hasSensitiveResponseBody(options) ? _redactedResponseBody : _compactJson(responseBody, empty: '无响应内容')}',
      );
    } catch (_) {
      // 调试日志不得改变请求结果。
    }
  }

  String _compactJson(Object? value, {required String empty}) {
    if (value == null) return empty;
    if (value is Map && value.isEmpty) {
      return empty;
    }
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

class _ResponseLogOutput extends LogOutput {
  _ResponseLogOutput(this._writer);

  static const _wrapWidth = 1200;

  final void Function(String message)? _writer;

  @override
  void output(OutputEvent event) {
    for (final line in event.lines) {
      if (_writer == null) {
        debugPrint(line, wrapWidth: _wrapWidth);
      } else {
        _writeWrapped(line, _writer);
      }
    }
  }

  void _writeWrapped(String line, void Function(String message) writer) {
    var chunk = StringBuffer();
    var chunkLength = 0;
    for (final rune in line.runes) {
      chunk.writeCharCode(rune);
      chunkLength++;
      if (chunkLength == _wrapWidth) {
        writer(chunk.toString());
        chunk = StringBuffer();
        chunkLength = 0;
      }
    }
    if (chunkLength > 0) {
      writer(chunk.toString());
    }
  }
}
