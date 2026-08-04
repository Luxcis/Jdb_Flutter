# 通用列表页影片接口实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让综合搜索的系列、片商、导演、清单、番号五个实体点击后进入的 `CommonListPage` 真正调用 `/api/v1/movies/tags` 获取影片并用瀑布流网格分页展示；筛选默认含磁链、排序默认热度（清单默认存入时间）；筛选与排序分两行各占满整行，仅普通实体"发布日期"支持正序/倒序切换。

**Architecture:** 新增 `TagMoviesDataSource`/`TagMoviesService`/`UnavailableTagMoviesDataSource` 统一解析 `/api/v1/movies/tags`；`Series`/`Maker`/`Director`/`Code` 增加 `type` 字段并在搜索解析时保留；`CommonListPage` 接收 `type`/`category`/`id` 与可选数据源注入口，内部按类别生成排序选项、管理筛选/排序/方向状态并驱动 `PaginationController` 与现有 `MovieGridView` 瀑布流分页。

**Tech Stack:** Flutter、Dart、Material 3、Dio `ApiClient`、`PaginationController`、`SortSegmented`/`SortSelect`/`MovieGridView`、`json_serializable` + `build_runner`、`flutter_test` + `FakeAdapter`。

## Global Constraints

- 固定调用 `GET /api/v1/movies/tags`，`filter_by` 格式 `{type}:{category}:{id}[:{filter}]`，`limit=48`。
- 排序 `sort_by` 直传 API 值；仅 `sort_by == 'release'` 时携带 `order_by`，其他排序不携带。
- 方向切换按钮仅普通实体（`category != 'l'`）的"发布日期"（`release`）可用；清单"创建时间"固定倒序。
- 排序默认值：普通实体与番号为 `hit`，清单为 `update`；筛选默认 `magnet`（`filter=m`）。
- 系列/片商/导演排序选项五项、番号六项（含 `digit`）、清单三项（`update`/`release`/`score`）。
- 模型加字段后必须运行 `dart run build_runner build --delete-conflicting-outputs` 重新生成 `.g.dart`。
- 不新增依赖，不修改 ARB；用户可见中文直接按项目约定硬编码。
- 保留工作区中与本计划无关的改动；每次提交只暂存任务列出的文件。

---

### Task 1: 实体模型 type 字段与搜索解析

**Files:**
- Modify: `lib/core/models/series.dart`
- Modify: `lib/core/models/maker.dart`
- Modify: `lib/core/models/director.dart`
- Modify: `lib/core/models/code.dart`
- Modify: `lib/features/search/services/search_entity_service.dart:142-160`
- Modify: `test/features/search/search_entity_service_test.dart`

**Interfaces:**
- Consumes: 现有 `json_serializable` 模型与 `_namedEntityJson`/`_codeJson`。
- Produces: `Series/Maker/Director/Code` 新增 `int type` 字段（默认 0），搜索解析保留 type。

- [ ] **Step 1: 写 type 字段解析失败测试**

在 `test/features/search/search_entity_service_test.dart` 末尾追加：

```dart
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
```

- [ ] **Step 2: 运行服务测试并确认 RED**

Run: `flutter test test/features/search/search_entity_service_test.dart`
Expected: FAIL，原因是 `Series/Code/Maker/Director` 尚不存在 `type` 属性。

- [ ] **Step 3: 为四个模型增加 type 字段**

`lib/core/models/series.dart`：

```dart
@JsonSerializable(fieldRename: FieldRename.snake, createToJson: false)
class Series {
  const Series({
    required this.id,
    required this.name,
    this.movieCount = 0,
    this.type = 0,
  });
  final String id;
  final String name;
  final int movieCount;
  final int type;
  factory Series.fromJson(Map<String, dynamic> json) => _$SeriesFromJson(json);
}
```

`lib/core/models/maker.dart`：

```dart
@JsonSerializable(fieldRename: FieldRename.snake, createToJson: false)
class Maker {
  const Maker({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.movieCount = 0,
    this.type = 0,
  });
  final String id;
  final String name;
  final String? avatarUrl;
  final int movieCount;
  final int type;
  factory Maker.fromJson(Map<String, dynamic> json) => _$MakerFromJson(json);
}
```

