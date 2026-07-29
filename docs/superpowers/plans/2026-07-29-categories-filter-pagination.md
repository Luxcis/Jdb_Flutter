# Categories Dynamic Filters and Pagination Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 重构分类页，使五个 Tab 使用 `/api/v2/tags` 动态筛选面板、固定七段 `filter_by`、相互独立状态和三列网格自动分页。

**Architecture:** 在 categories feature 内新增不可变筛选模型、标签模型和每 Tab 控制器。`CategoryService` 只负责 OpenAPI 请求与解析；控制器负责动态分组映射、即时重载、标签缓存和分页状态；页面持有五个控制器并用独立 Tab 子树保留滚动位置。共享 `PaginationController`/`MovieGridView` 仅增加“保留旧内容刷新”和滚动阈值预取能力，影片卡片继续复用 `MovieCard`。

**Tech Stack:** Flutter、Dart 3.8、Material 3、Dio、`ChangeNotifier`、`flutter_test`

## Global Constraints

- Tab 类型严格为 `0=有码`、`1=无码`、`2=欧美`、`3=FC2`、`4=动漫`。
- `filter_by` 固定为 `{type}:t:{main}:{extra}:{year}:{duration}:{month}`。
- 五个 Tab 首次请求分别为 `0:t:::::`、`1:t:::::`、`2:t:::::`、`3:t:::::`、`4:t:::::`。
- `/api/v2/tags` 返回的 `category_id=main/year/duration/month` 分别写入对应段；其他分组合并写入 `extra`。
- `main/year/duration/month` 单选，其他动态分组多选。
- 筛选点击后立即生效并保持面板打开。
- 分类影片每页固定 `limit=48`。
- 影片列表为三列等高网格，接近底部 `400px` 时自动加载下一页。
- 影片卡片必须复用现有 `MovieCard`，不得新增分类专用影片卡片。
- 不新增第三方依赖；遵循 Material 3、系统亮暗主题和中文硬编码文案。

---

## File Structure

- Create `lib/features/categories/models/category_filter.dart`
  - 不可变筛选、排序值和固定七段序列化。
- Create `lib/features/categories/models/category_tag.dart`
  - `/api/v2/tags` 分组和选项解析。
- Modify `lib/features/categories/services/category_service.dart`
  - 标签请求、正确影片请求及分页解析。
- Create `lib/features/categories/services/category_tab_controller.dart`
  - 单个 Tab 的标签、筛选、影片分页和请求代次状态。
- Create `lib/features/categories/widgets/category_filter_sheet.dart`
  - 动态紧凑底部筛选面板。
- Modify `lib/features/categories/screens/categories_screen.dart`
  - 五个独立控制器、Tab 保活和筛选面板入口。
- Modify `lib/core/widgets/pagination_controller.dart`
  - 支持保留旧列表的刷新替换。
- Modify `lib/core/widgets/movie_grid_view.dart`
  - `400px` 阈值预取、刷新反馈和已有列表分页失败重试。
- Create `test/features/categories/category_filter_test.dart`
- Create `test/features/categories/category_tab_controller_test.dart`
- Create `test/features/categories/categories_screen_test.dart`
- Modify `test/api_integration_test.dart`
- Modify `test/core/widgets/pagination_controller_test.dart`
- Modify `test/core/widgets/movie_grid_view_test.dart`

---

### Task 1: 固定七段筛选模型与动态标签模型

**Files:**
- Create: `lib/features/categories/models/category_filter.dart`
- Create: `lib/features/categories/models/category_tag.dart`
- Create: `test/features/categories/category_filter_test.dart`

**Interfaces:**
- Produces: `CategoryFilter`, `CategorySort`, `CategoryTagGroup`, `CategoryTagItem`
- Produces: `CategoryFilter.toggle(String categoryId, String value)`
- Produces: `CategoryFilter.toFilterBy(int type, List<String> categoryOrder)`

- [ ] **Step 1: 写筛选格式和标签解析失败测试**

```dart
// test/features/categories/category_filter_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/features/categories/models/category_filter.dart';
import 'package:jade/features/categories/models/category_tag.dart';

void main() {
  test('五个类型的空筛选保留固定七段', () {
    for (var type = 0; type < 5; type++) {
      expect(const CategoryFilter().toFilterBy(type, const []), '$type:t:::::');
    }
  });

  test('按 category_id 写入固定段位并稳定拼接 extra', () {
    final filter = const CategoryFilter()
        .toggle('main', 'm')
        .toggle('subject', '23')
        .toggle('role', '158')
        .toggle('year', '2024')
        .toggle('duration', '120')
        .toggle('month', '01');

    expect(
      filter.toFilterBy(
        0,
        const ['main', 'role', 'subject', 'year', 'duration', 'month'],
      ),
      '0:t:m:158,23:2024:120:01',
    );
  });

  test('固定段单选可替换和取消，extra 分组可多选', () {
    final filter = const CategoryFilter()
        .toggle('main', 'p')
        .toggle('main', 'm')
        .toggle('subject', '23')
        .toggle('subject', '51')
        .toggle('main', 'm');

    expect(filter.main, isNull);
    expect(filter.selectedValues('subject'), {'23', '51'});
  });

  test('解析接口返回的动态标签分组', () {
    final group = CategoryTagGroup.fromJson({
      'category': '题材',
      'category_id': 'subject',
      'tags': [
        {'id': '23', 'name': '剧情', 'videos_count': 12},
      ],
    });

    expect(group.category, '题材');
    expect(group.categoryId, 'subject');
    expect(group.tags.single.id, '23');
    expect(group.tags.single.videosCount, 12);
  });
}
```

