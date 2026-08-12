import 'package:flutter_test/flutter_test.dart';
import 'package:jade/features/movie_detail/models/movie_preview_args.dart';

void main() {
  group('MoviePreviewArgs.replaceHostWithLine', () {
    test('将预告片 URL 的 host 替换为当前选中线路', () {
      expect(
        MoviePreviewArgs.replaceHostWithLine(
          'https://media.example.com/preview.m3u8?sign=a%2Bb%3Dc&t=123',
          'https://jdforrepam.com',
        ),
        'https://jdforrepam.com/preview.m3u8?sign=a%2Bb%3Dc&t=123',
      );
    });

    test('保留签名查询参数与 fragment', () {
      expect(
        MoviePreviewArgs.replaceHostWithLine(
          'https://media.example.com/preview.m3u8?sign=x&t=1#frag',
          'https://backup.example.com',
        ),
        'https://backup.example.com/preview.m3u8?sign=x&t=1#frag',
      );
    });

    test('使用线路声明的 scheme 与端口', () {
      expect(
        MoviePreviewArgs.replaceHostWithLine(
          'https://media.example.com/preview.m3u8?sign=x',
          'http://jdforrepam.com:8443',
        ),
        'http://jdforrepam.com:8443/preview.m3u8?sign=x',
      );
    });

    test('线路未声明端口时丢弃原 URL 的显式端口', () {
      expect(
        MoviePreviewArgs.replaceHostWithLine(
          'https://media.example.com:8080/preview.m3u8?sign=x',
          'https://jdforrepam.com',
        ),
        'https://jdforrepam.com/preview.m3u8?sign=x',
      );
    });

    test('无路径时仅替换 host 并保留查询参数', () {
      expect(
        MoviePreviewArgs.replaceHostWithLine(
          'https://media.example.com?sign=x',
          'https://jdforrepam.com',
        ),
        'https://jdforrepam.com?sign=x',
      );
    });

    test('线路地址无效时原样返回', () {
      const url = 'https://media.example.com/preview.m3u8';
      expect(MoviePreviewArgs.replaceHostWithLine(url, null), url);
      expect(MoviePreviewArgs.replaceHostWithLine(url, ''), url);
      expect(MoviePreviewArgs.replaceHostWithLine(url, 'not a url'), url);
      expect(MoviePreviewArgs.replaceHostWithLine(url, 'ftp://a.com'), url);
    });

    test('预告片地址无效时原样返回', () {
      expect(
        MoviePreviewArgs.replaceHostWithLine(
          'not a url',
          'https://jdforrepam.com',
        ),
        'not a url',
      );
      expect(
        MoviePreviewArgs.replaceHostWithLine(
          'file:///tmp/preview.m3u8',
          'https://jdforrepam.com',
        ),
        'file:///tmp/preview.m3u8',
      );
    });
  });
}
