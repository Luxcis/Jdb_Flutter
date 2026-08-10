import 'package:dio/dio.dart';

final class AuthRequestContext {
  const AuthRequestContext._();

  static const _tokenOverrideKey = 'jade.auth.tokenOverride';
  static const _suppressGlobalAuthErrorKey =
      'jade.auth.suppressGlobalAuthError';
  static const _sensitiveResponseBodyKey = 'jade.logging.sensitiveResponseBody';

  static Options candidateTokenOptions(String token) => Options(
    extra: {
      _tokenOverrideKey: token,
      _suppressGlobalAuthErrorKey: true,
      _sensitiveResponseBodyKey: true,
    },
  );

  static String? tokenOverride(RequestOptions options) =>
      options.extra[_tokenOverrideKey] as String?;

  static bool suppressesGlobalAuthError(RequestOptions options) =>
      options.extra[_suppressGlobalAuthErrorKey] == true;

  static bool hasSensitiveResponseBody(RequestOptions options) =>
      options.extra[_sensitiveResponseBodyKey] == true;
}
