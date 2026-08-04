import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/domain_manager.dart';
import 'package:jade/core/network/endpoints.dart';
import 'package:jade/core/network/interceptors/response_interceptor.dart';
import 'package:jade/core/network/testing/fake_adapter.dart';
import 'package:jade/features/search/services/search_entity_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('六类搜索发送 type page limit 并解析强类型结果', () async {
    final fixture = await buildSearchEntityFixture();
    fixture.adapter.enqueue(Endpoints.searchV2, {
      'success': 1,
      'data': {
        'series': [
          {'id': 's1', 'name': 'Madonna', 'videos_count': 9},
        ],
        'current_page': 2,
        'total_pages': 4,
        'total': 80,
      },
    });

    final result = await fixture.service.getSeries(query: 'madonna', page: 2);

    expect(result.items.single.id, 's1');
    expect(result.items.single.name, 'Madonna');
    expect(result.items.single.movieCount, 9);
    expect(result.currentPage, 2);
    expect(result.totalPages, 4);
    expect(fixture.adapter.requests.single.queryParameters, {
      'q': 'madonna',
      'type': 'series',
      'page': 2,
      'limit': 48,
    });
  });

  test('番号兼容 name 且清单兼容 movies_count views_count', () async {
    final fixture = await buildSearchEntityFixture();
    fixture.adapter.enqueueSequence(Endpoints.searchV2, [
      {
        'success': 1,
        'data': {
          'codes': [
            {'id': 'IPZZ', 'name': 'IPZZ', 'videos_count': 7},
          ],
        },
      },
      {
        'success': 1,
        'data': {
          'lists': [
            {'id': 'l1', 'name': '收藏精选', 'movies_count': 12, 'views_count': 34},
          ],
        },
      },
    ]);

    final codes = await fixture.service.getCodes(query: 'IPZZ');
    final lists = await fixture.service.getLists(query: '收藏');

    expect(codes.items.single.number, 'IPZZ');
    expect(codes.items.single.movieCount, 7);
    expect(lists.items.single.movieCount, 12);
    expect(lists.items.single.viewedCount, 34);
  });

  test('缺少 total_pages 时满 48 条允许下一页，少于 48 条停止', () async {
    final fixture = await buildSearchEntityFixture();
    fixture.adapter.enqueueSequence(Endpoints.searchV2, [
      makerResponse(48),
      makerResponse(47),
    ]);

    final full = await fixture.service.getMakers(query: 'S1');
    final partial = await fixture.service.getMakers(query: 'S1');

    expect(full.totalPages, 2);
    expect(partial.totalPages, 1);
  });

  test('演员片商导演使用各自 type 和集合键', () async {
    final fixture = await buildSearchEntityFixture();
    fixture.adapter.enqueueSequence(Endpoints.searchV2, [
      {
        'success': 1,
        'data': {
          'actors': [
            {'id': 'a1', 'name': '演员', 'avatar_url': ''},
          ],
        },
      },
      {
        'success': 1,
        'data': {
          'makers': [
            {'id': 'm1', 'name': '片商', 'videos_count': 2},
          ],
        },
      },
      {
        'success': 1,
        'data': {
          'directors': [
            {'id': 'd1', 'name': '导演', 'videos_count': 3},
          ],
        },
      },
    ]);

    expect((await fixture.service.getActors(query: 'q')).items.single.id, 'a1');
    expect((await fixture.service.getMakers(query: 'q')).items.single.id, 'm1');
    expect(
      (await fixture.service.getDirectors(query: 'q')).items.single.id,
      'd1',
    );
    expect(
      fixture.adapter.requests.map(
        (request) => request.queryParameters['type'],
      ),
      ['actor', 'maker', 'director'],
    );
    expect(
      fixture.adapter.requests.map(
        (request) => request.queryParameters['page'],
      ),
      [1, 1, 1],
    );
    expect(
      fixture.adapter.requests.map(
        (request) => request.queryParameters['limit'],
      ),
      [48, 48, 48],
    );
  });

  test('搜索结果实体保留 type 字段', () async {
    final fixture = await buildSearchEntityFixture();
    fixture.adapter.enqueueSequence(Endpoints.searchV2, [
      {'success': 1, 'data': {'series': [{'id': 's1', 'name': 'S', 'type': 2, 'videos_count': 1}]}},
      {'success': 1, 'data': {'codes': [{'id': 'C', 'name': 'C', 'type': 3, 'videos_count': 1}]}},
      {'success': 1, 'data': {'makers': [{'id': 'm1', 'name': 'M', 'type': 1, 'videos_count': 1}]}},
      {'success': 1, 'data': {'directors': [{'id': 'd1', 'name': 'D', 'type': 4, 'videos_count': 1}]}},
    ]);

    expect((await fixture.service.getSeries(query: 'q')).items.single.type, 2);
    expect((await fixture.service.getCodes(query: 'q')).items.single.type, 3);
    expect((await fixture.service.getMakers(query: 'q')).items.single.type, 1);
    expect((await fixture.service.getDirectors(query: 'q')).items.single.type, 4);
  });

  test('搜索结果实体缺失 type 时默认为 0', () async {
    final fixture = await buildSearchEntityFixture();
    fixture.adapter.enqueue(Endpoints.searchV2, {
      'success': 1,
      'data': {'series': [{'id': 's1', 'name': 'S', 'videos_count': 1}]},
    });

    expect((await fixture.service.getSeries(query: 'q')).items.single.type, 0);
  });
}

Future<({FakeAdapter adapter, SearchEntityService service})>
buildSearchEntityFixture() async {
  final preferences = await SharedPreferences.getInstance();
  final domainManager = await DomainManager.load(preferences);
  final adapter = FakeAdapter();
  final dio = Dio(BaseOptions(baseUrl: domainManager.currentUrl))
    ..httpClientAdapter = adapter
    ..interceptors.add(ResponseInterceptor(onAuthError: () {}));
  final api = ApiClient.forTest(dio: dio, domainManager: domainManager);
  return (adapter: adapter, service: SearchEntityService(api));
}

Map<String, dynamic> makerResponse(int count) => {
  'success': 1,
  'data': {
    'makers': [
      for (var index = 0; index < count; index++)
        {'id': 'm$index', 'name': '片商$index', 'videos_count': index},
    ],
    'current_page': 1,
  },
};
