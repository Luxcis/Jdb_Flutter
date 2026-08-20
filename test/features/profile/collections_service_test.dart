import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/domain_manager.dart';
import 'package:jade/core/network/endpoints.dart';
import 'package:jade/core/network/interceptors/response_interceptor.dart';
import 'package:jade/core/network/testing/fake_adapter.dart';
import 'package:jade/features/profile/services/collections_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<({FakeAdapter adapter, FavoritesService service})>
buildFavoritesFixture() async {
  final preferences = await SharedPreferences.getInstance();
  final domainManager = await DomainManager.load(preferences);
  final adapter = FakeAdapter();
  final dio = Dio(BaseOptions(baseUrl: domainManager.currentUrl))
    ..httpClientAdapter = adapter
    ..interceptors.add(ResponseInterceptor(onAuthError: () {}));
  final api = ApiClient.forTest(dio: dio, domainManager: domainManager);
  return (adapter: adapter, service: FavoritesService(api));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('getCollectedActors 携带 type 参数并解析 actors', () async {
    final fixture = await buildFavoritesFixture();
    fixture.adapter.enqueue(Endpoints.usersCollectedActors, {
      'success': 1,
      'data': {
        'actors': [
          {'id': 'a1', 'name_zht': '三上悠亜', 'avatar': 'http://img/a1.jpg'},
        ],
        'current_page': 1,
        'total_pages': 1,
        'total': 1,
      },
    });

    final result = await fixture.service.getCollectedActors(type: '1', page: 1);

    expect(result.items.single.id, 'a1');
    expect(result.items.single.name, '三上悠亜');
    expect(fixture.adapter.requests.single.queryParameters, {
      'type': '1',
      'page': 1,
      'limit': 48,
    });
  });

  test('getCollectedMakers 解析 makers 分页', () async {
    final fixture = await buildFavoritesFixture();
    fixture.adapter.enqueue(Endpoints.usersCollectedMakers, {
      'success': 1,
      'data': {
        'makers': [
          {'id': 'm1', 'name': 'SOD', 'type': 0, 'movie_count': 9},
        ],
        'current_page': 1,
        'total_pages': 1,
      },
    });

    final result = await fixture.service.getCollectedMakers();

    expect(result.items.single.id, 'm1');
    expect(result.items.single.name, 'SOD');
    expect(result.items.single.movieCount, 9);
    expect(
      fixture.adapter.requests.single.path,
      Endpoints.usersCollectedMakers,
    );
  });

  test('getCollectedSeries 解析 series', () async {
    final fixture = await buildFavoritesFixture();
    fixture.adapter.enqueue(Endpoints.usersCollectedSeries, {
      'success': 1,
      'data': {
        'series': [
          {'id': 's1', 'name': 'S1', 'type': 0, 'movie_count': 5},
        ],
      },
    });

    final result = await fixture.service.getCollectedSeries();

    expect(result.items.single.id, 's1');
    expect(result.items.single.name, 'S1');
  });

  test('getCollectedDirectors 解析 directors', () async {
    final fixture = await buildFavoritesFixture();
    fixture.adapter.enqueue(Endpoints.usersCollectedDirectors, {
      'success': 1,
      'data': {
        'directors': [
          {'id': 'd1', 'name': '北野武', 'movie_count': 2},
        ],
      },
    });

    final result = await fixture.service.getCollectedDirectors();

    expect(result.items.single.id, 'd1');
    expect(result.items.single.name, '北野武');
  });

  test('getCollectedCodes 解析 codes', () async {
    final fixture = await buildFavoritesFixture();
    fixture.adapter.enqueue(Endpoints.usersCollectedCodes, {
      'success': 1,
      'data': {
        'codes': [
          {'id': 'c1', 'name': 'IPZZ-001', 'movie_count': 3},
        ],
      },
    });

    final result = await fixture.service.getCollectedCodes();

    expect(result.items.single.id, 'c1');
    expect(result.items.single.number, 'IPZZ-001');
  });

  test('getCollectedLists 携带必填 sort_by 并解析 lists', () async {
    final fixture = await buildFavoritesFixture();
    fixture.adapter.enqueue(Endpoints.usersCollectedLists, {
      'success': 1,
      'data': {
        'lists': [
          {'id': 'l1', 'name': '收藏精选', 'movies_count': 3},
        ],
      },
    });

    final result = await fixture.service.getCollectedLists(sortBy: 'recently');

    expect(result.items.single.id, 'l1');
    expect(fixture.adapter.requests.single.queryParameters, {
      'sort_by': 'recently',
      'page': 1,
      'limit': 48,
    });
  });

  test('uncollectActor 发送 POST collect_actions body uncollect', () async {
    final fixture = await buildFavoritesFixture();
    fixture.adapter.enqueue('${Endpoints.actors}/a1/collect_actions', {
      'success': 1,
      'data': null,
    });

    await fixture.service.uncollectActor('a1');

    final request = fixture.adapter.requests.single;
    expect(request.method, 'POST');
    expect(request.path, '${Endpoints.actors}/a1/collect_actions');
    expect(request.data, {'name': 'uncollect'});
  });

  test('uncollectMaker/Series/Director/Code/List 发送对应 POST', () async {
    final fixture = await buildFavoritesFixture();
    const targets = {
      '/api/v1/makers/m1/collect_actions': 'uncollectMaker',
      '/api/v1/series/s1/collect_actions': 'uncollectSeries',
      '/api/v1/directors/d1/collect_actions': 'uncollectDirector',
      '/api/v1/codes/c1/collect_actions': 'uncollectCode',
      '/api/v1/lists/l1/collect_actions': 'uncollectList',
    };
    for (final entry in targets.entries) {
      fixture.adapter.requests.clear();
      fixture.adapter.enqueue(entry.key, {'success': 1, 'data': null});
      switch (entry.value) {
        case 'uncollectMaker':
          await fixture.service.uncollectMaker('m1');
        case 'uncollectSeries':
          await fixture.service.uncollectSeries('s1');
        case 'uncollectDirector':
          await fixture.service.uncollectDirector('d1');
        case 'uncollectCode':
          await fixture.service.uncollectCode('c1');
        case 'uncollectList':
          await fixture.service.uncollectList('l1');
      }
      final request = fixture.adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.path, entry.key);
      expect(request.data, {'name': 'uncollect'});
    }
  });

  test('batchUncollectActors 发送 DELETE body ids 逗号拼接', () async {
    final fixture = await buildFavoritesFixture();
    fixture.adapter.enqueue(Endpoints.actorsBatchUncollection, {
      'success': 1,
      'data': null,
    });

    await fixture.service.batchUncollectActors(['1', '2', '3']);

    final request = fixture.adapter.requests.single;
    expect(request.method, 'DELETE');
    expect(request.path, Endpoints.actorsBatchUncollection);
    expect(request.data, {'ids': '1,2,3'});
  });

  test('getHasCollected 按 category 解析 has_collected', () async {
    final fixture = await buildFavoritesFixture();
    fixture.adapter.enqueue('/api/v1/lists/l1', {
      'success': 1,
      'data': {
        'has_collected': true,
        'list': {'id': 'l1'},
      },
    });

    final result = await fixture.service.getHasCollected('l', 'l1');

    expect(result, isTrue);
    expect(fixture.adapter.requests.single.path, '/api/v1/lists/l1');
  });

  test('getHasCollected 未知 category 返回 null', () async {
    final fixture = await buildFavoritesFixture();
    final result = await fixture.service.getHasCollected('p', 'x1');
    expect(result, isNull);
    expect(fixture.adapter.requests, isEmpty);
  });

  test('setCollected 发送 collect/uncollect body', () async {
    final fixture = await buildFavoritesFixture();
    fixture.adapter.enqueue('/api/v1/actors/a1/collect_actions', {
      'success': 1,
      'data': null,
    });

    await fixture.service.setCollected('a', 'a1', true);

    final request = fixture.adapter.requests.single;
    expect(request.method, 'POST');
    expect(request.path, '/api/v1/actors/a1/collect_actions');
    expect(request.data, {'name': 'collect'});
  });
}
