import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/network/interceptors/signature_interceptor.dart';
import 'package:jade/core/network/interceptors/auth_interceptor.dart';
import 'package:jade/core/network/api_client.dart';

class _FakeAuth implements TokenProvider {
  @override
  String? token;
  _FakeAuth([this.token]);
}

void main() {
  test('SignatureInterceptor 注入 jdsignature 与语言头', () {
    final ic = SignatureInterceptor();
    final opts = RequestOptions(path: '/api/v1/x');
    ic.onRequest(opts, RequestInterceptorHandler());
    expect(opts.headers['jdsignature'], isNotNull);
    final parts = (opts.headers['jdsignature'] as String).split('.');
    expect(parts.length, 3);
    expect(parts[1], 'lpw6vgqzsp');
    expect(opts.headers['accept-language'], 'zh-CN');
    expect(opts.headers['connection'], 'keep-alive');
  });

  test('AuthInterceptor 无 token 时不注入 Authorization', () {
    final ic = AuthInterceptor(_FakeAuth(null));
    final opts = RequestOptions(path: '/api/v1/x');
    ic.onRequest(opts, RequestInterceptorHandler());
    expect(opts.headers['authorization'], isNull);
  });

  test('AuthInterceptor 有 token 时注入 Bearer', () {
    final ic = AuthInterceptor(_FakeAuth('abc.def.ghi'));
    final opts = RequestOptions(path: '/api/v1/x');
    ic.onRequest(opts, RequestInterceptorHandler());
    expect(opts.headers['authorization'], 'Bearer abc.def.ghi');
  });
}
