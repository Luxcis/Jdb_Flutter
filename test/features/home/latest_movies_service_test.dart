import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/domain_manager.dart';
import 'package:jade/core/network/endpoints.dart';
import 'package:jade/core/network/interceptors/response_interceptor.dart';
import 'package:jade/core/network/testing/fake_adapter.dart';
import 'package:jade/features/home/services/latest_movies_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('完整发送类型 筛选 排序 页码和 48 条分页参数', () async {
    final fixture = await _buildFixture();
    fixture.adapter.enqueue(Endpoints.moviesLatest, {
      'success': 1,
      'data': {'movies': [], 'current_page': 1},
    });

    await fixture.service.getMovies(
      type: '1',
      filterBy: 'magnets',
      sortBy: 'update',
      page: 2,
    );

    expect(fixture.adapter.requests.single.queryParameters, {
      'type': '1',
      'filter_by': 'magnets',
      'sort_by': 'update',
      'page': 2,
      'limit': 48,
    });
  });

  test('解析 movies 与 current_page 并保留影片摘要字段', () async {
    final fixture = await _buildFixture();
    fixture.adapter.enqueue(Endpoints.moviesLatest, {
      'success': 1,
      'data': {
        'movies': [
          {
            'id': 'm1',
            'number': 'SSIS-001',
            'title': '测试影片',
            'thumb_url': 'thumb.jpg',
            'cover_url': 'cover.jpg',
            'release_date': '2026-08-01',
            'score': '4.5',
          },
        ],
        'current_page': 2,
        'total_pages': 3,
        'total_count': 49,
      },
    });

    final result = await fixture.service.getMovies(
      type: 'all',
      filterBy: 'can_play',
      sortBy: 'update',
      page: 2,
    );

    expect(result.items.single.id, 'm1');
    expect(result.items.single.thumbUrl, 'thumb.jpg');
    expect(result.items.single.score, 4.5);
    expect(result.currentPage, 2);
    expect(result.totalPages, 3);
    expect(result.total, 49);
  });

  test('缺少 total_pages 时以 48 条为满页阈值', () async {
    final fixture = await _buildFixture();
    fixture.adapter.enqueueSequence(Endpoints.moviesLatest, [
      {
        'success': 1,
        'data': {
          'movies': [
            for (var index = 0; index < 48; index++)
              {
                'id': 'm$index',
                'number': 'N$index',
                'title': '影片 $index',
                'cover_url': '',
              },
          ],
          'current_page': 1,
        },
      },
      {
        'success': 1,
        'data': {
          'movies': [
            {'id': 'm48', 'number': 'N48', 'title': '影片 48', 'cover_url': ''},
          ],
          'current_page': 2,
        },
      },
    ]);

    final fullPage = await fixture.service.getMovies(
      type: 'all',
      filterBy: 'magnets',
      sortBy: 'update',
    );
    final partialPage = await fixture.service.getMovies(
      type: 'all',
      filterBy: 'magnets',
      sortBy: 'update',
      page: 2,
    );

    expect(fullPage.totalPages, 2);
    expect(partialPage.totalPages, 2);
  });
}

Future<({FakeAdapter adapter, LatestMoviesService service})>
_buildFixture() async {
  final preferences = await SharedPreferences.getInstance();
  final domainManager = await DomainManager.load(preferences);
  final adapter = FakeAdapter();
  final dio = Dio(BaseOptions(baseUrl: domainManager.currentUrl))
    ..httpClientAdapter = adapter
    ..interceptors.add(ResponseInterceptor(onAuthError: () {}));
  final api = ApiClient.forTest(dio: dio, domainManager: domainManager);
  return (adapter: adapter, service: LatestMoviesService(api));
}