- [ ] **Step 2: 运行测试并确认因模型不存在而失败**

Run:

```bash
flutter test test/features/categories/category_filter_test.dart
```

Expected: FAIL，错误包含 `category_filter.dart` 或 `CategoryFilter` 不存在。

- [ ] **Step 3: 实现最小不可变模型**

```dart
// lib/features/categories/models/category_filter.dart
import 'dart:collection';
import 'package:flutter/foundation.dart';

enum CategorySort {
  release('发布日期', 'release'),
  update('更新时间', 'update'),
  score('评分', 'score'),
  hit('热度', 'hit'),
  wantWatch('想看人数', 'want_watch_count'),
  watched('看过人数', 'watched_count');

  const CategorySort(this.label, this.value);
  final String label;
  final String value;
}

@immutable
class CategoryFilter {
  const CategoryFilter({
    this.main,
    this.year,
    this.duration,
    this.month,
    this.extraByCategory = const {},
    this.sort = CategorySort.release,
    this.orderBy = 'desc',
  });

  final String? main;
  final String? year;
  final String? duration;
  final String? month;
  final Map<String, Set<String>> extraByCategory;
  final CategorySort sort;
  final String orderBy;

  Set<String> selectedValues(String categoryId) {
    final single = switch (categoryId) {
      'main' => main,
      'year' => year,
      'duration' => duration,
      'month' => month,
      _ => null,
    };
    if (single != null) return {single};
    return Set.unmodifiable(extraByCategory[categoryId] ?? const {});
  }

  CategoryFilter toggle(String categoryId, String value) {
    if (const {'main', 'year', 'duration', 'month'}.contains(categoryId)) {
      final selected = selectedValues(categoryId);
      final current = selected.isEmpty ? null : selected.first;
      return _copySingle(categoryId, current == value ? null : value);
    }
    final extras = {
      for (final entry in extraByCategory.entries)
        entry.key: LinkedHashSet<String>.of(entry.value),
    };
    final values = extras.putIfAbsent(categoryId, LinkedHashSet.new);
    values.contains(value) ? values.remove(value) : values.add(value);
    if (values.isEmpty) extras.remove(categoryId);
    return copyWith(extraByCategory: extras);
  }

  CategoryFilter _copySingle(String categoryId, String? value) => CategoryFilter(
    main: categoryId == 'main' ? value : main,
    year: categoryId == 'year' ? value : year,
    duration: categoryId == 'duration' ? value : duration,
    month: categoryId == 'month' ? value : month,
    extraByCategory: extraByCategory,
    sort: sort,
    orderBy: orderBy,
  );

  CategoryFilter copyWith({
    Map<String, Set<String>>? extraByCategory,
    CategorySort? sort,
    String? orderBy,
  }) => CategoryFilter(
    main: main,
    year: year,
    duration: duration,
    month: month,
    extraByCategory: extraByCategory ?? this.extraByCategory,
    sort: sort ?? this.sort,
    orderBy: orderBy ?? this.orderBy,
  );

  String toFilterBy(int type, List<String> categoryOrder) {
    final extras = LinkedHashSet<String>();
    for (final categoryId in categoryOrder) {
      extras.addAll(extraByCategory[categoryId] ?? const {});
    }
    return [
      '$type',
      't',
      main ?? '',
      extras.join(','),
      year ?? '',
      duration ?? '',
      month ?? '',
    ].join(':');
  }
}
```

```dart
// lib/features/categories/models/category_tag.dart
import 'package:jade/core/network/api_data.dart';

class CategoryTagGroup {
  const CategoryTagGroup({
    required this.category,
    required this.categoryId,
    required this.tags,
  });

  final String category;
  final String categoryId;
  final List<CategoryTagItem> tags;

  factory CategoryTagGroup.fromJson(Map<String, dynamic> json) =>
      CategoryTagGroup(
        category: apiString(json['category']) ?? '',
        categoryId: apiString(json['category_id']) ?? '',
        tags: apiList(json['tags'], const [])
            .map(CategoryTagItem.fromJson)
            .toList(growable: false),
      );
}

class CategoryTagItem {
  const CategoryTagItem({
    required this.id,
    required this.name,
    required this.videosCount,
  });

  final String id;
  final String name;
  final int videosCount;

  factory CategoryTagItem.fromJson(Map<String, dynamic> json) =>
      CategoryTagItem(
        id: apiString(json['id']) ?? '',
        name: apiString(json['name']) ?? '',
        videosCount: apiInt(json['videos_count'], 0),
      );
}
```

- [ ] **Step 4: 格式化并运行模型测试**

Run:

```bash
dart format lib/features/categories/models test/features/categories/category_filter_test.dart
flutter test test/features/categories/category_filter_test.dart
```

Expected: PASS，4 tests passed。

- [ ] **Step 5: 提交模型**

