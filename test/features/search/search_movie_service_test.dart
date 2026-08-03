import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/domain_manager.dart';
import 'package:jade/core/network/endpoints.dart';
import 'package:jade/core/network/interceptors/response_interceptor.dart';
import 'package:jade/core/network/testing/fake_adapter.dart';
import 'package:jade/features/search/models/search_movie_filter.dart';
import 'package:jade/features/search/services/search_movie_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('搜索影片携带完整筛选参数并解析分页响应', () async {
    final fixture = await _createFixture();
    fixture.adapter.enqueue(Endpoints.searchV2, {
      'success': 1,
      'data': {
        'movies': [
          {'id': 'movie-1', 'number': 'ABP-001', 'cover_url': 'cover.jpg'},
        ],
        'current_page': 2,
        'total_pages': 4,
        'total_count': 150,
      },
    });

    final result = await fixture.service.getMovies(
      query: 'ABP-001',
      filter: const SearchMovieFilter(
        type: SearchMovieType.uncensored,
        availability: SearchMovieAvailability.single,
        sort: SearchMovieSort.score,
      ),
      page: 2,
    );

    expect(fixture.adapter.requests.single.queryParameters, {
      'q': 'ABP-001',
      'type': 'movie',
      'movie_type': '1',
      'movie_filter_by': 'single',
      'movie_sort_by': 'score',
      'page': 2,
      'limit': 48,
    });
    expect(result.currentPage, 2);
    expect(result.totalPages, 4);
    expect(result.total, 150);
    expect(result.items.single.number, 'ABP-001');
  });

  test('缺失 total_pages 且当前页满页时推断存在下一页', () async {
    final fixture = await _createFixture();
    _enqueuePage(fixture.adapter, itemCount: 48);

    final result = await fixture.service.getMovies(
      query: 'ABP',
      filter: const SearchMovieFilter(),
    );

    expect(result.currentPage, 1);
    expect(result.totalPages, 2);
  });

  test('缺失 total_pages 且当前页非满页时推断当前页为末页', () async {
    final fixture = await _createFixture();
    _enqueuePage(fixture.adapter, itemCount: 47);

    final result = await fixture.service.getMovies(
      query: 'ABP',
      filter: const SearchMovieFilter(),
    );

    expect(result.currentPage, 1);
    expect(result.totalPages, 1);
  });
}

Future<({FakeAdapter adapter, SearchMovieService service})>
_createFixture() async {
  final preferences = await SharedPreferences.getInstance();
  final domainManager = await DomainManager.load(preferences);
  final adapter = FakeAdapter();
  final dio = Dio(BaseOptions(baseUrl: domainManager.currentUrl))
    ..httpClientAdapter = adapter
    ..interceptors.add(ResponseInterceptor(onAuthError: () {}));
  final api = ApiClient.forTest(dio: dio, domainManager: domainManager);
  return (adapter: adapter, service: SearchMovieService(api));
}

void _enqueuePage(FakeAdapter adapter, {required int itemCount}) {
  adapter.enqueue(Endpoints.searchV2, {
    'success': 1,
    'data': {
      'movies': [
        for (var index = 0; index < itemCount; index++)
          {
            'id': 'movie-$index',
            'number': 'ABP-$index',
            'cover_url': 'cover-$index.jpg',
          },
      ],
      'current_page': 1,
      'total_count': itemCount,
    },
  });
}
