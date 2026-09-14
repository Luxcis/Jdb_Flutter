import 'dart:typed_data';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';

const _imageSuffixes = ['.jpg', '.jpeg', '.png', '.webp', '.gif'];

bool looksLikeEncryptedImageUrl(String url) {
  final path = Uri.tryParse(url)?.path.toLowerCase() ?? url.toLowerCase();
  return _imageSuffixes.any(path.endsWith);
}

/// 加密 payload 首字节为密钥；未加密（key >= 0xff）时原样返回全部字节，
/// 已加密时原地异或后返回去掉密钥首字节的解密内容。
Uint8List decryptMobileImageBytes(List<int> data) {
  if (data.isEmpty) {
    throw ArgumentError('empty image payload');
  }

  final bytes = data is Uint8List ? data : Uint8List.fromList(data);
  final key = bytes.first;
  if (key >= 0xff) return bytes;

  for (var i = 1; i < bytes.length; i++) {
    bytes[i] ^= key;
  }
  return Uint8List.fromList(Uint8List.sublistView(bytes, 1));
}

class DecryptingImageFileService extends FileService {
  DecryptingImageFileService({FileService? delegate})
    : _delegate = delegate ?? HttpFileService();

  final FileService _delegate;

  @override
  Future<FileServiceResponse> get(
    String url, {
    Map<String, String>? headers,
  }) async {
    final response = await _delegate.get(url, headers: headers);
    if (!looksLikeEncryptedImageUrl(url)) {
      return response;
    }

    final encrypted = await response.content.expand((chunk) => chunk).toList();
    final decrypted = decryptMobileImageBytes(encrypted);
    return _DecryptedFileServiceResponse(response, decrypted);
  }
}

class JdbImageCacheManager extends CacheManager with ImageCacheManager {
  JdbImageCacheManager._()
    : super(
        Config(
          key,
          stalePeriod: const Duration(days: 7),
          maxNrOfCacheObjects: 300,
          fileService: DecryptingImageFileService(),
        ),
      );

  static const key = 'jdbImageCache';
  static final instance = JdbImageCacheManager._();
}

class _DecryptedFileServiceResponse implements FileServiceResponse {
  const _DecryptedFileServiceResponse(this._delegate, this._data);

  final FileServiceResponse _delegate;
  final List<int> _data;

  @override
  Stream<List<int>> get content => Stream.value(_data);

  @override
  int get contentLength => _data.length;

  @override
  String? get eTag => _delegate.eTag;

  @override
  String get fileExtension => _delegate.fileExtension;

  @override
  int get statusCode => _delegate.statusCode;

  @override
  DateTime get validTill => _delegate.validTill;
}
