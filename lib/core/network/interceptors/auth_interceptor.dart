import 'package:dio/dio.dart';

/// 抽象 token 提供者，避免直接依赖 AuthProvider（后者在 providers 任务实现）。
abstract class TokenProvider {
  String? get token;
}

class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._tokenProvider);
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
