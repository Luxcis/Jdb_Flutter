// test/core/network/api_client_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/endpoints.dart';
import 'package:jade/core/network/interceptors/response_interceptor.dart';
import 'package:jade/core/network/interceptors/response_logging_interceptor.dart';
import 'package:jade/core/network/testing/fake_adapter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TokenProvider implements TokenProvider {
  @override
  String? token;
  _TokenProvider([this.token]);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('get 解包 success==1 的 data', () async {
    final prefs = await SharedPreferences.getInstance();
    final api = await ApiClient.create(
      prefs: prefs,
      tokenProvider: _TokenProvider(),
      onAuthError: () {},
    );
    final adapter = FakeAdapter();
    adapter.enqueue(Endpoints.moviesRecommend, {
      'success': 1,
      'data': {'r': 1},
    });
    api.setAdapterForTest(adapter);

    final resp = await api.get(Endpoints.moviesRecommend);
    expect(resp.data, {'r': 1});
    // 验证签名头已注入
    expect(adapter.requests.last.headers['jdsignature'], isNotNull);
  });

  test('get success==0 抛 ApiException', () async {
    final prefs = await SharedPreferences.getInstance();
    final api = await ApiClient.create(
      prefs: prefs,
      tokenProvider: _TokenProvider(),
      onAuthError: () {},
    );
    final adapter = FakeAdapter();
    adapter.enqueue(Endpoints.moviesLatest, {
      'success': 0,
      'action': 'ParameterInvalid',
      'message': '參數不能爲空',
    });
    api.setAdapterForTest(adapter);
    expect(
      () => api.get(Endpoints.moviesLatest),
      throwsA(predicate((e) => e.toString().contains('ParameterInvalid'))),
    );
  });

  test('JWTVerificationError 触发 onAuthError', () async {
    final prefs = await SharedPreferences.getInstance();
    var authCalled = false;
    final api = await ApiClient.create(
      prefs: prefs,
      tokenProvider: _TokenProvider('t'),
      onAuthError: () => authCalled = true,
    );
    final adapter = FakeAdapter();
    adapter.enqueue(Endpoints.users, {
      'success': 0,
      'action': 'JWTVerificationError',
      'message': '請登錄帳號',
    });
    api.setAdapterForTest(adapter);
    await expectLater(() => api.get(Endpoints.users), throwsA(isNotNull));
    expect(authCalled, isTrue);
  });

  test('token 非空时注入 Authorization', () async {
    final prefs = await SharedPreferences.getInstance();
    final api = await ApiClient.create(
      prefs: prefs,
      tokenProvider: _TokenProvider('mytoken'),
      onAuthError: () {},
    );
    final adapter = FakeAdapter();
    adapter.enqueue(Endpoints.users, {'success': 1, 'data': null});
    api.setAdapterForTest(adapter);
    await api.get(Endpoints.users);
    expect(adapter.requests.last.headers['authorization'], 'Bearer mytoken');
  });

  test('在业务响应解包前装配响应日志拦截器', () async {
    final prefs = await SharedPreferences.getInstance();
    final api = await ApiClient.create(
      prefs: prefs,
      tokenProvider: _TokenProvider(),
      onAuthError: () {},
    );

    final loggingIndex = api.dio.interceptors.indexWhere(
      (interceptor) => interceptor is ResponseLoggingInterceptor,
    );
    final responseIndex = api.dio.interceptors.indexWhere(
      (interceptor) => interceptor is ResponseInterceptor,
    );

    expect(loggingIndex, isNonNegative);
    expect(responseIndex, greaterThan(loggingIndex));
  });
}