```bash
git add lib/features/categories/models/category_filter.dart lib/features/categories/models/category_tag.dart test/features/categories/category_filter_test.dart
git commit -m "feat(categories): model dynamic filters"
```

---

### Task 2: 按 OpenAPI 请求标签和分类影片

**Files:**
- Modify: `lib/features/categories/services/category_service.dart`
- Modify: `test/api_integration_test.dart`

**Interfaces:**
- Consumes: `CategoryFilter`, `CategoryTagGroup`
- Produces: `abstract interface class CategoryDataSource`
- Produces: `Future<List<CategoryTagGroup>> getTags({required int type})`
- Produces: `Future<PagedResult<MovieSummary>> getMovies({required int type, required CategoryFilter filter, required List<String> categoryOrder, int page = 1})`

- [ ] **Step 1: 将旧 CategoryService 测试改为精确契约测试**

Replace the existing `CategoryService` group with tests that enqueue both endpoints:

```dart
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
```

- [ ] **Step 2: 运行定向 API 测试并确认旧实现失败**

Run:

```bash
flutter test test/api_integration_test.dart --plain-name CategoryService
```

Expected: FAIL；旧实现缺少 `getTags`，并发送 `type=1`、`filter_by=categories`、`limit=20`。

- [ ] **Step 3: 实现数据源接口与正确请求**

```dart
// lib/features/categories/services/category_service.dart
import 'package:jade/core/models/movie.dart';
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/api_data.dart';
import 'package:jade/core/network/endpoints.dart';
import 'package:jade/features/categories/models/category_filter.dart';
import 'package:jade/features/categories/models/category_tag.dart';

abstract interface class CategoryDataSource {
  Future<List<CategoryTagGroup>> getTags({required int type});

  Future<PagedResult<MovieSummary>> getMovies({
    required int type,
    required CategoryFilter filter,
    required List<String> categoryOrder,
    int page = 1,
  });
}

class CategoryService implements CategoryDataSource {
  CategoryService(this._api);
  final ApiClient _api;

  @override
  Future<List<CategoryTagGroup>> getTags({required int type}) async {
    final response = await _api.get(
      Endpoints.tagsV2,
      queryParameters: {'type': type},
    );
    return apiList(response.data, const ['tags'])
        .map(CategoryTagGroup.fromJson)
        .toList(growable: false);
  }

  @override
  Future<PagedResult<MovieSummary>> getMovies({
    required int type,
    required CategoryFilter filter,
    required List<String> categoryOrder,
    int page = 1,
  }) async {
    final query = <String, dynamic>{
      'filter_by': filter.toFilterBy(type, categoryOrder),
      'sort_by': filter.sort.value,
      if (filter.sort == CategorySort.release) 'order_by': filter.orderBy,
      'page': page,
      'limit': 48,
    };
    final response = await _api.get(
      Endpoints.moviesTags,
      queryParameters: query,
    );
    final data = apiMap(response.data);
    final items = apiList(data, const ['movies', 'items'])
        .map(normalizeMovieSummaryJson)
        .map(MovieSummary.fromJson)
        .toList(growable: false);
    return PagedResult(
      items: items,
      currentPage: apiInt(data['current_page'], page),
      totalPages: apiInt(data['total_pages'], page),
      total: apiInt(data['total_count'] ?? data['total'], items.length),
    );
  }
}
```

- [ ] **Step 4: 格式化并运行 CategoryService 测试**

Run:

```bash
dart format lib/features/categories/services/category_service.dart test/api_integration_test.dart
flutter test test/api_integration_test.dart --plain-name CategoryService
```

Expected: PASS，标签与影片查询参数完全匹配。

- [ ] **Step 5: 提交服务契约**

```bash
git add lib/features/categories/services/category_service.dart test/api_integration_test.dart
git commit -m "feat(categories): use tags API filter contract"
```

---

### Task 3: 共享分页支持保留内容刷新和阈值预取

**Files:**
- Modify: `lib/core/widgets/pagination_controller.dart`
- Modify: `lib/core/widgets/movie_grid_view.dart`
- Modify: `test/core/widgets/pagination_controller_test.dart`
- Modify: `test/core/widgets/movie_grid_view_test.dart`

**Interfaces:**
- Produces: `Future<void> reloadWith(PageFetcher<T> fetch, {bool preserveItems = false})`
- Produces: `bool get isRefreshing`
- Changes: `MovieGridView` 在 `extentAfter < 400` 的滚动更新中调用 `fetchMore`

- [ ] **Step 1: 写“旧内容保留至新结果成功”和“400px 预取”失败测试**

Append to `pagination_controller_test.dart`:

```dart
test('preserveItems 刷新在成功前保留旧内容并在成功后替换', () async {
  final next = Completer<PagedResult<int>>();
  final controller = PaginationController<int>(
    fetch: (_) async => _page([1]),
  );
  await controller.fetchMore();

  final refresh = controller.reloadWith(
    (_) => next.future,
    preserveItems: true,
  );

  expect(controller.items, [1]);
  expect(controller.isRefreshing, isTrue);
  next.complete(_page([2]));
  await refresh;
  expect(controller.items, [2]);
  expect(controller.isRefreshing, isFalse);
});
```

Append to `movie_grid_view_test.dart`:

