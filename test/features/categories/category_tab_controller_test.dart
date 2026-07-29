import 'dart:async';
import 'dart:collection';

import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/models/movie.dart';
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/features/categories/models/category_filter.dart';
import 'package:jade/features/categories/models/category_tag.dart';
import 'package:jade/features/categories/services/category_service.dart';
import 'package:jade/features/categories/services/category_tab_controller.dart';

class _MovieRequest {
  const _MovieRequest({
    required this.type,
    required this.filterBy,
    required this.page,
  });

  final int type;
  final String filterBy;
  final int page;
}

class _FakeSource implements CategoryDataSource {
  final tagsCalls = <int>[];
  final movieRequests = <_MovieRequest>[];
  final _pendingMovies = Queue<Completer<PagedResult<MovieSummary>>>();
  Completer<List<CategoryTagGroup>>? pendingTags;
  List<CategoryTagGroup> tagsResult = _tagGroups;
  var tagFailuresRemaining = 0;

  void queuePendingMovie(Completer<PagedResult<MovieSummary>> pending) {
    _pendingMovies.add(pending);
  }

  @override
  Future<List<CategoryTagGroup>> getTags({required int type}) async {
    tagsCalls.add(type);
    if (tagFailuresRemaining > 0) {
      tagFailuresRemaining--;
      throw StateError('标签加载失败');
    }
    final pending = pendingTags;
    if (pending != null) return pending.future;
    return tagsResult;
  }

  @override
  Future<PagedResult<MovieSummary>> getMovies({
    required int type,
    required CategoryFilter filter,
    required List<CategoryFilterGroupOrder> groupOrder,
    int page = 1,
  }) {
    movieRequests.add(
      _MovieRequest(
        type: type,
        filterBy: filter.toFilterBy(type, groupOrder),
        page: page,
      ),
    );
    if (_pendingMovies.isNotEmpty) return _pendingMovies.removeFirst().future;
    return Future.value(_moviePage(type: type, page: page));
  }
}

const _tagGroups = [
  CategoryTagGroup(
    category: '基本',
    categoryId: 'main',
    tags: [CategoryTagItem(id: 'p', name: '可播放', videosCount: 1)],
  ),
  CategoryTagGroup(
    category: '题材',
    categoryId: 'subject',
    tags: [
      CategoryTagItem(id: '23', name: '剧情', videosCount: 1),
      CategoryTagItem(id: '51', name: '喜剧', videosCount: 1),
    ],
  ),
  CategoryTagGroup(
    category: '系列',
    categoryId: 'series',
    tags: [CategoryTagItem(id: '99', name: '系列作', videosCount: 1)],
  ),
];

PagedResult<MovieSummary> _moviePage({
  required int type,
  required int page,
  String? id,
}) => PagedResult(
  items: [
    MovieSummary(
      id: id ?? '$type-$page',
      number: 'N',
      title: '影片',
      coverUrl: '',
    ),
  ],
  currentPage: page,
  totalPages: page,
  total: 1,
);

