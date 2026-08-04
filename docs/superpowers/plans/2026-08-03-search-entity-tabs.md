# 综合搜索实体 Tab Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为综合搜索补齐演员、系列、片商、导演、清单、番号六个 Tab 的强类型接口请求、自动分页、统一列表样式和公共列表页占位导航。

**Architecture:** 新增 `SearchEntityDataSource` 统一解析 `/api/v2/search` 的六个类型分支，并用每个 Tab 独立的 `SearchPageSession<T>` 去重和终止重复分页。展示层复用 `ActorGridView`，新增通用名称数量行、通用分页列表与共享清单行；非演员实体点击进入只展示标题、筛选排序和空影片网格的 `CommonListPage`，本期不请求影片接口。

**Tech Stack:** Flutter、Dart、Material 3、Provider、Dio `ApiClient`、`PaginationController`、`flutter_test`、现有 `FakeAdapter`。

## Global Constraints

- 固定调用 `GET /api/v2/search`，六个实体请求都发送 `q`、`type`、`page`、`limit=48`。
- 类型映射固定为 `actor/series/maker/director/list/code`，集合键固定为 `actors/series/makers/directors/lists/codes`。
- 非影片分页缺少元数据时以 48 条为下一页阈值；重复 ID 必须去重，整页无新增数据时必须停止。
- 系列、片商、导演、番号使用无斑马纹的 `名称 (数量)` 列表，组件只暴露 `name`、`count`、`onTap`。
- 演员使用现有 `ActorGridView`；清单样式与影片详情“相关清单”一致。
- 所有搜索列表接近底部 200px 时自动加载下一页，并支持首屏加载、空状态、首屏重试、尾部加载和尾部重试。
- 公共页标题使用“类型 - 名称”，同行显示四项 `SortSegmented` 与“最新、热门、评分”下拉选项，并保留 `MovieGridView` 自动分页结构。
- 公共页本期不得调用影片接口；筛选和排序只更新本地 UI 状态。
- 不新增依赖，不修改 ARB；用户可见中文直接按项目约定硬编码。
- 保留工作区中与本计划无关的改动；每次提交只暂存任务列出的文件。

---

### Task 1: 六类搜索服务与重复分页会话

**Files:**
- Create: `lib/features/search/services/search_entity_service.dart`
- Create: `lib/features/search/services/search_page_session.dart`
- Create: `test/features/search/search_entity_service_test.dart`
- Create: `test/features/search/search_page_session_test.dart`

**Interfaces:**
- Consumes: `ApiClient.get`、`Endpoints.searchV2`、`apiMap/apiList/apiInt/apiString`、现有 `ActorSummary/Series/Maker/Director/ListModel/Code/PagedResult`。
- Produces: `SearchEntityDataSource` 六个分页方法、`SearchEntityService`、`UnavailableSearchEntityDataSource`、`SearchPageSession<T>.fetch(int page)`。

- [x] **Step 1: 写服务请求与解析失败测试**

```dart
// test/features/search/search_entity_service_test.dart
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
```

再加入以下集合键隔离测试；测试夹具通过 `FakeAdapter` 观察真实 Dio 查询参数，不直接 mock 服务方法：

```dart
test('演员片商导演使用各自 type 和集合键', () async {
  final fixture = await buildSearchEntityFixture();
  fixture.adapter.enqueueSequence(Endpoints.searchV2, [
    {'success': 1, 'data': {'actors': [{'id': 'a1', 'name': '演员', 'avatar_url': ''}]}},
    {'success': 1, 'data': {'makers': [{'id': 'm1', 'name': '片商', 'videos_count': 2}]}},
    {'success': 1, 'data': {'directors': [{'id': 'd1', 'name': '导演', 'videos_count': 3}]}},
  ]);

  expect((await fixture.service.getActors(query: 'q')).items.single.id, 'a1');
  expect((await fixture.service.getMakers(query: 'q')).items.single.id, 'm1');
  expect((await fixture.service.getDirectors(query: 'q')).items.single.id, 'd1');
  expect(
    fixture.adapter.requests.map((request) => request.queryParameters['type']),
    ['actor', 'maker', 'director'],
  );
});
```

- [x] **Step 2: 运行服务测试并确认 RED**

Run: `flutter test test/features/search/search_entity_service_test.dart`

Expected: FAIL，原因是 `search_entity_service.dart`、`SearchEntityService` 和六个方法尚不存在。

- [x] **Step 3: 实现六类强类型服务**

