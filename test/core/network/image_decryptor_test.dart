import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/network/image_decryptor.dart';

void main() {
  group('decryptMobileImageBytes', () {
    test('丢弃首字节密钥并 XOR 还原图片 payload', () {
      const key = 0x3d;
      final plain = <int>[
        0xff,
        0xd8,
        0xff,
        0xe0,
        0x00,
        0x10,
        0x4a,
        0x46,
        0x49,
        0x46,
        0x00,
      ];
      final encrypted = <int>[key, ...plain.map((byte) => byte ^ key)];

      expect(decryptMobileImageBytes(encrypted), plain);
    });

    test('首字节为 0xff 时原样返回普通 JPEG', () {
      final jpeg = <int>[0xff, 0xd8, 0xff, 0xe0];

      expect(decryptMobileImageBytes(jpeg), jpeg);
    });

    test('空 payload 抛出错误', () {
      expect(() => decryptMobileImageBytes(const []), throwsArgumentError);
    });
  });

  group('looksLikeEncryptedImageUrl', () {
    test('只按 URL path 判断受支持图片后缀', () {
      expect(looksLikeEncryptedImageUrl('https://cdn/covers/a.jpg'), isTrue);
      expect(
        looksLikeEncryptedImageUrl('https://cdn/covers/a.JPG?x=1'),
        isTrue,
      );
      expect(looksLikeEncryptedImageUrl('https://cdn/covers/a.webp'), isTrue);
      expect(looksLikeEncryptedImageUrl('https://cdn/api/movie/123'), isFalse);
    });
  });

  group('DecryptingImageFileService', () {
    test('图片 URL 的响应流会被解密', () async {
      const key = 0x11;
      final plain = <int>[0xff, 0xd8, 0xff, 0xe0];
      final encrypted = <int>[key, ...plain.map((byte) => byte ^ key)];
      final service = DecryptingImageFileService(
        delegate: _FakeFileService(encrypted),
      );

      final response = await service.get('https://cdn/covers/a.jpg');
      final data = await response.content.expand((chunk) => chunk).toList();

      expect(data, plain);
      expect(response.contentLength, plain.length);
    });

    test('非图片 URL 的响应流保持原样', () async {
      final payload = <int>[0x01, 0x02, 0x03];
      final service = DecryptingImageFileService(
        delegate: _FakeFileService(payload),
      );

      final response = await service.get('https://cdn/api/movie/123');
      final data = await response.content.expand((chunk) => chunk).toList();

      expect(data, payload);
      expect(response.contentLength, payload.length);
    });
  });
}

class _FakeFileService extends FileService {
  _FakeFileService(this.payload);

  final List<int> payload;

  @override
  Future<FileServiceResponse> get(
    String url, {
    Map<String, String>? headers,
  }) async {
    return _FakeFileServiceResponse(payload);
  }
}

class _FakeFileServiceResponse implements FileServiceResponse {
  const _FakeFileServiceResponse(this.payload);

  final List<int> payload;

  @override
  Stream<List<int>> get content => Stream.value(payload);

  @override
  int get contentLength => payload.length;

  @override
  String? get eTag => 'fake-etag';

  @override
  String get fileExtension => '.jpg';

  @override
  int get statusCode => 200;

  @override
  DateTime get validTill => DateTime(2099);
}
