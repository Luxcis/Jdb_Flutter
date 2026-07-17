import 'package:dio/dio.dart';
import 'package:jade/core/network/api_client.dart';

class AuthInterceptor extends Interceptor {
  AuthInterceptor(Object tokenProvider)
      : _tokenProvider = tokenProvider is TokenProvider
            ? tokenProvider
            : (throw ArgumentError(
                'tokenProvider must implement TokenProvider')) {
    assert(tokenProvider is TokenProvider);
  }
  final TokenProvider _tokenProvider;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = _tokenProvider.token;
    if (token != null && token.isNotEmpty) {
      options.headers['authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }
}
