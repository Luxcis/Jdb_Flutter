import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/constants/app_constants.dart';

void main() {
  test('默认 API 域名使用主域名', () {
    expect(AppConstants.fallbackBaseUrl, 'https://jdforrepam.com');
  });

  test('仓库不再引用不可达的 staging API 域名', () {
    final staleDomain = 'https://staging.${'letidi'}.com';
    final allowedExtensions = {'.dart', '.md', '.json', '.yaml', '.yml'};
    final offenders = <String>[];

    for (final entity in Directory.current.listSync(recursive: true)) {
      if (entity is! File) continue;
      final path = entity.path;
      if (_isIgnoredPath(path)) continue;
      if (!allowedExtensions.any(path.endsWith)) continue;

      final content = entity.readAsStringSync();
      if (content.contains(staleDomain)) {
        offenders.add(path);
      }
    }

    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });
}

bool _isIgnoredPath(String path) {
  return path.contains('/.git/') ||
      path.contains('/.dart_tool/') ||
      path.contains('/build/') ||
      path.endsWith('/test/core/network/default_domain_test.dart');
}
