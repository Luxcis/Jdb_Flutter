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
void ok(FakeAdapter a, String path, dynamic data,
    {int statusCode = 200}) {
  a.enqueue(path, {'success': 1, 'data': data},
      statusCode: statusCode);
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
      ok(adapter, Endpoints.startup, {
        'backup_domains_data': null,
      });
      await api.get(Endpoints.startup, queryParameters: {
        'platform': 'android',
        'app_channel': 'google',
        'app_version': '1.9.29',
        'app_version_number': '35',
      });
      expect(adapter.requests.last.path, Endpoints.startup);
      expect(
        adapter.requests.last.uri.queryParameters['platform'],
        'android',
      );
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
      ok(adapter, Endpoints.moviesRecommend, [
        {
          'id': 'm1', 'number': 'ABC-001', 'title': 'Test Movie',
          'cover_url': 'covers/x.jpg', 'score': 8.5,
        }
      ]);
      final list = await svc.getRecommends();
      expect(list.length, 1);
      expect(list.first.title, 'Test Movie');
      expect(list.first.score, 8.5);
    });

    test('GET /api/v1/movies/recommend_periods → 返回字符串列表', () async {
      ok(adapter, Endpoints.moviesRecommendPeriods, [
        '2024-01', '2024-02'
      ]);
      final list = await svc.getRecommendPeriods();
      expect(list, ['2024-01', '2024-02']);
    });

    test('GET /api/v1/movies/latest → 带分页参数', () async {
      ok(adapter, Endpoints.moviesLatest, {
        'items': [
          {'id': 'm1', 'number': 'N1', 'title': 'T1',
           'cover_url': 'c.jpg'},
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
        'items': [
          {'id': 'm1', 'number': 'N1', 'title': 'T1',
           'cover_url': 'c.jpg'},
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
        'items': [
          {'id': 'r1', 'number': 'R1', 'title': 'R',
           'cover_url': 'c.jpg'},
        ],
        'current_page': 1, 'total_pages': 1, 'total': 1,
      });
      final r = await svc.getTop250(page: 1);
      expect(r.items.length, 1);
    });

    test('GET /api/v1/rankings/playback → 看热播', () async {
      ok(adapter, Endpoints.rankingsPlayback, {
        'items': [],
        'current_page': 1, 'total_pages': 1, 'total': 0,
      });
      final r = await svc.getPlayback(period: 'monthly', page: 1);
      expect(adapter.requests.last.path, Endpoints.rankingsPlayback);
    });

    test('GET /api/v1/rankings → 带 type/period 参数', () async {
      ok(adapter, Endpoints.rankings, {
        'items': [],
        'current_page': 1, 'total_pages': 1, 'total': 0,
      });
      await svc.getRanking(type: 1, period: 'monthly', page: 1);
      final q = adapter.requests.last.uri.queryParameters;
      expect(q['type'], '1');
      expect(q['period'], 'monthly');
    });

    test('GET /api/v1/rankings/actors → 演员排名', () async {
      ok(adapter, Endpoints.rankingsActors, {
        'items': [],
        'current_page': 1, 'total_pages': 1, 'total': 0,
      });
      await svc.getActorRanking(type: 1, period: 'monthly', page: 1);
      expect(adapter.requests.last.path, Endpoints.rankingsActors);
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
        'items': [
          {'id': 'a1', 'name': 'Actor1', 'avatar_url': 'a.jpg'},
        ],
        'current_page': 1, 'total_pages': 3, 'total': 30,
      });
      final r = await svc.getActors(type: 1, page: 2, limit: 10);
      final q = adapter.requests.last.uri.queryParameters;
      expect(q['type'], '1');
      expect(q['page'], '2');
      expect(r.items.first.name, 'Actor1');
    });

    test('GET /api/v1/actors/recommend → 推荐演员', () async {
      ok(adapter, Endpoints.actorsRecommend, [
        {'id': 'a1', 'name': '新人A', 'avatar_url': 'a.jpg'},
      ]);
      final list = await svc.getRecommends();
      expect(list.length, 1);
      expect(list.first.name, '新人A');
    });

    test('GET /api/v1/actors/{id} → 演员详情', () async {
      ok(adapter, '${Endpoints.actors}/a1', {
        'id': 'a1', 'name': 'Actress', 'avatar_url': 'a.jpg',
        'birthday': '1998-05-20', 'age': 26,
        'height': '165cm', 'cup': 'D',
      });
      final d = await svc.getDetail('a1');
      expect(d.name, 'Actress');
      expect(d.age, 26);
    });

    test('GET /api/v1/actors/{id} → 最小字段容错', () async {
      ok(adapter, '${Endpoints.actors}/a1', {
        'id': 'a1', 'name': 'Minimal', 'avatar_url': 'a.jpg',
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
        'items': [
          {'id': 'm1', 'number': 'N1', 'title': 'T1',
           'cover_url': 'c.jpg'},
        ],
        'current_page': 1, 'total_pages': 1, 'total': 1,
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
        'id': 'm1', 'number': 'SSIS-001', 'title': 'Movie',
        'cover_url': 'c.jpg',
        'actors': [],
        'screenshots': ['s1.jpg'],
        'tags': ['Tag1'],
      });
      final d = await svc.getDetail('m1');
      expect(d.title, 'Movie');
      expect(d.screenshots.length, 1);
    });

    test('GET /api/v1/movies/{id}/magnets → 磁链列表', () async {
      ok(adapter, '/api/v1/movies/m1/magnets', [
        {
          'hash': 'abc123', 'title': 'Best', 'size': '2.1GB',
          'publish_date': '2024-01-01', 'is_high_definition': true,
        },
      ]);
      final list = await svc.getMagnets('m1');
      expect(list.first.hash, 'abc123');
      expect(list.first.isHighDefinition, isTrue);
    });

    test('GET /api/v1/movies/{id}/reviews → 评论列表', () async {
      ok(adapter, '/api/v1/movies/m1/reviews', [
        {
          'id': 'r1', 'score': 4.0, 'content': 'Great!',
          'status': 'public',
          'author': {'name': 'User1'},
        },
      ]);
      final list = await svc.getReviews('m1');
      expect(list.first.content, 'Great!');
    });

    test('GET /api/v1/movies/{id}/may_also_like → 你可能也喜欢', () async {
      ok(adapter, '/api/v1/movies/m1/may_also_like', [
        {'id': 'm2', 'number': 'ABC-001', 'title': 'Related',
         'cover_url': 'c.jpg'},
      ]);
      final list = await svc.getMayAlsoLike('m1');
      expect(list.first.title, 'Related');
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
      final resp = await api.post(Endpoints.sessions, data: {
        'username': 'test@test.com',
        'password': 'password',
      });
      expect(adapter.requests.last.method, 'POST');
      expect(adapter.requests.last.path, Endpoints.sessions);
      expect(resp.data, contains('token'));
    });

    test('POST /api/v1/users → 注册（含设备信息）', () async {
      ok(adapter, Endpoints.users, {});
      await api.post(Endpoints.users, data: {
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
      });
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
          {'id': 'm1', 'number': 'ABC-001', 'title': 'Test',
           'cover_url': 'c.jpg'},
        ],
        'current_page': 1, 'total_pages': 3, 'total': 30,
      });
      final resp = await api.get(Endpoints.searchV2, queryParameters: {
        'q': 'test', 'type': 'movie', 'page': 1,
      });
      final q = adapter.requests.last.uri.queryParameters;
      expect(q['q'], 'test');
      expect(q['type'], 'movie');
    });

    test('GET /api/v2/search → 演员搜索', () async {
      ok(adapter, Endpoints.searchV2, {
        'actors': [
          {'id': 'a1', 'name': 'Actor1', 'avatar_url': 'a.jpg'},
        ],
        'current_page': 1, 'total_pages': 1, 'total': 1,
      });
      await api.get(Endpoints.searchV2, queryParameters: {
        'q': 'test', 'type': 'actor',
      });
      expect(
        adapter.requests.last.uri.queryParameters['type'],
        'actor',
      );
    });
  });
}
