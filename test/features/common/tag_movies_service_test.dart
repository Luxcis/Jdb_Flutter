import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/domain_manager.dart';
import 'package:jade/core/network/endpoints.dart';
import 'package:jade/core/network/interceptors/response_interceptor.dart';
import 'package:jade/core/network/testing/fake_adapter.dart';
import 'package:jade/features/common/services/tag_movies_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('filter_by 无筛选时拼接实体段，有筛选时追加 filter 段', () async {
    final fixture = await buildTagMoviesFixture();
    fixture.adapter.enqueueSequence(Endpoints.moviesTags, [
      tagMoviesResponse(),
      tagMoviesResponse(),
    ]);

    await fixture.service.getMovies(
      type: 2,
      category: 's',
      id: 's1',
      filter: '',
      sortBy: 'hit',
    );
    await fixture.service.getMovies(
      type: 2,
      category: 's',
      id: 's1',
      filter: 'm',
      sortBy: 'hit',
    );

    expect(
      fixture.adapter.requests.map(
        (request) => request.queryParameters['filter_by'],
      ),
      ['2:s:s1', '2:s:s1:m'],
    );
  });

  test('category=t 将筛选条件放在标签 ID 前', () async {
    final fixture = await buildTagMoviesFixture();
    fixture.adapter.enqueueSequence(Endpoints.moviesTags, [
      tagMoviesResponse(),
      tagMoviesResponse(),
      tagMoviesResponse(),
      tagMoviesResponse(),
    ]);

    for (final filter in ['', 'p', 'm', 'c']) {
      await fixture.service.getMovies(
        type: 1,
        category: 't',
        id: 'tag-9',
        filter: filter,
        sortBy: 'hit',
      );
    }

    expect(
      fixture.adapter.requests.map(
        (request) => request.queryParameters['filter_by'],
      ),
      ['1:t::tag-9', '1:t:p:tag-9', '1:t:m:tag-9', '1:t:c:tag-9'],
    );
  });

  test('sort_by=release 携带 order_by，其他排序不携带', () async {
    final fixture = await buildTagMoviesFixture();
    fixture.adapter.enqueueSequence(Endpoints.moviesTags, [
      tagMoviesResponse(),
      tagMoviesResponse(),
      tagMoviesResponse(),
    ]);

    await fixture.service.getMovies(
      type: 0,
      category: 'c',
      id: 'IPZZ',
      filter: 'm',
      sortBy: 'hit',
    );
    await fixture.service.getMovies(
      type: 0,
      category: 'c',
      id: 'IPZZ',
      filter: 'm',
      sortBy: 'release',
    );
    await fixture.service.getMovies(
      type: 0,
      category: 'c',
      id: 'IPZZ',
      filter: 'm',
      sortBy: 'release',
      orderBy: 'asc',
    );

    final params = fixture.adapter.requests
        .map((request) => request.queryParameters)
        .toList();
    expect(params[0].containsKey('order_by'), isFalse);
    expect(params[1]['order_by'], 'desc');
    expect(params[2]['order_by'], 'asc');
    expect(params[0]['sort_by'], 'hit');
    expect(params[1]['sort_by'], 'release');
    expect(params[2]['sort_by'], 'release');
  });

  test('movies 集合解析与分页元数据', () async {
    final fixture = await buildTagMoviesFixture();
    fixture.adapter.enqueue(Endpoints.moviesTags, {
      'success': 1,
      'data': {
        'movies': [
          {'id': 'm1', 'number': 'SSIS-001', 'title': '测试', 'cover_url': ''},
        ],
        'current_page': 2,
        'total_pages': 4,
        'total_count': 80,
      },
    });

    final result = await fixture.service.getMovies(
      type: 0,
      category: 'l',
      id: 'list-1',
      filter: 'm',
      sortBy: 'update',
      page: 2,
    );

    expect(result.items.single.id, 'm1');
    expect(result.currentPage, 2);
    expect(result.totalPages, 4);
    expect(result.total, 80);
    expect(fixture.adapter.requests.single.queryParameters, {
      'filter_by': '0:l:list-1:m',
      'sort_by': 'update',
      'page': 2,
      'limit': 48,
    });
  });

  test('缺少 total_pages 时按 48 条阈值推断下一页', () async {
    final fixture = await buildTagMoviesFixture();
    fixture.adapter.enqueueSequence(Endpoints.moviesTags, [
      {
        'success': 1,
        'data': {
          'movies': [
            for (var index = 0; index < 48; index++)
              {
                'id': 'm$index',
                'number': 'N$index',
                'title': 'T',
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
            {'id': 'm48', 'number': 'N48', 'title': 'T', 'cover_url': ''},
          ],
          'current_page': 2,
        },
      },
    ]);

    final full = await fixture.service.getMovies(
      type: 0,
      category: 'm',
      id: 'maker-1',
      filter: 'm',
      sortBy: 'hit',
    );
    final partial = await fixture.service.getMovies(
      type: 0,
      category: 'm',
      id: 'maker-1',
      filter: 'm',
      sortBy: 'hit',
    );

    expect(full.totalPages, 2);
    expect(partial.totalPages, 2);
  });
}

Future<({FakeAdapter adapter, TagMoviesService service})>
buildTagMoviesFixture() async {
  final preferences = await SharedPreferences.getInstance();
  final domainManager = await DomainManager.load(preferences);
  final adapter = FakeAdapter();
  final dio = Dio(BaseOptions(baseUrl: domainManager.currentUrl))
    ..httpClientAdapter = adapter
    ..interceptors.add(ResponseInterceptor(onAuthError: () {}));
  final api = ApiClient.forTest(dio: dio, domainManager: domainManager);
  return (adapter: adapter, service: TagMoviesService(api));
}

Map<String, dynamic> tagMoviesResponse() => {
  'success': 1,
  'data': {'movies': [], 'current_page': 1},
};
