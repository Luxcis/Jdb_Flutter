import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/domain_manager.dart';
import 'package:jade/core/network/testing/fake_adapter.dart';
import 'package:jade/core/network/interceptors/response_interceptor.dart';
import 'package:jade/core/network/endpoints.dart';
import 'package:jade/features/home/services/home_service.dart';
import 'package:jade/features/rankings/services/ranking_service.dart';
import 'package:jade/features/actors/services/actor_service.dart';
import 'package:jade/features/categories/services/category_service.dart';
import 'package:jade/features/movie_detail/services/movie_detail_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 创建测试用 ApiClient，装配 ResponseInterceptor 以解包 success/data。
/// FakeAdapter 按 path 匹配，不区分 method。
Future<ApiClient> _createTestApi(FakeAdapter adapter) async {
  final prefs = await SharedPreferences.getInstance();
  // 预设域名避免 domain resolver 报错
  await prefs.setString('key_baseurl', 'https://jdforrepam.com');
  await prefs.setStringList('key_api_domains', ['https://jdforrepam.com']);
  final dm = await DomainManager.load(prefs);
  final dio = Dio(BaseOptions(baseUrl: dm.currentUrl));
  dio.httpClientAdapter = adapter;
  // 装配 ResponseInterceptor 解包 success/data 信封
  dio.interceptors.add(ResponseInterceptor(onAuthError: () {}));
  return ApiClient.forTest(dio: dio, domainManager: dm);
}