```dart
// lib/features/search/services/search_entity_service.dart
abstract interface class SearchEntityDataSource {
  Future<PagedResult<ActorSummary>> getActors({required String query, int page = 1});
  Future<PagedResult<Series>> getSeries({required String query, int page = 1});
  Future<PagedResult<Maker>> getMakers({required String query, int page = 1});
  Future<PagedResult<Director>> getDirectors({required String query, int page = 1});
  Future<PagedResult<ListModel>> getLists({required String query, int page = 1});
  Future<PagedResult<Code>> getCodes({required String query, int page = 1});
}

class SearchEntityService implements SearchEntityDataSource {
  SearchEntityService(this._api);
  static const pageSize = 48;
  final ApiClient _api;

  Future<PagedResult<T>> _getPage<T>({
    required String query,
    required String type,
    required String collectionKey,
    required int page,
    required T Function(Map<String, dynamic>) fromJson,
  }) async {
    final response = await _api.get(
      Endpoints.searchV2,
      queryParameters: {'q': query, 'type': type, 'page': page, 'limit': pageSize},
    );
    final data = apiMap(response.data);
    final rawItems = apiList(data, [collectionKey]);
    final items = rawItems.map(fromJson).toList(growable: false);
    final currentPage = apiInt(data['current_page'], page);
    final totalPages = data['total_pages'] == null
        ? currentPage + (rawItems.length >= pageSize ? 1 : 0)
        : apiInt(data['total_pages'], currentPage);
    return PagedResult(
      items: items,
      currentPage: currentPage,
      totalPages: totalPages,
      total: apiInt(data['total_count'] ?? data['total'], items.length),
    );
  }
}
```

六个公开方法只负责传入固定 `type`、集合键与转换器。系列、片商、导演先规范化 `id/name/movie_count`；番号规范化 `name/number/id` 到 `Code.number`；清单复用 `normalizeListModelJson`；演员复用 `normalizeActorSummaryJson`。实现 `UnavailableSearchEntityDataSource`，六个方法均返回当前页的空 `PagedResult`。

```dart
Map<String, dynamic> _namedEntityJson(Map<String, dynamic> json) => {
  ...json,
  'id': apiString(json['id']) ?? '',
  'name': apiString(json['name']) ?? '',
  'movie_count': apiInt(json['movie_count'] ?? json['movies_count'] ?? json['videos_count'], 0),
};

Map<String, dynamic> _codeJson(Map<String, dynamic> json) => {
  ...json,
  'id': apiString(json['id'] ?? json['name'] ?? json['number']) ?? '',
  'number': apiString(json['number'] ?? json['name'] ?? json['id']) ?? '',
  'movie_count': apiInt(json['movie_count'] ?? json['movies_count'] ?? json['videos_count'], 0),
};

@override
Future<PagedResult<ActorSummary>> getActors({required String query, int page = 1}) =>
    _getPage(query: query, type: 'actor', collectionKey: 'actors', page: page,
      fromJson: (json) => ActorSummary.fromJson(normalizeActorSummaryJson(json)));
@override
Future<PagedResult<Series>> getSeries({required String query, int page = 1}) =>
    _getPage(query: query, type: 'series', collectionKey: 'series', page: page,
      fromJson: (json) => Series.fromJson(_namedEntityJson(json)));
@override
Future<PagedResult<Maker>> getMakers({required String query, int page = 1}) =>
    _getPage(query: query, type: 'maker', collectionKey: 'makers', page: page,
      fromJson: (json) => Maker.fromJson(_namedEntityJson(json)));
@override
Future<PagedResult<Director>> getDirectors({required String query, int page = 1}) =>
    _getPage(query: query, type: 'director', collectionKey: 'directors', page: page,
      fromJson: (json) => Director.fromJson(_namedEntityJson(json)));
@override
Future<PagedResult<ListModel>> getLists({required String query, int page = 1}) =>
    _getPage(query: query, type: 'list', collectionKey: 'lists', page: page,
      fromJson: (json) => ListModel.fromJson(normalizeListModelJson(json)));
@override
Future<PagedResult<Code>> getCodes({required String query, int page = 1}) =>
    _getPage(query: query, type: 'code', collectionKey: 'codes', page: page,
      fromJson: (json) => Code.fromJson(_codeJson(json)));

class UnavailableSearchEntityDataSource implements SearchEntityDataSource {
  const UnavailableSearchEntityDataSource();

  Future<PagedResult<T>> _empty<T>(int page) async =>
      PagedResult(items: const [], currentPage: page, totalPages: page, total: 0);

  @override
  Future<PagedResult<ActorSummary>> getActors({required String query, int page = 1}) => _empty(page);
  @override
  Future<PagedResult<Series>> getSeries({required String query, int page = 1}) => _empty(page);
  @override
  Future<PagedResult<Maker>> getMakers({required String query, int page = 1}) => _empty(page);
  @override
  Future<PagedResult<Director>> getDirectors({required String query, int page = 1}) => _empty(page);
  @override
  Future<PagedResult<ListModel>> getLists({required String query, int page = 1}) => _empty(page);
  @override
  Future<PagedResult<Code>> getCodes({required String query, int page = 1}) => _empty(page);
}
```

- [x] **Step 4: 运行服务测试并确认 GREEN**

Run: `flutter test test/features/search/search_entity_service_test.dart`

Expected: PASS，六种 `type`、字段兼容和分页推断全部通过。

- [x] **Step 5: 写分页去重会话失败测试**