```dart
testWidgets('滚动接近底部 400px 时自动请求下一页', (tester) async {
  final requestedPages = <int>[];
  final movies = List.generate(
    30,
    (index) => MovieSummary(
      id: '$index',
      number: 'N-$index',
      title: '影片 $index',
      coverUrl: '',
    ),
  );
  final controller = PaginationController<MovieSummary>(
    fetch: (page) async {
      requestedPages.add(page);
      return PagedResult(
        items: page == 1 ? movies : const [],
        currentPage: page,
        totalPages: 2,
        total: 30,
      );
    },
  );
  addTearDown(controller.dispose);
  await controller.fetchMore();
  await tester.pumpWidget(
    MaterialApp(home: Scaffold(body: MovieGridView(controller: controller))),
  );

  await tester.drag(find.byType(CustomScrollView), const Offset(0, -900));
  await tester.pump();

  expect(requestedPages, contains(2));
});
```

- [ ] **Step 2: 运行测试并确认失败原因正确**

Run:

```bash
flutter test test/core/widgets/pagination_controller_test.dart test/core/widgets/movie_grid_view_test.dart
```

Expected: FAIL；`preserveItems`/`isRefreshing` 不存在或只有滚动结束且 `200px` 才加载。

- [ ] **Step 3: 扩展 PaginationController**

Add fields/getter:

```dart
bool _replaceOnSuccess = false;
bool _isRefreshing = false;
bool get isRefreshing => _isRefreshing;
```

In `fetchMore`, before the request:

```dart
final requestedPage = _page + 1;
_isRefreshing = _replaceOnSuccess && _items.isNotEmpty;
```

Replace success append logic:

```dart
final result = await fetch(requestedPage);
if (generation != _generation) return;
_page = result.currentPage;
if (_replaceOnSuccess) {
  _items.clear();
  _replaceOnSuccess = false;
}
_items.addAll(result.items);
_hasMore = _page < result.totalPages;
```

In `finally`, before notifying:

```dart
_isRefreshing = false;
```

Change reload signature and reset:

```dart
Future<void> reloadWith(
  PageFetcher<T> fetch, {
  bool preserveItems = false,
}) async {
  _generation++;
  _fetch = fetch;
  _page = 0;
  if (!preserveItems) _items.clear();
  _replaceOnSuccess = preserveItems && _items.isNotEmpty;
  _hasMore = true;
  _isLoading = false;
  _isRefreshing = false;
  _error = null;
  notifyListeners();
  await fetchMore();
}
```

Keep `refresh()` source-compatible:

```dart
Future<void> refresh() => reloadWith(_fetch);
```

- [ ] **Step 4: 将网格触发改为滚动过程中 400px 预取并展示刷新条**

In `MovieGridView`, trigger on metrics notifications:

```dart
onNotification: (notification) {
  if (notification.metrics.extentAfter < 400) {
    controller.fetchMore();
  }
  return false;
},
```

Wrap the `CustomScrollView` in a `Stack` and add:

```dart
if (controller.isRefreshing)
  const Positioned(
    top: 0,
    left: 0,
    right: 0,
    child: LinearProgressIndicator(key: Key('movie-grid-refreshing')),
  ),
```

When `controller.error != null && controller.items.isNotEmpty`, append a bottom retry sliver:

```dart
SliverToBoxAdapter(
  child: TextButton.icon(
    key: const Key('movie-grid-load-more-retry'),
    onPressed: controller.fetchMore,
    icon: const Icon(Icons.refresh),
    label: const Text('加载失败，点击重试'),
  ),
),
```

- [ ] **Step 5: 格式化并运行共享组件测试**

Run:

```bash
dart format lib/core/widgets/pagination_controller.dart lib/core/widgets/movie_grid_view.dart test/core/widgets/pagination_controller_test.dart test/core/widgets/movie_grid_view_test.dart
flutter test test/core/widgets/pagination_controller_test.dart test/core/widgets/movie_grid_view_test.dart
```

Expected: PASS；现有首次加载和加载更多测试继续通过。

- [ ] **Step 6: 提交共享分页增强**

```bash
git add lib/core/widgets/pagination_controller.dart lib/core/widgets/movie_grid_view.dart test/core/widgets/pagination_controller_test.dart test/core/widgets/movie_grid_view_test.dart
git commit -m "feat: preload movie grid pages while scrolling"
```

---

### Task 4: 每个 Tab 的独立状态控制器

**Files:**
- Create: `lib/features/categories/services/category_tab_controller.dart`
- Create: `test/features/categories/category_tab_controller_test.dart`

**Interfaces:**
- Consumes: `CategoryDataSource`, `CategoryFilter`, `CategoryTagGroup`, `PaginationController<MovieSummary>`
- Produces: `CategoryTabController`
- Produces: `initialize()`, `retryTags()`, `toggleFilter()`, `changeSort()`, `toggleOrder()`

- [ ] **Step 1: 写独立状态、即时刷新、缓存和旧响应测试**

