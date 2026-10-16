import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jade/features/movie_detail/services/missav_page_parser.dart';

/// 构造一个最小可解析的 Dean Edwards packer 脚本。
String _packed(String payload, int radix, int count, String keywords) {
  return "eval(function(p,a,c,k,e,d){return p}("
      "'$payload',$radix,$count,'$keywords'.split('|'),0,{}))";
}

String _fixture(String name) =>
    File('test/features/movie_detail/fixtures/$name').readAsStringSync();

void main() {
  group('normalizeMissavCode', () {
    test('纯番号保留并小写化', () {
      expect(normalizeMissavCode('DLDSS-564'), 'dldss-564');
      expect(normalizeMissavCode('dldss-564'), 'dldss-564');
    });

    test('去除空白与首尾空白', () {
      expect(normalizeMissavCode('  DLDSS 564  '), 'dldss564');
    });

    test('完整 missav 链接取末段番号', () {
      expect(
        normalizeMissavCode('https://missav.live/ja/dldss-564'),
        'dldss-564',
      );
      expect(
        normalizeMissavCode('https://missav.ws/ja/dldss-564-uncensored-leak'),
        'dldss-564-uncensored-leak',
      );
    });

    test('链接中的大写番号同样统一为小写', () {
      expect(
        normalizeMissavCode('https://missav.live/ja/DLDSS-564'),
        'dldss-564',
      );
    });

    test('末尾带斜杠的链接同样可解析', () {
      expect(
        normalizeMissavCode('https://missav.live/ja/dldss-564/'),
        'dldss-564',
      );
    });

    test('空输入返回空串', () {
      expect(normalizeMissavCode('   '), '');
    });
  });

  group('extractSurritMasterUrl', () {
    test('radix 16 packer 可解出 surrit 播放列表', () {
      const uuid = 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee';
      final html = _packed('0.1/2', 16, 3, 'surrit|com|$uuid');
      expect(
        extractSurritMasterUrl(html),
        'https://surrit.com/$uuid/playlist.m3u8',
      );
    });

    test('radix 62 packer 可解出 surrit 播放列表', () {
      const uuid = 'ffffffff-1111-2222-3333-444444444444';
      final html = _packed(
        '0.1/b',
        62,
        12,
        'surrit|com|x|x|x|x|x|x|x|x|x|$uuid',
      );
      expect(
        extractSurritMasterUrl(html),
        'https://surrit.com/$uuid/playlist.m3u8',
      );
    });

    test('真实页面片段（radix 16，UUID 被拆分为多个 token）可完整还原', () {
      final html = _fixture('missav_packer_radix16.txt');
      expect(
        extractSurritMasterUrl(html),
        'https://surrit.com/a5e4d7c9-2206-4f41-901c-1dd66a6ead27/playlist.m3u8',
      );
    });

    test('真实页面片段（radix 38，镜像白名单脚本）不含 surrit 时返回 null', () {
      final html = _fixture('missav_packer_radix38.txt');
      expect(extractSurritMasterUrl(html), isNull);
    });

    test('无 packer 时按明文 surrit 地址兜底', () {
      const uuid = '12345678-90ab-cdef-1234-567890abcdef';
      final html =
          '<script>var source="https://surrit.com/$uuid/playlist.m3u8";</script>';
      expect(
        extractSurritMasterUrl(html),
        'https://surrit.com/$uuid/playlist.m3u8',
      );
    });

    test('页面没有 surrit 信息时返回 null', () {
      expect(
        extractSurritMasterUrl('<html><body>没有播放地址</body></html>'),
        isNull,
      );
    });
  });
}
