// lib/core/network/interceptors/response_interceptor.dart
import 'package:dio/dio.dart';
import 'package:jade/core/network/api_exception.dart';

class ResponseInterceptor extends Interceptor {
  ResponseInterceptor({required this.onAuthError});
  final void Function() onAuthError;

  static const _htmlEntities = {
    'amp': '&',
    'lt': '<',
    'gt': '>',
    'quot': '"',
    'apos': "'",
    'nbsp': ' ',
  };

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final data = response.data;
    if (data is! Map) {
      handler.next(response);
      return;
    }
    final success = data['success'];
    if (success == 1) {
      response.data = _decodeHtmlEntities(data['data']);
      handler.next(response);
      return;
    }
    final action = (data['action'] as String?) ?? '';
    final message = _decodeHtmlEntities(data['message']) as String?;
    if (_isAuthAction(action)) {
      onAuthError();
    }
    final ex = ApiException.fromAction(action, message);
    handler.reject(
      DioException(
        requestOptions: response.requestOptions,
        error: ex,
        type: DioExceptionType.badResponse,
        response: response,
      ),
    );
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final response = err.response;
    final data = response?.data;
    if (data is Map) {
      final action = (data['action'] as String?) ?? '';
      final message = _decodeHtmlEntities(data['message']) as String?;
      if (_isAuthAction(action)) {
        onAuthError();
        handler.reject(
          DioException(
            requestOptions: err.requestOptions,
            error: ApiException.fromAction(action, message),
            type: err.type,
            response: response,
          ),
        );
        return;
      }
    }
    if (response?.statusCode == 401) {
      onAuthError();
    }
    handler.next(err);
  }

  bool _isAuthAction(String action) =>
      action == ApiErrorActions.jwtVerificationError ||
      action == ApiErrorActions.nonExistentUser;

  Object? _decodeHtmlEntities(Object? value) {
    if (value is String) {
      return value.replaceAllMapped(RegExp(r'&(#x[0-9a-fA-F]+|#\d+|\w+);'), (
        match,
      ) {
        final entity = match.group(1)!;
        if (entity.startsWith('#x')) {
          final codePoint = int.tryParse(entity.substring(2), radix: 16);
          return codePoint == null
              ? match.group(0)!
              : String.fromCharCode(codePoint);
        }
        if (entity.startsWith('#')) {
          final codePoint = int.tryParse(entity.substring(1));
          return codePoint == null
              ? match.group(0)!
              : String.fromCharCode(codePoint);
        }
        return _htmlEntities[entity] ?? match.group(0)!;
      });
    }
    if (value is List) {
      return value.map(_decodeHtmlEntities).toList();
    }
    if (value is Map) {
      return value.map(
        (key, entryValue) => MapEntry(key, _decodeHtmlEntities(entryValue)),
      );
    }
    return value;
  }
}