```dart
// test/features/search/search_page_session_test.dart
test('重复下一页不追加并终止分页', () async {
  final pages = <int, PagedResult<_Item>>{
    1: const PagedResult(
      items: [_Item('1'), _Item('2')],
      currentPage: 1,
      totalPages: 3,
      total: 4,
    ),
    2: const PagedResult(
      items: [_Item('1'), _Item('2')],
      currentPage: 2,
      totalPages: 3,
      total: 4,
    ),
  };
  final session = SearchPageSession<_Item>(
    fetchPage: (page) async => pages[page]!,
    idOf: (item) => item.id,
  );

  final first = await session.fetch(1);
  final second = await session.fetch(2);

  expect(first.items.map((item) => item.id), ['1', '2']);
  expect(second.items, isEmpty);
  expect(second.currentPage, second.totalPages);
});

test('重新请求第一页会清空已见 ID', () async {
  const page = PagedResult(
    items: [_Item('1')],
    currentPage: 1,
    totalPages: 1,
    total: 1,
  );
  final session = SearchPageSession<_Item>(
    fetchPage: (_) async => page,
    idOf: (item) => item.id,
  );

  expect((await session.fetch(1)).items, hasLength(1));
  expect((await session.fetch(1)).items, hasLength(1));
});

class _Item {
  const _Item(this.id);
  final String id;
}
```

- [x] **Step 6: 运行分页会话测试并确认 RED**

Run: `flutter test test/features/search/search_page_session_test.dart`

Expected: FAIL，原因是 `SearchPageSession` 尚不存在。

- [x] **Step 7: 实现分页会话并验证 GREEN**

```dart
// lib/features/search/services/search_page_session.dart
class SearchPageSession<T> {
  SearchPageSession({required this.fetchPage, required this.idOf});

  final Future<PagedResult<T>> Function(int page) fetchPage;
  final String Function(T item) idOf;
  final Set<String> _seenIds = {};

  Future<PagedResult<T>> fetch(int page) async {
    if (page == 1) _seenIds.clear();
    final result = await fetchPage(page);
    final newItems = result.items
        .where((item) => _seenIds.add(idOf(item)))
        .toList(growable: false);
    final stoppedByDuplicatePage = result.items.isNotEmpty && newItems.isEmpty;
    return PagedResult(
      items: newItems,
      currentPage: result.currentPage,
      totalPages: stoppedByDuplicatePage
          ? result.currentPage
          : result.totalPages,
      total: result.total,
    );
  }
}
```

Run: `flutter test test/features/search/search_entity_service_test.dart test/features/search/search_page_session_test.dart`

Expected: PASS。

- [x] **Step 8: 提交 Task 1**

```bash
git add lib/features/search/services/search_entity_service.dart \
  lib/features/search/services/search_page_session.dart \
  test/features/search/search_entity_service_test.dart \
  test/features/search/search_page_session_test.dart
git commit -m "feat: add typed search entity pagination"
```

---

### Task 2: 无斑马纹实体行、分页列表和共享清单行

**Files:**
- Create: `lib/features/search/widgets/search_entity_list_tile.dart`
- Create: `lib/features/search/widgets/search_paginated_list_view.dart`
- Create: `lib/core/widgets/list_summary_tile.dart`
- Modify: `lib/features/movie_detail/screens/movie_detail_screen.dart`
- Create: `test/features/search/search_entity_list_tile_test.dart`
- Create: `test/features/search/search_paginated_list_view_test.dart`
- Create: `test/core/widgets/list_summary_tile_test.dart`
- Modify: `test/features/movie_detail/movie_detail_screen_test.dart`

**Interfaces:**
- Consumes: `PaginationController<T>`、`EmptyState`、`ErrorRetryWidget`、`ListModel`。
- Produces: `SearchEntityListTile(name, count, onTap)`、`SearchPaginatedListView<T>(controller, itemBuilder, emptyMessage)`、`ListSummaryTile(list, onTap?)`。

- [x] **Step 1: 写名称数量行失败测试**

```dart
// test/features/search/search_entity_list_tile_test.dart
testWidgets('同行显示名称和灰色括号数量并触发点击', (tester) async {
  var tapped = false;
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SearchEntityListTile(
        name: 'ハッピー山田',
        count: 9,
        onTap: () => tapped = true,
      ),
    ),
  ));

  expect(find.text('ハッピー山田'), findsOneWidget);
  expect(find.text('(9)'), findsOneWidget);
  final count = tester.widget<Text>(find.text('(9)'));
  expect(count.style?.color, Theme.of(tester.element(find.text('(9)'))).colorScheme.onSurfaceVariant);
  await tester.tap(find.byType(SearchEntityListTile));
  expect(tapped, isTrue);
});

testWidgets('相邻行使用相同背景而不是斑马纹', (tester) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(body: Column(children: [
      SearchEntityListTile(key: const Key('row-1'), name: 'A', count: 1, onTap: () {}),
      SearchEntityListTile(key: const Key('row-2'), name: 'B', count: 2, onTap: () {}),
    ])),
  ));
  final first = tester.widget<Material>(find.descendant(
    of: find.byKey(const Key('row-1')),
    matching: find.byType(Material),
  ).first);
  final second = tester.widget<Material>(find.descendant(
    of: find.byKey(const Key('row-2')),
    matching: find.byType(Material),
  ).first);
  expect(first.color, Theme.of(tester.element(find.byKey(const Key('row-1')))).colorScheme.surface);
  expect(second.color, first.color);
});
```

- [x] **Step 2: 运行名称数量行测试并确认 RED**

Run: `flutter test test/features/search/search_entity_list_tile_test.dart`

