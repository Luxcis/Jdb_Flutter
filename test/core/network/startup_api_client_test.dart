import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/constants/app_constants.dart';
import 'package:jade/core/models/startup.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/domain_manager.dart';
import 'package:jade/core/network/endpoints.dart';
import 'package:jade/core/network/startup_api_client.dart';
import 'package:jade/core/network/testing/fake_adapter.dart';
import 'package:jade/core/providers/startup_provider.dart';
import 'package:jade/core/storage/storage_keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 按 host 决定行为的适配器：命中 [failedHosts] 的请求抛连接错误，
/// [statusByHost] 指定状态码，其余返回成功响应。
class _HostGatedAdapter implements HttpClientAdapter {
  _HostGatedAdapter({
    this.failedHosts = const {},
    this.statusByHost = const {},
    required this.body,
  });

  final Set<String> failedHosts;
  final Map<String, int> statusByHost;
  final Map<String, dynamic> body;
  final List<Uri> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final uri = options.uri;
    requests.add(uri);
    if (failedHosts.contains(uri.host)) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'Connection reset by peer',
        error: const SocketException('Connection reset by peer'),
      );
    }
    final status = statusByHost[uri.host] ?? 200;
    final payload = status == 200
        ? body
        : <String, dynamic>{
            'success': 0,
            'action': 'Blocked',
            'message': '线路被封',
          };
    return ResponseBody.fromString(
      jsonEncode(payload),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {
    requests.clear();
  }
}