`lib/core/models/director.dart`：

```dart
@JsonSerializable(fieldRename: FieldRename.snake, createToJson: false)
class Director {
  const Director({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.movieCount = 0,
    this.type = 0,
  });
  final String id;
  final String name;
  final String? avatarUrl;
  final int movieCount;
  final int type;
  factory Director.fromJson(Map<String, dynamic> json) => _$DirectorFromJson(json);
}
```

`lib/core/models/code.dart`：

```dart
@JsonSerializable(fieldRename: FieldRename.snake, createToJson: false)
class Code {
  const Code({
    required this.id,
    required this.number,
    this.movieCount = 0,
    this.type = 0,
  });
  final String id;
  final String number;
  final int movieCount;
  final int type;
  factory Code.fromJson(Map<String, dynamic> json) => _$CodeFromJson(json);
}
```

- [ ] **Step 4: 搜索服务规范化保留 type**

`lib/features/search/services/search_entity_service.dart` 的 `_namedEntityJson`：

```dart
Map<String, dynamic> _namedEntityJson(Map<String, dynamic> json) => {
  ...json,
  'id': apiString(json['id']) ?? '',
  'name': apiString(json['name']) ?? '',
  'type': apiInt(json['type'], 0),
  'movie_count': apiInt(
    json['movie_count'] ?? json['movies_count'] ?? json['videos_count'],
    0,
  ),
};
```

`_codeJson`：

```dart
Map<String, dynamic> _codeJson(Map<String, dynamic> json) => {
  ...json,
  'id': apiString(json['id'] ?? json['name'] ?? json['number']) ?? '',
  'number': apiString(json['number'] ?? json['name'] ?? json['id']) ?? '',
  'type': apiInt(json['type'], 0),
  'movie_count': apiInt(
    json['movie_count'] ?? json['movies_count'] ?? json['videos_count'],
    0,
  ),
};
```

- [ ] **Step 5: 重新生成序列化代码**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: 成功，重新生成 `series.g.dart`、`maker.g.dart`、`director.g.dart`、`code.g.dart`。

- [ ] **Step 6: 运行服务测试并确认 GREEN**

Run: `flutter test test/features/search/search_entity_service_test.dart`
Expected: PASS，type 解析与默认值断言全部通过。

- [ ] **Step 7: 提交 Task 1**

```bash
git add lib/core/models/series.dart lib/core/models/maker.dart \
  lib/core/models/director.dart lib/core/models/code.dart \
  lib/core/models/series.g.dart lib/core/models/maker.g.dart \
  lib/core/models/director.g.dart lib/core/models/code.g.dart \
  lib/features/search/services/search_entity_service.dart \
  test/features/search/search_entity_service_test.dart
git commit -m "feat: add type to search entities"
```

---

### Task 2: TagMovies 强类型数据源

**Files:**
- Create: `lib/features/common/services/tag_movies_service.dart`
- Create: `test/features/common/tag_movies_service_test.dart`

**Interfaces:**
- Consumes: `ApiClient.get`、`Endpoints.moviesTags`、`apiMap/apiList/apiInt`、`normalizeMovieSummaryJson`、`MovieSummary`、`PagedResult`。
- Produces: `TagMoviesDataSource`、`TagMoviesService`、`UnavailableTagMoviesDataSource`。

- [ ] **Step 1: 写服务请求与解析失败测试**

