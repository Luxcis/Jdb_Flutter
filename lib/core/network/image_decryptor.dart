import 'package:flutter_cache_manager/flutter_cache_manager.dart';

const _imageSuffixes = ['.jpg', '.jpeg', '.png', '.webp', '.gif'];

bool looksLikeEncryptedImageUrl(String url) {
  final path = Uri.tryParse(url)?.path.toLowerCase() ?? url.toLowerCase();
  return _imageSuffixes.any(path.endsWith);
}

List<int> decryptMobileImageBytes(List<int> data) {
  if (data.isEmpty) {
    throw ArgumentError('empty image payload');
  }

  final key = data.first;
  if (key >= 0xff) {
    return List<int>.of(data);
  }

  return [for (final byte in data.skip(1)) byte ^ key];
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
