import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/domain_manager.dart';
import 'package:jade/core/network/endpoints.dart';
import 'package:jade/core/network/interceptors/response_interceptor.dart';
import 'package:jade/core/network/testing/fake_adapter.dart';
import 'package:jade/features/directors/services/director_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('getDirectors 发送 type page limit 并解析 videos_count 为 movieCount', () async {
    final fixture = await buildDirectorFixture();
    fixture.adapter.enqueue(Endpoints.directors, {
      'success': 1,
      'data': {
        'directors': [
          {'id': 'AqK', 'type': '0', 'name': 'K太郎', 'videos_count': 3122},
        ],
        'current_page': 1,
      },
    });

    final result = await fixture.service.getDirectors(type: 0, page: 1);

    expect(result.items.single.id, 'AqK');
    expect(result.items.single.name, 'K太郎');
    expect(result.items.single.type, 0);
    expect(result.items.single.movieCount, 3122);
    expect(fixture.adapter.requests.single.queryParameters, {
      'type': '0',
      'page': 1,
      'limit': 48,
    });
  });

  test('缺少 total_pages 时满 48 条允许下一页，少于 48 条停止', () async {
    final fixture = await buildDirectorFixture();
    fixture.adapter.enqueueSequence(Endpoints.directors, [
      directorResponse(48),
      directorResponse(47),
    ]);

    final full = await fixture.service.getDirectors(type: 0);
    final partial = await fixture.service.getDirectors(type: 0);

    expect(full.totalPages, 2);
    expect(partial.totalPages, 1);
  });
}

Future<({FakeAdapter adapter, DirectorService service})> buildDirectorFixture() async {
  final preferences = await SharedPreferences.getInstance();
  final domainManager = await DomainManager.load(preferences);
  final adapter = FakeAdapter();
  final dio = Dio(BaseOptions(baseUrl: domainManager.currentUrl))
    ..httpClientAdapter = adapter
    ..interceptors.add(ResponseInterceptor(onAuthError: () {}));
  final api = ApiClient.forTest(dio: dio, domainManager: domainManager);
  return (adapter: adapter, service: DirectorService(api));
}

Map<String, dynamic> directorResponse(int count) => {
  'success': 1,
  'data': {
    'directors': [
      for (var index = 0; index < count; index++)
        {'id': 'd$index', 'type': '0', 'name': '导演$index', 'videos_count': index},
    ],
    'current_page': 1,
  },
};
