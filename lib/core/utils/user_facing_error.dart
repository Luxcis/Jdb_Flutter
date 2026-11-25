import 'package:dio/dio.dart';
import 'package:jade/core/network/api_exception.dart';

/// 把捕获到的异常映射为面向用户的中文提示。
///
/// 规则（与审查报告 ERR-4 一致）：
/// - [ApiException]（或包在 [DioException.error] 中的）优先使用服务端 message；
/// - 连接/超时类错误统一为「网络连接失败，请检查网络」；
/// - 其余一律「加载失败，请重试」，不向用户暴露 dio/异常原始英文文本。
String userFacingErrorMessage(Object error) {
  final apiError = _apiExceptionOf(error);
  if (apiError != null) {
    final message = _normalizedMessage(apiError.message);
    if (message != null) return message;
    switch (apiError.action) {
      case ApiErrorActions.parameterInvalid:
        return '请求参数有误，请稍后重试';
      case ApiErrorActions.invalidSignature:
        return '请求校验失败，请稍后重试';
      case ApiErrorActions.jwtVerificationError:
      case ApiErrorActions.nonExistentUser:
        return '登录状态已失效，请重新登录';
    }
    return '加载失败，请重试';
  }

  if (error is DioException) {
    switch (error.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return '网络连接失败，请检查网络';
      default:
        return '加载失败，请重试';
    }
  }

  return '加载失败，请重试';
}

/// 从页面捕获到的异常中提取 [ApiException]（含 Dio 包装场景）。
ApiException? userFacingApiException(Object error) => _apiExceptionOf(error);

ApiException? _apiExceptionOf(Object error) {
  if (error is ApiException) return error;
  if (error is DioException) {
    final inner = error.error;
    if (inner is ApiException) return inner;
  }
  return null;
}

String? _normalizedMessage(String? message) {
  final trimmed = message?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed;
}
