import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/models/actor.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/endpoints.dart';
import 'package:jade/core/network/testing/fake_adapter.dart';
import 'package:jade/features/actors/services/actor_movie_controller.dart';
import 'package:jade/features/actors/services/actor_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _NoOpTokenProvider implements TokenProvider {
  const _NoOpTokenProvider();

  @override
  String? get token => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeAdapter adapter;
  late ActorService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final api = await ApiClient.create(
      prefs: prefs,
      tokenProvider: const _NoOpTokenProvider(),
      onAuthError: () {},
    );
    adapter = FakeAdapter();
    api.setAdapterForTest(adapter);
    service = ActorService(api);
  });

  Map<String, dynamic> moviesResponse(List<String> ids) => {
    'success': 1,
    'data': {
      'movies': [
        for (final id in ids)
          {'id': id, 'number': id, 'title': id, 'cover_url': ''},
      ],
      'current_page': 1,
      'total_pages': 1,
    },
  };

  ActorMovieController buildController() => ActorMovieController(
    actorId: 'a1',
    type: 0,
    filterTags: const [ActorTagItem(id: 'f1', name: '基本筛选', videosCount: 2)],
    tags: const [
      ActorTagItem(id: 't1', name: '标签一', videosCount: 3),
      ActorTagItem(id: 't2', name: '标签二', videosCount: 4),
    ],
    service: service,
  );

  RequestOptions lastMovieRequest() => adapter.requests.lastWhere(
    (request) => request.path == Endpoints.moviesTags,
  );

  test('initialize 以演员类型、默认排序请求第 1 页且不带标签过滤', () async {
    adapter.enqueue(Endpoints.moviesTags, moviesResponse(['m1']));
    final controller = buildController();
    addTearDown(controller.dispose);

    await controller.initialize();

    final request = lastMovieRequest();
    expect(request.uri.queryParameters['filter_by'], '0:a:a1');
    expect(request.uri.queryParameters['sort_by'], 'release');
    expect(request.uri.queryParameters['order_by'], 'desc');
    expect(request.uri.queryParameters['page'], '1');
    expect(request.uri.queryParameters.containsKey('filter_by_tags'), isFalse);
    expect(controller.movies.items.single.id, 'm1');
  });

  test('多选标签按选择顺序逗号拼接，取消后再重组', () async {
    adapter.enqueue(Endpoints.moviesTags, moviesResponse(['m1']));
    final controller = buildController();
    addTearDown(controller.dispose);
    await controller.initialize();

    await controller.toggleTag('t1');
    expect(lastMovieRequest().uri.queryParameters['filter_by_tags'], 't1');

    await controller.toggleTag('t2');
    expect(lastMovieRequest().uri.queryParameters['filter_by_tags'], 't1,t2');
    expect(controller.selectedTagIds, {'t1', 't2'});

    await controller.toggleTag('t1');
    expect(lastMovieRequest().uri.queryParameters['filter_by_tags'], 't2');
    expect(controller.selectedTagIds, {'t2'});
  });

  test('排序字段与升降序写入请求参数', () async {
    adapter.enqueue(Endpoints.moviesTags, moviesResponse(['m1']));
    final controller = buildController();
    addTearDown(controller.dispose);
    await controller.initialize();

    await controller.changeSort('score');
    expect(lastMovieRequest().uri.queryParameters['sort_by'], 'score');
    expect(lastMovieRequest().uri.queryParameters['order_by'], 'desc');

    await controller.toggleOrder();
    expect(controller.orderBy, 'asc');
    expect(lastMovieRequest().uri.queryParameters['sort_by'], 'score');
    expect(lastMovieRequest().uri.queryParameters['order_by'], 'asc');

    await controller.toggleTag('t1');
    final request = lastMovieRequest();
    expect(request.uri.queryParameters['filter_by_tags'], 't1');
    expect(request.uri.queryParameters['sort_by'], 'score');
    expect(request.uri.queryParameters['order_by'], 'asc');
  });

  test('标签变化使用 preserveItems 重载：请求完成前保留原影片', () async {
    adapter.enqueue(Endpoints.moviesTags, moviesResponse(['m1']));
    final controller = buildController();
    addTearDown(controller.dispose);
    await controller.initialize();
    expect(controller.movies.items.single.id, 'm1');

    adapter.responseDelay = const Duration(milliseconds: 50);
    adapter.enqueue(Endpoints.moviesTags, moviesResponse(['m2']));
    final pending = controller.toggleTag('t1');
    await Future<void>.delayed(Duration.zero);

    expect(controller.movies.isRefreshing, isTrue);
    expect(controller.movies.items.single.id, 'm1');

    await pending;
    expect(controller.movies.isRefreshing, isFalse);
    expect(controller.movies.items.single.id, 'm2');
  });

  test('initialize 重复调用不会重复请求', () async {
    adapter.enqueue(Endpoints.moviesTags, moviesResponse(['m1']));
    final controller = buildController();
    addTearDown(controller.dispose);

    await controller.initialize();
    await controller.initialize();

    expect(
      adapter.requests.where((request) => request.path == Endpoints.moviesTags),
      hasLength(1),
    );
  });

  test('dispose 后调用所有变更方法都不抛异常且不再请求', () async {
    adapter.enqueue(Endpoints.moviesTags, moviesResponse(['m1']));
    final controller = buildController();
    await controller.initialize();
    controller.dispose();
    final requestCount = adapter.requests.length;

    await controller.toggleTag('t1');
    await controller.changeSort('score');
    await controller.toggleOrder();
    await controller.initialize();

    expect(adapter.requests.length, requestCount);
    expect(controller.selectedTagIds, isEmpty);
    expect(controller.sortBy, 'release');
    expect(controller.orderBy, 'desc');
  });

  test('标签/排序变化会通知监听者', () async {
    adapter.enqueue(Endpoints.moviesTags, moviesResponse(['m1']));
    final controller = buildController();
    addTearDown(controller.dispose);
    await controller.initialize();

    var notifications = 0;
    controller.addListener(() => notifications++);

    await controller.toggleTag('t1');
    await controller.changeSort('update');
    await controller.toggleOrder();

    expect(notifications, greaterThanOrEqualTo(3));
  });
}
