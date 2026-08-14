import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/domain_manager.dart';
import 'package:jade/core/network/endpoints.dart';
import 'package:jade/core/network/interceptors/response_interceptor.dart';
import 'package:jade/core/network/testing/fake_adapter.dart';
import 'package:jade/features/profile/services/review_movies_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('我想看的首屏完整发送状态 类型 排序和 24 条分页参数', () async {
    final fixture = await _buildFixture();
    fixture.adapter.enqueue(Endpoints.usersReviewMoviesV2, {
      'success': 1,
      'data': {'movies': [], 'current_page': 1},
    });

    await fixture.service.getMovies(
      status: 'want_watch',
      type: 'all',
      sortBy: 'create',
      orderBy: 'desc',
    );

    expect(fixture.adapter.requests.single.queryParameters, {
      'status': 'want_watch',
      'type': 'all',
      'sort_by': 'create',
      'order_by': 'desc',
      'page': 1,
      'limit': 24,
    });
  });

  test('解析 movies 与 current_page 并保留影片摘要字段', () async {
    final fixture = await _buildFixture();
    fixture.adapter.enqueue(Endpoints.usersReviewMoviesV2, {
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
      status: 'want_watch',
      type: '1',
      sortBy: 'release',
      orderBy: 'asc',
      page: 2,
    );

    expect(result.items.single.id, 'm1');
    expect(result.items.single.thumbUrl, 'thumb.jpg');
    expect(result.items.single.score, 4.5);
    expect(result.currentPage, 2);
    expect(result.totalPages, 3);
    expect(result.total, 49);
  });

  test('缺少 total_pages 时以 24 条为满页阈值', () async {
    final fixture = await _buildFixture();
    fixture.adapter.enqueueSequence(Endpoints.usersReviewMoviesV2, [
      {
        'success': 1,
        'data': {
          'movies': [
            for (var index = 0; index < 24; index++)
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
            {'id': 'm24', 'number': 'N24', 'title': '影片 24', 'cover_url': ''},
          ],
          'current_page': 2,
        },
      },
    ]);

    final fullPage = await fixture.service.getMovies(
      status: 'want_watch',
      type: 'all',
      sortBy: 'create',
      orderBy: 'desc',
    );
    final partialPage = await fixture.service.getMovies(
      status: 'want_watch',
      type: 'all',
      sortBy: 'create',
      orderBy: 'desc',
      page: 2,
    );

    expect(fullPage.totalPages, 2);
    expect(partialPage.totalPages, 2);
  });
}

Future<({FakeAdapter adapter, ReviewMoviesService service})>
_buildFixture() async {
  final preferences = await SharedPreferences.getInstance();
  final domainManager = await DomainManager.load(preferences);
  final adapter = FakeAdapter();
  final dio = Dio(BaseOptions(baseUrl: domainManager.currentUrl))
    ..httpClientAdapter = adapter
    ..interceptors.add(ResponseInterceptor(onAuthError: () {}));
  final api = ApiClient.forTest(dio: dio, domainManager: domainManager);
  return (adapter: adapter, service: ReviewMoviesService(api));
}
