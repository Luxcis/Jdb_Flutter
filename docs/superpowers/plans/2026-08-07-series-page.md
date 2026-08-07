# 首页系列页实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> 规格：`docs/superpowers/specs/2026-08-07-series-page-design.md`

**Goal:** 把首页「系列」豆腐块的 `/series` 占位页替换为真实系列页：5 个分类 Tab（番号、有码、无码、欧美、动漫），番号 Tab 走 `/api/v1/series/letters`，其余走 `/api/v1/series?type=0/1/2/4`，列表样式与搜索结果一致，番号 Tab 额外显示 description 副标题。

**Architecture:** 先把搜索功能私有的 `SearchEntityListTile`/`SearchPaginatedListView` 提升为共享组件 `EntityListTile`/`PaginatedListView`（core 层），再新建 `lib/features/series/` feature（模型、服务、页面），最后把 `/series` 路由接入 `SeriesPage`。每个 Tab 独立 `PaginationController` + `AutomaticKeepAliveClientMixin` 保活，点击条目用 `Navigator.push` 打开 `CommonListPage`（与搜索结果一致）。

**Tech Stack:** Flutter / Dart，go_router，json 手写反序列化（`api_data.dart` 辅助函数），`PaginationController` 分页，widget/unit 测试用 `flutter_test` + `FakeAdapter`。

## Global Constraints

- RULES.md：Material 3；文案中文硬编码，不用 l10n；Feature-First 结构，feature 只依赖 core（`features/common` 按现有惯例可被引用，见 search 对 `CommonListPage` 的用法）。
- 接口契约（以用户附件 OpenAPI 为准）：`/api/v1/series/letters` 返回 `data.letters[]`（`id/letter/type/description/videos_count/views_count`）；`/api/v1/series` 返回 `data.series[]`（`id/type/name/videos_count`），`type` 必填且为字符串 `0/1/2/4`（有码/无码/欧美/动漫）。
- 两个接口示例均无 `total_pages`/`total`：沿用 `TagMoviesService` 启发式——返回条数满 `limit` 推断还有下一页，否则到底。每页 `limit = 48`。
- 列表条目：名称（番号 Tab 用 `letter`）+ 括号数量；番号 Tab 额外副标题展示 `description`。
- 点击跳转：系列 → `CommonListPage(category: 's')`；番号 → `CommonListPage(category: 'c')`；标题格式 `'系列 - 名称'` / `'番号 - 字母'`。
- 不做：系列详情页、片商/导演占位页改造、下拉刷新。

---

### Task 1: 提升 EntityListTile 到 core（新增可选 subtitle）

**Files:**
- Create: `lib/core/widgets/entity_list_tile.dart`
- Create (move): `test/core/widgets/entity_list_tile_test.dart`
- Modify: `lib/features/search/screens/search_results_screen.dart`（4 处引用 + import）
- Modify: `test/features/search/search_screen_test.dart`（import + 5 处 `SearchEntityListTile` 引用）
- Delete: `lib/features/search/widgets/search_entity_list_tile.dart`
- Delete: `test/features/search/search_entity_list_tile_test.dart`

**Interfaces:**
- Produces: `EntityListTile` 构造参数 `{Key? key, required String name, required int count, required VoidCallback onTap, String? subtitle}`。后续 Task 4 的番号 Tab 传 `subtitle`。

- [ ] **Step 1: 创建共享组件并迁移测试（先写测试）**

创建 `test/core/widgets/entity_list_tile_test.dart`（内容为原 `test/features/search/search_entity_list_tile_test.dart` 全文，仅替换 import 为 `package:jade/core/widgets/entity_list_tile.dart`、类名为 `EntityListTile`），并追加一个副标题用例：

```dart
testWidgets('可选副标题渲染在名称下方', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: EntityListTile(
          name: 'IPX',
          count: 998,
          subtitle: 'IdeaPocket美少女夢工廠',
          onTap: () {},
        ),
      ),
    ),
  );

  expect(find.text('IPX'), findsOneWidget);
  expect(find.text('(998)'), findsOneWidget);
  expect(find.text('IdeaPocket美少女夢工廠'), findsOneWidget);
});
```

- [ ] **Step 2: 运行新测试确认失败**

Run: `flutter test test/core/widgets/entity_list_tile_test.dart`
Expected: FAIL（`EntityListTile` 未定义）

- [ ] **Step 3: 创建共享组件实现**

创建 `lib/core/widgets/entity_list_tile.dart`：