Expected: FAIL，原因是 `SearchEntityListTile` 尚不存在。

- [x] **Step 3: 实现名称数量行并验证 GREEN**

```dart
// lib/features/search/widgets/search_entity_list_tile.dart
class SearchEntityListTile extends StatelessWidget {
  const SearchEntityListTile({
    super.key,
    required this.name,
    required this.count,
    required this.onTap,
  });

  final String name;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Row(children: [
            Flexible(child: Text(name, overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 6),
            Text('($count)', style: TextStyle(color: colors.onSurfaceVariant)),
          ]),
        ),
      ),
    );
  }
}
```

Run: `flutter test test/features/search/search_entity_list_tile_test.dart`

Expected: PASS。

- [x] **Step 4: 写通用分页列表状态失败测试**

```dart
// test/features/search/search_paginated_list_view_test.dart
testWidgets('接近底部自动加载并在追加失败时保留内容显示重试', (tester) async {
  final controller = PaginationController<_Item>(fetch: (page) async {
    if (page == 1) {
      return PagedResult(
        items: List.generate(30, (i) => _Item('$i')),
        currentPage: 1,
        totalPages: 2,
        total: 31,
      );
    }
    throw StateError('page 2 failed');
  })..fetchMore();
  await tester.pumpWidget(MaterialApp(
    home: SearchPaginatedListView<_Item>(
      controller: controller,
      emptyMessage: '暂无结果',
      itemBuilder: (_, item) => Text(item.id),
    ),
  ));
  await tester.pumpAndSettle();
  await tester.fling(find.byType(ListView), const Offset(0, -3000), 3000);
  await tester.pumpAndSettle();

  expect(find.text('0'), findsOneWidget);
  expect(find.byKey(const Key('search-list-tail-retry')), findsOneWidget);
});
```

同一测试文件加入以下状态测试：

```dart
Future<void> pumpList(WidgetTester tester, PaginationController<_Item> controller) =>
    tester.pumpWidget(MaterialApp(home: SearchPaginatedListView<_Item>(
      controller: controller,
      emptyMessage: '暂无结果',
      itemBuilder: (_, item) => Text(item.id),
    )));

testWidgets('首屏加载完成后显示空状态', (tester) async {
  final completer = Completer<PagedResult<_Item>>();
  final controller = PaginationController<_Item>(fetch: (_) => completer.future)..fetchMore();
  await pumpList(tester, controller);
  expect(find.byType(CircularProgressIndicator), findsOneWidget);
  completer.complete(const PagedResult(items: [], currentPage: 1, totalPages: 1, total: 0));
  await tester.pumpAndSettle();
  expect(find.text('暂无结果'), findsOneWidget);
});

testWidgets('首屏错误点击重试后恢复空状态', (tester) async {
  var attempts = 0;
  final controller = PaginationController<_Item>(fetch: (_) async {
    attempts++;
    if (attempts == 1) throw StateError('first failed');
    return const PagedResult(items: [], currentPage: 1, totalPages: 1, total: 0);
  })..fetchMore();
  await pumpList(tester, controller);
  await tester.pumpAndSettle();
  expect(find.byType(ErrorRetryWidget), findsOneWidget);
  await tester.tap(find.text('重试'));
  await tester.pumpAndSettle();
  expect(attempts, 2);
  expect(find.text('暂无结果'), findsOneWidget);
});

testWidgets('追加加载保留现有内容并显示尾部进度', (tester) async {
  final secondPage = Completer<PagedResult<_Item>>();
  final controller = PaginationController<_Item>(fetch: (page) async {
    if (page == 1) {
      return const PagedResult(items: [_Item('1')], currentPage: 1, totalPages: 2, total: 2);
    }
    return secondPage.future;
  })..fetchMore();
  await pumpList(tester, controller);
  await tester.pumpAndSettle();
  controller.fetchMore();
  await tester.pump();
  expect(find.text('1'), findsOneWidget);
  expect(find.byType(CircularProgressIndicator), findsOneWidget);
  secondPage.complete(const PagedResult(items: [_Item('2')], currentPage: 2, totalPages: 2, total: 2));
  await tester.pumpAndSettle();
});
```

- [x] **Step 5: 运行分页列表测试并确认 RED**

Run: `flutter test test/features/search/search_paginated_list_view_test.dart`

Expected: FAIL，原因是 `SearchPaginatedListView` 尚不存在。

- [x] **Step 6: 实现通用分页列表并验证 GREEN**

```dart
// lib/features/search/widgets/search_paginated_list_view.dart
class SearchPaginatedListView<T> extends StatelessWidget {
  const SearchPaginatedListView({
    super.key,
    required this.controller,
    required this.itemBuilder,
    required this.emptyMessage,
  });

  final PaginationController<T> controller;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      if (controller.error != null && controller.items.isEmpty) {
        return ErrorRetryWidget(message: controller.error.toString(), onRetry: controller.refresh);
      }
      if (controller.isLoading && controller.items.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }
      if (controller.items.isEmpty) return EmptyState(message: emptyMessage);
      final hasTail = controller.isLoading || controller.error != null;
      return NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if ((notification is ScrollUpdateNotification || notification is ScrollEndNotification) &&
              notification.metrics.extentAfter < 200) {
            controller.fetchMore();
          }
          return false;
        },
        child: ListView.separated(
          itemCount: controller.items.length + (hasTail ? 1 : 0),
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            if (index < controller.items.length) return itemBuilder(context, controller.items[index]);
            if (controller.isLoading) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              );
            }
            return Center(child: TextButton(
              key: const Key('search-list-tail-retry'),
              onPressed: controller.fetchMore,
              child: const Text('重试'),
            ));
          },
        ),
      );
    },
  );
}
```

