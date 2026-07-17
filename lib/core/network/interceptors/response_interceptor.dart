// lib/core/network/interceptors/response_interceptor.dart
import 'package:dio/dio.dart';
import 'package:jade/core/network/api_exception.dart';

class ResponseInterceptor extends Interceptor {
  ResponseInterceptor({required this.onAuthError});
  final void Function() onAuthError;

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final data = response.data;
    if (data is! Map) {
      handler.next(response);
      return;
    }
    final success = data['success'];
    if (success == 1) {
      response.data = data['data'];
      handler.next(response);
      return;
    }
    final action = (data['action'] as String?) ?? '';
    final message = data['message'] as String?;
    if (action == ApiErrorActions.jwtVerificationError) {
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
}