```dart
import 'package:flutter/material.dart';

class EntityListTile extends StatelessWidget {
  const EntityListTile({
    super.key,
    required this.name,
    required this.count,
    required this.onTap,
    this.subtitle,
  });

  final String name;
  final int count;
  final VoidCallback onTap;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, overflow: TextOverflow.ellipsis),
                    if (subtitle case final subtitle?) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '($count)',
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: 更新 search 引用并删除旧文件**

在 `lib/features/search/screens/search_results_screen.dart`：
- 删除 `import 'package:jade/features/search/widgets/search_entity_list_tile.dart';`
- 新增 `import 'package:jade/core/widgets/entity_list_tile.dart';`
- 4 处 `SearchEntityListTile(` 改为 `EntityListTile(`（约第 152/172/192/232 行）。

在 `test/features/search/search_screen_test.dart`：
- import 改为 `package:jade/core/widgets/entity_list_tile.dart`
- 第 437 行 `find.byType(SearchEntityListTile)` → `find.byType(EntityListTile)`
- 第 478/479/480/482 行 `rowType: SearchEntityListTile` → `rowType: EntityListTile`

删除 `lib/features/search/widgets/search_entity_list_tile.dart` 与
`test/features/search/search_entity_list_tile_test.dart`。

- [ ] **Step 5: 运行相关测试确认通过**

Run: `flutter test test/core/widgets/entity_list_tile_test.dart test/features/search/search_screen_test.dart`
Expected: PASS

- [ ] **Step 6: 提交**

```bash
git add lib/core/widgets/entity_list_tile.dart test/core/widgets/entity_list_tile_test.dart lib/features/search test/features/search
git commit -m "feat(widgets): promote EntityListTile to core with optional subtitle"
```

---

### Task 2: 提升 PaginatedListView 到 core

**Files:**
- Create: `lib/core/widgets/paginated_list_view.dart`
- Create (move): `test/core/widgets/paginated_list_view_test.dart`
- Modify: `lib/features/search/screens/search_results_screen.dart`（import + 1 处引用）
- Delete: `lib/features/search/widgets/search_paginated_list_view.dart`
- Delete: `test/features/search/search_paginated_list_view_test.dart`

**Interfaces:**
- Produces: `PaginatedListView<T>` 构造参数 `{Key? key, required PaginationController<T> controller, required Widget Function(BuildContext, T) itemBuilder, required String emptyMessage}`。Task 4 的每个系列 Tab 复用它。

- [ ] **Step 1: 迁移测试**

创建 `test/core/widgets/paginated_list_view_test.dart`（内容为原 `test/features/search/search_paginated_list_view_test.dart` 全文，仅替换 import 为 `package:jade/core/widgets/paginated_list_view.dart`、类名为 `PaginatedListView`）。

- [ ] **Step 2: 运行新测试确认失败**

Run: `flutter test test/core/widgets/paginated_list_view_test.dart`
Expected: FAIL（`PaginatedListView` 未定义）

- [ ] **Step 3: 创建共享组件实现**

创建 `lib/core/widgets/paginated_list_view.dart`（内容为原
`lib/features/search/widgets/search_paginated_list_view.dart` 全文，仅类名改为
`PaginatedListView`，import 不变——它只依赖 core 组件）。

- [ ] **Step 4: 更新 search 引用并删除旧文件**

在 `lib/features/search/screens/search_results_screen.dart`：
- 删除 `import 'package:jade/features/search/widgets/search_paginated_list_view.dart';`
- 新增 `import 'package:jade/core/widgets/paginated_list_view.dart';`
- 第 301 行 `SearchPaginatedListView<T>(` → `PaginatedListView<T>(`

删除 `lib/features/search/widgets/search_paginated_list_view.dart` 与
`test/features/search/search_paginated_list_view_test.dart`。

- [ ] **Step 5: 运行相关测试确认通过**

Run: `flutter test test/core/widgets/paginated_list_view_test.dart test/features/search/search_screen_test.dart`
Expected: PASS

- [ ] **Step 6: 提交**

```bash
git add lib/core/widgets/paginated_list_view.dart test/core/widgets/paginated_list_view_test.dart lib/features/search test/features/search
git commit -m "feat(widgets): promote PaginatedListView to core"
```

---

### Task 3: series feature 数据层（endpoint + 模型 + 服务）

**Files:**
- Modify: `lib/core/network/endpoints.dart:59`（新增 seriesLetters）
- Create: `lib/features/series/models/series_letter.dart`
- Create: `lib/features/series/services/series_service.dart`
- Create: `test/features/series/series_service_test.dart`

**Interfaces:**
- Consumes: `Endpoints.series`（已有）、`ApiClient.get(path, {queryParameters})`、`apiMap`/`apiList`/`apiInt`/`apiString`、`Series.fromJson`（core，键名 `movie_count`）、`PagedResult<T>`。
- Produces: `SeriesDataSource` 抽象：`Future<PagedResult<SeriesLetter>> getLetters({int page = 1, int limit = 48})`、`Future<PagedResult<Series>> getSeries({required String type, int page = 1, int limit = 48})`；`SeriesService implements SeriesDataSource`；`UnavailableSeriesDataSource implements SeriesDataSource`（const，返回空页）。`SeriesLetter` 字段：`id/letter/description(String?)/videosCount/viewsCount/type`，`factory fromJson`。

- [ ] **Step 1: 新增 endpoint**

在 `lib/core/network/endpoints.dart` 的「导演/片商/系列/番号」区块（`series` 附近）新增：

```dart
  static const String seriesLetters = '/api/v1/series/letters';
```

- [ ] **Step 2: 写服务测试（先失败）**

创建 `test/features/series/series_service_test.dart`：

```dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/domain_manager.dart';
import 'package:jade/core/network/endpoints.dart';
import 'package:jade/core/network/interceptors/response_interceptor.dart';
import 'package:jade/core/network/testing/fake_adapter.dart';
import 'package:jade/features/series/services/series_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('getLetters 请求 page limit 并解析 description 与数量', () async {
    final fixture = await buildSeriesFixture();
    fixture.adapter.enqueue(Endpoints.seriesLetters, {
      'success': 1,
      'data': {
        'letters': [
          {
            'id': 'IPX',
            'letter': 'IPX',
            'type': 0,
            'description': 'IdeaPocket美少女夢工廠',
            'videos_count': 998,
            'views_count': 3593620,
          },
        ],
        'current_page': 1,
      },
    });

    final result = await fixture.service.getLetters();

    expect(result.items.single.id, 'IPX');
    expect(result.items.single.letter, 'IPX');
    expect(result.items.single.description, 'IdeaPocket美少女夢工廠');
    expect(result.items.single.videosCount, 998);
    expect(result.items.single.viewsCount, 3593620);
    expect(result.items.single.type, 0);
    expect(fixture.adapter.requests.single.queryParameters, {
      'page': 1,
      'limit': 48,
    });
  });

  test('getSeries 请求 type page limit 并把 videos_count 映射为 movieCount', () async {
    final fixture = await buildSeriesFixture();
    fixture.adapter.enqueue(Endpoints.series, {
      'success': 1,
      'data': {
        'series': [
          {'id': 'rY2v', 'type': 0, 'name': '测试系列', 'videos_count': 1100},
        ],
        'current_page': 1,
      },
    });

    final result = await fixture.service.getSeries(type: '0', page: 2);

    expect(result.items.single.id, 'rY2v');
    expect(result.items.single.name, '测试系列');
    expect(result.items.single.movieCount, 1100);
    expect(result.items.single.type, 0);
    expect(fixture.adapter.requests.single.queryParameters, {
      'type': '0',
      'page': 2,
      'limit': 48,
    });
  });

  test('缺少 total_pages 时满 48 条允许下一页，少于 48 条停止', () async {
    final fixture = await buildSeriesFixture();
    fixture.adapter.enqueueSequence(Endpoints.series, [
      {
        'success': 1,
        'data': {
          'series': [
            for (var i = 0; i < 48; i++)
              {'id': 's$i', 'type': 0, 'name': 'S$i', 'videos_count': 1},
          ],
          'current_page': 1,
        },
      },
      {
        'success': 1,
        'data': {
          'series': [
            {'id': 's48', 'type': 0, 'name': 'S48', 'videos_count': 1},
          ],
          'current_page': 2,
        },
      },
    ]);

    final full = await fixture.service.getSeries(type: '0');
    final partial = await fixture.service.getSeries(type: '0', page: 2);

    expect(full.totalPages, 2);
    expect(partial.totalPages, 2);
  });
}

Future<({FakeAdapter adapter, SeriesService service})> buildSeriesFixture() async {
  final preferences = await SharedPreferences.getInstance();
  final domainManager = await DomainManager.load(preferences);
  final adapter = FakeAdapter();
  final dio = Dio(BaseOptions(baseUrl: domainManager.currentUrl))
    ..httpClientAdapter = adapter
    ..interceptors.add(ResponseInterceptor(onAuthError: () {}));
  final api = ApiClient.forTest(dio: dio, domainManager: domainManager);
  return (adapter: adapter, service: SeriesService(api));
}
```

- [ ] **Step 3: 运行测试确认失败**

Run: `flutter test test/features/series/series_service_test.dart`
Expected: FAIL（`SeriesService`/`SeriesLetter` 未定义）

- [ ] **Step 4: 创建模型**

创建 `lib/features/series/models/series_letter.dart`：

```dart
import 'package:jade/core/network/api_data.dart';

class SeriesLetter {
  const SeriesLetter({
    required this.id,
    required this.letter,
    this.description,
    this.videosCount = 0,
    this.viewsCount = 0,
    this.type = 0,
  });

  final String id;
  final String letter;
  final String? description;
  final int videosCount;
  final int viewsCount;
  final int type;

  factory SeriesLetter.fromJson(Map<String, dynamic> json) => SeriesLetter(
    id: apiString(json['id']) ?? apiString(json['letter']) ?? '',
    letter: apiString(json['letter']) ?? apiString(json['id']) ?? '',
    description: apiString(json['description']),
    videosCount: apiInt(json['videos_count'], 0),
    viewsCount: apiInt(json['views_count'], 0),
    type: apiInt(json['type'], 0),
  );
}
```

- [ ] **Step 5: 创建服务**

创建 `lib/features/series/services/series_service.dart`：

```dart
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/core/models/series.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/api_data.dart';
import 'package:jade/core/network/endpoints.dart';
import 'package:jade/features/series/models/series_letter.dart';

abstract interface class SeriesDataSource {
  Future<PagedResult<SeriesLetter>> getLetters({
    int page = 1,
    int limit = 48,
  });

  Future<PagedResult<Series>> getSeries({
    required String type,
    int page = 1,
    int limit = 48,
  });
}

class SeriesService implements SeriesDataSource {
  SeriesService(this._api);

  final ApiClient _api;

  @override
  Future<PagedResult<SeriesLetter>> getLetters({
    int page = 1,
    int limit = 48,
  }) async {
    final response = await _api.get(
      Endpoints.seriesLetters,
      queryParameters: {'page': page, 'limit': limit},
    );
    return _parsePage(
      response.data,
      key: 'letters',
      fallbackPage: page,
      limit: limit,
      fromJson: SeriesLetter.fromJson,
    );
  }

  @override
  Future<PagedResult<Series>> getSeries({
    required String type,
    int page = 1,
    int limit = 48,
  }) async {
    final response = await _api.get(
      Endpoints.series,
      queryParameters: {'type': type, 'page': page, 'limit': limit},
    );
    return _parsePage(
      response.data,
      key: 'series',
      fallbackPage: page,
      limit: limit,
      fromJson: (json) => Series.fromJson(_seriesJson(json)),
    );
  }

  PagedResult<T> _parsePage<T>(
    dynamic data, {
    required String key,
    required int fallbackPage,
    required int limit,
    required T Function(Map<String, dynamic>) fromJson,
  }) {
    final map = apiMap(data);
    final items = apiList(map, [key]).map(fromJson).toList(growable: false);
    final currentPage = apiInt(map['current_page'], fallbackPage);
    final totalPages = map['total_pages'] == null
        ? currentPage + (items.length >= limit ? 1 : 0)
        : apiInt(map['total_pages'], currentPage);
    return PagedResult(
      items: items,
      currentPage: currentPage,
      totalPages: totalPages,
      total: apiInt(map['total_count'] ?? map['total'], items.length),
    );
  }
}

Map<String, dynamic> _seriesJson(Map<String, dynamic> json) => {
  ...json,
  'id': apiString(json['id']) ?? '',
  'name': apiString(json['name']) ?? '',
  'type': apiInt(json['type'], 0),
  'movie_count': apiInt(
    json['movie_count'] ?? json['movies_count'] ?? json['videos_count'],
    0,
  ),
};

class UnavailableSeriesDataSource implements SeriesDataSource {
  const UnavailableSeriesDataSource();

  Future<PagedResult<T>> _empty<T>(int page) async => PagedResult(
    items: const [],
    currentPage: page,
    totalPages: page,
    total: 0,
  );

  @override
  Future<PagedResult<SeriesLetter>> getLetters({
    int page = 1,
    int limit = 48,
  }) => _empty(page);

  @override
  Future<PagedResult<Series>> getSeries({
    required String type,
    int page = 1,
    int limit = 48,
  }) => _empty(page);
}
```

- [ ] **Step 6: 运行测试确认通过**

Run: `flutter test test/features/series/series_service_test.dart`
Expected: PASS

- [ ] **Step 7: 提交**

```bash
git add lib/core/network/endpoints.dart lib/features/series test/features/series/series_service_test.dart
git commit -m "feat(series): add letters/list service with series letter model"
```

---

### Task 4: SeriesPage + index + 路由接入

**Files:**
- Create: `lib/features/series/screens/series_page.dart`
- Create: `lib/features/series/index.dart`
- Modify: `lib/core/router/app_router.dart:189-190`（替换 `/series` 占位页）+ import
- Create: `test/features/series/series_page_test.dart`

**Interfaces:**
- Consumes: `SeriesDataSource`（Task 3）、`EntityListTile`（Task 1）、`PaginatedListView`（Task 2）、`PaginationController<T>`、`CommonListPage`（`lib/features/common/screens/common_list_page.dart`）。
- Produces: `SeriesPage` 构造参数 `{Key? key, SeriesDataSource? dataSource}`（测试注入用）。

- [ ] **Step 1: 写页面测试（先失败）**

创建 `test/features/series/series_page_test.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/core/models/series.dart';
import 'package:jade/core/widgets/entity_list_tile.dart';
import 'package:jade/features/series/models/series_letter.dart';
import 'package:jade/features/series/screens/series_page.dart';
import 'package:jade/features/series/services/series_service.dart';

void main() {
  testWidgets('渲染 5 个 Tab，番号 Tab 展示字母、数量与 description 副标题', (tester) async {
    final source = _RecordingSeriesDataSource();
    await tester.pumpWidget(
      MaterialApp(home: SeriesPage(dataSource: source)),
    );
    await tester.pumpAndSettle();

    for (final tab in ['番号', '有码', '无码', '欧美', '动漫']) {
      expect(find.text(tab), findsOneWidget);
    }
    expect(find.text('IPX'), findsOneWidget);
    expect(find.text('(998)'), findsOneWidget);
    expect(find.text('IdeaPocket美少女夢工廠'), findsOneWidget);
    expect(source.lettersCalls, [1]);
    expect(source.seriesCalls, isEmpty);
  });

  testWidgets('切换到有码 Tab 触发 getSeries(type=0)', (tester) async {
    final source = _RecordingSeriesDataSource();
    await tester.pumpWidget(
      MaterialApp(home: SeriesPage(dataSource: source)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('有码'));
    await tester.pumpAndSettle();

    expect(source.seriesCalls, [(type: '0', page: 1)]);
    expect(find.text('测试系列'), findsOneWidget);
    expect(find.text('(1100)'), findsOneWidget);
  });

  testWidgets('点击系列条目进入 CommonListPage，番号条目进入番号公共页', (tester) async {
    final source = _RecordingSeriesDataSource();
    await tester.pumpWidget(
      MaterialApp(home: SeriesPage(dataSource: source)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('IPX'));
    await tester.pumpAndSettle();
    expect(find.text('番号 - IPX'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('有码'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('测试系列'));
    await tester.pumpAndSettle();
    expect(find.text('系列 - 测试系列'), findsOneWidget);
  });
}

class _RecordingSeriesDataSource implements SeriesDataSource {
  final lettersCalls = <int>[];
  final seriesCalls = <({String type, int page})>[];

  @override
  Future<PagedResult<SeriesLetter>> getLetters({
    int page = 1,
    int limit = 48,
  }) async {
    lettersCalls.add(page);
    return PagedResult(
      items: [
        SeriesLetter(
          id: 'IPX',
          letter: 'IPX',
          description: 'IdeaPocket美少女夢工廠',
          videosCount: 998,
          viewsCount: 3593620,
          type: 0,
        ),
      ],
      currentPage: page,
      totalPages: page,
      total: 1,
    );
  }

  @override
  Future<PagedResult<Series>> getSeries({
    required String type,
    int page = 1,
    int limit = 48,
  }) async {
    seriesCalls.add((type: type, page: page));
    return PagedResult(
      items: [
        Series(
          id: 'rY2v',
          name: '测试系列',
          movieCount: 1100,
          type: int.parse(type),
        ),
      ],
      currentPage: page,
      totalPages: page,
      total: 1,
    );
  }
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/features/series/series_page_test.dart`
Expected: FAIL（`SeriesPage` 未定义）

- [ ] **Step 3: 创建页面**

创建 `lib/features/series/screens/series_page.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/core/models/series.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/widgets/entity_list_tile.dart';
import 'package:jade/core/widgets/paginated_list_view.dart';
import 'package:jade/core/widgets/pagination_controller.dart';
import 'package:jade/features/common/screens/common_list_page.dart';
import 'package:jade/features/series/models/series_letter.dart';
import 'package:jade/features/series/services/series_service.dart';

class SeriesPage extends StatefulWidget {
  const SeriesPage({super.key, this.dataSource});

  final SeriesDataSource? dataSource;

  @override
  State<SeriesPage> createState() => _SeriesPageState();
}

class _SeriesPageState extends State<SeriesPage>
    with TickerProviderStateMixin {
  static const tabs = ['番号', '有码', '无码', '欧美', '动漫'];
  static const types = ['0', '1', '2', '4'];

  late final TabController _tabController;
  late final SeriesDataSource _dataSource;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: tabs.length, vsync: this);
    _dataSource =
        widget.dataSource ??
        switch (ApiClient.instanceOrNull) {
          final api? => SeriesService(api),
          null => const UnavailableSeriesDataSource(),
        };
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('系列'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: [for (final tab in tabs) Tab(text: tab)],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _SeriesTab<SeriesLetter>(
            fetchPage: (page) => _dataSource.getLetters(page: page),
            emptyMessage: '暂无番号',
            itemBuilder: (context, item) => EntityListTile(
              name: item.letter,
              count: item.videosCount,
              subtitle: item.description,
              onTap: () => _openCommonList(
                context,
                '番号',
                item.letter,
                item.type,
                'c',
                item.id,
              ),
            ),
          ),
          for (final type in types)
            _SeriesTab<Series>(
              fetchPage: (page) =>
                  _dataSource.getSeries(type: type, page: page),
              emptyMessage: '暂无系列',
              itemBuilder: (context, item) => EntityListTile(
                name: item.name,
                count: item.movieCount,
                onTap: () => _openCommonList(
                  context,
                  '系列',
                  item.name,
                  item.type,
                  's',
                  item.id,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SeriesTab<T> extends StatefulWidget {
  const _SeriesTab({
    required this.fetchPage,
    required this.itemBuilder,
    required this.emptyMessage,
  });

  final Future<PagedResult<T>> Function(int page) fetchPage;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final String emptyMessage;

  @override
  State<_SeriesTab<T>> createState() => _SeriesTabState<T>();
}

class _SeriesTabState<T> extends State<_SeriesTab<T>>
    with AutomaticKeepAliveClientMixin {
  late final PaginationController<T> _controller;

  @override
  void initState() {
    super.initState();
    _controller = PaginationController<T>(fetch: widget.fetchPage)..fetchMore();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return PaginatedListView<T>(
      controller: _controller,
      itemBuilder: widget.itemBuilder,
      emptyMessage: widget.emptyMessage,
    );
  }
}

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

- [ ] **Step 4: 创建 index 并接入路由**

创建 `lib/features/series/index.dart`：

```dart
export 'screens/series_page.dart';
```

在 `lib/core/router/app_router.dart`：
- import 区块新增 `import 'package:jade/features/series/index.dart';`
- 将 `/series` 路由的 builder 从 `const _SimpleListPage(title: '系列')` 改为 `const SeriesPage()`：

```dart
    GoRoute(
      path: AppRoutes.series,
      builder: (c, s) => const SeriesPage(),
    ),
```

- [ ] **Step 5: 运行测试确认通过**

Run: `flutter test test/features/series/series_page_test.dart`
Expected: PASS

- [ ] **Step 6: 提交**

```bash
git add lib/features/series lib/core/router/app_router.dart test/features/series/series_page_test.dart
git commit -m "feat(series): add series page with five tabs wired to /series"
```

---

### Task 5: 全量验证

**Files:** 无新增；可能修复前序任务遗漏。

- [ ] **Step 1: 静态分析**

Run: `flutter analyze`
Expected: No issues found（若命中前序遗漏问题，就地修复后重跑）

- [ ] **Step 2: 全量测试**

Run: `flutter test`
Expected: All tests passed（关注 search 与 series 相关用例）

- [ ] **Step 3: 抽查路由冒烟（可选）**

Run: `flutter test test/features/search/search_screen_test.dart test/features/series/series_page_test.dart`
Expected: PASS

- [ ] **Step 4: 若有修复则提交**

```bash
git add -A
git commit -m "fix(series): resolve analyze or test failures"
```
（无修复则跳过本步）
