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
    await prefs.setStringList(StorageKeys.apiDomains,
        ['https://jdforrepam.com', 'https://backup1.com']);
    final dm = await DomainManager.load(prefs);
    expect(dm.currentUrl, 'https://jdforrepam.com');
    expect(dm.apiDomains.length, 2);
  });

  test('applyStartup 写入域名列表与 CDN 端点并持久化', () async {
    final prefs = await SharedPreferences.getInstance();
    final dm = await DomainManager.load(prefs);
    await dm.applyStartup(BackupDomains(
      apiDomains: ['https://jdforrepam.com', 'https://backup1.com'],
      imageEndpoint: 'https://cdn.example.com/',
    ));
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
    await dm.applyStartup(BackupDomains(
      apiDomains: ['https://jdforrepam.com', 'https://b.com', 'https://c.com'],
    ));
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
    await dm.applyStartup(BackupDomains(
      apiDomains: ['https://jdforrepam.com', 'https://b.com'],
    ));
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
    await dm.applyStartup(BackupDomains(
      apiDomains: ['https://jdforrepam.com', 'https://b.com'],
    ));
    await dm.select('https://b.com');
    expect(dm.lineMode, LineMode.manual);
    expect(dm.isAutoMode, isFalse);
    expect(dm.currentUrl, 'https://b.com');
    expect(prefs.getString(StorageKeys.line), 'https://b.com');
  });

  test('selectAuto 恢复自动与主域名并持久化', () async {
    final prefs = await SharedPreferences.getInstance();
    final dm = await DomainManager.load(prefs);
    await dm.applyStartup(BackupDomains(
      apiDomains: ['https://jdforrepam.com', 'https://b.com'],
    ));
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
    await dm.applyStartup(BackupDomains(
      apiDomains: ['https://jdforrepam.com', 'https://b.com'],
    ));
    await dm.select('https://b.com');
    expect(await dm.rotate(), isFalse);
    expect(dm.currentUrl, 'https://b.com');
  });

  test('applyStartup 在手动域名仍存在时保持手动选择', () async {
    final prefs = await SharedPreferences.getInstance();
    final dm = await DomainManager.load(prefs);
    await dm.applyStartup(BackupDomains(
      apiDomains: ['https://jdforrepam.com', 'https://b.com'],
    ));
    await dm.select('https://b.com');
    await dm.applyStartup(BackupDomains(
      apiDomains: ['https://jdforrepam.com', 'https://b.com', 'https://c.com'],
    ));
    expect(dm.lineMode, LineMode.manual);
    expect(dm.currentUrl, 'https://b.com');
  });

  test('applyStartup 在手动域名失效时回退自动并切主域名', () async {
    final prefs = await SharedPreferences.getInstance();
    final dm = await DomainManager.load(prefs);
    await dm.applyStartup(BackupDomains(
      apiDomains: ['https://jdforrepam.com', 'https://b.com'],
    ));
    await dm.select('https://b.com');
    await dm.applyStartup(BackupDomains(
      apiDomains: ['https://jdforrepam.com', 'https://c.com'],
    ));
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
}
