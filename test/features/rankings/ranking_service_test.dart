import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/domain_manager.dart';
import 'package:jade/core/network/endpoints.dart';
import 'package:jade/core/network/interceptors/response_interceptor.dart';
import 'package:jade/core/network/testing/fake_adapter.dart';
import 'package:jade/features/rankings/services/ranking_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 创建测试用 ApiClient，装配 ResponseInterceptor 以解包 success/data。
Future<ApiClient> _createTestApi(FakeAdapter adapter) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('key_baseurl', 'https://jdforrepam.com');
  await prefs.setStringList('key_api_domains', ['https://jdforrepam.com']);
  final dm = await DomainManager.load(prefs);
  final dio = Dio(BaseOptions(baseUrl: dm.currentUrl));
  dio.httpClientAdapter = adapter;
  dio.interceptors.add(ResponseInterceptor(onAuthError: () {}));
  return ApiClient.forTest(dio: dio, domainManager: dm);
}

Map<String, dynamic> _movie(int rank, {Object? ranking}) => {
  'id': 'm-$rank',
  'number': 'M-$rank',
  'title': 'Movie $rank',
  'cover_url': 'cover.jpg',
  'ranking': ?ranking,
};

void _ok(FakeAdapter adapter, String path, Map<String, dynamic> data) {
  adapter.enqueue(path, {'success': 1, 'data': data});
}

List<Map<String, dynamic>> _movies(int from, int to) => [
  for (var rank = from; rank <= to; rank++) _movie(rank),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('榜单分页推断（响应缺少 total_pages）', () {
    late FakeAdapter adapter;
    late RankingService service;

    setUp(() async {
      adapter = FakeAdapter();
      service = RankingService(await _createTestApi(adapter));
    });

    test('满页时 totalPages 为 page + 1，可继续加载第 2 页', () async {
      _ok(adapter, Endpoints.rankings, {
        'movies': _movies(1, RankingService.defaultRankingPageSize),
        'current_page': 1,
      });

      final result = await service.getRanking(type: '0');

      expect(result.items, hasLength(RankingService.defaultRankingPageSize));
      expect(result.currentPage, 1);
      expect(result.totalPages, 2);
    });

    test('未满页时判定为末页', () async {
      _ok(adapter, Endpoints.rankings, {
        'movies': _movies(1, 7),
        'current_page': 1,
      });

      final result = await service.getRanking(type: '0');

      expect(result.currentPage, 1);
      expect(result.totalPages, 1);
    });

    test('服务端 current_page 前移时按服务端页码推断', () async {
      _ok(adapter, Endpoints.rankings, {
        'movies': _movies(51, 70),
        'current_page': 2,
      });

      final result = await service.getRanking(type: '0', page: 1);

      expect(result.currentPage, 2);
      expect(result.totalPages, 3);
    });

    test('响应携带 total_pages 时以其为准', () async {
      _ok(adapter, Endpoints.rankings, {
        'movies': _movies(1, 3),
        'current_page': 1,
        'total_pages': 9,
      });

      final result = await service.getRanking(type: '0');

      expect(result.totalPages, 9);
    });

    test('播放榜请求不携带页码，不做满页推断', () async {
      _ok(adapter, Endpoints.rankingsPlayback, {
        'movies': _movies(1, RankingService.defaultRankingPageSize),
        'current_page': 1,
      });

      final result = await service.getPlayback();

      expect(result.items, hasLength(RankingService.defaultRankingPageSize));
      expect(result.totalPages, 1);
      expect(
        adapter.requests.last.uri.queryParameters.containsKey('page'),
        isFalse,
      );
    });
  });

  group('Top250 响应解析', () {
    late FakeAdapter adapter;
    late RankingService service;

    setUp(() async {
      adapter = FakeAdapter();
      service = RankingService(await _createTestApi(adapter));
    });

    test('解析服务端 ranking 字段，缺失时为 null', () async {
      _ok(adapter, Endpoints.moviesTop, {
        'movies': [_movie(1, ranking: 1), _movie(4, ranking: '4'), _movie(7)],
        'current_page': 1,
      });

      final result = await service.getTop250();

      expect(result.items.map((movie) => movie.ranking), [1, 4, null]);
    });

    test('满页 50 条且缺少 total_pages 时 totalPages 为 2', () async {
      _ok(adapter, Endpoints.moviesTop, {'movies': _movies(1, 50)});

      final result = await service.getTop250();

      expect(result.items, hasLength(50));
      expect(result.totalPages, 2);
    });
  });
}
