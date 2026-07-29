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
import 'package:jade/features/categories/models/category_filter.dart';
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

    test('首页最新上架使用 can_play 的 latest 完整参数', () async {
      ok(adapter, Endpoints.moviesLatest, {
        'movies': [
          {'id': 'm2', 'number': 'N2', 'title': 'T2', 'cover_url': 'c2.jpg'},
        ],
      });

      final list = await svc.getLatest(page: 2);

      final request = adapter.requests.last;
      expect(request.path, Endpoints.moviesLatest);
      expect(request.uri.queryParameters, {
        'type': 'all',
        'filter_by': 'can_play',
        'sort_by': 'update',
        'order_by': 'desc',
        'limit': '9',
        'page': '2',
      });
      expect(list.single.id, 'm2');
    });

    test('首页近期磁链更新使用 magnets 的 latest 完整参数', () async {
      ok(adapter, Endpoints.moviesLatest, {
        'movies': [
          {'id': 'm3', 'number': 'N3', 'title': 'T3', 'cover_url': 'c3.jpg'},
        ],
      });

      final list = await svc.getMagnetUpdates(page: 3);

      final request = adapter.requests.last;
      expect(request.path, Endpoints.moviesLatest);
      expect(request.uri.queryParameters, {
        'type': 'all',
        'filter_by': 'magnets',
        'sort_by': 'update',
        'order_by': 'desc',
        'limit': '9',
        'page': '3',
      });
      expect(list.single.id, 'm3');
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

    test('GET /api/v1/movies/top → 使用 Top250 专用筛选参数', () async {
      ok(adapter, Endpoints.moviesTop, {
        'movies': [
          {'id': 'r1', 'number': 'R1', 'title': 'R', 'cover_url': 'c.jpg'},
        ],
        'current_page': 1,
        'total_pages': 1,
        'total': 1,
      });
      final r = await svc.getTop250(
        startRank: 51,
        type: 'video_type',
        typeValue: '2',
        ignoreWatched: true,
      );
      final q = adapter.requests.last.uri.queryParameters;
      expect(q['start_rank'], '51');
      expect(q['type'], 'video_type');
      expect(q['type_value'], '2');
      expect(q['ignore_watched'], 'true');
      expect(q['limit'], '50');
      expect(q.containsKey('page'), isFalse);
      expect(r.items.length, 1);
    });

    test('GET /api/v1/rankings/playback → 使用筛选与周期枚举', () async {
      ok(adapter, Endpoints.rankingsPlayback, {
        'movies': [],
        'current_page': 1,
        'total_pages': 1,
        'total': 0,
      });
      await svc.getPlayback(filterBy: 'high_score', period: 'weekly');
      expect(adapter.requests.last.path, Endpoints.rankingsPlayback);
      expect(
        adapter.requests.last.uri.queryParameters['filter_by'],
        'high_score',
      );
      expect(adapter.requests.last.uri.queryParameters['period'], 'weekly');
      expect(
        adapter.requests.last.uri.queryParameters.containsKey('page'),
        isFalse,
      );
      expect(
        adapter.requests.last.uri.queryParameters.containsKey('limit'),
        isFalse,
      );
    });

    test('GET /api/v1/rankings → 带 type/period/page 参数', () async {
      ok(adapter, Endpoints.rankings, {
        'movies': [],
        'current_page': 2,
        'total_pages': 2,
        'total': 0,
      });
      await svc.getRanking(type: '0', period: 'monthly', page: 2);
      final q = adapter.requests.last.uri.queryParameters;
      expect(q['type'], '0');
      expect(q['period'], 'monthly');
      expect(q['page'], '2');
      expect(q.containsKey('limit'), isFalse);
    });

    test('GET /api/v1/rankings/actors → 仅传整数 type', () async {
      ok(adapter, Endpoints.rankingsActors, {
        'actors': [],
        'current_page': 1,
        'total_pages': 1,
        'total': 0,
      });
      await svc.getActorRanking(type: 2);
      expect(adapter.requests.last.path, Endpoints.rankingsActors);
      final q = adapter.requests.last.uri.queryParameters;
      expect(q['type'], '2');
      expect(q.containsKey('period'), isFalse);
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
    late CategoryService service;

    setUp(() async {
      adapter = FakeAdapter();
      final api = await _createTestApi(adapter);
      service = CategoryService(api);
    });

    test('GET /api/v2/tags 按 type 获取并解析动态分组', () async {
      ok(adapter, Endpoints.tagsV2, {
        'tags': [
          {
            'category': '基本',
            'category_id': 'main',
            'tags': [
              {'id': 'p', 'name': '可播放', 'videos_count': 10},
            ],
          },
        ],
      });

      final groups = await service.getTags(type: 0);

      expect(adapter.requests.last.uri.queryParameters, {'type': '0'});
      expect(groups.single.categoryId, 'main');
      expect(groups.single.tags.single.id, 'p');
    });

    test('GET /api/v1/movies/tags 首次请求使用空筛选和 limit 48', () async {
      ok(adapter, Endpoints.moviesTags, {
        'movies': [
          {'id': 'm1', 'number': 'N1', 'title': 'T1', 'cover_url': 'c.jpg'},
        ],
        'current_page': 1,
        'total_pages': 2,
        'total_count': 49,
      });

      final result = await service.getMovies(
        type: 0,
        filter: const CategoryFilter(),
        categoryOrder: const [],
      );

      expect(adapter.requests.last.uri.queryParameters, {
        'filter_by': '0:t:::::',
        'sort_by': 'release',
        'order_by': 'desc',
        'page': '1',
        'limit': '48',
      });
      expect(result.total, 49);
    });

    test('非 release 排序不发送 order_by', () async {
      ok(adapter, Endpoints.moviesTags, {
        'movies': <Map<String, dynamic>>[],
        'current_page': 2,
        'total_pages': 2,
        'total': 0,
      });
      final filter = const CategoryFilter().copyWith(sort: CategorySort.score);

      await service.getMovies(
        type: 4,
        filter: filter,
        categoryOrder: const [],
        page: 2,
      );

      final query = adapter.requests.last.uri.queryParameters;
      expect(query['filter_by'], '4:t:::::');
      expect(query['sort_by'], 'score');
      expect(query.containsKey('order_by'), isFalse);
      expect(query['page'], '2');
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

    test('GET /api/v1/lists/simple 携带分页参数并解析 has_movie', () async {
      ok(adapter, Endpoints.listsSimple, {
        'lists': [
          {
            'id': 'list-1',
            'name': '已存入片单',
            'movies_count': 12,
            'views_count': 34,
            'has_movie': true,
          },
        ],
      });

      final lists = await svc.getSimpleLists('m1', page: 2);

      expect(adapter.requests.last.path, Endpoints.listsSimple);
      final query = adapter.requests.last.uri.queryParameters;
      expect(query['movie_id'], 'm1');
      expect(query['page'], '2');
      expect(query['limit'], '48');
      expect(lists.single.hasMovie, isTrue);
      expect(lists.single.movieCount, 12);
    });

    test(
      'POST /api/v1/lists/{list_id}/movie_actions 使用 multipart 表单',
      () async {
        ok(adapter, '${Endpoints.lists}/list-1/movie_actions', {});

        await svc.toggleMovieInList(
          listId: 'list-1',
          listName: '测试片单',
          movieId: 'm1',
        );

        final request = adapter.requests.last;
        expect(request.method, 'POST');
        expect(request.path, '${Endpoints.lists}/list-1/movie_actions');
        final formData = request.data as FormData;
        final fields = Map.fromEntries(formData.fields);
        expect(fields['movie_id'], 'm1');
        expect(fields['name'], '测试片单');
      },
    );

    test('POST /api/v1/lists 创建清单并存入当前影片', () async {
      ok(adapter, Endpoints.lists, {});

      await svc.createListWithMovie(name: '新清单', movieId: 'm1');

      final request = adapter.requests.last;
      expect(request.method, 'POST');
      expect(request.path, Endpoints.lists);
      final formData = request.data as FormData;
      final fields = Map.fromEntries(formData.fields);
      expect(fields['name'], '新清单');
      expect(fields['movie_id'], 'm1');
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

    test('GET /api/v1/movies/{id}/reviews → 携带 sort_by 参数', () async {
      ok(adapter, '/api/v1/movies/m1/reviews', {
        'reviews': <Map<String, dynamic>>[],
      });

      await svc.getReviews('m1', sortBy: 'recently');

      expect(adapter.requests.last.path, '/api/v1/movies/m1/reviews');
      expect(adapter.requests.last.uri.queryParameters['sort_by'], 'recently');
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
