// test/core/network/domain_manager_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jade/core/constants/app_constants.dart';
import 'package:jade/core/storage/storage_keys.dart';
import 'package:jade/core/models/startup.dart';
import 'package:jade/core/network/domain_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('load 缺省返回兜底域名', () async {
    final prefs = await SharedPreferences.getInstance();
    final dm = await DomainManager.load(prefs);
    expect(dm.currentUrl, AppConstants.fallbackBaseUrl);
    expect(dm.apiDomains, isEmpty);
  });

  test('load 从 SP 恢复已存域名', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(StorageKeys.baseUrl, 'https://jdforrepam.com');
    await prefs.setStringList(StorageKeys.apiDomains, [
      'https://jdforrepam.com',
      'https://backup1.com',
    ]);
    final dm = await DomainManager.load(prefs);
    expect(dm.currentUrl, 'https://jdforrepam.com');
    expect(dm.apiDomains.length, 2);
  });

  test('applyStartup 写入域名列表与 CDN 端点并持久化', () async {
    final prefs = await SharedPreferences.getInstance();
    final dm = await DomainManager.load(prefs);
    await dm.applyStartup(
      BackupDomains(
        apiDomains: ['https://jdforrepam.com', 'https://backup1.com'],
        imageEndpoint: 'https://cdn.example.com/',
      ),
    );
    expect(dm.currentUrl, 'https://jdforrepam.com');
    expect(dm.isOnMainDomain, isTrue);
    expect(dm.imageEndpoint, 'https://cdn.example.com/');
    expect(prefs.getString(StorageKeys.baseUrl), 'https://jdforrepam.com');
  });

  test('imageEndpoint 在 applyStartup 前使用兜底值', () async {
    final prefs = await SharedPreferences.getInstance();
    final dm = await DomainManager.load(prefs);
    expect(dm.imageEndpoint, AppConstants.fallbackImageCdn);
  });

  test('rotate 顺序轮转并回到首个', () async {
    final prefs = await SharedPreferences.getInstance();
    final dm = await DomainManager.load(prefs);
    await dm.applyStartup(
      BackupDomains(
        apiDomains: [
          'https://jdforrepam.com',
          'https://b.com',
          'https://c.com',
        ],
      ),
    );
    expect(dm.currentUrl, 'https://jdforrepam.com');
    await dm.rotate();
    expect(dm.currentUrl, 'https://b.com');
    await dm.rotate();
    expect(dm.currentUrl, 'https://c.com');
    await dm.rotate();
    expect(dm.currentUrl, 'https://jdforrepam.com');
  });

  test('rotate 无备用域名返回 false', () async {
    final prefs = await SharedPreferences.getInstance();
    final dm = await DomainManager.load(prefs);
    expect(await dm.rotate(), isFalse);
  });

  test('离开主域名时 isOnMainDomain 为 false', () async {
    final prefs = await SharedPreferences.getInstance();
    final dm = await DomainManager.load(prefs);
    await dm.applyStartup(
      BackupDomains(apiDomains: ['https://jdforrepam.com', 'https://b.com']),
    );
    await dm.rotate();
    expect(dm.isOnMainDomain, isFalse);
  });

  test('isOnMainDomain 在 apiDomains 为空时返回 false', () async {
    final prefs = await SharedPreferences.getInstance();
    final dm = await DomainManager.load(prefs);
    expect(dm.isOnMainDomain, isFalse);
  });

  test('select 切换到手动线路并持久化', () async {
    final prefs = await SharedPreferences.getInstance();
    final dm = await DomainManager.load(prefs);
    await dm.applyStartup(
      BackupDomains(apiDomains: ['https://jdforrepam.com', 'https://b.com']),
    );
    await dm.select('https://b.com');
    expect(dm.lineMode, LineMode.manual);
    expect(dm.isAutoMode, isFalse);
    expect(dm.currentUrl, 'https://b.com');
    expect(prefs.getString(StorageKeys.line), 'https://b.com');
  });

  test('selectAuto 恢复自动与主域名并持久化', () async {
    final prefs = await SharedPreferences.getInstance();
    final dm = await DomainManager.load(prefs);
    await dm.applyStartup(
      BackupDomains(apiDomains: ['https://jdforrepam.com', 'https://b.com']),
    );
    await dm.select('https://b.com');
    await dm.selectAuto();
    expect(dm.lineMode, LineMode.auto);
    expect(dm.isAutoMode, isTrue);
    expect(dm.currentUrl, 'https://jdforrepam.com');
    expect(prefs.getString(StorageKeys.line), 'auto');
  });

  test('manual 模式下 rotate 返回 false 且不改动 currentUrl', () async {
    final prefs = await SharedPreferences.getInstance();
    final dm = await DomainManager.load(prefs);
    await dm.applyStartup(
      BackupDomains(apiDomains: ['https://jdforrepam.com', 'https://b.com']),
    );
    await dm.select('https://b.com');
    expect(await dm.rotate(), isFalse);
    expect(dm.currentUrl, 'https://b.com');
  });

  test('applyStartup 在手动域名仍存在时保持手动选择', () async {
    final prefs = await SharedPreferences.getInstance();
    final dm = await DomainManager.load(prefs);
    await dm.applyStartup(
      BackupDomains(apiDomains: ['https://jdforrepam.com', 'https://b.com']),
    );
    await dm.select('https://b.com');
    await dm.applyStartup(
      BackupDomains(
        apiDomains: [
          'https://jdforrepam.com',
          'https://b.com',
          'https://c.com',
        ],
      ),
    );
    expect(dm.lineMode, LineMode.manual);
    expect(dm.currentUrl, 'https://b.com');
  });

  test('applyStartup 在手动域名失效时回退自动并切主域名', () async {
    final prefs = await SharedPreferences.getInstance();
    final dm = await DomainManager.load(prefs);
    await dm.applyStartup(
      BackupDomains(apiDomains: ['https://jdforrepam.com', 'https://b.com']),
    );
    await dm.select('https://b.com');
    await dm.applyStartup(
      BackupDomains(apiDomains: ['https://jdforrepam.com', 'https://c.com']),
    );
    expect(dm.lineMode, LineMode.auto);
    expect(dm.currentUrl, 'https://jdforrepam.com');
    expect(prefs.getString(StorageKeys.line), 'auto');
  });

  test('load 从 SP 恢复手动模式与手动域名', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(StorageKeys.baseUrl, 'https://b.com');
    await prefs.setStringList(StorageKeys.apiDomains, [
      'https://jdforrepam.com',
      'https://b.com',
    ]);
    await prefs.setString(StorageKeys.line, 'https://b.com');
    final dm = await DomainManager.load(prefs);
    expect(dm.lineMode, LineMode.manual);
    expect(dm.currentUrl, 'https://b.com');
  });

  test('load 缺省 line 为 auto', () async {
    final prefs = await SharedPreferences.getInstance();
    final dm = await DomainManager.load(prefs);
    expect(dm.lineMode, LineMode.auto);
    expect(dm.isAutoMode, isTrue);
  });

  group('下发域名校验', () {
    test('applyStartup 丢弃非 https/空 host 域名并只持久化合规项', () async {
      final prefs = await SharedPreferences.getInstance();
      final dm = await DomainManager.load(prefs);

      await dm.applyStartup(
        BackupDomains(
          apiDomains: const [
            'http://insecure.example',
            'https://good.example',
            '',
            'not a url',
            'https://good.example',
            'ftp://files.example',
          ],
          backupUrls: const ['https://backup.example', 'http://bad.example'],
          permanentAppDomain: 'http://bad.example',
          unblockAppDomain: 'https://unblock.example',
          imageEndpoint: 'https://cdn.example/',
        ),
      );

      expect(dm.apiDomains, ['https://good.example']);
      expect(dm.currentUrl, 'https://good.example');
      expect(prefs.getStringList(StorageKeys.apiDomains), [
        'https://good.example',
      ]);
      expect(prefs.getString(StorageKeys.baseUrl), 'https://good.example');
      // 不合规的永久域名不进入候选；合规的解封域名进入候选。
      expect(
        dm.candidateBaseUrls,
        containsAll(<String>['https://unblock.example']),
      );
      expect(dm.candidateBaseUrls, isNot(contains('http://bad.example')));
    });

    test('applyStartup 全部不合规时保持当前线路与历史域名列表', () async {
      final prefs = await SharedPreferences.getInstance();
      final dm = await DomainManager.load(prefs);
      await dm.applyStartup(
        BackupDomains(apiDomains: ['https://a.example', 'https://b.example']),
      );

      await dm.applyStartup(
        BackupDomains(
          apiDomains: ['http://insecure.example', ''],
          backupUrls: ['ftp://bad.example'],
        ),
      );

      expect(dm.currentUrl, 'https://a.example');
      expect(dm.apiDomains, ['https://a.example', 'https://b.example']);
      expect(prefs.getStringList(StorageKeys.apiDomains), [
        'https://a.example',
        'https://b.example',
      ]);
      expect(dm.imageEndpoint, AppConstants.fallbackImageCdn);
      // 历史可用域名仍可轮转。
      expect(await dm.rotate(), isTrue);
      expect(dm.currentUrl, 'https://b.example');
    });

    test('load 丢弃持久化存储中的不合规域名与非法 baseUrl', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(StorageKeys.baseUrl, 'http://insecure.example');
      await prefs.setStringList(StorageKeys.apiDomains, [
        'http://insecure.example',
        'https://ok.example',
        '',
      ]);

      final dm = await DomainManager.load(prefs);

      expect(dm.apiDomains, ['https://ok.example']);
      expect(dm.currentUrl, 'https://ok.example');
    });

    test('load 在持久化域名全部不合规时回退兜底域名', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(StorageKeys.baseUrl, 'http://insecure.example');
      await prefs.setStringList(StorageKeys.apiDomains, [
        'http://insecure.example',
      ]);

      final dm = await DomainManager.load(prefs);

      expect(dm.apiDomains, isEmpty);
      expect(dm.currentUrl, AppConstants.fallbackBaseUrl);
    });

    test('load 忽略不合规的手动线路', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(StorageKeys.baseUrl, 'https://ok.example');
      await prefs.setStringList(StorageKeys.apiDomains, ['https://ok.example']);
      await prefs.setString(StorageKeys.line, 'http://evil.example');

      final dm = await DomainManager.load(prefs);

      expect(dm.lineMode, LineMode.auto);
      expect(dm.currentUrl, 'https://ok.example');
    });

    test('select 拒绝不合规域名且不改变当前状态', () async {
      final prefs = await SharedPreferences.getInstance();
      final dm = await DomainManager.load(prefs);
      await dm.applyStartup(
        BackupDomains(apiDomains: ['https://a.example', 'https://b.example']),
      );

      await dm.select('http://evil.example');
      await dm.select('');

      expect(dm.currentUrl, 'https://a.example');
      expect(dm.lineMode, LineMode.auto);
      expect(prefs.getString(StorageKeys.line), 'auto');

      // 合规域名仍可正常手动选择。
      await dm.select('https://b.example');
      expect(dm.currentUrl, 'https://b.example');
      expect(dm.lineMode, LineMode.manual);
    });
  });

  group('启动候选线路', () {
    test('candidateBaseUrls 以当前线路开头并去重、附带兜底域名', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(StorageKeys.baseUrl, 'https://b.example');
      await prefs.setStringList(StorageKeys.apiDomains, [
        'https://a.example',
        'https://b.example',
        'http://bad.example',
      ]);

      final dm = await DomainManager.load(prefs);

      expect(dm.candidateBaseUrls, [
        'https://b.example',
        'https://a.example',
        AppConstants.fallbackBaseUrl,
      ]);
    });

    test('candidateBaseUrls 覆盖备用域名、永久域名与解封域名', () async {
      final prefs = await SharedPreferences.getInstance();
      final dm = await DomainManager.load(prefs);
      await dm.applyStartup(
        BackupDomains(
          apiDomains: const ['https://a.example', 'https://b.example'],
          backupUrls: const [
            'https://b.example',
            'https://backup.example',
            'http://bad.example',
          ],
          permanentAppDomain: 'https://permanent.example',
          unblockAppDomain: 'http://insecure.example',
        ),
      );

      expect(dm.candidateBaseUrls, [
        'https://a.example',
        'https://b.example',
        'https://backup.example',
        'https://permanent.example',
        AppConstants.fallbackBaseUrl,
      ]);
    });

    test('load 从持久化 baseUrl 恢复轮转起点', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(StorageKeys.baseUrl, 'https://b.example');
      await prefs.setStringList(StorageKeys.apiDomains, [
        'https://a.example',
        'https://b.example',
      ]);

      final dm = await DomainManager.load(prefs);
      expect(await dm.rotate(), isTrue);

      expect(dm.currentUrl, 'https://a.example');
    });
  });
}