```dart
// test/features/categories/category_tab_controller_test.dart
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/models/movie.dart';
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/features/categories/models/category_filter.dart';
import 'package:jade/features/categories/models/category_tag.dart';
import 'package:jade/features/categories/services/category_service.dart';
import 'package:jade/features/categories/services/category_tab_controller.dart';

class _FakeSource implements CategoryDataSource {
  final tagsCalls = <int>[];
  final movieFilters = <String>[];
  Completer<PagedResult<MovieSummary>>? pendingMovie;

  @override
  Future<List<CategoryTagGroup>> getTags({required int type}) async {
    tagsCalls.add(type);
    return const [
      CategoryTagGroup(
        category: '基本',
        categoryId: 'main',
        tags: [CategoryTagItem(id: 'p', name: '可播放', videosCount: 1)],
      ),
      CategoryTagGroup(
        category: '题材',
        categoryId: 'subject',
        tags: [CategoryTagItem(id: '23', name: '剧情', videosCount: 1)],
      ),
    ];
  }

  @override
  Future<PagedResult<MovieSummary>> getMovies({
    required int type,
    required CategoryFilter filter,
    required List<String> categoryOrder,
    int page = 1,
  }) {
    movieFilters.add(filter.toFilterBy(type, categoryOrder));
    final pending = pendingMovie;
    if (pending != null) return pending.future;
    return Future.value(
      PagedResult(
        items: [
          MovieSummary(
            id: '$type-$page',
            number: 'N',
            title: '影片',
            coverUrl: '',
          ),
        ],
        currentPage: page,
        totalPages: page,
        total: 1,
      ),
    );
  }
}

void main() {
  test('初始化使用当前 type 空筛选并只加载一次标签', () async {
    final source = _FakeSource();
    final controller = CategoryTabController(type: 1, source: source);
    addTearDown(controller.dispose);

    await controller.initialize();
    await controller.initialize();

    expect(source.tagsCalls, [1]);
    expect(source.movieFilters.first, '1:t:::::');
  });

  test('两个 Tab 的筛选状态互不影响', () async {
    final source = _FakeSource();
    final first = CategoryTabController(type: 0, source: source);
    final second = CategoryTabController(type: 1, source: source);
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    await Future.wait([first.initialize(), second.initialize()]);

    await first.toggleFilter('main', 'p');

    expect(first.filter.main, 'p');
    expect(second.filter.main, isNull);
    expect(source.movieFilters.last, '0:t:p::::');
  });

  test('动态 extra 立即重载第一页并保持稳定顺序', () async {
    final source = _FakeSource();
    final controller = CategoryTabController(type: 0, source: source);
    addTearDown(controller.dispose);
    await controller.initialize();

    await controller.toggleFilter('subject', '23');

    expect(source.movieFilters.last, '0:t::23:::');
  });
}
```

- [ ] **Step 2: 运行控制器测试并确认类不存在**

Run:

```bash
flutter test test/features/categories/category_tab_controller_test.dart
```

Expected: FAIL，`CategoryTabController` 不存在。

- [ ] **Step 3: 实现每 Tab 控制器**

```dart
// lib/features/categories/services/category_tab_controller.dart
import 'package:flutter/foundation.dart';
import 'package:jade/core/models/movie.dart';
import 'package:jade/core/widgets/pagination_controller.dart';
import 'package:jade/features/categories/models/category_filter.dart';
import 'package:jade/features/categories/models/category_tag.dart';
import 'package:jade/features/categories/services/category_service.dart';

class CategoryTabController extends ChangeNotifier {
  CategoryTabController({required this.type, required CategoryDataSource source})
      : _source = source,
        movies = PaginationController<MovieSummary>(
          fetch: (_) => throw StateError('controller not initialized'),
        ) {
    movies.addListener(_notifyFromMovies);
  }

  final int type;
  final CategoryDataSource _source;
  final PaginationController<MovieSummary> movies;

  CategoryFilter _filter = const CategoryFilter();
  List<CategoryTagGroup> _groups = const [];
  bool _initialized = false;
  bool _tagsLoading = false;
  Object? _tagsError;

  CategoryFilter get filter => _filter;
  List<CategoryTagGroup> get groups => _groups;
  bool get tagsLoading => _tagsLoading;
  Object? get tagsError => _tagsError;
  List<String> get _categoryOrder =>
      _groups.map((group) => group.categoryId).toList(growable: false);

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    await Future.wait([retryTags(), movies.reloadWith(_fetchPage)]);
  }

  Future<void> retryTags() async {
    if (_tagsLoading) return;
    _tagsLoading = true;
    _tagsError = null;
    notifyListeners();
    try {
      _groups = await _source.getTags(type: type);
    } catch (error) {
      _tagsError = error;
    } finally {
      _tagsLoading = false;
      notifyListeners();
    }
  }

  Future<void> toggleFilter(String categoryId, String value) async {
    _filter = _filter.toggle(categoryId, value);
    notifyListeners();
    await movies.reloadWith(_fetchPage, preserveItems: true);
  }

  Future<void> changeSort(CategorySort sort) async {
    _filter = _filter.copyWith(sort: sort);
    notifyListeners();
    await movies.reloadWith(_fetchPage, preserveItems: true);
  }

  Future<void> toggleOrder() async {
    _filter = _filter.copyWith(
      orderBy: _filter.orderBy == 'desc' ? 'asc' : 'desc',
    );
    notifyListeners();
    await movies.reloadWith(_fetchPage, preserveItems: true);
  }

  Future<PagedResult<MovieSummary>> _fetchPage(int page) => _source.getMovies(
    type: type,
    filter: _filter,
    categoryOrder: _categoryOrder,
    page: page,
  );

  void _notifyFromMovies() => notifyListeners();

  @override
  void dispose() {
    movies.removeListener(_notifyFromMovies);
    movies.dispose();
    super.dispose();
  }
}
```