/// stub 成功响应：adapter.enqueue(path, {'success':1,'data': data})
void ok(FakeAdapter a, String path, dynamic data, {int statusCode = 200}) {
  a.enqueue(path, {'success': 1, 'data': data}, statusCode: statusCode);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // ═══════════════════════════════════════════════
  // 1. 启动接口
  // ═══════════════════════════════════════════════
  group('GET /api/v1/startup', () {
    late FakeAdapter adapter;
    late ApiClient api;

    setUp(() async {
      adapter = FakeAdapter();
      api = await _createTestApi(adapter);
    });

    test('路径正确且带 platform 参数', () async {
      ok(adapter, Endpoints.startup, {'backup_domains_data': null});
      await api.get(
        Endpoints.startup,
        queryParameters: {
          'platform': 'android',
          'app_channel': 'google',
          'app_version': '1.9.29',
          'app_version_number': '35',
        },
      );
      expect(adapter.requests.last.path, Endpoints.startup);
      expect(adapter.requests.last.uri.queryParameters['platform'], 'android');
    });
  });

  // ═══════════════════════════════════════════════
  // 2. HomeService — 首页 4 个接口
  // ═══════════════════════════════════════════════
  group('HomeService', () {
    late FakeAdapter adapter;
    late HomeService svc;

    setUp(() async {
      adapter = FakeAdapter();
      final api = await _createTestApi(adapter);
      svc = HomeService(api);
    });

    test('GET /api/v1/movies/recommend → 解析 MovieSummary 列表', () async {
      ok(adapter, Endpoints.moviesRecommend, {
        'movies': [
          {
            'id': 'm1',
            'number': 'ABC-001',
            'title': 'Test Movie',
            'cover_url': 'covers/x.jpg',
            'score': 8.5,
          },
        ],
      });
      final list = await svc.getRecommends();
      expect(list.length, 1);
      expect(list.first.title, 'Test Movie');
      expect(list.first.score, 8.5);
    });

    test('GET /api/v1/movies/recommend_periods → 返回字符串列表', () async {
      ok(adapter, Endpoints.moviesRecommendPeriods, {
        'periods': [
          {'period': '2024-01'},
          {'period': '2024-02'},
        ],
      });
      final list = await svc.getRecommendPeriods();
      expect(list, ['2024-01', '2024-02']);
    });

    test('GET /api/v1/movies/latest → 带分页参数', () async {
      ok(adapter, Endpoints.moviesLatest, {
        'movies': [
          {'id': 'm1', 'number': 'N1', 'title': 'T1', 'cover_url': 'c.jpg'},
        ],
      });
      final list = await svc.getLatest(page: 2, limit: 10);
      final q = adapter.requests.last.uri.queryParameters;
      expect(q['page'], '2');
      expect(q['limit'], '10');
      expect(list.length, 1);
    });

    test('GET /api/v1/movies/tags → magnet 更新带 filter_by', () async {
      ok(adapter, Endpoints.moviesTags, {
        'movies': [
          {'id': 'm1', 'number': 'N1', 'title': 'T1', 'cover_url': 'c.jpg'},
        ],
      });
      final list = await svc.getMagnetUpdates(limit: 9);
      final q = adapter.requests.last.uri.queryParameters;
      expect(q['filter_by'], 'categories');
      expect(q['sort_by'], 'magnet_date');
      expect(list.length, 1);
    });
  });

  // ═══════════════════════════════════════════════
  // 3. RankingService — 排行榜 4 个接口
  // ═══════════════════════════════════════════════
  group('RankingService', () {
    late FakeAdapter adapter;
    late RankingService svc;

    setUp(() async {
      adapter = FakeAdapter();
      final api = await _createTestApi(adapter);
      svc = RankingService(api);
    });

    test('GET /api/v1/movies/top → Top250', () async {
      ok(adapter, Endpoints.moviesTop, {
        'movies': [
          {'id': 'r1', 'number': 'R1', 'title': 'R', 'cover_url': 'c.jpg'},
        ],
        'current_page': 1,
        'total_pages': 1,
        'total': 1,
      });
      final r = await svc.getTop250(page: 1);
      expect(r.items.length, 1);
    });

    test('GET /api/v1/rankings/playback → 看热播', () async {
      ok(adapter, Endpoints.rankingsPlayback, {
        'movies': [],
        'current_page': 1,
        'total_pages': 1,
        'total': 0,
      });
      await svc.getPlayback(filterBy: 'month', period: 'all', page: 1);
      expect(adapter.requests.last.path, Endpoints.rankingsPlayback);
      expect(adapter.requests.last.uri.queryParameters['filter_by'], 'month');
      expect(adapter.requests.last.uri.queryParameters['period'], 'all');
      expect(
        adapter.requests.last.uri.queryParameters.containsKey('page'),
        isFalse,
      );
      expect(
        adapter.requests.last.uri.queryParameters.containsKey('limit'),
        isFalse,
      );
    });

    test('GET /api/v1/rankings → 带 type/period 参数', () async {
      ok(adapter, Endpoints.rankings, {
        'movies': [],
        'current_page': 1,
        'total_pages': 1,
        'total': 0,
      });
      await svc.getRanking(type: 'month', period: 'month', page: 1);
      final q = adapter.requests.last.uri.queryParameters;
      expect(q['type'], 'month');
      expect(q['period'], 'month');
      expect(q.containsKey('page'), isFalse);
      expect(q.containsKey('limit'), isFalse);
    });

    test('GET /api/v1/rankings/actors → 演员排名', () async {
      ok(adapter, Endpoints.rankingsActors, {
        'actors': [],
        'current_page': 1,
        'total_pages': 1,
        'total': 0,
      });
      await svc.getActorRanking(type: 'month', period: 'month', page: 1);
      expect(adapter.requests.last.path, Endpoints.rankingsActors);
      final q = adapter.requests.last.uri.queryParameters;
      expect(q['type'], 'month');
      expect(q['period'], 'month');
      expect(q.containsKey('page'), isFalse);
      expect(q.containsKey('limit'), isFalse);
    });
  });

  // ═══════════════════════════════════════════════
  // 4. ActorService — 演员 4 个接口
  // ═══════════════════════════════════════════════
  group('ActorService', () {
    late FakeAdapter adapter;
    late ActorService svc;

    setUp(() async {
      adapter = FakeAdapter();
      final api = await _createTestApi(adapter);
      svc = ActorService(api);
    });

    test('GET /api/v1/actors → 带 type/page 参数', () async {
      ok(adapter, Endpoints.actors, {
        'actors': [
          {'id': 'a1', 'name': 'Actor1', 'avatar_url': 'a.jpg'},
        ],
        'current_page': 1,
        'total_pages': 3,
        'total': 30,
      });
      final r = await svc.getActors(type: 'hot', page: 2, limit: 10);
      final q = adapter.requests.last.uri.queryParameters;
      expect(q['type'], 'hot');
      expect(q.containsKey('page'), isFalse);
      expect(r.items.first.name, 'Actor1');
    });

    test('GET /api/v1/actors/recommend → 推荐演员', () async {
      ok(adapter, Endpoints.actorsRecommend, {
        'new_actors': [
          {'id': 'a1', 'name': '新人A', 'avatar_url': 'a.jpg'},
        ],
        'monthly_actors': [],
        'recommend_actors': [],
      });
      final list = await svc.getRecommends();
      expect(list.length, 1);
      expect(list.first.name, '新人A');
    });

    test('GET /api/v1/actors/{id} → 演员详情', () async {
      ok(adapter, '${Endpoints.actors}/a1', {
        'actor': {
          'id': 'a1',
          'name': 'Actress',
          'avatar_url': 'a.jpg',
          'birthday': '1998-05-20',
          'age': 26,
          'height': 165,
          'cup': 'D',
        },
      });
      final d = await svc.getDetail('a1');
      expect(d.name, 'Actress');
      expect(d.age, 26);
    });

    test('GET /api/v1/actors/{id} → 最小字段容错', () async {
      ok(adapter, '${Endpoints.actors}/a1', {
        'id': 'a1',
        'name': 'Minimal',
        'avatar_url': 'a.jpg',
      });
      final d = await svc.getDetail('a1');
      expect(d.name, 'Minimal');
      expect(d.birthday, isNull);
    });
  });

  // ═══════════════════════════════════════════════
  // 5. CategoryService
  // ═══════════════════════════════════════════════
  group('CategoryService', () {
    late FakeAdapter adapter;
    late CategoryService svc;

    setUp(() async {
      adapter = FakeAdapter();
      final api = await _createTestApi(adapter);
      svc = CategoryService(api);
    });

    test('GET /api/v1/movies/tags → 带 type/sort/filter_by 参数', () async {
      ok(adapter, Endpoints.moviesTags, {
        'movies': [
          {'id': 'm1', 'number': 'N1', 'title': 'T1', 'cover_url': 'c.jpg'},
        ],
        'current_page': 1,
        'total_pages': 1,
        'total': 1,
      });
      await svc.getMovies(type: 1, sortBy: 'date', orderBy: 'desc');
      final q = adapter.requests.last.uri.queryParameters;
      expect(q['type'], '1');
      expect(q['filter_by'], 'categories');
      expect(q['sort_by'], 'date');
      expect(q['order_by'], 'desc');
    });
  });

  // ═══════════════════════════════════════════════
  // 6. MovieDetailService — 影片详情 4 个接口
  // ═══════════════════════════════════════════════
  group('MovieDetailService', () {
    late FakeAdapter adapter;
    late MovieDetailService svc;

    setUp(() async {
      adapter = FakeAdapter();
      final api = await _createTestApi(adapter);
      svc = MovieDetailService(api);
    });

    test('GET /api/v4/movies/{id} → 影片详情V4', () async {
      ok(adapter, '/api/v4/movies/m1', {
        'movie': {
          'id': 'm1',
          'number': 'SSIS-001',
          'title': 'Movie',
          'cover_url': 'c.jpg',
          'actors': [],
          'preview_images': [
            {'url': 's1.jpg'},
          ],
          'tags': [
            {'name': 'Tag1'},
          ],
        },
      });
      final d = await svc.getDetail('m1');
      expect(d.title, 'Movie');
      expect(d.screenshots.length, 1);
    });

    test('GET /api/v1/movies/{id}/magnets 解析真实字段类型', () async {
      ok(adapter, '/api/v1/movies/m1/magnets', {
        'magnets': [
          {
            'name': 'movie.torrent',
            'hash': 'hash-1',
            'size': 9910,
            'hd': true,
            'created_at': '2026-07-22',
          },
        ],
      });

      final magnets = await svc.getMagnets('m1');

      expect(adapter.requests.last.path, '/api/v1/movies/m1/magnets');
      expect(magnets.single.size, '9.68 GB');
      expect(magnets.single.isHighDefinition, isTrue);
    });

    test('GET /api/v1/lists/related 携带 movie_id 并解析统计字段', () async {
      ok(adapter, Endpoints.listsRelated, {
        'lists': [
          {
            'id': 'list-1',
            'name': '测试片单',
            'movies_count': 12,
            'views_count': 34,
          },
        ],
      });

      final lists = await svc.getRelatedLists('m1');

      expect(adapter.requests.last.path, Endpoints.listsRelated);
      expect(adapter.requests.last.uri.queryParameters['movie_id'], 'm1');
      expect(lists.single.movieCount, 12);
      expect(lists.single.viewedCount, 34);
    });

    test('GET /api/v1/movies/{id}/reviews → 评论列表', () async {
      ok(adapter, '/api/v1/movies/m1/reviews', {
        'reviews': [
          {
            'id': 1,
            'score': 4,
            'content': 'Great!',
            'status': 'public',
            'username': 'User1',
            'likes_count': 3,
          },
        ],
      });
      final list = await svc.getReviews('m1');
      expect(list.first.content, 'Great!');
    });

    test('getMagnets 空列表容错', () async {
      ok(adapter, '/api/v1/movies/m1/magnets', []);
      final list = await svc.getMagnets('m1');
      expect(list, isEmpty);
    });
  });

  // ═══════════════════════════════════════════════
  // 7. 认证接口
  // ═══════════════════════════════════════════════
  group('Auth endpoints', () {
    late FakeAdapter adapter;
    late ApiClient api;

    setUp(() async {
      adapter = FakeAdapter();
      api = await _createTestApi(adapter);
    });

    test('POST /api/v1/sessions → 登录', () async {
      ok(adapter, Endpoints.sessions, {
        'token': 'jwt-token',
        'user': {'id': 1, 'username': 'test'},
      });
      final resp = await api.post(
        Endpoints.sessions,
        data: {'username': 'test@test.com', 'password': 'password'},
      );
      expect(adapter.requests.last.method, 'POST');
      expect(adapter.requests.last.path, Endpoints.sessions);
      expect(resp.data, contains('token'));
    });

    test('POST /api/v1/users → 注册（含设备信息）', () async {
      ok(adapter, Endpoints.users, {});
      await api.post(
        Endpoints.users,
        data: {
          'email': 'new@test.com',
          'username': 'new@test.com',
          'password': 'pass123',
          'device_uuid': 'test-uuid',
          'device_name': 'Jade',
          'device_model': 'Flutter',
          'platform': 'android',
          'system_version': '14',
          'app_channel': 'google',
          'app_version': '1.9.29',
          'app_version_number': '35',
        },
      );
      expect(adapter.requests.last.path, Endpoints.users);
    });
  });

  // ═══════════════════════════════════════════════
  // 8. 搜索接口
  // ═══════════════════════════════════════════════
  group('Search endpoint', () {
    late FakeAdapter adapter;
    late ApiClient api;

    setUp(() async {
      adapter = FakeAdapter();
      api = await _createTestApi(adapter);
    });

    test('GET /api/v2/search → 影片搜索', () async {
      ok(adapter, Endpoints.searchV2, {
        'movies': [
          {
            'id': 'm1',
            'number': 'ABC-001',
            'title': 'Test',
            'cover_url': 'c.jpg',
          },
        ],
        'current_page': 1,
        'total_pages': 3,
        'total': 30,
      });
      await api.get(
        Endpoints.searchV2,
        queryParameters: {'q': 'test', 'type': 'movie', 'page': 1},
      );
      final q = adapter.requests.last.uri.queryParameters;
      expect(q['q'], 'test');
      expect(q['type'], 'movie');
    });

    test('GET /api/v2/search → 演员搜索', () async {
      ok(adapter, Endpoints.searchV2, {
        'actors': [
          {'id': 'a1', 'name': 'Actor1', 'avatar_url': 'a.jpg'},
        ],
        'current_page': 1,
        'total_pages': 1,
        'total': 1,
      });
      await api.get(
        Endpoints.searchV2,
        queryParameters: {'q': 'test', 'type': 'actor'},
      );
      expect(adapter.requests.last.uri.queryParameters['type'], 'actor');
    });
  });
}
