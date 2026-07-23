import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/network/api_exception.dart';
import 'package:jade/core/network/interceptors/response_interceptor.dart';

Response _mkResp(Map<String, dynamic> body) {
  return Response(
    requestOptions: RequestOptions(path: '/x'),
    data: body,
    statusCode: 200,
  );
}

class _TestHandler extends ResponseInterceptorHandler {
  @override
  void reject(
    DioException error, [
    bool callFollowingErrorInterceptor = false,
  ]) {
    throw error.error!;
  }
}

void main() {
  test('success==1 解包 data', () {
    var authCalled = false;
    final ic = ResponseInterceptor(onAuthError: () => authCalled = true);
    final resp = _mkResp({
      'success': 1,
      'data': {'k': 'v'},
    });
    ic.onResponse(resp, _TestHandler());
    expect(resp.data, {'k': 'v'});
    expect(authCalled, isFalse);
  });

  test('success==1 解包 data 时转译嵌套字符串中的 HTML 实体', () {
    var authCalled = false;
    final ic = ResponseInterceptor(onAuthError: () => authCalled = true);
    final resp = _mkResp({
      'success': 1,
      'data': {
        'title': 'A&amp;B',
        'tags': [
          '剧情 &amp; 爱情',
          {'name': '演员&#x2F;导演'},
        ],
      },
    });

    ic.onResponse(resp, _TestHandler());

    expect(resp.data, {
      'title': 'A&B',
      'tags': [
        '剧情 & 爱情',
        {'name': '演员/导演'},
      ],
    });
    expect(authCalled, isFalse);
  });

  test('success==0 抛 ApiException 且非鉴权不调 onAuthError', () {
    var authCalled = false;
    final ic = ResponseInterceptor(onAuthError: () => authCalled = true);
    final resp = _mkResp({
      'success': 0,
      'action': ApiErrorActions.parameterInvalid,
      'message': '參數不能爲空',
    });
    expect(
      () => ic.onResponse(resp, _TestHandler()),
      throwsA(isA<ApiException>()),
    );
    expect(authCalled, isFalse);
  });

  test('JWTVerificationError 触发 onAuthError 并抛异常', () {
    var authCalled = false;
    final ic = ResponseInterceptor(onAuthError: () => authCalled = true);
    final resp = _mkResp({
      'success': 0,
      'action': ApiErrorActions.jwtVerificationError,
      'message': '請登錄帳號',
    });
    expect(
      () => ic.onResponse(resp, _TestHandler()),
      throwsA(isA<ApiException>()),
    );
    expect(authCalled, isTrue);
  });
}
