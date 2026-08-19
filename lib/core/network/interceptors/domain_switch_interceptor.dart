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

  /// 是否需要触发线路轮转：服务端业务码 608（线路被封）或连接级错误
  /// （连接被重置/超时，无 HTTP 响应，如 `Connection reset by peer`）。
  static bool _shouldRotate(DioException err) {
    if (err.response?.statusCode == 608) return true;
    return switch (err.type) {
      DioExceptionType.connectionError ||
      DioExceptionType.connectionTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.sendTimeout => true,
      _ => false,
    };
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (_retried || !_shouldRotate(err)) {
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