void main() {
  test('初始化使用当前 type 的空筛选，且成功标签只加载一次', () async {
    final source = _FakeSource();
    final controller = CategoryTabController(type: 1, source: source);
    addTearDown(controller.dispose);

    await controller.initialize();
    await controller.initialize();

    expect(source.tagsCalls, [1]);
    expect(source.movieRequests.single.filterBy, '1:t:::::');
    expect(source.movieRequests.single.page, 1);
  });

  test('标签加载失败后可重试，成功结果会被缓存', () async {
    final source = _FakeSource()..tagFailuresRemaining = 1;
    final controller = CategoryTabController(type: 1, source: source);
    addTearDown(controller.dispose);

    await controller.initialize();

    expect(controller.tagsError, isA<StateError>());
    expect(controller.groups, isEmpty);
    await controller.retryTags();
    await controller.initialize();

    expect(controller.tagsError, isNull);
    expect(controller.groups, hasLength(3));
    expect(source.tagsCalls, [1, 1]);
  });

  test('标签成功后直接重试不会重复请求', () async {
    final source = _FakeSource();
    final controller = CategoryTabController(type: 1, source: source);
    addTearDown(controller.dispose);

    await controller.initialize();
    await controller.retryTags();

    expect(source.tagsCalls, [1]);
  });

  test('空标签列表也会缓存为成功结果', () async {
    final source = _FakeSource()..tagsResult = const [];
    final controller = CategoryTabController(type: 1, source: source);
    addTearDown(controller.dispose);

    await controller.retryTags();
    await controller.retryTags();

    expect(controller.groups, isEmpty);
    expect(controller.tagsError, isNull);
    expect(source.tagsCalls, [1]);
  });

  test('并发初始化会共同等待标签与首屏影片请求', () async {
    final source = _FakeSource();
    final tags = Completer<List<CategoryTagGroup>>();
    final movies = Completer<PagedResult<MovieSummary>>();
    source.pendingTags = tags;
    source.queuePendingMovie(movies);
    final controller = CategoryTabController(type: 0, source: source);
    addTearDown(controller.dispose);
    var completions = 0;

    final first = controller.initialize();
    final second = controller.initialize();
    unawaited(first.then<void>((_) => completions++));
    unawaited(second.then<void>((_) => completions++));

    expect(source.tagsCalls, [0]);
    expect(source.movieRequests, hasLength(1));
    tags.complete(_tagGroups);
    await Future<void>.delayed(Duration.zero);
    expect(completions, 0);
    movies.complete(_moviePage(type: 0, page: 1));
    await Future.wait([first, second]);

    expect(completions, 2);
  });

  test('并发标签重试共用请求并共同等待完成', () async {
    final source = _FakeSource();
    final tags = Completer<List<CategoryTagGroup>>();
    source.pendingTags = tags;
    final controller = CategoryTabController(type: 0, source: source);
    addTearDown(controller.dispose);
    var completions = 0;

    final first = controller.retryTags();
    final second = controller.retryTags();
    unawaited(first.then<void>((_) => completions++));
    unawaited(second.then<void>((_) => completions++));

    expect(source.tagsCalls, [0]);
    expect(completions, 0);
    await Future<void>.delayed(Duration.zero);
    expect(completions, 0);
    tags.complete(_tagGroups);
    await Future.wait([first, second]);

    expect(completions, 2);
  });

  test('两个 Tab 的筛选状态与请求完全隔离', () async {
    final source = _FakeSource();
    final first = CategoryTabController(type: 0, source: source);
    final second = CategoryTabController(type: 1, source: source);
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    await Future.wait([first.initialize(), second.initialize()]);

    await first.toggleFilter('main', 'p');

    expect(first.filter.main, 'p');
    expect(second.filter.main, isNull);
    expect(source.movieRequests.last.type, 0);
    expect(source.movieRequests.last.filterBy, '0:t:p::::');
  });

  test('动态 extra 按标签类别顺序稳定映射并立即从第一页重载', () async {
    final source = _FakeSource();
    final controller = CategoryTabController(type: 0, source: source);
    addTearDown(controller.dispose);
    await controller.initialize();

    await controller.toggleFilter('series', '99');
    await controller.toggleFilter('subject', '23');

    expect(source.movieRequests.last.filterBy, '0:t::23,99:::');
    expect(source.movieRequests.last.page, 1);
  });

  test('动态 extra 反向点击时仍按接口组内 tag 顺序映射', () async {
    final source = _FakeSource();
    final controller = CategoryTabController(type: 0, source: source);
    addTearDown(controller.dispose);
    await controller.initialize();

    await controller.toggleFilter('subject', '51');
    await controller.toggleFilter('subject', '23');

    expect(source.movieRequests.last.filterBy, '0:t::23,51:::');
  });

  test('更改排序和排序方向都会立即从第一页重载', () async {
    final source = _FakeSource();
    final controller = CategoryTabController(type: 0, source: source);
    addTearDown(controller.dispose);
    await controller.initialize();

    await controller.changeSort(CategorySort.score);
    await controller.toggleOrder();

    expect(controller.filter.sort, CategorySort.score);
    expect(controller.filter.orderBy, 'asc');
    expect(source.movieRequests.sublist(1).map((request) => request.page), [
      1,
      1,
    ]);
  });

  test('旧筛选请求完成后不会覆盖最新筛选结果', () async {
    final source = _FakeSource();
    final controller = CategoryTabController(type: 0, source: source);
    addTearDown(controller.dispose);
    await controller.initialize();
    final stale = Completer<PagedResult<MovieSummary>>();
    final current = Completer<PagedResult<MovieSummary>>();
    source.queuePendingMovie(stale);
    final firstReload = controller.toggleFilter('subject', '23');
    source.queuePendingMovie(current);
    final secondReload = controller.toggleFilter('series', '99');

    current.complete(_moviePage(type: 0, page: 1, id: 'current'));
    await secondReload;
    stale.complete(_moviePage(type: 0, page: 1, id: 'stale'));
    await firstReload;

    expect(controller.movies.items.single.id, 'current');
  });

  test('释放后完成中的请求不会触发异常', () async {
    final source = _FakeSource();
    final controller = CategoryTabController(type: 0, source: source);
    await controller.initialize();
    final pending = Completer<PagedResult<MovieSummary>>();
    source.queuePendingMovie(pending);
    final reload = controller.toggleFilter('subject', '23');

    controller.dispose();
    pending.complete(_moviePage(type: 0, page: 1));

    await expectLater(reload, completes);
  });

  test('释放后的标签成功结果不会写入 groups 或通知 listener', () async {
    final source = _FakeSource();
    final tags = Completer<List<CategoryTagGroup>>();
    source.pendingTags = tags;
    final controller = CategoryTabController(type: 0, source: source);
    var notifications = 0;
    controller.addListener(() => notifications++);

    final retry = controller.retryTags();
    expect(notifications, 1);
    controller.dispose();
    expect(notifications, 1);
    tags.complete(_tagGroups);
    await retry;

    expect(notifications, 1);
    expect(controller.groups, isEmpty);
    expect(controller.tagsError, isNull);
  });

  test('释放后的标签失败结果不会写入 error', () async {
    final source = _FakeSource();
    final tags = Completer<List<CategoryTagGroup>>();
    source.pendingTags = tags;
    final controller = CategoryTabController(type: 0, source: source);

    final retry = controller.retryTags();
    controller.dispose();
    tags.completeError(StateError('迟到的标签失败'));
    await retry;

    expect(controller.groups, isEmpty);
    expect(controller.tagsError, isNull);
  });
}