Future<StartupProvider> _createProvider({
  required StartupApi startupApi,
  required DomainManager domainManager,
  StartupDomainsDecoder? decoder,
}) async {
  final apiClient = ApiClient.forTest(
    dio: Dio(BaseOptions(baseUrl: domainManager.currentUrl)),
    domainManager: domainManager,
  );
  return StartupProvider.create(
    startupApi: startupApi,
    apiClient: apiClient,
    domainManager: domainManager,
    decoder:
        decoder ??
        (_) => const BackupDomains(apiDomains: ['https://new.example']),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('无候选时使用兜底域名并携带完整参数和签名', () async {
    final adapter = FakeAdapter()
      ..enqueue(Endpoints.startup, {
        'success': 1,
        'data': {'backup_domains_data': 'ciphertext'},
      });
    final client = StartupApiClient.create()..setAdapterForTest(adapter);

    final result = await client.fetchStartup();

    expect(result.backupDomainsData, 'ciphertext');
    final request = adapter.requests.single;
    expect(request.uri.origin, AppConstants.fallbackBaseUrl);
    expect(request.uri.path, Endpoints.startup);
    expect(request.uri.queryParameters, {
      'last_ad_id': '',
      'platform': 'android',
      'app_channel': 'google',
      'app_version': 'official',
      'app_version_number': '1.9.29',
    });
    expect(request.headers['jdsignature'], isNotEmpty);
  });

  test('resetCandidates 过滤不合规参数并从首个候选开始', () {
    final client = StartupApiClient.create(
      candidateBaseUrls: const [
        'http://insecure.example',
        'https://a.example',
        'https://b.example',
        'https://a.example',
      ],
    );

    expect(client.currentBaseUrl, 'https://a.example');
    expect(client.useNextDomain(), isTrue);
    expect(client.currentBaseUrl, 'https://b.example');
    expect(client.useNextDomain(), isFalse);
    expect(client.currentBaseUrl, 'https://b.example');

    // 全部不合规时保持当前线路不变。
    expect(client.resetCandidates(const ['http://bad.example']), isFalse);
    expect(client.currentBaseUrl, 'https://b.example');

    expect(client.resetCandidates(const ['https://c.example']), isTrue);
    expect(client.currentBaseUrl, 'https://c.example');
  });

  test('启动失败时按候选域名重试并从持久化线路开始', () async {
    SharedPreferences.setMockInitialValues({
      StorageKeys.baseUrl: 'https://persisted.example',
      StorageKeys.apiDomains: [
        'https://persisted.example',
        'https://second.example',
      ],
    });
    final prefs = await SharedPreferences.getInstance();
    final domainManager = await DomainManager.load(prefs);
    final adapter = _HostGatedAdapter(
      failedHosts: const {'persisted.example'},
      body: {
        'success': 1,
        'data': {'backup_domains_data': 'ciphertext'},
      },
    );
    final startupApi = StartupApiClient.create()..setAdapterForTest(adapter);
    final provider = await _createProvider(
      startupApi: startupApi,
      domainManager: domainManager,
    );

    final succeeded = await provider.load();

    expect(succeeded, isTrue);
    expect(provider.status, StartupStatus.success);
    expect(adapter.requests.map((uri) => uri.host).toList(), [
      'persisted.example',
      'second.example',
    ]);
    expect(domainManager.currentUrl, 'https://new.example');
  });

  test('608 线路被封时换用下一候选域名', () async {
    SharedPreferences.setMockInitialValues({
      StorageKeys.baseUrl: 'https://persisted.example',
      StorageKeys.apiDomains: [
        'https://persisted.example',
        'https://second.example',
      ],
    });
    final prefs = await SharedPreferences.getInstance();
    final domainManager = await DomainManager.load(prefs);
    final adapter = _HostGatedAdapter(
      statusByHost: const {'persisted.example': 608},
      body: {
        'success': 1,
        'data': {'backup_domains_data': 'ciphertext'},
      },
    );
    final startupApi = StartupApiClient.create()..setAdapterForTest(adapter);
    final provider = await _createProvider(
      startupApi: startupApi,
      domainManager: domainManager,
    );

    final succeeded = await provider.load();

    expect(succeeded, isTrue);
    expect(adapter.requests.map((uri) => uri.host).toList(), [
      'persisted.example',
      'second.example',
    ]);
  });

  test('全部候选失败时进入失败态，重试重新从持久化线路遍历', () async {
    SharedPreferences.setMockInitialValues({
      StorageKeys.baseUrl: 'https://persisted.example',
      StorageKeys.apiDomains: [
        'https://persisted.example',
        'https://second.example',
      ],
    });
    final prefs = await SharedPreferences.getInstance();
    final domainManager = await DomainManager.load(prefs);
    final adapter = _HostGatedAdapter(
      failedHosts: const {
        'persisted.example',
        'second.example',
        'jdforrepam.com',
      },
      body: {
        'success': 1,
        'data': {'backup_domains_data': 'ciphertext'},
      },
    );
    final startupApi = StartupApiClient.create()..setAdapterForTest(adapter);
    final provider = await _createProvider(
      startupApi: startupApi,
      domainManager: domainManager,
    );

    final succeeded = await provider.load();

    expect(succeeded, isFalse);
    expect(provider.status, StartupStatus.failure);
    expect(provider.errorMessage, StartupProvider.failureMessage);
    expect(provider.lastErrorRetryable, isTrue);
    expect(adapter.requests.map((uri) => uri.host).toList(), [
      'persisted.example',
      'second.example',
      'jdforrepam.com',
    ]);

    await provider.retry();

    expect(adapter.requests.map((uri) => uri.host).toList(), [
      'persisted.example',
      'second.example',
      'jdforrepam.com',
      'persisted.example',
      'second.example',
      'jdforrepam.com',
    ]);
  });

  test('解码失败不轮换候选且标记为不可重试', () async {
    SharedPreferences.setMockInitialValues({
      StorageKeys.baseUrl: 'https://persisted.example',
      StorageKeys.apiDomains: ['https://persisted.example'],
    });
    final prefs = await SharedPreferences.getInstance();
    final domainManager = await DomainManager.load(prefs);
    final adapter = _HostGatedAdapter(
      body: {
        'success': 1,
        'data': {'backup_domains_data': 'ciphertext'},
      },
    );
    final startupApi = StartupApiClient.create()..setAdapterForTest(adapter);
    final provider = await _createProvider(
      startupApi: startupApi,
      domainManager: domainManager,
      decoder: (_) => throw const FormatException('bad domains'),
    );

    final succeeded = await provider.load();

    expect(succeeded, isFalse);
    expect(provider.status, StartupStatus.failure);
    expect(provider.lastErrorRetryable, isFalse);
    expect(adapter.requests.map((uri) => uri.host).toList(), [
      'persisted.example',
    ]);
  });
}
