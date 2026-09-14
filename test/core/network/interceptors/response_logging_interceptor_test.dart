import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/network/auth_request_context.dart';
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

RequestOptions _candidateRequestOptions(String token) {
  final options = _requestOptions();
  options.extra.addAll(
    AuthRequestContext.candidateTokenOptions(token).extra ?? const {},
  );
  return options;
}

void main() {
  group('ResponseLoggingInterceptor', () {
    test('普通成功响应输出请求参数、响应结果和原始内容并继续响应', () {
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
      expect(logs.length, greaterThan(1));
      final output = logs.join('\n');
      expect(output, contains('HTTP RESPONSE'));
      expect(output, contains('Method: POST'));
      expect(output, contains('URI: https://example.test/movies?page=1'));
      expect(output, contains('Query: {"page":1}'));
      expect(output, contains('Request Body: {"type":"latest"}'));
      expect(output, contains('Status: 200'));
      expect(output, contains('Result: SUCCESS'));
      expect(output, contains('Body: {"success":1,"data":{"id":"1"}}'));
      expect(output, isNot(contains('"Body": {')));
    });

    test('候选 Token 敏感成功响应隐藏原始 Body', () {
      const candidateToken = 'candidate-success-secret-71a';
      final logs = <String>[];
      final interceptor = ResponseLoggingInterceptor(
        enabled: true,
        output: logs.add,
      );
      final response = Response<dynamic>(
        requestOptions: _candidateRequestOptions(candidateToken),
        statusCode: 200,
        data: {
          'success': 1,
          'data': {'echo': candidateToken},
        },
      );
      final handler = _ResponseHandler();

      interceptor.onResponse(response, handler);

      expect(handler.forwarded, same(response));
      final output = logs.join('\n');
      expect(output, contains('Body: [REDACTED_SECRET]'));
      expect(output, isNot(contains(candidateToken)));
    });

    test('候选 Token 敏感错误响应隐藏原始 Body', () {
      const candidateToken = 'candidate-error-secret-82b';
      final logs = <String>[];
      final interceptor = ResponseLoggingInterceptor(
        enabled: true,
        output: logs.add,
      );
      final options = _candidateRequestOptions(candidateToken);
      final response = Response<dynamic>(
        requestOptions: options,
        statusCode: 401,
        data: {'success': 0, 'message': 'rejected $candidateToken'},
      );
      final error = DioException(
        requestOptions: options,
        response: response,
        type: DioExceptionType.badResponse,
      );
      final handler = _ErrorHandler();

      interceptor.onError(error, handler);

      expect(handler.forwarded, same(error));
      final output = logs.join('\n');
      expect(output, contains('Body: [REDACTED_SECRET]'));
      expect(output, isNot(contains(candidateToken)));
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
      expect(logs, isNotEmpty);
      final output = logs.join('\n');
      expect(output, contains('Result: ERROR'));
      expect(output, contains('Body: {"success":0,"message":"参数错误"}'));
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
      expect(logs, isNotEmpty);
      final output = logs.join('\n');
      expect(output, contains('Status: connectionError'));
      expect(output, contains('Result: ERROR'));
      expect(output, contains('Body: 无响应内容'));
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

    test('超长响应 Body 使用紧凑 JSON 且自定义输出保留完整内容', () {
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
      expect(logs.any((line) => line.runes.length == 800), isFalse);
      expect(logs.every((line) => line.runes.length <= 1200), isTrue);
      expect(
        logs.join(),
        contains('Body: {"success":1,"data":{"content":"$longContent"}}'),
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
      final output = logs.join('\n');
      expect('Status: 608'.allMatches(output), hasLength(1));
      expect('Status: 200'.allMatches(output), hasLength(1));
    });

    group('敏感请求体', () {
      test('登录接口的请求体整段脱敏，不出现明文密码', () {
        final logs = <String>[];
        final interceptor = ResponseLoggingInterceptor(
          enabled: true,
          output: logs.add,
        );
        final options = RequestOptions(
          path: '/api/v1/sessions',
          baseUrl: 'https://example.test',
          method: 'POST',
          data: {'account': 'user-1', 'password': 'plain-secret'},
        );
        final response = Response<dynamic>(
          requestOptions: options,
          statusCode: 200,
          data: {'success': 1, 'data': {'token': 't1'}},
        );

        interceptor.onResponse(response, _ResponseHandler());

        final output = logs.join('\n');
        expect(output, contains('Request Body: [REDACTED_REQUEST_BODY]'));
        expect(output, isNot(contains('plain-secret')));
        expect(output, isNot(contains('"password":')));
      });

      test('普通路径的请求体仍原样输出', () {
        final logs = <String>[];
        final interceptor = ResponseLoggingInterceptor(
          enabled: true,
          output: logs.add,
        );
        final options = RequestOptions(
          path: '/api/v1/following_tags',
          baseUrl: 'https://example.test',
          method: 'POST',
          data: {'name': 'tag-1'},
        );
        final response = Response<dynamic>(
          requestOptions: options,
          statusCode: 200,
          data: {'success': 1},
        );

        interceptor.onResponse(response, _ResponseHandler());

        final output = logs.join('\n');
        expect(output, contains('Request Body: {"name":"tag-1"}'));
      });

      test('改密接口的请求体整段脱敏', () {
        final logs = <String>[];
        final interceptor = ResponseLoggingInterceptor(
          enabled: true,
          output: logs.add,
        );
        final options = RequestOptions(
          path: '/api/v1/users/change_password',
          baseUrl: 'https://example.test',
          method: 'PUT',
          data: {'old_password': 'a', 'password': 'b'},
        );
        final response = Response<dynamic>(
          requestOptions: options,
          statusCode: 200,
          data: {'success': 1},
        );

        interceptor.onResponse(response, _ResponseHandler());

        final output = logs.join('\n');
        expect(output, contains('Request Body: [REDACTED_REQUEST_BODY]'));
        expect(output, isNot(contains('old_password')));
      });
    });
  });
}
