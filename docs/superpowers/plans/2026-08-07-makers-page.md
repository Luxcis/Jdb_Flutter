# 首页片商页实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> 规格：`docs/superpowers/specs/2026-08-07-makers-page-design.md`

**Goal:** 把首页「片商」豆腐块的 `/makers` 占位页替换为真实片商页：5 个分类 Tab（有码、无码、欧美、FC2、动漫），每个 Tab 调用 `/api/v1/makers?type=0/1/2/3/4`，分页列表样式与搜索结果片商 Tab 一致，点击条目进入 `CommonListPage`。

**Architecture:** 先在 core 层新增共享归一化函数 `normalizeMakerJson`（`videos_count → movie_count`）并让搜索服务复用；再新建 `lib/features/makers/` feature（服务 + 页面），每个 Tab 独立 `PaginationController` + `AutomaticKeepAliveClientMixin` 保活；最后把 `/makers` 路由接入 `MakersPage`，更新 `endpoints.dart` 过期备注并补充首页豆腐块测试。

**Tech Stack:** Flutter / Dart，go_router，json 手写反序列化（`api_data.dart` 辅助函数），`PaginationController` 分页，widget/unit 测试用 `flutter_test` + `FakeAdapter`。

## Global Constraints

- RULES.md：Material 3；文案中文硬编码，不用 l10n；Feature-First 结构，feature 只依赖 core（`features/common` 按现有惯例可被引用，见 series/search 对 `CommonListPage` 的用法）。
- 接口契约（以用户附件 OpenAPI 为准）：`/api/v1/makers` 返回 `data.makers[]`（`id/type/name/videos_count`）+ `current_page`；`type` 必填为字符串 `0/1/2/3/4`（有码/无码/欧美/FC2/动漫），`page` 从 1 开始，`limit` 固定 48。
- 示例响应无 `total_pages`/`total`：沿用 `apiPageResult` 启发式——返回条数满 `limit` 推断还有下一页，否则到底。
- 列表条目：名称 + 括号数量，`EntityListTile(name, count)`。
- 点击跳转：`CommonListPage(category: 'm')`，标题格式 `'片商 - 名称'`。
- 不做：片商详情页、`/directors` 占位页改造、下拉刷新、页面内搜索框/筛选。
- 提交纪律：只暂存与本次任务相关的文件，保留工作区其它变更。

---

### Task 1: core 共享 normalizeMakerJson 并让搜索服务复用

**Files:**
- Modify: `lib/core/network/api_data.dart`（新增 `normalizeMakerJson`）
- Modify: `lib/features/search/services/search_entity_service.dart`（`getMakers` 改用共享函数）
- Test: `test/core/network/api_data_test.dart`（新增用例）

**Interfaces:**
- Produces: `Map<String, dynamic> normalizeMakerJson(Map<String, dynamic> json)`，字段 `id`（兜底 `''`）、`name`（兜底 `''`）、`type`（兜底 0）、`movie_count`（取 `movie_count ?? movies_count ?? videos_count`，兜底 0）。后续 Task 2 的 `MakerService` 依赖它。

- [ ] **Step 1: 写失败测试**

在 `test/core/network/api_data_test.dart` 追加 import 与两个用例（文件顶部已有 `import 'package:jade/core/network/api_data.dart';`，需新增 `import 'package:jade/core/models/maker.dart';`）：

