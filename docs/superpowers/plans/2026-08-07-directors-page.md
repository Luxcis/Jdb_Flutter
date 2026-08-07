# 导演页 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 实现首页「导演」豆腐块对应的真实导演页面：2 个 Tab（有码/欧美）分页调用 `/api/v1/directors`，列表展示与搜索结果导演 Tab 一致。

**Architecture:** Feature-First。新建 `lib/features/directors/`（screens/services/index），页面结构完全复刻已上线的 `MakersPage`（TabController + 每 Tab 独立 `PaginationController` + `PaginatedListView` + `EntityListTile`）。共享归一化 `normalizeDirectorJson` 加入 `lib/core/network/api_data.dart`，路由 `/directors` 从占位页 `_SimpleListPage` 替换为 `DirectorsPage`。

**Tech Stack:** Flutter / Dart，go_router，Dio，provider，json_annotation。测试用 `flutter_test` + 项目自有 `FakeAdapter`。

## Global Constraints

- 文案全部中文硬编码，不使用 ARB/l10n（RULES.md）。
- Feature-First 结构：新增文件只放 `screens/`、`services/`、`index.dart`；feature 之间不互相依赖，只依赖 `lib/core`。
- 每个 feature 必须有 `index.dart` 作为入口，仅导出路由需要的 Page。
- `/api/v1/directors` 参数：`type` 必填 string（0=有码、2=欧美），`page` 从 1 开始，`limit` 固定 48（APK 行为）。
- 响应 `data.directors[]` + `current_page`；条目字段 `videos_count` 需映射为 `Director.movieCount`。
- 响应无 `total_pages`/`total` 时用 `apiPageResult` 启发式：满 48 条推断还有下一页。
- 条目点击进入 `CommonListPage(title: '导演 - $name', type, category: 'd', id)`，与搜索结果一致。
- 不引入下拉刷新、不新建导演详情页、不加搜索框/筛选。
- 不重构 MakersPage/SeriesPage；首页豆腐块不改（`/directors` 入口已存在）。
- 单条提交：每个任务独立 commit，commit message 遵循仓库 `feat(scope): 描述` 风格。

### Task 1: 共享归一化 normalizeDirectorJson

**Files:**
- Modify: `lib/core/network/api_data.dart`（在 `normalizeMakerJson` 之后新增 `normalizeDirectorJson`）
- Modify: `lib/features/search/services/search_entity_service.dart:102-111`（`getDirectors` 改用 `normalizeDirectorJson`）
- Test: `test/core/network/api_data_test.dart`（新增 2 个用例）

**Interfaces:**
- Consumes: `apiString`、`apiInt`（`lib/core/network/api_data.dart` 内已有），`Director`（`lib/core/models/director.dart`）。
- Produces: `Map<String, dynamic> normalizeDirectorJson(Map<String, dynamic> json)` —— 把 `videos_count`/`movies_count` 映射为 `movie_count`，兜底 `id`/`name`/`type`。供 Task 2 的 `DirectorService` 与 Task 1 的 `SearchEntityService.getDirectors` 使用。

- [ ] **Step 1: 写失败测试**

在 `test/core/network/api_data_test.dart` 的 `main()` 内（`normalizeMakerJson` 用例之后）追加：

```dart
  test('normalizeDirectorJson 将 videos_count 映射为 movieCount 并保留 type', () {
    final director = Director.fromJson(
      normalizeDirectorJson({
        'id': 'AqK',
        'type': '0',
        'name': 'K太郎',
        'videos_count': 3122,
      }),
    );

    expect(director.id, 'AqK');
    expect(director.name, 'K太郎');
    expect(director.type, 0);
    expect(director.movieCount, 3122);
  });

  test('normalizeDirectorJson 为缺失字段提供兜底值', () {
    final director = Director.fromJson(normalizeDirectorJson({'id': null}));

    expect(director.id, '');
    expect(director.name, '');
    expect(director.type, 0);
    expect(director.movieCount, 0);
  });
```