```dart
// test/features/common/tag_movies_service_test.dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/domain_manager.dart';
import 'package:jade/core/network/endpoints.dart';
import 'package:jade/core/network/interceptors/response_interceptor.dart';
import 'package:jade/core/network/testing/fake_adapter.dart';
import 'package:jade/features/common/services/tag_movies_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('filter_by 无筛选时拼接实体段，有筛选时追加 filter 段', () async {
    final fixture = await buildTagMoviesFixture();
    fixture.adapter.enqueueSequence(Endpoints.moviesTags, [
      tagMoviesResponse(),
      tagMoviesResponse(),
    ]);

    await fixture.service.getMovies(
      type: 2,
      category: 's',
      id: 's1',
      filter: '',
      sortBy: 'hit',
    );
    await fixture.service.getMovies(
      type: 2,
      category: 's',
      id: 's1',
      filter: 'm',
      sortBy: 'hit',
    );

    expect(
      fixture.adapter.requests.map(
        (request) => request.queryParameters['filter_by'],
      ),
      ['2:s:s1', '2:s:s1:m'],
    );
  });

  test('sort_by=release 携带 order_by，其他排序不携带', () async {
    final fixture = await buildTagMoviesFixture();
    fixture.adapter.enqueueSequence(Endpoints.moviesTags, [
      tagMoviesResponse(),
      tagMoviesResponse(),
      tagMoviesResponse(),
    ]);

    await fixture.service.getMovies(
      type: 0,
      category: 'c',
      id: 'IPZZ',
      filter: 'm',
      sortBy: 'hit',
    );
    await fixture.service.getMovies(
      type: 0,
      category: 'c',
      id: 'IPZZ',
      filter: 'm',
      sortBy: 'release',
    );
    await fixture.service.getMovies(
      type: 0,
      category: 'c',
      id: 'IPZZ',
      filter: 'm',
      sortBy: 'release',
      orderBy: 'asc',
    );

    final params = fixture.adapter.requests.map(
      (request) => request.queryParameters,
    ).toList();
    expect(params[0].containsKey('order_by'), isFalse);
    expect(params[1]['order_by'], 'desc');
    expect(params[2]['order_by'], 'asc');
    expect(params[0]['sort_by'], 'hit');
    expect(params[1]['sort_by'], 'release');
    expect(params[2]['sort_by'], 'release');
  });

  test('movies 集合解析与分页元数据', () async {
    final fixture = await buildTagMoviesFixture();
    fixture.adapter.enqueue(Endpoints.moviesTags, {
      'success': 1,
      'data': {
        'movies': [
          {'id': 'm1', 'number': 'SSIS-001', 'title': '测试', 'cover_url': ''},
        ],
        'current_page': 2,
        'total_pages': 4,
        'total_count': 80,
      },
    });

    final result = await fixture.service.getMovies(
      type: 0,
      category: 'l',
      id: 'list-1',
      filter: 'm',
      sortBy: 'update',
      page: 2,
    );

    expect(result.items.single.id, 'm1');
    expect(result.currentPage, 2);
    expect(result.totalPages, 4);
    expect(result.total, 80);
    expect(fixture.adapter.requests.single.queryParameters, {
      'filter_by': '0:l:list-1:m',
      'sort_by': 'update',
      'page': 2,
      'limit': 48,
    });
  });

  test('缺少 total_pages 时按 48 条阈值推断下一页', () async {
    final fixture = await buildTagMoviesFixture();
    fixture.adapter.enqueueSequence(Endpoints.moviesTags, [
      {
        'success': 1,
        'data': {
          'movies': [
            for (var index = 0; index < 48; index++)
              {'id': 'm$index', 'number': 'N$index', 'title': 'T', 'cover_url': ''},
          ],
          'current_page': 1,
        },
      },
      {
        'success': 1,
        'data': {
          'movies': [
            {'id': 'm48', 'number': 'N48', 'title': 'T', 'cover_url': ''},
          ],
          'current_page': 2,
        },
      },
    ]);

    final full = await fixture.service.getMovies(
      type: 0,
      category: 'm',
      id: 'maker-1',
      filter: 'm',
      sortBy: 'hit',
    );
    final partial = await fixture.service.getMovies(
      type: 0,
      category: 'm',
      id: 'maker-1',
      filter: 'm',
      sortBy: 'hit',
    );

    expect(full.totalPages, 2);
    expect(partial.totalPages, 2);
  });
}

Future<({FakeAdapter adapter, TagMoviesService service})>
buildTagMoviesFixture() async {
  final preferences = await SharedPreferences.getInstance();
  final domainManager = await DomainManager.load(preferences);
  final adapter = FakeAdapter();
  final dio = Dio(BaseOptions(baseUrl: domainManager.currentUrl))
    ..httpClientAdapter = adapter
    ..interceptors.add(ResponseInterceptor(onAuthError: () {}));
  final api = ApiClient.forTest(dio: dio, domainManager: domainManager);
  return (adapter: adapter, service: TagMoviesService(api));
}

Map<String, dynamic> tagMoviesResponse() => {
  'success': 1,
  'data': {
    'movies': [],
    'current_page': 1,
  },
};
```