Import `package:jade/core/models/paged_result.dart` in the same file.

- [ ] **Step 4: 补充标签失败重试和排序参数测试**

Add tests that use a fake with a first failing `getTags`, assert `tagsError`, call
`retryTags`, then assert one group and two calls. Add a sort test:

```dart
await controller.changeSort(CategorySort.score);
expect(controller.filter.sort, CategorySort.score);
expect(source.movieFilters.last, '0:t:::::');
```

- [ ] **Step 5: 格式化并运行控制器与共享分页测试**

Run:

```bash
dart format lib/features/categories/services/category_tab_controller.dart test/features/categories/category_tab_controller_test.dart
flutter test test/features/categories/category_tab_controller_test.dart test/core/widgets/pagination_controller_test.dart
```

Expected: PASS；Tab 状态独立，标签只缓存一次，即时筛选从第一页重载。

- [ ] **Step 6: 提交 Tab 控制器**

```bash
git add lib/features/categories/services/category_tab_controller.dart test/features/categories/category_tab_controller_test.dart
git commit -m "feat(categories): isolate tab filter state"
```

---

### Task 5: 动态紧凑筛选面板

**Files:**
- Create: `lib/features/categories/widgets/category_filter_sheet.dart`
- Create: `test/features/categories/categories_screen_test.dart` (first section)

**Interfaces:**
- Consumes: `CategoryTabController`
- Produces: `CategoryFilterSheet`
- Keys: `category-filter-list` plus runtime patterns
  `category-filter-group-${group.categoryId}` and
  `category-filter-${group.categoryId}-${item.id}`

- [ ] **Step 1: 写动态分组、紧凑样式和即时生效 Widget 测试**

Create the test fixture with a `_FakeSource` that returns groups `main`, `subject`,
`year`, `duration`, and `month`, and records filter strings. Pump:

```dart
await tester.pumpWidget(
  MaterialApp(
    home: Scaffold(
      body: CategoryFilterSheet(controller: controller),
    ),
  ),
);
await tester.pump();
```

Assertions:

```dart
expect(find.text('基本'), findsOneWidget);
expect(find.text('题材'), findsOneWidget);
expect(find.text('可播放'), findsOneWidget);
expect(find.text('剧情'), findsOneWidget);
expect(find.text('客户端固定分组'), findsNothing);

for (final chip in tester.widgetList<FilterChip>(find.byType(FilterChip))) {
  expect(chip.visualDensity, VisualDensity.compact);
  expect(chip.materialTapTargetSize, MaterialTapTargetSize.shrinkWrap);
  expect(chip.showCheckmark, isFalse);
}

await tester.tap(
  find.byKey(const Key('category-filter-main-p')),
);
await tester.pump();
expect(source.movieFilters.last, '0:t:p::::');
expect(find.text('筛选'), findsOneWidget);
```

- [ ] **Step 2: 运行 Widget 测试并确认面板不存在**

Run:

```bash
flutter test test/features/categories/categories_screen_test.dart
```

Expected: FAIL，`CategoryFilterSheet` 不存在。

- [ ] **Step 3: 实现动态紧凑面板**

```dart
// lib/features/categories/widgets/category_filter_sheet.dart
import 'package:flutter/material.dart';
import 'package:jade/features/categories/models/category_filter.dart';
import 'package:jade/features/categories/services/category_tab_controller.dart';

class CategoryFilterSheet extends StatelessWidget {
  const CategoryFilterSheet({super.key, required this.controller});
  final CategoryTabController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
            child: Row(
              children: [
                Text('筛选', style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                PopupMenuButton<CategorySort>(
                  key: const Key('category-sort-menu'),
                  initialValue: controller.filter.sort,
                  onSelected: controller.changeSort,
                  itemBuilder: (_) => [
                    for (final sort in CategorySort.values)
                      PopupMenuItem(value: sort, child: Text(sort.label)),
                  ],
                  child: Text(controller.filter.sort.label),
                ),
                if (controller.filter.sort == CategorySort.release)
                  IconButton(
                    key: const Key('category-order-toggle'),
                    tooltip: controller.filter.orderBy == 'desc' ? '降序' : '升序',
                    onPressed: controller.toggleOrder,
                    icon: Icon(
                      controller.filter.orderBy == 'desc'
                          ? Icons.south
                          : Icons.north,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(child: _FilterBody(controller: controller)),
        ],
      ),
    );
  }
}

class _FilterBody extends StatelessWidget {
  const _FilterBody({required this.controller});
  final CategoryTabController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.tagsLoading && controller.groups.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (controller.tagsError != null && controller.groups.isEmpty) {
      return Center(
        child: TextButton.icon(
          onPressed: controller.retryTags,
          icon: const Icon(Icons.refresh),
          label: const Text('筛选内容加载失败，点击重试'),
        ),
      );
    }
    return ListView.separated(
      key: const Key('category-filter-list'),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: controller.groups.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final group = controller.groups[index];
        final selected = controller.filter.selectedValues(group.categoryId);
        return Row(
          key: Key('category-filter-group-${group.categoryId}'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 64,
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(group.category),
              ),
            ),
            Expanded(
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final item in group.tags)
                    FilterChip(
                      key: Key(
                        'category-filter-${group.categoryId}-${item.id}',
                      ),
                      label: Text(item.name),
                      selected: selected.contains(item.id),
                      onSelected: (_) => controller.toggleFilter(
                        group.categoryId,
                        item.id,
                      ),
                      showCheckmark: false,
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
```