并在文件头部 import 区加 `import 'package:jade/core/models/director.dart';`。

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/core/network/api_data_test.dart`
Expected: 编译失败（`normalizeDirectorJson` 未定义）。

- [ ] **Step 3: 实现归一化函数**

在 `lib/core/network/api_data.dart` 的 `normalizeMakerJson` 之后新增：

```dart
Map<String, dynamic> normalizeDirectorJson(Map<String, dynamic> json) => {
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

同时修改 `lib/features/search/services/search_entity_service.dart` 的 `getDirectors`：

```dart
  @override
  Future<PagedResult<Director>> getDirectors({
    required String query,
    int page = 1,
  }) => _getPage(
    query: query,
    type: 'director',
    collectionKey: 'directors',
    page: page,
    fromJson: (json) => Director.fromJson(normalizeDirectorJson(json)),
  );
```

并确认该文件已 import `package:jade/core/network/api_data.dart`（已有，`_namedEntityJson` 依赖它）。

- [ ] **Step 4: 运行测试确认通过**

Run: `flutter test test/core/network/api_data_test.dart test/features/search/search_entity_service_test.dart`
Expected: 全部 PASS。

- [ ] **Step 5: 提交**

```bash
git add lib/core/network/api_data.dart lib/features/search/services/search_entity_service.dart test/core/network/api_data_test.dart
git commit -m "feat(network): add shared normalizeDirectorJson mapping for directors"
```

### Task 2: DirectorService

**Files:**
- Create: `lib/features/directors/services/director_service.dart`
- Test: `test/features/directors/director_service_test.dart`

**Interfaces:**
- Consumes: `Director`（`lib/core/models/director.dart`）、`PagedResult`（`lib/core/models/paged_result.dart`）、`ApiClient`（`lib/core/network/api_client.dart`）、`apiPageResult` + `normalizeDirectorJson`（`lib/core/network/api_data.dart`）、`Endpoints.directors`（`lib/core/network/endpoints.dart`，值 `/api/v1/directors`，已存在）。
- Produces: `abstract interface class DirectorDataSource`（`Future<PagedResult<Director>> getDirectors({required int type, int page = 1, int limit = 48})`）、`class DirectorService implements DirectorDataSource`、`class UnavailableDirectorDataSource implements DirectorDataSource`。供 Task 3 的 `DirectorsPage` 注入。

- [ ] **Step 1: 写失败测试**

新建 `test/features/directors/director_service_test.dart`：

```dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/domain_manager.dart';
import 'package:jade/core/network/endpoints.dart';
import 'package:jade/core/network/interceptors/response_interceptor.dart';
import 'package:jade/core/network/testing/fake_adapter.dart';
import 'package:jade/features/directors/services/director_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('getDirectors 发送 type page limit 并解析 videos_count 为 movieCount', () async {
    final fixture = await buildDirectorFixture();
    fixture.adapter.enqueue(Endpoints.directors, {
      'success': 1,
      'data': {
        'directors': [
          {'id': 'AqK', 'type': '0', 'name': 'K太郎', 'videos_count': 3122},
        ],
        'current_page': 1,
      },
    });

    final result = await fixture.service.getDirectors(type: 0, page: 1);

    expect(result.items.single.id, 'AqK');
    expect(result.items.single.name, 'K太郎');
    expect(result.items.single.type, 0);
    expect(result.items.single.movieCount, 3122);
    expect(fixture.adapter.requests.single.queryParameters, {
      'type': '0',
      'page': 1,
      'limit': 48,
    });
  });

  test('缺少 total_pages 时满 48 条允许下一页，少于 48 条停止', () async {
    final fixture = await buildDirectorFixture();
    fixture.adapter.enqueueSequence(Endpoints.directors, [
      directorResponse(48),
      directorResponse(47),
    ]);

    final full = await fixture.service.getDirectors(type: 0);
    final partial = await fixture.service.getDirectors(type: 0);

    expect(full.totalPages, 2);
    expect(partial.totalPages, 1);
  });
}

Future<({FakeAdapter adapter, DirectorService service})> buildDirectorFixture() async {
  final preferences = await SharedPreferences.getInstance();
  final domainManager = await DomainManager.load(preferences);
  final adapter = FakeAdapter();
  final dio = Dio(BaseOptions(baseUrl: domainManager.currentUrl))
    ..httpClientAdapter = adapter
    ..interceptors.add(ResponseInterceptor(onAuthError: () {}));
  final api = ApiClient.forTest(dio: dio, domainManager: domainManager);
  return (adapter: adapter, service: DirectorService(api));
}

Map<String, dynamic> directorResponse(int count) => {
  'success': 1,
  'data': {
    'directors': [
      for (var index = 0; index < count; index++)
        {'id': 'd$index', 'type': '0', 'name': '导演$index', 'videos_count': index},
    ],
    'current_page': 1,
  },
};
```

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/features/directors/director_service_test.dart`
Expected: 编译失败（`director_service.dart` 不存在）。

- [ ] **Step 3: 实现服务**

新建 `lib/features/directors/services/director_service.dart`：

```dart
import 'package:jade/core/models/director.dart';
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/api_data.dart';
import 'package:jade/core/network/endpoints.dart';

abstract interface class DirectorDataSource {
  Future<PagedResult<Director>> getDirectors({
    required int type,
    int page = 1,
    int limit = 48,
  });
}

class DirectorService implements DirectorDataSource {
  DirectorService(this._api);

  final ApiClient _api;

  @override
  Future<PagedResult<Director>> getDirectors({
    required int type,
    int page = 1,
    int limit = 48,
  }) async {
    final response = await _api.get(
      Endpoints.directors,
      queryParameters: {'type': '$type', 'page': page, 'limit': limit},
    );
    return apiPageResult(
      response.data,
      keys: ['directors'],
      page: page,
      pageSize: limit,
      fromJson: (json) => Director.fromJson(normalizeDirectorJson(json)),
    );
  }
}

class UnavailableDirectorDataSource implements DirectorDataSource {
  const UnavailableDirectorDataSource();

  @override
  Future<PagedResult<Director>> getDirectors({
    required int type,
    int page = 1,
    int limit = 48,
  }) async => PagedResult(
    items: const [],
    currentPage: page,
    totalPages: page,
    total: 0,
  );
}
```

- [ ] **Step 4: 运行测试确认通过**

Run: `flutter test test/features/directors/director_service_test.dart`
Expected: 全部 PASS。

- [ ] **Step 5: 提交**

```bash
git add lib/features/directors/services/director_service.dart test/features/directors/director_service_test.dart
git commit -m "feat(directors): add director list service with type pagination"
```

### Task 3: DirectorsPage + index

**Files:**
- Create: `lib/features/directors/screens/directors_page.dart`
- Create: `lib/features/directors/index.dart`
- Test: `test/features/directors/directors_page_test.dart`

**Interfaces:**
- Consumes: `DirectorDataSource`/`UnavailableDirectorDataSource`（Task 2）、`Director`、`PagedResult`、`ApiClient.instanceOrNull`、`EntityListTile`、`PaginatedListView`、`PaginationController`、`CommonListPage`（`lib/features/common/screens/common_list_page.dart`）。
- Produces: `class DirectorsPage extends StatefulWidget`，构造参数 `const DirectorsPage({super.key, this.dataSource})`，`final DirectorDataSource? dataSource;`。供 Task 4 路由使用。

- [ ] **Step 1: 写失败测试**

新建 `test/features/directors/directors_page_test.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/models/director.dart';
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/core/widgets/movie_grid_view.dart';
import 'package:jade/features/common/screens/common_list_page.dart';
import 'package:jade/features/directors/screens/directors_page.dart';
import 'package:jade/features/directors/services/director_service.dart';

void main() {
  testWidgets('渲染 2 个 Tab，默认加载有码 type=0', (tester) async {
    final source = _RecordingDirectorDataSource();
    await tester.pumpWidget(MaterialApp(home: DirectorsPage(dataSource: source)));
    await tester.pumpAndSettle();

    for (final tab in ['有码', '欧美']) {
      expect(find.text(tab), findsOneWidget);
    }
    expect(find.text('K太郎'), findsOneWidget);
    expect(find.text('(3122)'), findsOneWidget);
    expect(source.calls, [(type: 0, page: 1)]);
  });

  testWidgets('切换到欧美 Tab 触发 getDirectors(type=2)', (tester) async {
    final source = _RecordingDirectorDataSource();
    await tester.pumpWidget(MaterialApp(home: DirectorsPage(dataSource: source)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('欧美'));
    await tester.pumpAndSettle();

    expect(source.calls, [(type: 0, page: 1), (type: 2, page: 1)]);
  });

  testWidgets('切回 Tab 保留列表状态，不重复请求', (tester) async {
    final source = _RecordingDirectorDataSource();
    await tester.pumpWidget(MaterialApp(home: DirectorsPage(dataSource: source)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('欧美'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('有码'));
    await tester.pumpAndSettle();

    expect(source.calls, [(type: 0, page: 1), (type: 2, page: 1)]);
  });

  testWidgets('点击导演条目进入与搜索结果一致的 CommonListPage', (tester) async {
    final source = _RecordingDirectorDataSource();
    await tester.pumpWidget(MaterialApp(home: DirectorsPage(dataSource: source)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('K太郎'));
    await tester.pumpAndSettle();

    final page = tester.widget<CommonListPage>(find.byType(CommonListPage));
    expect(page.title, '导演 - K太郎');
    expect(page.type, 0);
    expect(page.category, 'd');
    expect(page.id, 'AqK');
    expect(find.byKey(const Key('common-list-filter')), findsOneWidget);
    expect(find.byKey(const Key('common-list-sort')), findsOneWidget);
    expect(find.byType(MovieGridView), findsOneWidget);
  });
}

class _RecordingDirectorDataSource implements DirectorDataSource {
  final calls = <({int type, int page})>[];

  @override
  Future<PagedResult<Director>> getDirectors({
    required int type,
    int page = 1,
    int limit = 48,
  }) async {
    calls.add((type: type, page: page));
    return PagedResult(
      items: [
        Director(id: 'AqK', name: 'K太郎', movieCount: 3122, type: type),
      ],
      currentPage: page,
      totalPages: page,
      total: 1,
    );
  }
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/features/directors/directors_page_test.dart`
Expected: 编译失败（`directors_page.dart` 不存在）。

- [ ] **Step 3: 实现页面**

新建 `lib/features/directors/screens/directors_page.dart`（完整复刻 `MakersPage` 结构，仅 Tab/类型/标题/集合键不同）：

```dart
import 'package:flutter/material.dart';
import 'package:jade/core/models/director.dart';
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/widgets/entity_list_tile.dart';
import 'package:jade/core/widgets/paginated_list_view.dart';
import 'package:jade/core/widgets/pagination_controller.dart';
import 'package:jade/features/common/screens/common_list_page.dart';
import 'package:jade/features/directors/services/director_service.dart';

class DirectorsPage extends StatefulWidget {
  const DirectorsPage({super.key, this.dataSource});

  final DirectorDataSource? dataSource;

  @override
  State<DirectorsPage> createState() => _DirectorsPageState();
}

class _DirectorsPageState extends State<DirectorsPage>
    with TickerProviderStateMixin {
  static const tabs = ['有码', '欧美'];
  static const types = ['0', '2'];

  late final TabController _tabController;
  late final DirectorDataSource _dataSource;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: tabs.length, vsync: this);
    _dataSource =
        widget.dataSource ??
        switch (ApiClient.instanceOrNull) {
          final api? => DirectorService(api),
          null => const UnavailableDirectorDataSource(),
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
        title: const Text('导演'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: [for (final tab in tabs) Tab(text: tab)],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          for (final type in types)
            _DirectorsTab<Director>(
              fetchPage: (page) => _dataSource.getDirectors(
                type: int.parse(type),
                page: page,
              ),
              emptyMessage: '暂无导演',
              itemBuilder: (context, item) => EntityListTile(
                name: item.name,
                count: item.movieCount,
                onTap: () => _openCommonList(
                  context,
                  '导演',
                  item.name,
                  item.type,
                  'd',
                  item.id,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DirectorsTab<T> extends StatefulWidget {
  const _DirectorsTab({
    required this.fetchPage,
    required this.itemBuilder,
    required this.emptyMessage,
  });

  final Future<PagedResult<T>> Function(int page) fetchPage;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final String emptyMessage;

  @override
  State<_DirectorsTab<T>> createState() => _DirectorsTabState<T>();
}

class _DirectorsTabState<T> extends State<_DirectorsTab<T>>
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

新建 `lib/features/directors/index.dart`：

```dart
export 'screens/directors_page.dart';
```

- [ ] **Step 4: 运行测试确认通过**

Run: `flutter test test/features/directors/directors_page_test.dart`
Expected: 全部 PASS。

- [ ] **Step 5: 提交**

```bash
git add lib/features/directors test/features/directors/directors_page_test.dart
git commit -m "feat(directors): add directors page with two tabs"
```

### Task 4: 路由替换 + 豆腐块测试

**Files:**
- Modify: `lib/core/router/app_router.dart:199-201`（`/directors` 占位页换 `DirectorsPage`）+ 文件头部 import（`import 'package:jade/features/directors/index.dart';`）
- Test: `test/features/home/tofu_scroll_test.dart`（新增导演豆腐块用例）

**Interfaces:**
- Consumes: `DirectorsPage`（Task 3 的 `index.dart` 导出）。
- Produces: 无（路由接线完成，首页豆腐块无需改动）。

- [ ] **Step 1: 写失败测试**

在 `test/features/home/tofu_scroll_test.dart` 的 `main()` 内追加：

```dart
  testWidgets('导演豆腐块存在且点击进入 /directors', (tester) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(
            body: Align(alignment: Alignment.topCenter, child: TofuScroll()),
          ),
        ),
        GoRoute(
          path: '/directors',
          builder: (_, _) => const Scaffold(body: Text('导演页')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    expect(find.byKey(const Key('tofu-导演')), findsOneWidget);
    await tester.tap(find.text('导演'));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/directors');
  });
```

- [ ] **Step 2: 运行测试确认通过（此测试当前即可通过）**

Run: `flutter test test/features/home/tofu_scroll_test.dart`
Expected: 新增用例 PASS（豆腐块入口早已存在；此测试作为回归基线）。

- [ ] **Step 3: 替换路由**

在 `lib/core/router/app_router.dart` 头部 import 区（`import 'package:jade/features/makers/index.dart';` 之后）加：

```dart
import 'package:jade/features/directors/index.dart';
```

将：

```dart
    GoRoute(
      path: AppRoutes.directors,
      builder: (c, s) => const _SimpleListPage(title: '导演'),
    ),
```

替换为：

```dart
    GoRoute(
      path: AppRoutes.directors,
      builder: (c, s) => const DirectorsPage(),
    ),
```

- [ ] **Step 4: 运行测试确认通过**

Run: `flutter test test/features/home/tofu_scroll_test.dart test/features/directors`
Expected: 全部 PASS。

- [ ] **Step 5: 全量分析与测试**

Run: `flutter analyze`
Expected: 无新增 error/warning。

Run: `flutter test`
Expected: 全部 PASS（含既有测试，确认 `_SimpleListPage` 移除后无残留引用）。

- [ ] **Step 6: 提交**

```bash
git add lib/core/router/app_router.dart test/features/home/tofu_scroll_test.dart
git commit -m "feat(directors): wire directors route replacing placeholder page"
```

## Self-Review

**1. Spec coverage:**
- 豆腐块入口 → Task 4（回归测试）✓
- 2 Tab 有码/欧美 → Task 3 ✓
- type 0/2 调 `/api/v1/directors` → Task 2 ✓
- 列表与搜索一致（EntityListTile + CommonListPage 'd'）→ Task 3 ✓
- 分页 limit 48 + 启发式 → Task 2 ✓
- 归一化 videos_count → Task 1 ✓
- 路由替换 → Task 4 ✓
- 错误/空态/保活 → Task 3（复用 PaginatedListView）✓
- YAGNI 边界（不做详情页/下拉刷新/搜索框）→ 无对应任务 ✓

**2. Placeholder scan:** 无 TBD/TODO；每个 Task 均含完整测试代码与实现代码。

**3. Type consistency:** `DirectorDataSource.getDirectors({required int type, int page = 1, int limit = 48})` 在 Task 2 定义，Task 3 的测试 mock 与页面调用签名一致；`normalizeDirectorJson(Map<String, dynamic>)` Task 1 定义，Task 2 `DirectorService` 使用一致；`DirectorsPage({super.key, this.dataSource})` Task 3 定义，Task 4 路由使用一致。
