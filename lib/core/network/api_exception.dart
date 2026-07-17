// lib/core/network/api_exception.dart

/// 统一 API 错误。覆盖 api-reference.md §3 错误码。
class ApiException implements Exception {
  const ApiException({required this.action, this.message});

  factory ApiException.fromAction(String action, String? message) =>
      ApiException(action: action, message: message);

  final String action;
  final String? message;

  /// 鉴权类错误（需触发登出/重定向登录）。
  bool get isAuthError =>
      action == ApiErrorActions.jwtVerificationError ||
      action == ApiErrorActions.nonExistentUser;

  @override
  String toString() => 'ApiException($action): ${message ?? ""}';
}

/// api-reference.md §3 已知 action 常量。
class ApiErrorActions {
  const ApiErrorActions._();
  static const String parameterInvalid = 'ParameterInvalid';
  static const String invalidSignature = 'InvalidSignature';
  static const String jwtVerificationError = 'JWTVerificationError';
  static const String nonExistentUser = 'NonExistentUser';
}