- [ ] **Step 4: 增加大字体窄屏无溢出测试**

Pump the sheet at `320x640` with `TextScaler.linear(1.5)`, then:

```dart
expect(find.byKey(const Key('category-filter-list')), findsOneWidget);
expect(tester.takeException(), isNull);
```

- [ ] **Step 5: 格式化并运行面板测试**

Run:

```bash
dart format lib/features/categories/widgets/category_filter_sheet.dart test/features/categories/categories_screen_test.dart
flutter test test/features/categories/categories_screen_test.dart
```

Expected: PASS；内容完全来自 fake `/api/v2/tags` 分组，点击立即发起新筛选。

- [ ] **Step 6: 提交动态面板**

```bash
git add lib/features/categories/widgets/category_filter_sheet.dart test/features/categories/categories_screen_test.dart
git commit -m "feat(categories): add dynamic compact filter sheet"
```

---

### Task 6: 重构分类页面并连接五个独立 Tab

**Files:**
- Modify: `lib/features/categories/screens/categories_screen.dart`
- Modify: `test/features/categories/categories_screen_test.dart`
- Delete if no consumers remain: `lib/core/widgets/filter_drawer.dart`
- Delete if no consumers remain: `lib/core/widgets/sort_select.dart`

**Interfaces:**
- Changes: `CategoriesPage({Key? key, CategoryDataSource? dataSource})`
- Produces keys: `categories-filter-button` and
  `category-tab-grid-${controller.type}`
- Consumes: `MovieGridView` and existing `MovieCard`

- [ ] **Step 1: 写页面首次请求、动态面板、Tab 隔离和 MovieCard 复用测试**

Add a pump helper that sets a `390x844` view, injects `_FakeSource`, pumps
`CategoriesPage(dataSource: source)`, and settles the current Tab.

Add tests:

```dart
testWidgets('首页为有码且首次 filter_by 为 0:t:::::', (tester) async {
  final source = await _pumpCategories(tester);
  expect(source.movieFilters.first, '0:t:::::');
  expect(find.byType(MovieCard), findsWidgets);
  expect(find.byKey(const Key('category-tab-grid-0')), findsOneWidget);
});

testWidgets('筛选面板内容来自当前 Tab 标签接口且点击后保持打开', (tester) async {
  final source = await _pumpCategories(tester);
  await tester.tap(find.byKey(const Key('categories-filter-button')));
  await tester.pumpAndSettle();
  expect(find.text('题材 0'), findsOneWidget);
  await tester.tap(find.byKey(const Key('category-filter-subject-23')));
  await tester.pump();
  expect(source.movieFilters.last, '0:t::23:::');
  expect(find.text('筛选'), findsOneWidget);
});

testWidgets('切换 Tab 使用 1:t::::: 且切回恢复有码选择', (tester) async {
  final source = await _pumpCategories(tester);
  await tester.tap(find.byKey(const Key('categories-filter-button')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('category-filter-main-p')));
  await tester.pump();
  await tester.tapAt(const Offset(8, 8));
  await tester.pumpAndSettle();

  final tabBar = tester.widget<TabBar>(find.byType(TabBar));
  tabBar.controller!.animateTo(1);
  await tester.pumpAndSettle();
  expect(source.movieFilters, contains('1:t:::::'));

  tabBar.controller!.animateTo(0);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('categories-filter-button')));
  await tester.pumpAndSettle();
  final chip = tester.widget<FilterChip>(
    find.byKey(const Key('category-filter-main-p')),
  );
  expect(chip.selected, isTrue);
});
```

- [ ] **Step 2: 运行页面测试并确认旧页面失败**

Run:

```bash
flutter test test/features/categories/categories_screen_test.dart
```

Expected: FAIL；旧页面仍使用 Drawer、占位筛选、错误 type 和共享 `_sortBy`。

- [ ] **Step 3: 用五个控制器重写 CategoriesPage**

Core structure:

```dart
class CategoriesPage extends StatefulWidget {
  const CategoriesPage({super.key, this.dataSource});
  final CategoryDataSource? dataSource;

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage>
    with TickerProviderStateMixin {
  static const tabs = ['有码', '无码', '欧美', 'FC2', '动漫'];
  late final TabController _tabController;
  late final List<CategoryTabController> _controllers;
  late final CategoryDataSource _source;
  var _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    final api = ApiClient.instanceOrNull;
    _source = widget.dataSource ??
        (api != null
            ? CategoryService(api)
            : const UnavailableCategoryDataSource());
    _controllers = [
      for (var type = 0; type < tabs.length; type++)
        CategoryTabController(type: type, source: _source),
    ];
    _tabController = TabController(length: tabs.length, vsync: this)
      ..addListener(_handleTabChanged);
  }

  void _handleTabChanged() {
    if (_selectedIndex == _tabController.index || !mounted) return;
    setState(() => _selectedIndex = _tabController.index);
  }

  void _showFilter() {
    final height = MediaQuery.sizeOf(context).height * .9;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      constraints: BoxConstraints.tightFor(height: height),
      builder: (_) => CategoryFilterSheet(
        controller: _controllers[_selectedIndex],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChanged);
    _tabController.dispose();
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }
}
```

