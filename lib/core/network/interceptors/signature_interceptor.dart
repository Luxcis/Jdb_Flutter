import 'package:dio/dio.dart';
import 'package:jade/core/network/signature.dart';

class SignatureInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.headers['jdsignature'] = JdSignature.generate();
    options.headers['accept-language'] = 'zh-CN';
    options.headers['connection'] = 'keep-alive';
    handler.next(options);
  }
}
