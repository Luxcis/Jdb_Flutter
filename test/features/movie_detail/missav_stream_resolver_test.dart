import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jade/features/movie_detail/services/missav_stream_resolver.dart';

const _uuid = 'a5e4d7c9-2206-4f41-901c-1dd66a6ead27';

String get _pageHtml => File(
  'test/features/movie_detail/fixtures/missav_packer_radix16.txt',
).readAsStringSync();

void main() {
  test('解析成功返回播放地址与 Referer/UA 请求头', () async {
    late http.Request captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response(_pageHtml, 200);
    });
    final resolver = MissavHttpStreamResolver(client: client);

    final resolved = await resolver.resolve('DLDSS-564');

    expect(
      resolved.playlistUrl.toString(),
      'https://surrit.com/$_uuid/playlist.m3u8',
    );
    expect(resolved.httpHeaders['Referer'], missavReferer);
    expect(resolved.httpHeaders['User-Agent'], missavUserAgent);
    expect(captured.url.toString(), 'https://missav.live/ja/dldss-564');
    expect(captured.headers['User-Agent'], missavUserAgent);
    expect(captured.headers['Accept-Language'], isNotNull);
  });

  test('完整链接输入可规范化为番号后再请求', () async {
    late http.Request captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response(_pageHtml, 200);
    });
    final resolver = MissavHttpStreamResolver(client: client);

    await resolver.resolve('https://missav.live/ja/DLDSS-564');

    expect(captured.url.toString(), 'https://missav.live/ja/dldss-564');
  });

  test('页面非 200 时抛出带状态码的可读错误', () async {
    final client = MockClient(
      (request) async => http.Response('Not Found', 404),
    );
    final resolver = MissavHttpStreamResolver(client: client);

    await expectLater(
      resolver.resolve('DLDSS-564'),
      throwsA(
        isA<MissavResolveException>().having(
          (error) => error.message,
          'message',
          allOf(contains('HTTP 404'), contains('番号')),
        ),
      ),
    );
  });

  test('页面没有 surrit 信息时抛出可读错误', () async {
    final client = MockClient(
      (request) async => http.Response('<html></html>', 200),
    );
    final resolver = MissavHttpStreamResolver(client: client);

    await expectLater(
      resolver.resolve('DLDSS-564'),
      throwsA(
        isA<MissavResolveException>().having(
          (error) => error.message,
          'message',
          contains('未在页面中找到播放列表'),
        ),
      ),
    );
  });

  test('空番号直接失败且不发起请求', () async {
    var requests = 0;
    final client = MockClient((request) async {
      requests++;
      return http.Response('', 200);
    });
    final resolver = MissavHttpStreamResolver(client: client);

    await expectLater(
      resolver.resolve('   '),
      throwsA(
        isA<MissavResolveException>().having(
          (error) => error.message,
          'message',
          contains('番号为空'),
        ),
      ),
    );
    expect(requests, 0);
  });

  test('请求异常时转换为可读错误', () async {
    final client = MockClient((request) async {
      throw const SocketException('network down');
    });
    final resolver = MissavHttpStreamResolver(client: client);

    await expectLater(
      resolver.resolve('DLDSS-564'),
      throwsA(
        isA<MissavResolveException>().having(
          (error) => error.message,
          'message',
          contains('页面请求失败'),
        ),
      ),
    );
  });
}
