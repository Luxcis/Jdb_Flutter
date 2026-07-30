import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/constants/app_constants.dart';
import 'package:jade/core/network/endpoints.dart';
import 'package:jade/core/network/startup_api_client.dart';
import 'package:jade/core/network/testing/fake_adapter.dart';

void main() {
  test('启动请求固定使用 jdforrepam.com 并携带完整参数和签名', () async {
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
}
