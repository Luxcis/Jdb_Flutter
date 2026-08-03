import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/models/startup.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/domain_manager.dart';
import 'package:jade/core/network/startup_api_client.dart';
import 'package:jade/core/providers/startup_provider.dart';
import 'package:jade/core/storage/storage_keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeStartupApi implements StartupApi {
  _FakeStartupApi(this._responses);

  final List<FutureOr<StartupData> Function()> _responses;
  int calls = 0;

  @override
  Future<StartupData> fetchStartup() async {
    final response = _responses[calls];
    calls += 1;
    return response();
  }
}

Future<
  ({
    StartupProvider provider,
    ApiClient apiClient,
    DomainManager domainManager,
    SharedPreferences prefs,
  })
>
_createSubject(StartupApi startupApi) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(StorageKeys.baseUrl, 'https://old.example');
  await prefs.setStringList(StorageKeys.apiDomains, ['https://old.example']);
  final domainManager = await DomainManager.load(prefs);
  final apiClient = ApiClient.forTest(
    dio: Dio(BaseOptions(baseUrl: domainManager.currentUrl)),
    domainManager: domainManager,
  );
  final provider = StartupProvider.create(
    startupApi: startupApi,
    apiClient: apiClient,
    domainManager: domainManager,
    decoder: (_) => const BackupDomains(
      apiDomains: ['https://backup.example'],
      imageEndpoint: 'https://images.example',
    ),
  );
  return (
    provider: provider,
    apiClient: apiClient,
    domainManager: domainManager,
    prefs: prefs,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('成功时应用备用域名并同步业务客户端', () async {
    final api = _FakeStartupApi([
      () => const StartupData(backupDomainsData: 'ciphertext'),
    ]);
    final subject = await _createSubject(api);

    final succeeded = await subject.provider.load();

    expect(succeeded, isTrue);
    expect(subject.provider.status, StartupStatus.success);
    expect(subject.domainManager.currentUrl, 'https://backup.example');
    expect(subject.apiClient.dio.options.baseUrl, 'https://backup.example');
    expect(
      subject.prefs.getString(StorageKeys.baseUrl),
      'https://backup.example',
    );
  });

  test('成功时暴露 startup 近期热词', () async {
    final api = _FakeStartupApi([
      () => const StartupData(
        backupDomainsData: 'ciphertext',
        recentKeywords: ['演员', 'ABP-001'],
        recentMagnetKeywords: ['桥本香菜'],
      ),
    ]);
    final subject = await _createSubject(api);

    final succeeded = await subject.provider.load();

    expect(succeeded, isTrue);
    expect(subject.provider.recentKeywords, ['演员', 'ABP-001']);
    expect(subject.provider.recentMagnetKeywords, ['桥本香菜']);
  });

  test('缺少域名数据时失败并保留在启动状态', () async {
    final api = _FakeStartupApi([() => const StartupData()]);
    final subject = await _createSubject(api);

    final succeeded = await subject.provider.load();

    expect(succeeded, isFalse);
    expect(subject.provider.status, StartupStatus.failure);
    expect(subject.provider.errorMessage, '启动失败，请检查网络后重试');
    expect(subject.apiClient.dio.options.baseUrl, 'https://old.example');
  });

  test('空域名列表时失败且不覆盖历史业务域名', () async {
    final api = _FakeStartupApi([
      () => const StartupData(backupDomainsData: 'ciphertext'),
    ]);
    final subject = await _createSubject(api);
    final provider = StartupProvider.create(
      startupApi: api,
      apiClient: subject.apiClient,
      domainManager: subject.domainManager,
      decoder: (_) => const BackupDomains(apiDomains: []),
    );

    final succeeded = await provider.load();

    expect(succeeded, isFalse);
    expect(provider.status, StartupStatus.failure);
    expect(subject.domainManager.currentUrl, 'https://old.example');
  });

  test('加载期间忽略重复触发', () async {
    final completer = Completer<StartupData>();
    final api = _FakeStartupApi([() => completer.future]);
    final subject = await _createSubject(api);

    final first = subject.provider.load();
    final duplicate = await subject.provider.load();
    completer.complete(const StartupData(backupDomainsData: 'ciphertext'));

    expect(duplicate, isFalse);
    expect(await first, isTrue);
    expect(api.calls, 1);
  });
}