Run: `flutter test test/features/search/search_paginated_list_view_test.dart`

Expected: PASS。

- [x] **Step 7: 写并实现共享清单行**

先在 `test/core/widgets/list_summary_tile_test.dart` 写以下失败测试：

```dart
testWidgets('显示加粗名称影片数查看数箭头并触发点击', (tester) async {
  var tapped = false;
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: ListSummaryTile(
    list: const ListModel(id: 'l1', name: '收藏精选', movieCount: 12, viewedCount: 34),
    onTap: () => tapped = true,
  ))));
  expect(find.text('收藏精选'), findsOneWidget);
  expect(find.text('12 部影片，被查看 34 次'), findsOneWidget);
  expect(find.byIcon(Icons.chevron_right), findsOneWidget);
  expect(tester.widget<Text>(find.text('收藏精选')).style?.fontWeight, FontWeight.w600);
  await tester.tap(find.byType(ListSummaryTile));
  expect(tapped, isTrue);
});
```

确认测试因组件不存在而失败后实现：

```dart
// lib/core/widgets/list_summary_tile.dart
class ListSummaryTile extends StatelessWidget {
  const ListSummaryTile({super.key, required this.list, this.onTap});
  final ListModel list;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    onTap: onTap,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    title: Text(
      list.name,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
    ),
    subtitle: Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text('${list.movieCount} 部影片，被查看 ${list.viewedCount} 次'),
    ),
    trailing: const Icon(Icons.chevron_right),
  );
}
```

把影片详情 `_RelatedListList` 的内联 `ListTile` 替换为 `ListSummaryTile(list: list)`，保持现有不可点击语义不变；搜索清单 Tab 传入实际导航回调。运行：

Run: `flutter test test/core/widgets/list_summary_tile_test.dart test/features/movie_detail/movie_detail_screen_test.dart`

Expected: PASS，相关清单视觉回归不变。

- [x] **Step 8: 提交 Task 2**

```bash
git add lib/features/search/widgets/search_entity_list_tile.dart \
  lib/features/search/widgets/search_paginated_list_view.dart \
  lib/core/widgets/list_summary_tile.dart \
  lib/features/movie_detail/screens/movie_detail_screen.dart \
  test/features/search/search_entity_list_tile_test.dart \
  test/features/search/search_paginated_list_view_test.dart \
  test/core/widgets/list_summary_tile_test.dart \
  test/features/movie_detail/movie_detail_screen_test.dart
git commit -m "feat: add paginated search entity lists"
```

---

### Task 3: 六个 Tab 组装与公共列表页占位导航

**Files:**
- Modify: `lib/features/search/screens/search_results_screen.dart`
- Modify: `lib/features/common/screens/common_list_page.dart`
- Modify: `test/features/search/search_screen_test.dart`
- Create: `test/features/common/common_list_page_test.dart`

**Interfaces:**
- Consumes: Task 1 的 `SearchEntityDataSource/SearchEntityService/SearchPageSession`，Task 2 的三个列表组件，现有 `ActorGridView/CommonListPage`。
- Produces: `SearchResultsPage.entityDataSource` 测试注入口、六个独立分页 Tab、非演员实体的空数据公共页导航。

- [x] **Step 1: 写公共列表页内容失败测试**

```dart
// test/features/common/common_list_page_test.dart
testWidgets('显示标题筛选排序和影片网格且本地数据源不访问 ApiClient', (tester) async {
  var fetchCount = 0;
  await tester.pumpWidget(MaterialApp(
    home: CommonListPage(
      title: '系列 - Madonna',
      dataSource: (page) async {
        fetchCount++;
        return PagedResult(
          items: const [],
          currentPage: page,
          totalPages: page,
          total: 0,
        );
      },
    ),
  ));
  await tester.pumpAndSettle();

  expect(find.text('系列 - Madonna'), findsOneWidget);
  for (final label in ['全部', '可播放', '含磁链', '字幕']) {
    expect(find.text(label), findsOneWidget);
  }
  expect(find.text('最新'), findsOneWidget);
  expect(find.byKey(const Key('common-list-filter')), findsOneWidget);
  expect(find.byKey(const Key('common-list-sort')), findsOneWidget);
  expect(find.byType(MovieGridView), findsOneWidget);
  expect(fetchCount, 1);

  await tester.tap(find.text('全部'));
  await tester.pumpAndSettle();
  expect(
    tester.widget<SortSegmented<String>>(find.byKey(const Key('common-list-filter'))).value,
    'all',
  );
  await tester.tap(find.byKey(const Key('common-list-sort')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('热门').last);
  await tester.pumpAndSettle();
  expect(
    tester.widget<SortSelect<String>>(find.byKey(const Key('common-list-sort'))).value,
    'hot',
  );
});
```

