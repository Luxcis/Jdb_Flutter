import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/models/startup.dart';

void main() {
  test('解析 recent_keywords 字符串列表', () {
    final startup = StartupData.fromJson({
      'recent_keywords': ['演员', 'ABP-001'],
    });

    expect(startup.recentKeywords, ['演员', 'ABP-001']);
  });

  test('缺少 recent_keywords 时默认为空列表', () {
    expect(StartupData.fromJson(const {}).recentKeywords, isEmpty);
  });

  test('解析 recent_magnet_keywords 字符串列表', () {
    final startup = StartupData.fromJson({
      'recent_magnet_keywords': ['桥本香菜', '蜘蛛侠'],
    });

    expect(startup.recentMagnetKeywords, ['桥本香菜', '蜘蛛侠']);
  });

  test('缺少 recent_magnet_keywords 时默认为空列表', () {
    expect(StartupData.fromJson(const {}).recentMagnetKeywords, isEmpty);
  });

  group('字段类型漂移容错', () {
    test('recent_keywords 跳过非字符串项并保留合法项', () {
      final startup = StartupData.fromJson({
        'recent_keywords': [
          '演员',
          1,
          null,
          {'name': 'x'},
          ['nested'],
          'ABP-001',
          true,
        ],
      });

      expect(startup.recentKeywords, ['演员', 'ABP-001']);
    });

    test('recent_magnet_keywords 跳过非字符串项并保留合法项', () {
      final startup = StartupData.fromJson({
        'recent_magnet_keywords': ['桥本香菜', 42, false, '蜘蛛侠'],
      });

      expect(startup.recentMagnetKeywords, ['桥本香菜', '蜘蛛侠']);
    });

    test('热词字段不是列表时降级为空列表', () {
      final startup = StartupData.fromJson({
        'recent_keywords': '演员',
        'recent_magnet_keywords': 3,
      });

      expect(startup.recentKeywords, isEmpty);
      expect(startup.recentMagnetKeywords, isEmpty);
    });

    test('settings/user 类型不符时降级为 null 且不抛 TypeError', () {
      expect(
        () => StartupData.fromJson({'settings': 'oops', 'user': 42}),
        returnsNormally,
      );

      final startup = StartupData.fromJson({'settings': 'oops', 'user': 42});

      expect(startup.settings, isNull);
      expect(startup.user, isNull);
    });

    test('settings/user 为对象时正常解析', () {
      final startup = StartupData.fromJson({
        'settings': {'blur': true},
        'user': {'id': 1},
      });

      expect(startup.settings, {'blur': true});
      expect(startup.user, {'id': 1});
    });

    test('类型异常的字段不影响其他字段解析', () {
      final startup = StartupData.fromJson({
        'backup_domains_data': 'ciphertext',
        'recent_keywords': [1, '演员'],
        'recent_magnet_keywords': [false, '桥本香菜'],
        'settings': 'oops',
        'user': [1, 2],
      });

      expect(startup.backupDomainsData, 'ciphertext');
      expect(startup.recentKeywords, ['演员']);
      expect(startup.recentMagnetKeywords, ['桥本香菜']);
      expect(startup.settings, isNull);
      expect(startup.user, isNull);
    });
  });

  group('BackupDomains 解析容错', () {
    test('apiDomains/backupUrls 跳过非字符串项', () {
      final domains = BackupDomains.fromJson({
        'apiDomains': ['https://a.example', 123, null, 'https://b.example'],
        'backupUrls': ['https://backup.example', false],
        'permanentAppDomain': 42,
      });

      expect(domains.apiDomains, ['https://a.example', 'https://b.example']);
      expect(domains.backupUrls, ['https://backup.example']);
      expect(domains.permanentAppDomain, isNull);
    });

    test('apiDomains/backupUrls 不是列表时降级为空列表', () {
      final domains = BackupDomains.fromJson({
        'apiDomains': 'https://a.example',
        'backupUrls': 1,
      });

      expect(domains.apiDomains, isEmpty);
      expect(domains.backupUrls, isEmpty);
    });
  });
}