注意：`partial.totalPages` 预期为 2 是因为第二页返回 1 条不满 48 但接口无 `total_pages`，推断逻辑为 `currentPage + (items.length >= 48 ? 1 : 0)`，第二页 items=1 时推断为 2（保持 currentPage）。此断言验证"不满 48 停止增长"的语义由 `PaginationController.hasMore` 在页面层终止。

- [ ] **Step 2: 运行服务测试并确认 RED**

Run: `flutter test test/features/common/tag_movies_service_test.dart`
Expected: FAIL，原因是 `tag_movies_service.dart`、`TagMoviesService` 尚不存在。

- [ ] **Step 3: 实现强类型数据源**

```dart
// lib/features/common/services/tag_movies_service.dart
import 'package:jade/core/models/movie.dart';
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/api_data.dart';
import 'package:jade/core/network/endpoints.dart';

abstract interface class TagMoviesDataSource {
  Future<PagedResult<MovieSummary>> getMovies({
    required int type,
    required String category,
    required String id,
    required String filter,
    required String sortBy,
    String orderBy = 'desc',
    int page = 1,
  });
}

class TagMoviesService implements TagMoviesDataSource {
  TagMoviesService(this._api);

  static const _pageSize = 48;

  final ApiClient _api;

  @override
  Future<PagedResult<MovieSummary>> getMovies({
    required int type,
    required String category,
    required String id,
    required String filter,
    required String sortBy,
    String orderBy = 'desc',
    int page = 1,
  }) async {
    final filterBy = filter.isEmpty
        ? '$type:$category:$id'
        : '$type:$category:$id:$filter';
    final query = <String, dynamic>{
      'filter_by': filterBy,
      'sort_by': sortBy,
      if (sortBy == 'release') 'order_by': orderBy,
      'page': page,
      'limit': _pageSize,
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
    final currentPage = apiInt(data['current_page'], page);
    final totalPages = data['total_pages'] == null
        ? currentPage + (items.length >= _pageSize ? 1 : 0)
        : apiInt(data['total_pages'], currentPage);
    return PagedResult(
      items: items,
      currentPage: currentPage,
      totalPages: totalPages,
      total: apiInt(data['total_count'] ?? data['total'], items.length),
    );
  }
}

class UnavailableTagMoviesDataSource implements TagMoviesDataSource {
  const UnavailableTagMoviesDataSource();

  @override
  Future<PagedResult<MovieSummary>> getMovies({
    required int type,
    required String category,
    required String id,
    required String filter,
    required String sortBy,
    String orderBy = 'desc',
    int page = 1,
  }) async => PagedResult(
    items: const [],
    currentPage: page,
    totalPages: page,
    total: 0,
  );
}
```

- [ ] **Step 4: 运行服务测试并确认 GREEN**

Run: `flutter test test/features/common/tag_movies_service_test.dart`
Expected: PASS。

- [ ] **Step 5: 提交 Task 2**

```bash
git add lib/features/common/services/tag_movies_service.dart \
  test/features/common/tag_movies_service_test.dart
git commit -m "feat: add tag movies data source"
```

---

### Task 3: CommonListPage 接入真实数据、两行布局与排序选项

**Files:**
- Modify: `lib/features/common/screens/common_list_page.dart`
- Modify: `test/features/common/common_list_page_test.dart`

**Interfaces:**
- Consumes: Task 2 的 `TagMoviesDataSource/TagMoviesService/UnavailableTagMoviesDataSource`，现有 `SortSegmented/SortSelect/MovieGridView/PaginationController/ApiClient`。
- Produces: `CommonListPage(type, category, id, dataSource?)`，两行布局、按类别排序选项、方向切换按钮。

