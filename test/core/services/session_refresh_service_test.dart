import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/network/api_exception.dart';
import 'package:jade/core/providers/auth_provider.dart';
import 'package:jade/core/services/session_refresh_service.dart';
import 'package:jade/features/profile/services/token_authentication_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

final class _FakeTokenAuthenticationService
    implements TokenAuthenticationService {
  _FakeTokenAuthenticationService(this._onAuthenticate);

  final Future<Map<String, dynamic>> Function(String token) _onAuthenticate;
  int calls = 0;

  @override
  Future<Map<String, dynamic>> authenticate(String token) {
    calls++;
    return _onAuthenticate(token);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<(AuthProvider, _FakeTokenAuthenticationService)>
      _loggedInService({
    required Future<Map<String, dynamic>> Function(String) onAuthenticate,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final auth = await AuthProvider.create(prefs);
    await auth.login(
      token: 'session-token',
      user: {'id': 1, 'username': 'cached-user'},
    );
    final tokenAuthentication = _FakeTokenAuthenticationService(onAuthenticate);
    return (auth, tokenAuthentication);
  }

  test('未登录时返回 skipped 且不调用接口', () async {
    final prefs = await SharedPreferences.getInstance();
    final auth = await AuthProvider.create(prefs);
    final tokenAuthentication = _FakeTokenAuthenticationService(
      (_) => throw StateError('不应调用'),
    );
    final service = ApiSessionRefreshService(
      auth: auth,
      tokenAuthentication: tokenAuthentication,
    );

    final status = await service.refresh();

    expect(status, SessionRefreshStatus.skipped);
    expect(tokenAuthentication.calls, 0);
  });

  test('校验成功时更新用户缓存并返回 success', () async {
    final (auth, tokenAuthentication) = await _loggedInService(
      onAuthenticate: (_) async => {
        'id': 1,
        'username': 'fresh-user',
        'want_watch_count': 7,
      },
    );
    final service = ApiSessionRefreshService(
      auth: auth,
      tokenAuthentication: tokenAuthentication,
    );

    final status = await service.refresh();

    expect(status, SessionRefreshStatus.success);
    expect(tokenAuthentication.calls, 1);
    expect(auth.token, 'session-token');
    expect(auth.user, {
      'id': 1,
      'username': 'fresh-user',
      'want_watch_count': 7,
    });
    expect(auth.isLogged, isTrue);
  });

  test('鉴权失败时登出并返回 expired', () async {
    final (auth, tokenAuthentication) = await _loggedInService(
      onAuthenticate: (_) async =>
          throw const ApiException(action: ApiErrorActions.jwtVerificationError),
    );
    final service = ApiSessionRefreshService(
      auth: auth,
      tokenAuthentication: tokenAuthentication,
    );

    final status = await service.refresh();

    expect(status, SessionRefreshStatus.expired);
    expect(auth.isLogged, isFalse);
    expect(auth.token, isNull);
    expect(auth.user, isNull);
  });

  test('HTTP 401 时登出并返回 expired', () async {
    final (auth, tokenAuthentication) = await _loggedInService(
      onAuthenticate: (_) async => throw DioException(
        requestOptions: RequestOptions(path: '/api/v1/users'),
        response: Response(
          requestOptions: RequestOptions(path: '/api/v1/users'),
          statusCode: 401,
          statusMessage: 'Unauthorized',
        ),
      ),
    );
    final service = ApiSessionRefreshService(
      auth: auth,
      tokenAuthentication: tokenAuthentication,
    );

    final status = await service.refresh();

    expect(status, SessionRefreshStatus.expired);
    expect(auth.isLogged, isFalse);
  });

  test('网络错误时保留会话并返回 failure', () async {
    final (auth, tokenAuthentication) = await _loggedInService(
      onAuthenticate: (_) async => throw DioException(
        requestOptions: RequestOptions(path: '/api/v1/users'),
        type: DioExceptionType.connectionTimeout,
      ),
    );
    final service = ApiSessionRefreshService(
      auth: auth,
      tokenAuthentication: tokenAuthentication,
    );

    final status = await service.refresh();

    expect(status, SessionRefreshStatus.failure);
    expect(auth.isLogged, isTrue);
    expect(auth.token, 'session-token');
  });

  test('非鉴权 ApiException 保留会话并返回 failure', () async {
    final (auth, tokenAuthentication) = await _loggedInService(
      onAuthenticate: (_) async =>
          throw const ApiException(action: ApiErrorActions.parameterInvalid),
    );
    final service = ApiSessionRefreshService(
      auth: auth,
      tokenAuthentication: tokenAuthentication,
    );

    final status = await service.refresh();

    expect(status, SessionRefreshStatus.failure);
    expect(auth.isLogged, isTrue);
  });
}