```dart
  test('normalizeMakerJson 将 videos_count 映射为 movieCount 并保留 type', () {
    final maker = Maker.fromJson(
      normalizeMakerJson({
        'id': 'xZyO',
        'type': 1,
        'name': 'Heydouga',
        'videos_count': 25645,
      }),
    );

    expect(maker.id, 'xZyO');
    expect(maker.name, 'Heydouga');
    expect(maker.type, 1);
    expect(maker.movieCount, 25645);
  });

  test('normalizeMakerJson 为缺失字段提供兜底值', () {
    final maker = Maker.fromJson(normalizeMakerJson({'id': null}));

    expect(maker.id, '');
    expect(maker.name, '');
    expect(maker.type, 0);
    expect(maker.movieCount, 0);
  });
```

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/core/network/api_data_test.dart`
Expected: FAIL（`normalizeMakerJson` 未定义）

- [ ] **Step 3: 实现共享归一化**

在 `lib/core/network/api_data.dart` 的 `normalizeActorSummaryJson` 之后新增：

```dart
Map<String, dynamic> normalizeMakerJson(Map<String, dynamic> json) => {
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

- [ ] **Step 4: 搜索服务复用共享函数**

在 `lib/features/search/services/search_entity_service.dart` 中把 `getMakers` 的 `fromJson` 从 `Maker.fromJson(_namedEntityJson(json))` 改为 `Maker.fromJson(normalizeMakerJson(json))`（`normalizeMakerJson` 来自 `api_data.dart`，该文件已 import）：

```dart
  @override
  Future<PagedResult<Maker>> getMakers({required String query, int page = 1}) =>
      _getPage(
        query: query,
        type: 'maker',
        collectionKey: 'makers',
        page: page,
        fromJson: (json) => Maker.fromJson(normalizeMakerJson(json)),
      );
```

- [ ] **Step 5: 运行相关测试确认通过**

Run: `flutter test test/core/network/api_data_test.dart test/features/search/search_entity_service_test.dart`
Expected: PASS（行为不变，搜索测试继续通过）

- [ ] **Step 6: 提交**

```bash
git add lib/core/network/api_data.dart lib/features/search/services/search_entity_service.dart test/core/network/api_data_test.dart
git commit -m "feat(network): add shared normalizeMakerJson mapping for makers"
```

---

### Task 2: makers feature 数据层（服务 + 数据源接口）

**Files:**
- Create: `lib/features/makers/services/maker_service.dart`
- Create: `test/features/makers/maker_service_test.dart`

**Interfaces:**
- Consumes: `Endpoints.makers`（已有）、`ApiClient.get(path, {queryParameters})`、`apiPageResult`/`normalizeMakerJson`（Task 1）、`Maker.fromJson`（core）、`PagedResult<T>`。
- Produces: `MakerDataSource` 抽象：`Future<PagedResult<Maker>> getMakers({required int type, int page = 1, int limit = 48})`；`MakerService implements MakerDataSource`；`UnavailableMakerDataSource implements MakerDataSource`（const，返回空页）。Task 3 的 `MakersPage` 依赖它。

- [ ] **Step 1: 写服务测试（先失败）**

创建 `test/features/makers/maker_service_test.dart`：

```dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/domain_manager.dart';
import 'package:jade/core/network/endpoints.dart';
import 'package:jade/core/network/interceptors/response_interceptor.dart';
import 'package:jade/core/network/testing/fake_adapter.dart';
import 'package:jade/features/makers/services/maker_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('getMakers 发送 type page limit 并解析 videos_count 为 movieCount', () async {
    final fixture = await buildMakerFixture();
    fixture.adapter.enqueue(Endpoints.makers, {
      'success': 1,
      'data': {
        'makers': [
          {'id': 'xZyO', 'type': 1, 'name': 'Heydouga', 'videos_count': 25645},
        ],
        'current_page': 1,
      },
    });

    final result = await fixture.service.getMakers(type: 1, page: 1);

    expect(result.items.single.id, 'xZyO');
    expect(result.items.single.name, 'Heydouga');
    expect(result.items.single.type, 1);
    expect(result.items.single.movieCount, 25645);
    expect(fixture.adapter.requests.single.queryParameters, {
      'type': '1',
      'page': 1,
      'limit': 48,
    });
  });

  test('缺少 total_pages 时满 48 条允许下一页，少于 48 条停止', () async {
    final fixture = await buildMakerFixture();
    fixture.adapter.enqueueSequence(Endpoints.makers, [
      makerResponse(48),
      makerResponse(47),
    ]);

    final full = await fixture.service.getMakers(type: 0);
    final partial = await fixture.service.getMakers(type: 0);

    expect(full.totalPages, 2);
    expect(partial.totalPages, 1);
  });
}

Future<({FakeAdapter adapter, MakerService service})> buildMakerFixture() async {
  final preferences = await SharedPreferences.getInstance();
  final domainManager = await DomainManager.load(preferences);
  final adapter = FakeAdapter();
  final dio = Dio(BaseOptions(baseUrl: domainManager.currentUrl))
    ..httpClientAdapter = adapter
    ..interceptors.add(ResponseInterceptor(onAuthError: () {}));
  final api = ApiClient.forTest(dio: dio, domainManager: domainManager);
  return (adapter: adapter, service: MakerService(api));
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

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/features/makers/maker_service_test.dart`
Expected: FAIL（`MakerService` 未定义）

- [ ] **Step 3: 实现服务**

创建 `lib/features/makers/services/maker_service.dart`：

```dart
import 'package:jade/core/models/maker.dart';
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/api_data.dart';
import 'package:jade/core/network/endpoints.dart';

abstract interface class MakerDataSource {
  Future<PagedResult<Maker>> getMakers({
    required int type,
    int page = 1,
    int limit = 48,
  });
}

class MakerService implements MakerDataSource {
  MakerService(this._api);

  final ApiClient _api;

  @override
  Future<PagedResult<Maker>> getMakers({
    required int type,
    int page = 1,
    int limit = 48,
  }) async {
    final response = await _api.get(
      Endpoints.makers,
      queryParameters: {'type': '$type', 'page': page, 'limit': limit},
    );
    return apiPageResult(
      response.data,
      keys: ['makers'],
      page: page,
      pageSize: limit,
      fromJson: (json) => Maker.fromJson(normalizeMakerJson(json)),
    );
  }
}

class UnavailableMakerDataSource implements MakerDataSource {
  const UnavailableMakerDataSource();

  @override
  Future<PagedResult<Maker>> getMakers({
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

Run: `flutter test test/features/makers/maker_service_test.dart`
Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add lib/features/makers/services/maker_service.dart test/features/makers/maker_service_test.dart
git commit -m "feat(makers): add maker list service with type pagination"
```

---

### Task 3: MakersPage 页面（5 Tab + 分页列表）

**Files:**
- Create: `lib/features/makers/screens/makers_page.dart`
- Create: `lib/features/makers/index.dart`
- Create: `test/features/makers/makers_page_test.dart`

**Interfaces:**
- Consumes: `MakerDataSource`（Task 2）、`Maker`/`PagedResult`（core）、`EntityListTile`/`PaginatedListView`/`PaginationController`（core widgets）、`CommonListPage`（features/common，按现有惯例）。
- Produces: `MakersPage({Key? key, MakerDataSource? dataSource})`，Task 4 路由引用。

- [ ] **Step 1: 写页面测试（先失败）**

创建 `test/features/makers/makers_page_test.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/models/maker.dart';
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/features/makers/screens/makers_page.dart';
import 'package:jade/features/makers/services/maker_service.dart';

void main() {
  testWidgets('渲染 5 个 Tab，默认加载有码 type=0', (tester) async {
    final source = _RecordingMakerDataSource();
    await tester.pumpWidget(MaterialApp(home: MakersPage(dataSource: source)));
    await tester.pumpAndSettle();

    for (final tab in ['有码', '无码', '欧美', 'FC2', '动漫']) {
      expect(find.text(tab), findsOneWidget);
    }
    expect(find.text('Heydouga'), findsOneWidget);
    expect(find.text('(25645)'), findsOneWidget);
    expect(source.calls, [(type: 0, page: 1)]);
  });

  testWidgets('切换到无码 Tab 触发 getMakers(type=1)', (tester) async {
    final source = _RecordingMakerDataSource();
    await tester.pumpWidget(MaterialApp(home: MakersPage(dataSource: source)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('无码'));
    await tester.pumpAndSettle();

    expect(source.calls, [(type: 0, page: 1), (type: 1, page: 1)]);
  });

  testWidgets('切回 Tab 保留列表状态，不重复请求', (tester) async {
    final source = _RecordingMakerDataSource();
    await tester.pumpWidget(MaterialApp(home: MakersPage(dataSource: source)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('无码'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('有码'));
    await tester.pumpAndSettle();

    expect(source.calls, [(type: 0, page: 1), (type: 1, page: 1)]);
  });

  testWidgets('点击片商条目进入 CommonListPage', (tester) async {
    final source = _RecordingMakerDataSource();
    await tester.pumpWidget(MaterialApp(home: MakersPage(dataSource: source)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Heydouga'));
    await tester.pumpAndSettle();

    expect(find.text('片商 - Heydouga'), findsOneWidget);
  });
}

class _RecordingMakerDataSource implements MakerDataSource {
  final calls = <({int type, int page})>[];

  @override
  Future<PagedResult<Maker>> getMakers({
    required int type,
    int page = 1,
    int limit = 48,
  }) async {
    calls.add((type: type, page: page));
    return PagedResult(
      items: [
        Maker(id: 'xZyO', name: 'Heydouga', movieCount: 25645, type: type),
      ],
      currentPage: page,
      totalPages: page,
      total: 1,
    );
  }
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/features/makers/makers_page_test.dart`
Expected: FAIL（`MakersPage` 未定义）

- [ ] **Step 3: 实现页面**

创建 `lib/features/makers/screens/makers_page.dart`（结构参照 `lib/features/series/screens/series_page.dart`）：

```dart
import 'package:flutter/material.dart';
import 'package:jade/core/models/maker.dart';
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/widgets/entity_list_tile.dart';
import 'package:jade/core/widgets/paginated_list_view.dart';
import 'package:jade/core/widgets/pagination_controller.dart';
import 'package:jade/features/common/screens/common_list_page.dart';
import 'package:jade/features/makers/services/maker_service.dart';

class MakersPage extends StatefulWidget {
  const MakersPage({super.key, this.dataSource});

  final MakerDataSource? dataSource;

  @override
  State<MakersPage> createState() => _MakersPageState();
}

class _MakersPageState extends State<MakersPage>
    with TickerProviderStateMixin {
  static const tabs = ['有码', '无码', '欧美', 'FC2', '动漫'];
  static const types = ['0', '1', '2', '3', '4'];

  late final TabController _tabController;
  late final MakerDataSource _dataSource;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: tabs.length, vsync: this);
    _dataSource =
        widget.dataSource ??
        switch (ApiClient.instanceOrNull) {
          final api? => MakerService(api),
          null => const UnavailableMakerDataSource(),
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
        title: const Text('片商'),
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
            _MakersTab<Maker>(
              fetchPage: (page) => _dataSource.getMakers(
                type: int.parse(type),
                page: page,
              ),
              emptyMessage: '暂无片商',
              itemBuilder: (context, item) => EntityListTile(
                name: item.name,
                count: item.movieCount,
                onTap: () => _openCommonList(
                  context,
                  '片商',
                  item.name,
                  item.type,
                  'm',
                  item.id,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MakersTab<T> extends StatefulWidget {
  const _MakersTab({
    required this.fetchPage,
    required this.itemBuilder,
    required this.emptyMessage,
  });

  final Future<PagedResult<T>> Function(int page) fetchPage;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final String emptyMessage;

  @override
  State<_MakersTab<T>> createState() => _MakersTabState<T>();
}

class _MakersTabState<T> extends State<_MakersTab<T>>
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

创建 `lib/features/makers/index.dart`：

```dart
export 'screens/makers_page.dart';
```

- [ ] **Step 4: 运行测试确认通过**

Run: `flutter test test/features/makers/makers_page_test.dart`
Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add lib/features/makers test/features/makers
git commit -m "feat(makers): add makers page with five tabs"
```

---

### Task 4: 路由接入 + endpoints 注释 + 首页豆腐块测试

**Files:**
- Modify: `lib/core/router/app_router.dart`（`/makers` → `MakersPage`）
- Modify: `lib/core/network/endpoints.dart`（更新 `/api/v1/makers` 过期备注）
- Modify: `test/features/home/tofu_scroll_test.dart`（补充片商豆腐块断言）

**Interfaces:**
- Consumes: `MakersPage`（Task 3，经 `lib/features/makers/index.dart`）。

- [ ] **Step 1: 路由接入**

在 `lib/core/router/app_router.dart` 顶部新增 `import 'package:jade/features/makers/index.dart';`（按字母序放在 `features/movie_detail/index.dart` 之前），并把 `/makers` 路由从占位页改为 `MakersPage`：

```dart
    GoRoute(
      path: AppRoutes.makers,
      builder: (c, s) => const MakersPage(),
    ),
```

`_SimpleListPage` 仍被 `/directors` 使用，保留。

- [ ] **Step 2: 更新 endpoints 备注**

在 `lib/core/network/endpoints.dart` 中把 `/api/v1/makers` 的过期备注
（`⚠️ 服务端Bug: 该接口无论传什么 type 值均返回 HTTP 500`）替换为：

```dart
  // type: 0 有码, 1 无码, 2 欧美, 3 FC2, 4 动漫; page 从 1 开始; limit 固定 48
  static const String makers = '/api/v1/makers';
```

- [ ] **Step 3: 补充豆腐块测试**

在 `test/features/home/tofu_scroll_test.dart` 的 `main()` 内追加用例（`/makers` 路由需在测试 router 中注册）：

```dart
  testWidgets('片商豆腐块存在且点击进入 /makers', (tester) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(
            body: Align(alignment: Alignment.topCenter, child: TofuScroll()),
          ),
        ),
        GoRoute(
          path: '/makers',
          builder: (_, _) => const Scaffold(body: Text('片商页')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    expect(find.byKey(const Key('tofu-片商')), findsOneWidget);
    await tester.tap(find.text('片商'));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/makers');
  });
```

- [ ] **Step 4: 运行相关测试确认通过**

Run: `flutter test test/features/home/tofu_scroll_test.dart test/core/router/app_router_test.dart`
Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add lib/core/router/app_router.dart lib/core/network/endpoints.dart test/features/home/tofu_scroll_test.dart
git commit -m "feat(makers): wire makers route and refresh endpoints note"
```

---

### Task 5: 全量验证

**Files:** 无新增。

- [ ] **Step 1: 静态分析**

Run: `flutter analyze`
Expected: No issues found

- [ ] **Step 2: 全量测试**

Run: `flutter test`
Expected: All tests pass（重点观察 `test/features/makers/`、`test/features/home/`、`test/core/network/api_data_test.dart`、`test/features/search/search_entity_service_test.dart`）

- [ ] **Step 3: 汇总**

检查 `git status --short`，确认只包含本次任务相关文件；如有意外改动需说明。