Add a no-API fallback to `category_service.dart`:

```dart
class UnavailableCategoryDataSource implements CategoryDataSource {
  const UnavailableCategoryDataSource();

  @override
  Future<List<CategoryTagGroup>> getTags({required int type}) async => const [];

  @override
  Future<PagedResult<MovieSummary>> getMovies({
    required int type,
    required CategoryFilter filter,
    required List<String> categoryOrder,
    int page = 1,
  }) async => PagedResult(
    items: const [],
    currentPage: page,
    totalPages: page,
    total: 0,
  );
}
```

Build:

```dart
return Scaffold(
  appBar: AppBar(
    title: const Text('类别'),
    actions: [
      IconButton(
        key: const Key('categories-filter-button'),
        tooltip: '筛选',
        onPressed: _showFilter,
        icon: const Icon(Icons.filter_alt_outlined),
      ),
    ],
    bottom: TabBar(
      controller: _tabController,
      isScrollable: true,
      tabs: [for (final tab in tabs) Tab(text: tab)],
    ),
  ),
  body: TabBarView(
    controller: _tabController,
    children: [
      for (final controller in _controllers)
        _CategoryTab(key: PageStorageKey(controller.type), controller: controller),
    ],
  ),
);
```

Implement `_CategoryTab` with `AutomaticKeepAliveClientMixin`, call
`controller.initialize()` once in `initState`, and build:

```dart
MovieGridView(
  key: Key('category-tab-grid-${widget.controller.type}'),
  controller: widget.controller.movies,
)
```

- [ ] **Step 4: 检查旧共享组件是否仍有消费者**

Run:

```bash
rg -n "FilterDrawer|SortSelect" lib test
```

If output only contains their definition files, delete exactly:

```bash
git rm lib/core/widgets/filter_drawer.dart lib/core/widgets/sort_select.dart
```

If any consumer remains, keep both files unchanged.

- [ ] **Step 5: 格式化并运行全部分类定向测试**

Run:

```bash
dart format lib/features/categories test/features/categories
flutter test test/features/categories test/api_integration_test.dart --plain-name CategoryService
```

Expected: PASS；五个 Tab 请求类型正确、筛选即时生效、状态互不覆盖、卡片为 `MovieCard`。

- [ ] **Step 6: 提交页面重构**

```bash
git add lib/features/categories test/features/categories lib/core/widgets/filter_drawer.dart lib/core/widgets/sort_select.dart
git commit -m "feat(categories): rebuild independent filter tabs"
```

When one or both optional shared files were not deleted, stage only paths that exist.

---

### Task 7: 回归验证和规格一致性检查

**Files:**
- Modify only if verification exposes a defect: files already listed in Tasks 1–6

**Interfaces:**
- Verifies all interfaces and global constraints; produces no new API.

- [ ] **Step 1: 运行分类和共享组件定向测试**

Run:

```bash
flutter test test/features/categories test/core/widgets/pagination_controller_test.dart test/core/widgets/movie_grid_view_test.dart
```

Expected: PASS，无异常或跳过。

- [ ] **Step 2: 运行 API 集成测试**

Run:

```bash
flutter test test/api_integration_test.dart
```

Expected: PASS，CategoryService 及其他服务回归均通过。

- [ ] **Step 3: 运行完整 Flutter 测试**

Run:

```bash
flutter test
```

Expected: PASS，全部测试通过。

- [ ] **Step 4: 运行静态分析**

Run:

```bash
flutter analyze
```

Expected: `No issues found!`

- [ ] **Step 5: 检查格式、差异和工作树范围**

Run:

```bash
dart format --output=none --set-exit-if-changed lib/features/categories lib/core/widgets/pagination_controller.dart lib/core/widgets/movie_grid_view.dart test/features/categories test/core/widgets/pagination_controller_test.dart test/core/widgets/movie_grid_view_test.dart test/api_integration_test.dart
git diff --check
git status --short
```

Expected: formatter exit 0；`git diff --check` 无输出；状态只包含本计划明确涉及且尚未提交的文件。

- [ ] **Step 6: 对照验收条件逐项核验**

Confirm from tests and request history:

```text
首次请求为 0:t::::: 到 4:t:::::
动态 category_id 正确进入 main/extra/year/duration/month
每个 Tab 筛选和滚动状态独立
筛选点击后立即请求且面板不关闭
limit=48
滚动距底部 400px 自动请求 page+1
影片项使用 MovieCard
快速重载只接受最后一代结果
```

- [ ] **Step 7: 若验证修复产生改动，提交最终修复**

```bash
git add lib/features/categories lib/core/widgets/pagination_controller.dart lib/core/widgets/movie_grid_view.dart test/features/categories test/core/widgets/pagination_controller_test.dart test/core/widgets/movie_grid_view_test.dart test/api_integration_test.dart
git commit -m "fix(categories): resolve verification regressions"
```

Skip this commit when verification required no fixes.
