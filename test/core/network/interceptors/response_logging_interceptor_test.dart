import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/network/interceptors/response_logging_interceptor.dart';

class _RequestHandler extends RequestInterceptorHandler {
  RequestOptions? forwarded;

  @override
  void next(RequestOptions requestOptions) {
    forwarded = requestOptions;
  }
}

class _ResponseHandler extends ResponseInterceptorHandler {
  Response<dynamic>? forwarded;

  @override
  void next(Response<dynamic> response) {
    forwarded = response;
  }
}

class _ErrorHandler extends ErrorInterceptorHandler {
  DioException? forwarded;

  @override
  void next(DioException error) {
    forwarded = error;
  }
}

RequestOptions _requestOptions() {
  return RequestOptions(
    path: '/movies',
    baseUrl: 'https://example.test',
    method: 'POST',
    queryParameters: {'page': 1},
    data: {'type': 'latest'},
  );
}

void main() {
  group('ResponseLoggingInterceptor', () {
    test('成功响应输出请求参数、响应结果和原始内容并继续响应', () {
      final logs = <String>[];
      final interceptor = ResponseLoggingInterceptor(
        enabled: true,
        output: logs.add,
      );
      final response = Response<dynamic>(
        requestOptions: _requestOptions(),
        statusCode: 200,
        data: {
          'success': 1,
          'data': {'id': '1'},
        },
      );
      final handler = _ResponseHandler();

      interceptor.onResponse(response, handler);

      expect(handler.forwarded, same(response));
      expect(logs, hasLength(1));
      expect(logs.single, contains('Method: POST'));
      expect(logs.single, contains('URI: https://example.test/movies?page=1'));
      expect(logs.single, contains('Query: {"page":1}'));
      expect(logs.single, contains('Request Body: {"type":"latest"}'));
      expect(logs.single, contains('Status: 200'));
      expect(logs.single, contains('Result: SUCCESS'));
      expect(logs.single, contains('Body: {"success":1,"data":{"id":"1"}}'));
    });

    test('业务失败输出 ERROR 且进入错误链时不重复输出', () {
      final logs = <String>[];
      final interceptor = ResponseLoggingInterceptor(
        enabled: true,
        output: logs.add,
      );
      final response = Response<dynamic>(
        requestOptions: _requestOptions(),
        statusCode: 200,
        data: {'success': 0, 'message': '参数错误'},
      );

      interceptor.onResponse(response, _ResponseHandler());
      final error = DioException(
        requestOptions: response.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
      );
      final errorHandler = _ErrorHandler();
      interceptor.onError(error, errorHandler);

      expect(errorHandler.forwarded, same(error));
      expect(logs, hasLength(1));
      expect(logs.single, contains('Result: ERROR'));
      expect(logs.single, contains('Body: {"success":0,"message":"参数错误"}'));
    });

    test('连接错误输出错误类型和无响应内容并继续异常', () {
      final logs = <String>[];
      final interceptor = ResponseLoggingInterceptor(
        enabled: true,
        output: logs.add,
      );
      final error = DioException(
        requestOptions: _requestOptions(),
        type: DioExceptionType.connectionError,
      );
      final handler = _ErrorHandler();

      interceptor.onError(error, handler);

      expect(handler.forwarded, same(error));
      expect(logs, hasLength(1));
      expect(logs.single, contains('Status: connectionError'));
      expect(logs.single, contains('Result: ERROR'));
      expect(logs.single, contains('Body: 无响应内容'));
    });

    test('禁用时不输出日志', () {
      final logs = <String>[];
      final interceptor = ResponseLoggingInterceptor(
        enabled: false,
        output: logs.add,
      );
      final response = Response<dynamic>(
        requestOptions: _requestOptions(),
        statusCode: 200,
        data: {'success': 1},
      );

      interceptor.onResponse(response, _ResponseHandler());

      expect(logs, isEmpty);
    });

    test('超长响应分段输出且拼接后保留完整内容', () {
      final logs = <String>[];
      final interceptor = ResponseLoggingInterceptor(
        enabled: true,
        output: logs.add,
      );
      final longContent = List.filled(1200, '响应🙂').join();
      final response = Response<dynamic>(
        requestOptions: _requestOptions(),
        statusCode: 200,
        data: {
          'success': 1,
          'data': {'content': longContent},
        },
      );

      interceptor.onResponse(response, _ResponseHandler());

      expect(logs.length, greaterThan(1));
      expect(logs.every((chunk) => chunk.runes.length <= 800), isTrue);
      expect(logs.join(), contains('"content":"$longContent"'));
      expect(
        logs.join(),
        endsWith('-----------------------------------------------------'),
      );
    });

    test('重新进入请求链后允许重试结果产生新日志', () {
      final logs = <String>[];
      final interceptor = ResponseLoggingInterceptor(
        enabled: true,
        output: logs.add,
      );
      final options = _requestOptions();
      final firstResponse = Response<dynamic>(
        requestOptions: options,
        statusCode: 608,
        data: {'message': '切换域名'},
      );
      interceptor.onResponse(firstResponse, _ResponseHandler());

      final requestHandler = _RequestHandler();
      interceptor.onRequest(options, requestHandler);
      final retryResponse = Response<dynamic>(
        requestOptions: options,
        statusCode: 200,
        data: {'success': 1},
      );
      interceptor.onResponse(retryResponse, _ResponseHandler());

      expect(requestHandler.forwarded, same(options));
      expect(logs, hasLength(2));
      expect(logs.first, contains('Status: 608'));
      expect(logs.last, contains('Status: 200'));
    });
  });
}
