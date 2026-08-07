import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/domain_manager.dart';
import 'package:jade/core/network/endpoints.dart';
import 'package:jade/core/network/interceptors/response_interceptor.dart';
import 'package:jade/core/network/testing/fake_adapter.dart';
import 'package:jade/features/makers/services/maker_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('getMakers 发送 type page limit 并解析 videos_count 为 movieCount', () async {
    final fixture = await buildMakerFixture();
    fixture.adapter.enqueue(Endpoints.makers, {
      'success': 1,
      'data': {
        'makers': [
          {'id': 'xZyO', 'type': 1, 'name': 'Heydouga', 'videos_count': 25645},
        ],
        'current_page': 1,
      },
    });

    final result = await fixture.service.getMakers(type: 1, page: 1);

    expect(result.items.single.id, 'xZyO');
    expect(result.items.single.name, 'Heydouga');
    expect(result.items.single.type, 1);
    expect(result.items.single.movieCount, 25645);
    expect(fixture.adapter.requests.single.queryParameters, {
      'type': '1',
      'page': 1,
      'limit': 48,
    });
  });

  test('缺少 total_pages 时满 48 条允许下一页，少于 48 条停止', () async {
    final fixture = await buildMakerFixture();
    fixture.adapter.enqueueSequence(Endpoints.makers, [
      makerResponse(48),
      makerResponse(47),
    ]);

    final full = await fixture.service.getMakers(type: 0);
    final partial = await fixture.service.getMakers(type: 0);

    expect(full.totalPages, 2);
    expect(partial.totalPages, 1);
  });
}

Future<({FakeAdapter adapter, MakerService service})> buildMakerFixture() async {
  final preferences = await SharedPreferences.getInstance();
  final domainManager = await DomainManager.load(preferences);
  final adapter = FakeAdapter();
  final dio = Dio(BaseOptions(baseUrl: domainManager.currentUrl))
    ..httpClientAdapter = adapter
    ..interceptors.add(ResponseInterceptor(onAuthError: () {}));
  final api = ApiClient.forTest(dio: dio, domainManager: domainManager);
  return (adapter: adapter, service: MakerService(api));
}

Map<String, dynamic> makerResponse(int count) => {
  'success': 1,
  'data': {
    'makers': [
      for (var index = 0; index < count; index++)
        {'id': 'm$index', 'name': '片商$index', 'videos_count': index},
    ],
    'current_page': 1,
  },
};
