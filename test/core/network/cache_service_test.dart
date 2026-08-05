import 'dart:io';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/network/cache_service.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// 为 flutter_cache_manager 的 Config 构造提供 fake 目录，避免
/// MissingPluginException（纯 Dart 单测环境无插件实现）。
class _FakePathProvider extends PathProviderPlatform {
  @override
  Future<String?> getTemporaryPath() async => Directory.systemTemp.path;

  @override
  Future<String?> getApplicationSupportPath() async =>
      Directory.systemTemp.path;
}

class _FakeCacheManager extends CacheManager {
  _FakeCacheManager() : super(Config('fake-cache-test'));

  int emptyCacheCalls = 0;

  @override
  Future<void> emptyCache() async {
    emptyCacheCalls++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    PathProviderPlatform.instance = _FakePathProvider();
  });

  group('formatCacheSize', () {
    test('0 字节显示 0 B', () {
      expect(formatCacheSize(0), '0 B');
    });

    test('B 级显示整数', () {
      expect(formatCacheSize(512), '512 B');
    });

    test('KB 级保留一位小数', () {
      expect(formatCacheSize(1536), '1.5 KB');
    });

    test('MB 级保留一位小数', () {
      expect(formatCacheSize((24 * 1024 + 512) * 1024), '24.5 MB');
    });
  });

  group('JdbImageCacheService', () {
    test('缓存目录不存在时大小返回 0', () async {
      final tmp = await Directory.systemTemp.createTemp('cache_service_test');
      addTearDown(() => tmp.delete(recursive: true));

      final service = JdbImageCacheService(
        cacheDirectory: () async => tmp,
        cacheManager: _FakeCacheManager(),
      );

      expect(await service.getCacheSizeBytes(), 0);
    });

    test('统计缓存目录内文件大小之和', () async {
      final tmp = await Directory.systemTemp.createTemp('cache_service_test');
      addTearDown(() => tmp.delete(recursive: true));
      final cacheDir = Directory('${tmp.path}/jdbImageCache');
      await cacheDir.create(recursive: true);
      await File('${cacheDir.path}/a.jpg').writeAsBytes(List.filled(100, 1));
      await File('${cacheDir.path}/b.jpg').writeAsBytes(List.filled(200, 2));

      final service = JdbImageCacheService(
        cacheDirectory: () async => tmp,
        cacheManager: _FakeCacheManager(),
      );

      expect(await service.getCacheSizeBytes(), 300);
    });

    test('clearAll 调用 emptyCache 并删除缓存目录（含孤儿文件）', () async {
      final tmp = await Directory.systemTemp.createTemp('cache_service_test');
      addTearDown(() => tmp.delete(recursive: true));
      final manager = _FakeCacheManager();
      // 模拟未被 emptyCache 索引到的孤儿文件。
      final cacheDir = Directory('${tmp.path}/jdbImageCache');
      await cacheDir.create(recursive: true);
      await File('${cacheDir.path}/orphan.jpg').writeAsBytes(List.filled(10, 1));

      final service = JdbImageCacheService(
        cacheDirectory: () async => tmp,
        cacheManager: manager,
      );

      await service.clearAll();

      expect(manager.emptyCacheCalls, 1);
      expect(await cacheDir.exists(), isFalse);
    });
  });
}
