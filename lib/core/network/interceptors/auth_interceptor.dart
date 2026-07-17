import 'package:dio/dio.dart';

class AuthInterceptor extends Interceptor {
  AuthInterceptor(dynamic tokenProvider) : _tokenProvider = tokenProvider;
  final dynamic _tokenProvider;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = _tokenProvider.token;
    if (token != null && token.isNotEmpty) {
      options.headers['authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }
}
