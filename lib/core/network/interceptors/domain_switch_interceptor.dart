import 'package:dio/dio.dart';
import 'package:jade/core/network/domain_manager.dart';

class DomainSwitchInterceptor extends Interceptor {
  DomainSwitchInterceptor({required this.domainManager, required this.dio});

  /// 标记「该请求已因轮转重试过一次」的 [RequestOptions.extra] 键。
  ///
  /// 标记随请求存活，请求结束即清除，因此不会像实例字段那样在进程内永久
  /// 禁止后续请求轮转。
  static const String retryMarkerKey = 'jade.domain_switch.retried';

  final DomainManager domainManager;
  final Dio dio;

  /// 进行中的轮转。多个请求并发失败时共享同一次 [DomainManager.rotate]，
  /// 保证只切换一次线路。
  Future<bool>? _pendingRotation;

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

  static bool _hasRetried(RequestOptions options) =>
      options.extra[retryMarkerKey] == true;

  static void _markRetried(RequestOptions options) {
    options.extra = {...options.extra, retryMarkerKey: true};
  }

  static void _clearRetryMarker(RequestOptions options) {
    if (!options.extra.containsKey(retryMarkerKey)) return;
    options.extra = {...options.extra}..remove(retryMarkerKey);
  }

  static String _normalize(String url) =>
      url.endsWith('/') ? url.substring(0, url.length - 1) : url;

  Future<bool> _rotateOnce() {
    final pending = _pendingRotation;
    if (pending != null) return pending;
    final future = domainManager.rotate().whenComplete(() {
      _pendingRotation = null;
    });
    _pendingRotation = future;
    return future;
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final options = err.requestOptions;
    if (_hasRetried(options) || !_shouldRotate(err)) {
      handler.next(err);
      return;
    }

    _markRetried(options);
    RequestOptions? retryRequest;
    try {
      // 并发失败的请求可能已经由别的请求完成轮转：沿用它切换后的线路重试，
      // 避免在只有 2 个域名时又跳回刚刚失效的地址。
      final failedUrl = options.baseUrl;
      final alreadySwitched =
          failedUrl.isNotEmpty &&
          _normalize(failedUrl) != _normalize(domainManager.currentUrl);
      var targetUrl = domainManager.currentUrl;
      if (!alreadySwitched) {
        final rotated = await _rotateOnce();
        if (!rotated) {
          handler.next(err);
          return;
        }
        targetUrl = domainManager.currentUrl;
        onRotated?.call();
      }
      dio.options.baseUrl = targetUrl;
      retryRequest = options.copyWith(baseUrl: targetUrl, path: options.path);
      _markRetried(retryRequest);
      final response = await dio.fetch(retryRequest);
      handler.resolve(response);
    } on DioException catch (retryError) {
      // 保留轮转重试的真实错误：response/type/error 原样透传，不包装成
      // 丢失响应的 badResponse。
      handler.next(retryError);
    } catch (error, stackTrace) {
      handler.next(
        DioException(
          requestOptions: retryRequest ?? options,
          error: error,
          stackTrace: stackTrace,
          type: DioExceptionType.unknown,
        ),
      );
    } finally {
      _clearRetryMarker(options);
      if (retryRequest != null) _clearRetryMarker(retryRequest);
    }
  }
}