- [ ] **Step 1: 重写页面失败测试**

将 `test/features/common/common_list_page_test.dart` 整体替换为：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/models/movie.dart';
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/core/widgets/movie_grid_view.dart';
import 'package:jade/core/widgets/sort_segmented.dart';
import 'package:jade/core/widgets/sort_select.dart';
import 'package:jade/features/common/screens/common_list_page.dart';
import 'package:jade/features/common/services/tag_movies_service.dart';

typedef _Call = ({
  int type,
  String category,
  String id,
  String filter,
  String sortBy,
  String orderBy,
  int page,
});

class _RecordingTagMoviesDataSource implements TagMoviesDataSource {
  final calls = <_Call>[];

  @override
  Future<PagedResult<MovieSummary>> getMovies({
    required int type,
    required String category,
    required String id,
    required String filter,
    required String sortBy,
    String orderBy = 'desc',
    int page = 1,
  }) async {
    calls.add((
      type: type,
      category: category,
      id: id,
      filter: filter,
      sortBy: sortBy,
      orderBy: orderBy,
      page: page,
    ));
    return PagedResult(
      items: const [],
      currentPage: page,
      totalPages: page,
      total: 0,
    );
  }
}

void main() {
  testWidgets('两行布局各占整行且首屏默认含磁链热度', (tester) async {
    final source = _RecordingTagMoviesDataSource();
    await tester.pumpWidget(
      MaterialApp(
        home: CommonListPage(
          title: '系列 - Madonna',
          type: 2,
          category: 's',
          id: 's1',
          dataSource: source,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('系列 - Madonna'), findsOneWidget);
    final filterRow = tester.getTopLeft(
      find.byKey(const Key('common-list-filter')),
    );
    final sortRow = tester.getTopLeft(find.byKey(const Key('common-list-sort')));
    expect(sortRow.dy, greaterThan(filterRow.dy));
    expect(
      tester.widget<SortSegmented<String>>(
        find.byKey(const Key('common-list-filter')),
      ).value,
      'magnet',
    );
    final call = source.calls.single;
    expect(call.filter, 'm');
    expect(call.sortBy, 'hit');
    expect(call.type, 2);
    expect(call.category, 's');
    expect(call.id, 's1');
    expect(find.byType(MovieGridView), findsOneWidget);
  });

  testWidgets('清单默认排序为存入时间', (tester) async {
    final source = _RecordingTagMoviesDataSource();
    await tester.pumpWidget(
      MaterialApp(
        home: CommonListPage(
          title: '清单 - 收藏精选',
          type: 0,
          category: 'l',
          id: 'list-1',
          dataSource: source,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(source.calls.single.sortBy, 'update');
    expect(find.text('存入时间'), findsOneWidget);
    expect(find.text('创建时间'), findsOneWidget);
    expect(find.text('评分'), findsOneWidget);
    expect(find.text('热度'), findsNothing);
    expect(find.text('番号'), findsNothing);
  });

  testWidgets('番号排序选项含番号', (tester) async {
    final source = _RecordingTagMoviesDataSource();
    await tester.pumpWidget(
      MaterialApp(
        home: CommonListPage(
          title: '番号 - IPZZ',
          type: 0,
          category: 'c',
          id: 'IPZZ',
          dataSource: source,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(source.calls.single.sortBy, 'hit');
    await tester.tap(find.byKey(const Key('common-list-sort')));
    await tester.pumpAndSettle();
    expect(find.text('番号').last, findsOneWidget);
  });

  testWidgets('切换筛选全部后去掉 filter 段并重新加载', (tester) async {
    final source = _RecordingTagMoviesDataSource();
    await tester.pumpWidget(
      MaterialApp(
        home: CommonListPage(
          title: '系列 - Madonna',
          type: 2,
          category: 's',
          id: 's1',
          dataSource: source,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(source.calls, hasLength(1));

    await tester.tap(find.text('全部'));
    await tester.pumpAndSettle();

    expect(source.calls, hasLength(2));
    expect(source.calls.last.filter, '');
    expect(source.calls.last.page, 1);
  });

  testWidgets('切换排序评分后 sort_by=score 且从第一页重新加载', (tester) async {
    final source = _RecordingTagMoviesDataSource();
    await tester.pumpWidget(
      MaterialApp(
        home: CommonListPage(
          title: '系列 - Madonna',
          type: 2,
          category: 's',
          id: 's1',
          dataSource: source,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('common-list-sort')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('评分').last);
    await tester.pumpAndSettle();

    expect(source.calls.last.sortBy, 'score');
    expect(source.calls.last.page, 1);
  });

  testWidgets('发布日期可切换方向，其他排序方向按钮不可用', (tester) async {
    final source = _RecordingTagMoviesDataSource();
    await tester.pumpWidget(
      MaterialApp(
        home: CommonListPage(
          title: '系列 - Madonna',
          type: 2,
          category: 's',
          id: 's1',
          dataSource: source,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 默认热度：方向按钮不可用
    var toggle = tester.widget<IconButton>(
      find.byKey(const Key('common-list-order-toggle')),
    );
    expect(toggle.onPressed, isNull);

    // 切换到发布日期：方向按钮可用
    await tester.tap(find.byKey(const Key('common-list-sort')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('发布日期').last);
    await tester.pumpAndSettle();
    toggle = tester.widget<IconButton>(
      find.byKey(const Key('common-list-order-toggle')),
    );
    expect(toggle.onPressed, isNotNull);
    expect(source.calls.last.orderBy, 'desc');

    // 点击方向按钮切正序
    await tester.tap(find.byKey(const Key('common-list-order-toggle')));
    await tester.pumpAndSettle();
    expect(source.calls.last.orderBy, 'asc');
    expect(source.calls.last.sortBy, 'release');
  });

  testWidgets('清单创建时间方向按钮不可用', (tester) async {
    final source = _RecordingTagMoviesDataSource();
    await tester.pumpWidget(
      MaterialApp(
        home: CommonListPage(
          title: '清单 - 收藏精选',
          type: 0,
          category: 'l',
          id: 'list-1',
          dataSource: source,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('common-list-sort')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('创建时间').last);
    await tester.pumpAndSettle();

    final toggle = tester.widget<IconButton>(
      find.byKey(const Key('common-list-order-toggle')),
    );
    expect(toggle.onPressed, isNull);
    expect(source.calls.last.sortBy, 'release');
    expect(source.calls.last.orderBy, 'desc');
  });
}
```

- [ ] **Step 2: 运行页面测试并确认 RED**

Run: `flutter test test/features/common/common_list_page_test.dart`
Expected: FAIL，原因是 `CommonListPage` 构造参数与布局尚未实现。

- [ ] **Step 3: 实现 CommonListPage**

将 `lib/features/common/screens/common_list_page.dart` 整体替换为：

```dart
import 'package:flutter/material.dart';
import 'package:jade/core/models/movie.dart';
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/widgets/movie_grid_view.dart';
import 'package:jade/core/widgets/pagination_controller.dart';
import 'package:jade/core/widgets/sort_segmented.dart';
import 'package:jade/core/widgets/sort_select.dart';
import 'package:jade/features/common/services/tag_movies_service.dart';

typedef _SortOption = ({String label, String value});

class CommonListPage extends StatefulWidget {
  const CommonListPage({
    super.key,
    required this.title,
    required this.type,
    required this.category,
    required this.id,
    this.dataSource,
  });

  final String title;
  final int type;
  final String category;
  final String id;
  final TagMoviesDataSource? dataSource;

  @override
  State<CommonListPage> createState() => _CommonListPageState();
}

class _CommonListPageState extends State<CommonListPage> {
  static const _filterOptions = [
    (label: '全部', value: 'all'),
    (label: '可播放', value: 'playable'),
    (label: '含磁链', value: 'magnet'),
    (label: '字幕', value: 'subtitle'),
  ];

  static const _commonSortOptions = [
    (label: '发布日期', value: 'release'),
    (label: '评分', value: 'score'),
    (label: '热度', value: 'hit'),
    (label: '想看人数', value: 'want_watch_count'),
    (label: '看过人数', value: 'watched_count'),
  ];

  static const _listSortOptions = [
    (label: '存入时间', value: 'update'),
    (label: '创建时间', value: 'release'),
    (label: '评分', value: 'score'),
  ];

  late final List<_SortOption> _sortOptions;
  late final TagMoviesDataSource _dataSource;
  late final PaginationController<MovieSummary> _ctrl;
  var _filter = 'magnet';
  late String _sort;
  var _orderBy = 'desc';

  @override
  void initState() {
    super.initState();
    _sortOptions = switch (widget.category) {
      'l' => _listSortOptions,
      'c' => [..._commonSortOptions, const (label: '番号', value: 'digit')],
      _ => _commonSortOptions,
    };
    _sort = widget.category == 'l' ? 'update' : 'hit';
    _dataSource =
        widget.dataSource ??
        switch (ApiClient.instanceOrNull) {
          final api? => TagMoviesService(api),
          null => const UnavailableTagMoviesDataSource(),
        };
    _ctrl = PaginationController<MovieSummary>(fetch: _fetchPage)..fetchMore();
  }

  String get _filterApi => switch (_filter) {
    'all' => '',
    'playable' => 'p',
    'magnet' => 'm',
    'subtitle' => 'c',
    _ => '',
  };

  bool get _canToggleOrder => _sort == 'release' && widget.category != 'l';

  Future<PagedResult<MovieSummary>> _fetchPage(int page) => _dataSource.getMovies(
    type: widget.type,
    category: widget.category,
    id: widget.id,
    filter: _filterApi,
    sortBy: _sort,
    orderBy: _orderBy,
    page: page,
  );

  void _changeFilter(String value) {
    if (value == _filter) return;
    setState(() => _filter = value);
    _ctrl.reloadWith(_fetchPage);
  }

  void _changeSort(String? value) {
    if (value == null || value == _sort) return;
    setState(() => _sort = value);
    _ctrl.reloadWith(_fetchPage);
  }

  void _toggleOrder() {
    setState(() => _orderBy = _orderBy == 'asc' ? 'desc' : 'asc');
    _ctrl.reloadWith(_fetchPage);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: SortSegmented<String>(
              key: const Key('common-list-filter'),
              compact: true,
              expanded: true,
              options: _filterOptions,
              value: _filter,
              onChanged: _changeFilter,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: SortSelect<String>(
                    key: const Key('common-list-sort'),
                    options: _sortOptions,
                    value: _sort,
                    onChanged: _changeSort,
                  ),
                ),
                IconButton(
                  key: const Key('common-list-order-toggle'),
                  tooltip: _orderBy == 'asc' ? '倒序' : '正序',
                  onPressed: _canToggleOrder ? _toggleOrder : null,
                  icon: Icon(
                    _orderBy == 'asc'
                        ? Icons.arrow_upward
                        : Icons.arrow_downward,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(child: MovieGridView(controller: _ctrl)),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: 运行页面测试并确认 GREEN**

Run: `flutter test test/features/common/common_list_page_test.dart`
Expected: PASS。

- [ ] **Step 5: 提交 Task 3**

```bash
git add lib/features/common/screens/common_list_page.dart \
  test/features/common/common_list_page_test.dart
git commit -m "feat: wire common list movies data source"
```

---

### Task 4: 搜索结果页导航传参

**Files:**
- Modify: `lib/features/search/screens/search_results_screen.dart:145-208,369-381`
- Modify: `test/features/search/search_screen_test.dart`

**Interfaces:**
- Consumes: Task 1 的实体 `type` 字段、Task 3 的 `CommonListPage` 新签名。
- Produces: 各实体 Tab 导航携带 `type/category/id`；删除 `_emptyMoviePage`。

- [ ] **Step 1: 更新导航闭包**

`lib/features/search/screens/search_results_screen.dart` 的 `_openCommonList` 与占位数据源替换为：

```dart
void _openCommonList(
  BuildContext context,
  String typeLabel,
  String name,
  int type,
  String category,
  String id,
) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => CommonListPage(
        title: '$typeLabel - $name',
        type: type,
        category: category,
        id: id,
      ),
    ),
  );
}
```

删除 `_emptyMoviePage` 函数。五个 Tab 的 `onTap` 依次改为：

```dart
onTap: () =>
    _openCommonList(context, '系列', item.name, item.type, 's', item.id),
```

```dart
onTap: () =>
    _openCommonList(context, '片商', item.name, item.type, 'm', item.id),
```

```dart
onTap: () =>
    _openCommonList(context, '导演', item.name, item.type, 'd', item.id),
```

```dart
onTap: () =>
    _openCommonList(context, '清单', item.name, 0, 'l', item.id),
```

```dart
onTap: () =>
    _openCommonList(context, '番号', item.number, item.type, 'c', item.id),
```

- [ ] **Step 2: 更新搜索页面测试**

`test/features/search/search_screen_test.dart` 中"非演员实体进入类型减名称公共页且不请求搜索或影片接口"测试的现有断言**无需修改**：新布局下 `find.byKey(const Key('common-list-filter'))`、`find.byKey(const Key('common-list-sort'))`、`find.byType(MovieGridView)` 依然成立；导航进入的 `CommonListPage` 在测试环境因 `ApiClient.instanceOrNull` 为 null 使用 `UnavailableTagMoviesDataSource`，不发起影片请求，因此 `source.totalCalls` 与 `movieSource.calls` 断言保持不变。

可选：给 `_FakeSearchEntityDataSource.singleNamedResults()` 的系列项补充 type 以验证导航传参：

```dart
seriesPages: const {
  1: PagedResult(
    items: [Series(id: 's1', name: '测试系列', movieCount: 1, type: 2)],
    currentPage: 1,
    totalPages: 1,
    total: 1,
  ),
},
```

（`Series` 构造的 `type` 参数来自 Task 1，默认 0 已满足编译，此补充仅为断言导航来源。）

- [ ] **Step 3: 运行聚焦测试并确认 GREEN**

Run: `flutter test test/features/search/search_screen_test.dart test/features/common/common_list_page_test.dart test/features/common/tag_movies_service_test.dart test/features/search/search_entity_service_test.dart`
Expected: PASS。

- [ ] **Step 4: 提交 Task 4**

```bash
git add lib/features/search/screens/search_results_screen.dart \
  test/features/search/search_screen_test.dart
git commit -m "feat: pass entity params to common list"
```

---

### Task 5: 契约回归、全量验证与计划勾选

**Files:**
- Modify only if a real regression is found: files already owned by Tasks 1-4 and their tests.
- Update checklist: `docs/superpowers/plans/2026-08-04-common-list-page-movies.md`

- [ ] **Step 1: 运行聚焦测试**

Run:

```bash
flutter test \
  test/features/search/search_entity_service_test.dart \
  test/features/search/search_screen_test.dart \
  test/features/common/tag_movies_service_test.dart \
  test/features/common/common_list_page_test.dart \
  test/core/widgets/list_summary_tile_test.dart \
  test/features/movie_detail/movie_detail_screen_test.dart
```

Expected: PASS，无测试失败和未处理异常。

- [ ] **Step 2: 格式化并检查差异**

Run:

```bash
dart format lib/features/common lib/features/search test/features/common test/features/search
git diff --check
git status --short
```

Expected: `dart format` 成功，`git diff --check` 无输出；状态中只有本计划相关文件。

- [ ] **Step 3: 运行全量自动化验证**

Run:

```bash
flutter test
flutter analyze
```

Expected: 全部测试通过；静态分析输出 `No issues found!`。

- [ ] **Step 4: 更新计划勾选并提交验证记录**

将本计划实际完成的步骤改为 `[x]`，只提交计划勾选变化：

```bash
git add docs/superpowers/plans/2026-08-04-common-list-page-movies.md
git commit -m "docs: complete common list page movies plan"
```