数据源始终为本地空页，测试不初始化 `ApiClient`。页面实现仍补充 `dispose` 释放内部 `PaginationController`。

- [x] **Step 2: 运行公共页测试并确认 RED**

Run: `flutter test test/features/common/common_list_page_test.dart`

Expected: 当前页面内容主体大部分存在，但测试至少因控制器未释放或所需稳定 Key 缺失而 FAIL；确认失败点来自待实现的公共页契约，不修改断言绕过。

- [x] **Step 3: 最小调整公共列表页并验证 GREEN**

在 `CommonListPage` 为筛选区和排序控件增加稳定 Key，保留原有选项和回调：

```dart
SortSegmented<String>(
  key: const Key('common-list-filter'),
  options: const [
    (label: '全部', value: 'all'),
    (label: '可播放', value: 'playable'),
    (label: '含磁链', value: 'magnet'),
    (label: '字幕', value: 'subtitle'),
  ],
  value: _filter,
  onChanged: (value) {
    setState(() => _filter = value);
    _ctrl.refresh();
  },
)

SortSelect<String>(
  key: const Key('common-list-sort'),
  options: const [
    (label: '最新', value: 'date'),
    (label: '热门', value: 'hot'),
    (label: '评分', value: 'rating'),
  ],
  value: _sort,
  onChanged: (value) {
    if (value == null) return;
    setState(() => _sort = value);
    _ctrl.refresh();
  },
)
```

补充释放逻辑：

```dart
@override
void dispose() {
  _ctrl.dispose();
  super.dispose();
}
```

保留现有 `title`、`SortSegmented`、`SortSelect`、`MovieGridView` 和本地状态；不新增任何 API 服务。

Run: `flutter test test/features/common/common_list_page_test.dart`

Expected: PASS。

- [x] **Step 4: 写搜索结果六 Tab 失败测试**

