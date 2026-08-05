// lib/core/network/cache_service.dart
import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:jade/core/network/image_decryptor.dart';

/// 缓存服务抽象，便于在测试中注入 fake 实现。
abstract class CacheService {
  /// 返回当前缓存占用字节数。
  Future<int> getCacheSizeBytes();

  /// 清空磁盘与内存中的图片缓存。
  Future<void> clearAll();
}

/// 图片缓存服务：统计并清理 [JdbImageCacheManager] 的磁盘与内存缓存。
class JdbImageCacheService implements CacheService {
  JdbImageCacheService({
    CacheManager? cacheManager,
    Future<Directory> Function()? cacheDirectory,
  }) : _cacheManager = cacheManager ?? JdbImageCacheManager.instance,
       _cacheDirectory = cacheDirectory ?? getTemporaryDirectory;

  final CacheManager _cacheManager;
  final Future<Directory> Function() _cacheDirectory;

  @override
  Future<int> getCacheSizeBytes() async {
    try {
      final base = await _cacheDirectory();
      final dir = Directory('${base.path}/${JdbImageCacheManager.key}');
      if (!await dir.exists()) return 0;
      var total = 0;
      await for (final entity in dir.list(recursive: true)) {
        if (entity is File) {
          total += await entity.length();
        }
      }
      return total;
    } catch (_) {
      return 0;
    }
  }

  @override
  Future<void> clearAll() async {
    await _cacheManager.emptyCache();
    PaintingBinding.instance.imageCache.clear();
  }
}

/// 将字节数格式化为 B/KB/MB（KB/MB 保留一位小数），0 显示 `0 B`。
String formatCacheSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
  return '${(kb / 1024).toStringAsFixed(1)} MB';
}
