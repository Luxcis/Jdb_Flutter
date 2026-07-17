import 'package:dio/dio.dart';
import 'package:jade/core/network/domain_manager.dart';

class DomainSwitchInterceptor extends Interceptor {
  DomainSwitchInterceptor({
    required this.domainManager,
    required this.dio,
  });

  final DomainManager domainManager;
  final Dio dio;
  bool _retried = false;

  /// rotate 回调（设置后用于外部监听，测试用）。
  void Function()? onRotated;

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (_retried || err.response?.statusCode != 608) {
      handler.next(err);
      return;
    }
    final ok = await domainManager.rotate();
    if (!ok) {
      handler.next(err);
      return;
    }
    onRotated?.call();
    _retried = true;
    dio.options.baseUrl = domainManager.currentUrl;
    try {
      final retryReq = err.requestOptions.copyWith(
        baseUrl: domainManager.currentUrl,
        path: err.requestOptions.path,
      );
      final resp = await dio.fetch(retryReq);
      handler.resolve(resp);
    } catch (e) {
      handler.next(DioException(
        requestOptions: err.requestOptions,
        error: e,
        type: DioExceptionType.badResponse,
      ));
    }
  }
}