```dart
// test/features/search/search_screen_test.dart
testWidgets('系列 Tab 自动分页并以名称数量行展示', (tester) async {
  final source = FakeSearchEntityDataSource(
    seriesPages: {
      1: PagedResult(
        items: List.generate(48, (i) => Series(id: 's$i', name: '系列$i', movieCount: i)),
        currentPage: 1,
        totalPages: 2,
        total: 49,
      ),
      2: const PagedResult(
        items: [Series(id: 's48', name: '系列48', movieCount: 48)],
        currentPage: 2,
        totalPages: 2,
        total: 49,
      ),
    },
  );
  await pumpSearchResults(tester, entityDataSource: source);
  await tester.tap(find.text('系列'));
  await tester.pumpAndSettle();

  expect(find.byType(SearchEntityListTile), findsWidgets);
  await tester.fling(find.byType(ListView), const Offset(0, -5000), 5000);
  await tester.pumpAndSettle();
  expect(source.seriesRequestedPages, [1, 2]);
});

testWidgets('演员点击进入演员详情', (tester) async {
  final source = FakeSearchEntityDataSource(
    actors: const PagedResult(
      items: [ActorSummary(id: 'a1', name: '演员A', avatarUrl: '')],
      currentPage: 1,
      totalPages: 1,
      total: 1,
    ),
  );
  final router = buildSearchResultsRouter(source);
  addTearDown(router.dispose);
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pumpAndSettle();
  await tester.tap(find.text('演员'));
  await tester.pumpAndSettle();
  await tester.tap(find.byType(ActorCard));
  await tester.pumpAndSettle();
  expect(router.state.uri.path, '/actor/a1');
});

testWidgets('非演员实体进入类型减名称公共页且不请求影片接口', (tester) async {
  final cases = <({String tab, String expectedTitle})>[
    (tab: '系列', expectedTitle: '系列 - 测试系列'),
    (tab: '片商', expectedTitle: '片商 - 测试片商'),
    (tab: '导演', expectedTitle: '导演 - 测试导演'),
    (tab: '番号', expectedTitle: '番号 - TEST'),
    (tab: '清单', expectedTitle: '清单 - 测试清单'),
  ];
  for (final item in cases) {
    final source = FakeSearchEntityDataSource.singleNamedResults();
    await pumpSearchResults(tester, entityDataSource: source);
    await tester.tap(find.text(item.tab));
    await tester.pumpAndSettle();
    final requestCount = source.totalCalls;
    final row = item.tab == '清单'
        ? find.byType(ListSummaryTile)
        : find.byType(SearchEntityListTile);
    await tester.tap(row.first);
    await tester.pumpAndSettle();
    expect(find.text(item.expectedTitle), findsOneWidget);
    expect(find.byKey(const Key('common-list-filter')), findsOneWidget);
    expect(find.byKey(const Key('common-list-sort')), findsOneWidget);
    expect(find.byType(MovieGridView), findsOneWidget);
    expect(source.totalCalls, requestCount);
    await tester.pageBack();
    await tester.pumpAndSettle();
  }
});

Future<void> pumpSearchResults(
  WidgetTester tester, {
  required SearchEntityDataSource entityDataSource,
}) => tester.pumpWidget(MaterialApp(
  home: SearchResultsPage(
    query: 'test',
    entityDataSource: entityDataSource,
    movieDataSource: _RecordingSearchMovieDataSource(),
  ),
));

GoRouter buildSearchResultsRouter(SearchEntityDataSource entityDataSource) => GoRouter(
  initialLocation: '/search/results',
  routes: [
    GoRoute(
      path: '/search/results',
      builder: (_, _) => SearchResultsPage(
        query: 'test',
        entityDataSource: entityDataSource,
        movieDataSource: _RecordingSearchMovieDataSource(),
      ),
    ),
    GoRoute(
      path: '/actor/:id',
      builder: (_, state) => Scaffold(body: Text('actor ${state.pathParameters['id']}')),
    ),
  ],
);

class FakeSearchEntityDataSource implements SearchEntityDataSource {
  FakeSearchEntityDataSource({
    this.actors = const PagedResult(items: [], currentPage: 1, totalPages: 1, total: 0),
    this.seriesPages = const {},
    this.makers = const PagedResult(items: [], currentPage: 1, totalPages: 1, total: 0),
    this.directors = const PagedResult(items: [], currentPage: 1, totalPages: 1, total: 0),
    this.lists = const PagedResult(items: [], currentPage: 1, totalPages: 1, total: 0),
    this.codes = const PagedResult(items: [], currentPage: 1, totalPages: 1, total: 0),
  });

  factory FakeSearchEntityDataSource.singleNamedResults() => FakeSearchEntityDataSource(
    seriesPages: const {
      1: PagedResult(items: [Series(id: 's1', name: '测试系列', movieCount: 1)], currentPage: 1, totalPages: 1, total: 1),
    },
    makers: const PagedResult(items: [Maker(id: 'm1', name: '测试片商', movieCount: 2)], currentPage: 1, totalPages: 1, total: 1),
    directors: const PagedResult(items: [Director(id: 'd1', name: '测试导演', movieCount: 3)], currentPage: 1, totalPages: 1, total: 1),
    lists: const PagedResult(items: [ListModel(id: 'l1', name: '测试清单', movieCount: 4, viewedCount: 5)], currentPage: 1, totalPages: 1, total: 1),
    codes: const PagedResult(items: [Code(id: 'TEST', number: 'TEST', movieCount: 6)], currentPage: 1, totalPages: 1, total: 1),
  );

  final PagedResult<ActorSummary> actors;
  final Map<int, PagedResult<Series>> seriesPages;
  final PagedResult<Maker> makers;
  final PagedResult<Director> directors;
  final PagedResult<ListModel> lists;
  final PagedResult<Code> codes;
  final actorRequestedPages = <int>[];
  final seriesRequestedPages = <int>[];
  final makerRequestedPages = <int>[];
  final directorRequestedPages = <int>[];
  final listRequestedPages = <int>[];
  final codeRequestedPages = <int>[];
  int get totalCalls => actorRequestedPages.length + seriesRequestedPages.length +
      makerRequestedPages.length + directorRequestedPages.length +
      listRequestedPages.length + codeRequestedPages.length;

  @override
  Future<PagedResult<ActorSummary>> getActors({required String query, int page = 1}) async {
    actorRequestedPages.add(page);
    return actors;
  }
  @override
  Future<PagedResult<Series>> getSeries({required String query, int page = 1}) async {
    seriesRequestedPages.add(page);
    return seriesPages[page] ?? const PagedResult(items: [], currentPage: 1, totalPages: 1, total: 0);
  }
  @override
  Future<PagedResult<Maker>> getMakers({required String query, int page = 1}) async {
    makerRequestedPages.add(page);
    return makers;
  }
  @override
  Future<PagedResult<Director>> getDirectors({required String query, int page = 1}) async {
    directorRequestedPages.add(page);
    return directors;
  }
  @override
  Future<PagedResult<ListModel>> getLists({required String query, int page = 1}) async {
    listRequestedPages.add(page);
    return lists;
  }
  @override
  Future<PagedResult<Code>> getCodes({required String query, int page = 1}) async {
    codeRequestedPages.add(page);
    return codes;
  }
}
```

在第一个系列分页测试末尾切换到“片商”再切回“系列”，断言 `seriesRequestedPages` 仍为 `[1, 2]`，证明 Tab 状态保留且第一页没有重复请求。公共列表导航的表驱动测试已经同时证明清单使用 `ListSummaryTile`、其他四类使用 `SearchEntityListTile`。首屏和尾部错误状态由 Task 2 的通用分页列表测试覆盖，不在页面测试重复相同状态机断言。

- [x] **Step 5: 运行搜索页面测试并确认 RED**

Run: `flutter test test/features/search/search_screen_test.dart`

Expected: FAIL，原因包括 `entityDataSource` 注入口不存在、旧 `_EntitySearchTab/_CodeSearchTab` 不是分页组件、点击未导航。

- [x] **Step 6: 组装强类型分页 Tab**

在 `SearchResultsPage` 增加：

```dart
final SearchEntityDataSource? entityDataSource;
```

构建时解析真实或不可用数据源：

