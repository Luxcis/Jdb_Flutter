import 'package:flutter_test/flutter_test.dart';
import 'package:jade/features/movie_detail/models/online_play_source.dart';

void main() {
  group('播放源注册表', () {
    test('按 Jable、SupJav、MissAV 顺序注册三源', () {
      expect(onlinePlaySources.map((s) => s.id).toList(), const [
        'jable',
        'supjav',
        'missav',
      ]);
      expect(onlinePlaySources.map((s) => s.label).toList(), const [
        'Jable',
        'SupJav',
        'MissAV',
      ]);
      expect(onlinePlaySources.map((s) => s.host).toList(), const [
        'jable.tv',
        'supjav.com',
        'missav.live',
      ]);
    });

    test('注册表条目均可构造链接', () {
      for (final source in onlinePlaySources) {
        expect(
          source.buildUrl('IPX-538').scheme,
          'https',
          reason: '${source.id} 应构造 https 链接',
        );
      }
    });
  });

  group('buildUrl 番号代入', () {
    test('Jable 代入 videos 路径', () {
      expect(
        onlinePlaySources[0].buildUrl('IPX-538').toString(),
        'https://jable.tv/videos/ipx-538',
      );
    });

    test('SupJav 代入根路径', () {
      expect(
        onlinePlaySources[1].buildUrl('IPX-538').toString(),
        'https://supjav.com/ipx-538',
      );
    });

    test('MissAV 代入根路径', () {
      expect(
        onlinePlaySources[2].buildUrl('IPX-538').toString(),
        'https://missav.live/ipx-538',
      );
    });

    test('番号两侧空白被去除', () {
      expect(
        onlinePlaySources[2].buildUrl('  IPX-538 ').toString(),
        'https://missav.live/ipx-538',
      );
    });

    test('多段番号保留连字符并全部小写', () {
      expect(
        onlinePlaySources[0].buildUrl('FC2-PPV-1234567').toString(),
        'https://jable.tv/videos/fc2-ppv-1234567',
      );
    });

    test('已是小写番号保持不变', () {
      expect(
        onlinePlaySources[1].buildUrl('ipx-538').toString(),
        'https://supjav.com/ipx-538',
      );
    });
  });

  group('hasUsableMovieNumber', () {
    test('空白番号不可用', () {
      expect(hasUsableMovieNumber(''), isFalse);
      expect(hasUsableMovieNumber('   '), isFalse);
    });

    test('非空白番号可用', () {
      expect(hasUsableMovieNumber('IPX-538'), isTrue);
      expect(hasUsableMovieNumber(' IPX-538 '), isTrue);
    });
  });
}
