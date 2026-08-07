import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/domain_manager.dart';
import 'package:jade/core/network/endpoints.dart';
import 'package:jade/core/network/interceptors/response_interceptor.dart';
import 'package:jade/core/network/testing/fake_adapter.dart';
import 'package:jade/features/series/services/series_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('getLetters 请求 page limit 并解析 description 与数量', () async {
    final fixture = await buildSeriesFixture();
    fixture.adapter.enqueue(Endpoints.seriesLetters, {
      'success': 1,
      'data': {
        'letters': [
          {
            'id': 'IPX',
            'letter': 'IPX',
            'type': 0,
            'description': 'IdeaPocket美少女夢工廠',
            'videos_count': 998,
            'views_count': 3593620,
          },
        ],
        'current_page': 1,
      },
    });

    final result = await fixture.service.getLetters();

    expect(result.items.single.id, 'IPX');
    expect(result.items.single.letter, 'IPX');
    expect(result.items.single.description, 'IdeaPocket美少女夢工廠');
    expect(result.items.single.videosCount, 998);
    expect(result.items.single.viewsCount, 3593620);
    expect(result.items.single.type, 0);
    expect(fixture.adapter.requests.single.queryParameters, {
      'page': 1,
      'limit': 48,
    });
  });

  test('getSeries 请求 type page limit 并把 videos_count 映射为 movieCount', () async {
    final fixture = await buildSeriesFixture();
    fixture.adapter.enqueue(Endpoints.series, {
      'success': 1,
      'data': {
        'series': [
          {'id': 'rY2v', 'type': '0', 'name': '测试系列', 'videos_count': 1100},
        ],
        'current_page': 1,
      },
    });

    final result = await fixture.service.getSeries(type: '0', page: 2);

    expect(result.items.single.id, 'rY2v');
    expect(result.items.single.name, '测试系列');
    expect(result.items.single.movieCount, 1100);
    expect(result.items.single.type, 0);
    expect(fixture.adapter.requests.single.queryParameters, {
      'type': '0',
      'page': 2,
      'limit': 48,
    });
  });

  test('缺少 total_pages 时满 48 条允许下一页，少于 48 条停止', () async {
    final fixture = await buildSeriesFixture();
    fixture.adapter.enqueueSequence(Endpoints.series, [
      {
        'success': 1,
        'data': {
          'series': [
            for (var i = 0; i < 48; i++)
              {'id': 's$i', 'type': '0', 'name': 'S$i', 'videos_count': 1},
          ],
          'current_page': 1,
        },
      },
      {
        'success': 1,
        'data': {
          'series': [
            {'id': 's48', 'type': '0', 'name': 'S48', 'videos_count': 1},
          ],
          'current_page': 2,
        },
      },
    ]);

    final full = await fixture.service.getSeries(type: '0');
    final partial = await fixture.service.getSeries(type: '0', page: 2);

    expect(full.totalPages, 2);
    expect(partial.totalPages, 2);
  });
}

Future<({FakeAdapter adapter, SeriesService service})> buildSeriesFixture() async {
  final preferences = await SharedPreferences.getInstance();
  final domainManager = await DomainManager.load(preferences);
  final adapter = FakeAdapter();
  final dio = Dio(BaseOptions(baseUrl: domainManager.currentUrl))
    ..httpClientAdapter = adapter
    ..interceptors.add(ResponseInterceptor(onAuthError: () {}));
  final api = ApiClient.forTest(dio: dio, domainManager: domainManager);
  return (adapter: adapter, service: SeriesService(api));
}