```dart
final entityDataSource = widget.entityDataSource ?? switch (ApiClient.instanceOrNull) {
  final api? => SearchEntityService(api),
  null => const UnavailableSearchEntityDataSource(),
};
```

每个 Tab 创建自己的 `PaginationController` 和 `SearchPageSession`。例如系列：

```dart
final session = SearchPageSession<Series>(
  fetchPage: (page) => dataSource.getSeries(query: query, page: page),
  idOf: (item) => item.id,
);
final controller = PaginationController<Series>(fetch: session.fetch)..fetchMore();
```

系列、片商、导演、番号的 `itemBuilder` 返回 `SearchEntityListTile`；清单返回 `ListSummaryTile`；演员把控制器传给 `ActorGridView`。所有 Tab 使用 `AutomaticKeepAliveClientMixin`，并在 `dispose` 释放控制器。

删除旧的内联 `_EntitySearchTab`、`_ActorSearchTab` API 解析和 `_CodeSearchTab` 一次性请求，确保 `SearchResultsPage` 不再直接处理响应 Map。

- [x] **Step 7: 实现公共页导航闭包**

```dart
Future<PagedResult<MovieSummary>> _emptyMoviePage(int page) async =>
    PagedResult(items: const [], currentPage: page, totalPages: page, total: 0);

void _openCommonList(BuildContext context, String typeLabel, String name) {
  Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (_) => CommonListPage(
      title: '$typeLabel - $name',
      dataSource: _emptyMoviePage,
    ),
  ));
}
```

分别传入固定类型中文：`系列`、`片商`、`导演`、`番号`、`清单`。该闭包不得读取 `ApiClient`，不得调用 `/api/v1/movies/tags` 或实体详情接口。

- [x] **Step 8: 运行聚焦测试并确认 GREEN**

Run: `flutter test test/features/search/search_screen_test.dart test/features/common/common_list_page_test.dart test/features/movie_detail/movie_detail_screen_test.dart`

Expected: PASS，六个 Tab、公共页 UI 和相关清单回归全部通过。

- [x] **Step 9: 提交 Task 3**

```bash
git add lib/features/search/screens/search_results_screen.dart \
  lib/features/common/screens/common_list_page.dart \
  test/features/search/search_screen_test.dart \
  test/features/common/common_list_page_test.dart
git commit -m "feat: complete search entity tabs"
```

---

### Task 4: 契约回归、全量验证与 ADB 验收

**Files:**
- Modify only if a real regression is found: files already owned by Tasks 1-3 and their tests.
- Update checklist: `docs/superpowers/plans/2026-08-03-search-entity-tabs.md`

**Interfaces:**
- Consumes: Tasks 1-3 的完成实现。
- Produces: 可审计的聚焦测试、全量测试、静态分析和模拟器验收证据。

- [x] **Step 1: 运行搜索和共享组件聚焦测试**

Run:

```bash
flutter test \
  test/features/search/search_entity_service_test.dart \
  test/features/search/search_page_session_test.dart \
  test/features/search/search_entity_list_tile_test.dart \
  test/features/search/search_paginated_list_view_test.dart \
  test/features/search/search_screen_test.dart \
  test/features/common/common_list_page_test.dart \
  test/core/widgets/list_summary_tile_test.dart \
  test/features/movie_detail/movie_detail_screen_test.dart
```

Expected: PASS，无测试失败和未处理异常。

- [x] **Step 2: 格式化并检查差异**

Run:

```bash
dart format lib/features/search lib/features/common/screens/common_list_page.dart \
  lib/core/widgets/list_summary_tile.dart test/features/search \
  test/features/common test/core/widgets/list_summary_tile_test.dart
git diff --check
git status --short
```

Expected: `dart format` 成功，`git diff --check` 无输出；状态中只有本计划相关文件。

- [x] **Step 3: 运行全量自动化验证**

Run:

```bash
flutter test
flutter analyze
```

Expected: 全部测试通过；静态分析输出 `No issues found!`。若 Flutter SDK 缓存写入被环境权限阻止，使用已授权的 Flutter 执行路径原样重跑，不把环境错误归因于代码。

- [x] **Step 4: 使用 ADB 验证真实交互和请求**

在已连接模拟器上运行当前分支 Debug 应用，搜索一个能返回多类结果的关键词，逐项验证：

1. 演员请求包含 `type=actor&page=1&limit=48`，网格样式与演员页一致，点击进入演员详情。
2. 系列、片商、导演、清单、番号分别发送正确 `type`，列表无斑马纹并显示正确数量。
3. 搜索列表滑动接近底部时发送 `page=2`；重复页不重复展示且不继续无限请求。
4. 非演员实体点击后，标题显示“类型 - 名称”，筛选与排序同行，页面包含影片网格。
5. 在公共页切换筛选和排序时，网络日志中没有新增影片接口请求。
6. 返回搜索页后，各 Tab 已加载内容和滚动状态保持。

Expected: 无崩溃、无布局溢出、请求参数与上述契约一致。

- [x] **Step 5: 更新计划勾选并提交验证记录**

将本计划实际完成的步骤改为 `[x]`，只提交计划勾选变化：

```bash
git add docs/superpowers/plans/2026-08-03-search-entity-tabs.md
git commit -m "docs: complete search entity tabs plan"
```
