# 排行榜功能优化 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为排行榜增加可靠的加载反馈与 Tab 状态保留，按 OpenAPI 修正所有排行榜参数，并实现看热播与 Top250 筛选交互。

**Architecture:** 保留现有 Feature-First 结构，增强共享 `PaginationController` 的查询重载与过期响应隔离能力，并由排行榜各 Tab 独立持有控制器。排行榜服务只负责 OpenAPI 参数与响应映射，筛选值和 Material 3 UI 保持在 rankings feature 内。

**Tech Stack:** Flutter、Dart 3.8、Material 3、Provider、Dio、`flutter_test`、本地 OpenAPI、Android `adb_tool`

## Global Constraints

- 以 `docs/main/api/jdb_api_openapi.json` 为排行榜接口唯一权威来源。
- 不新增依赖，不修改 `pubspec.yaml`。
- 遵循 Material 3、系统亮暗主题和 `ColorScheme`；不硬编码独立色板。
- 项目文案直接使用中文，不添加 ARB 或 l10n。
- 不使用触觉反馈。
- 保留所有与本任务无关的工作区修改；每次只暂存当前任务文件。
- Top250 类型与年份互斥；选项变更后立即刷新且底部抽屉保持打开。
- 看热播使用已确认的两行分组圆角标签方案。
- 最终必须运行聚焦测试、静态分析，并用 `adb_tool` 完成设备截图和点按验证。

---

### Task 1: 让分页控制器安全重载查询并隔离过期响应

**Files:**
- Modify: `lib/core/widgets/pagination_controller.dart:4-49`
- Modify: `test/core/widgets/pagination_controller_test.dart:1-17`

**Interfaces:**
- Consumes: `PagedResult<T>`。
- Produces: `typedef PageFetcher<T> = Future<PagedResult<T>> Function(int page)`、`Future<void> reloadWith(PageFetcher<T> fetch)`；现有 `fetchMore()`、`refresh()` 调用方式保持兼容。

- [ ] **Step 1: 写出并发重载失败测试**

在 `test/core/widgets/pagination_controller_test.dart` 增加：

```dart
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/core/widgets/pagination_controller.dart';

PagedResult<int> page(List<int> items) => PagedResult(
  items: items,
  currentPage: 1,
  totalPages: 1,
  total: items.length,
);

test('reloadWith 只接受最后一次查询结果', () async {
  final first = Completer<PagedResult<int>>();
  final second = Completer<PagedResult<int>>();
  final controller = PaginationController<int>(fetch: (_) => first.future);

  final firstLoad = controller.fetchMore();
  final secondLoad = controller.reloadWith((_) => second.future);
  second.complete(page([2]));
  await secondLoad;
  first.complete(page([1]));
  await firstLoad;

  expect(controller.items, [2]);
  expect(controller.isLoading, isFalse);
});
```

- [ ] **Step 2: 运行测试确认 RED**

Run: `flutter test test/core/widgets/pagination_controller_test.dart`

Expected: FAIL，提示 `reloadWith` 未定义。

- [ ] **Step 3: 实现请求代次与查询重载**

将控制器核心改为：

```dart
typedef PageFetcher<T> = Future<PagedResult<T>> Function(int page);

class PaginationController<T> extends ChangeNotifier {
  PaginationController({required PageFetcher<T> fetch}) : _fetch = fetch;

  PageFetcher<T> _fetch;
  final List<T> _items = [];
  int _page = 0;
  int _generation = 0;
  bool _isLoading = false;
  bool _hasMore = true;
  Object? _error;

  List<T> get items => List.unmodifiable(_items);
  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;
  Object? get error => _error;

  Future<void> fetchMore() async {
    if (_isLoading || !_hasMore) return;
    final generation = _generation;
    final fetch = _fetch;
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final result = await fetch(_page + 1);
      if (generation != _generation) return;
      _page = result.currentPage;
      _items.addAll(result.items);
      _hasMore = _page < result.totalPages;
    } catch (error) {
      if (generation == _generation) _error = error;
    } finally {
      if (generation == _generation) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> reloadWith(PageFetcher<T> fetch) async {
    _generation++;
    _fetch = fetch;
    _page = 0;
    _items.clear();
    _hasMore = true;
    _isLoading = false;
    _error = null;
    notifyListeners();
    await fetchMore();
  }

  Future<void> refresh() => reloadWith(_fetch);

  void reshuffle() {
    _items.shuffle();
    notifyListeners();
  }

  @override
  void dispose() {
    _generation++;
    super.dispose();
  }
}
```

- [ ] **Step 4: 运行控制器测试确认 GREEN**

Run: `flutter test test/core/widgets/pagination_controller_test.dart`

Expected: PASS，包括既有异常捕获测试和新增并发测试。

- [ ] **Step 5: 提交控制器修改**

```bash
git add lib/core/widgets/pagination_controller.dart test/core/widgets/pagination_controller_test.dart
git commit -m "fix: make pagination reload race-safe"
```

---

### Task 2: 为影片网格补齐首次与分页 Loading

**Files:**
- Modify: `lib/core/widgets/movie_grid_view.dart:20-60`
- Create: `test/core/widgets/movie_grid_view_test.dart`

**Interfaces:**
- Consumes: Task 1 的 `PaginationController<MovieSummary>`。
- Produces: 空数据加载时的居中进度环，以及已有数据分页时的底部进度环。

- [ ] **Step 1: 写出 Loading 渲染失败测试**

创建 `test/core/widgets/movie_grid_view_test.dart`：

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/models/movie.dart';
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/core/widgets/movie_grid_view.dart';
import 'package:jade/core/widgets/pagination_controller.dart';

void main() {
  testWidgets('空数据首次加载时显示居中进度环', (tester) async {
    final pending = Completer<PagedResult<MovieSummary>>();
    final controller = PaginationController<MovieSummary>(
      fetch: (_) => pending.future,
    );
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: MovieGridView(controller: controller))),
    );

    controller.fetchMore();
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(GridView), findsNothing);
  });
}
```

- [ ] **Step 2: 运行测试确认 RED**

Run: `flutter test test/core/widgets/movie_grid_view_test.dart`

Expected: FAIL，当前实现仍渲染 itemCount 为 0 的 `GridView`。

- [ ] **Step 3: 实现首次 Loading 与 Sliver 底部 Loading**

在错误态判断后增加：

```dart
if (controller.isLoading && controller.items.isEmpty) {
  return const Center(child: CircularProgressIndicator());
}
```

将 `GridView.builder` 替换为保留原网格参数的 `CustomScrollView`：

```dart
child: CustomScrollView(
  slivers: [
    SliverPadding(
      padding: const EdgeInsets.all(8),
      sliver: SliverGrid.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 0.56,
        ),
        itemCount: controller.items.length,
        itemBuilder: (_, i) => MovieCard(
          movie: controller.items[i],
          onTap: onMovieTap == null
              ? null
              : () => onMovieTap!(controller.items[i]),
        ),
      ),
    ),
    if (controller.isLoading)
      const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
  ],
),
```

- [ ] **Step 4: 运行网格与现有卡片测试**

Run: `flutter test test/core/widgets/movie_grid_view_test.dart test/core/widgets/movie_card_test.dart`

Expected: PASS。

- [ ] **Step 5: 提交网格 Loading**

```bash
git add lib/core/widgets/movie_grid_view.dart test/core/widgets/movie_grid_view_test.dart
git commit -m "feat: show movie grid loading states"
```

---

### Task 3: 按 OpenAPI 修正 RankingService 参数

**Files:**
- Modify: `lib/features/rankings/services/ranking_service.dart:1-85`
- Modify: `test/api_integration_test.dart:137-216`

**Interfaces:**
- Consumes: `Endpoints.moviesTop`、`Endpoints.rankingsPlayback`、`Endpoints.rankings`、`Endpoints.rankingsActors`。
- Produces:
  - `getTop250({int startRank = 1, String type = 'all', String typeValue = '', bool ignoreWatched = false, int limit = 50})`
  - `getPlayback({String filterBy = 'high_score', String period = 'daily'})`
  - `getRanking({required String type, String period = 'daily', int page = 1})`
  - `getActorRanking({required int type})`

- [ ] **Step 1: 将集成测试改成 OpenAPI 契约**

用以下断言替换 RankingService 组内旧参数断言：

```dart
await svc.getTop250(
  startRank: 51,
  type: 'video_type',
  typeValue: '2',
  ignoreWatched: true,
);
final topQuery = adapter.requests.last.uri.queryParameters;
expect(topQuery, containsPair('start_rank', '51'));
expect(topQuery, containsPair('type', 'video_type'));
expect(topQuery, containsPair('type_value', '2'));
expect(topQuery, containsPair('ignore_watched', 'true'));
expect(topQuery, containsPair('limit', '50'));
expect(topQuery.containsKey('page'), isFalse);

await svc.getPlayback(filterBy: 'high_score', period: 'weekly');
final playbackQuery = adapter.requests.last.uri.queryParameters;
expect(playbackQuery['filter_by'], 'high_score');
expect(playbackQuery['period'], 'weekly');
expect(playbackQuery.containsKey('page'), isFalse);
expect(playbackQuery.containsKey('limit'), isFalse);

await svc.getRanking(type: '0', period: 'monthly', page: 2);
final rankingQuery = adapter.requests.last.uri.queryParameters;
expect(rankingQuery['type'], '0');
expect(rankingQuery['period'], 'monthly');
expect(rankingQuery['page'], '2');
expect(rankingQuery.containsKey('limit'), isFalse);

await svc.getActorRanking(type: 2);
expect(adapter.requests.last.uri.queryParameters, {'type': '2'});
```

- [ ] **Step 2: 运行 RankingService 测试确认 RED**

Run: `flutter test test/api_integration_test.dart --plain-name RankingService`

Expected: FAIL，旧签名缺少 Top250 参数，且综合排行榜不发送 `page`。

- [ ] **Step 3: 实现准确的查询参数**

核心实现：

```dart
Future<PagedResult<MovieSummary>> getTop250({
  int startRank = 1,
  String type = 'all',
  String typeValue = '',
  bool ignoreWatched = false,
  int limit = 50,
}) async {
  final response = await _api.get(
    Endpoints.moviesTop,
    queryParameters: {
      'start_rank': startRank,
      'type': type,
      'type_value': typeValue,
      'ignore_watched': ignoreWatched.toString(),
      'limit': limit,
    },
  );
  return _parseMoviePage(response.data, fallbackPage: 1);
}

Future<PagedResult<MovieSummary>> getPlayback({
  String filterBy = 'high_score',
  String period = 'daily',
}) async {
  final response = await _api.get(
    Endpoints.rankingsPlayback,
    queryParameters: {'filter_by': filterBy, 'period': period},
  );
  return _parseMoviePage(response.data, fallbackPage: 1);
}

Future<PagedResult<MovieSummary>> getRanking({
  required String type,
  String period = 'daily',
  int page = 1,
}) async {
  final response = await _api.get(
    Endpoints.rankings,
    queryParameters: {'type': type, 'period': period, 'page': page},
  );
  return _parseMoviePage(response.data, fallbackPage: page);
}
```

演员排行和解析 helper 使用以下实现：

```dart
Future<PagedResult<ActorSummary>> getActorRanking({
  required int type,
}) async {
  final response = await _api.get(
    Endpoints.rankingsActors,
    queryParameters: {'type': type},
  );
  final data = response.data as Map<String, dynamic>;
  final items = apiList(data, const ['actors', 'items'])
      .map((json) => ActorSummary.fromJson(normalizeActorSummaryJson(json)))
      .toList();
  return PagedResult(
    items: items,
    currentPage: 1,
    totalPages: 1,
    total: apiInt(data['total'], items.length),
  );
}

PagedResult<MovieSummary> _parseMoviePage(
  dynamic data, {
  required int fallbackPage,
}) {
  final map = data as Map<String, dynamic>;
  final items = apiList(map, const ['movies', 'items'])
      .map((json) => MovieSummary.fromJson(normalizeMovieSummaryJson(json)))
      .toList();
  return PagedResult(
    items: items,
    currentPage: apiInt(map['current_page'], fallbackPage),
    totalPages: apiInt(map['total_pages'], fallbackPage),
    total: apiInt(map['total'], items.length),
  );
}
```

- [ ] **Step 4: 运行 API 集成测试确认 GREEN**

Run: `flutter test test/api_integration_test.dart --plain-name RankingService`

Expected: PASS。

- [ ] **Step 5: 提交服务契约修复**

```bash
git add lib/features/rankings/services/ranking_service.dart test/api_integration_test.dart
git commit -m "fix: align ranking requests with OpenAPI"
```

---

### Task 4: 实现 Tab Loading、缓存与看热播筛选样式

**Files:**
- Modify: `lib/features/rankings/screens/rankings_screen.dart:14-270`
- Modify: `test/features/rankings/rankings_screen_test.dart:1-66`

**Interfaces:**
- Consumes: Task 1 的 `reloadWith`、Task 2 的 Loading 网格、Task 3 的服务签名。
- Produces: keep-alive 的 `_HotPlayTab`、`_RankTab`，以及 `high_score|all`、`daily|weekly|monthly` 的 ChoiceChip UI。

- [ ] **Step 1: 增加失败 Widget 测试**

先在 `rankings_screen_test.dart` 定义完整测试夹具：

```dart
class _RankingFixture {
  const _RankingFixture(this.adapter);
  final FakeAdapter adapter;
}

Future<_RankingFixture> _pumpRankings(
  WidgetTester tester, {
  Duration responseDelay = Duration.zero,
  bool loggedIn = true,
  double textScaleFactor = 1,
}) async {
  SharedPreferences.setMockInitialValues({
    'key_baseurl': 'https://jdforrepam.com',
    'key_api_domains': ['https://jdforrepam.com'],
  });
  final prefs = await SharedPreferences.getInstance();
  final auth = await AuthProvider.create(prefs);
  if (loggedIn) {
    await auth.login(token: 'token', user: {'id': 1});
  }
  final api = await ApiClient.create(
    prefs: prefs,
    tokenProvider: auth,
    onAuthError: auth.logout,
  );
  final adapter = FakeAdapter()..responseDelay = responseDelay;
  api.setAdapterForTest(adapter);
  for (final path in [
    Endpoints.moviesTop,
    Endpoints.rankingsPlayback,
    Endpoints.rankings,
  ]) {
    adapter.enqueue(path, {
      'success': 1,
      'data': {
        'movies': [
          {
            'id': path,
            'number': 'ABC-001',
            'title': path == Endpoints.rankingsPlayback
                ? 'Hot Movie'
                : 'Ranked Movie',
            'cover_url': 'cover.jpg',
          },
        ],
        'current_page': 1,
        'total_pages': 1,
        'total': 1,
      },
    });
  }
  await tester.pumpWidget(
    ChangeNotifierProvider<AuthProvider>.value(
      value: auth,
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: const Size(320, 640),
            textScaler: TextScaler.linear(textScaleFactor),
          ),
          child: const RankingsPage(),
        ),
      ),
    ),
  );
  return _RankingFixture(adapter);
}
```

然后增加：

```dart
testWidgets('切换到看热播时先显示 Loading 且不显示空网格', (tester) async {
  final fixture = await _pumpRankings(
    tester,
    responseDelay: const Duration(seconds: 1),
  );

  await tester.tap(find.text('看热播'));
  await tester.pump();

  expect(find.byType(CircularProgressIndicator), findsOneWidget);
  expect(find.byType(GridView), findsNothing);
  expect(fixture.adapter.requests.last.path, Endpoints.rankingsPlayback);
});

testWidgets('看热播使用分组圆角标签并发送 OpenAPI 参数', (tester) async {
  final fixture = await _pumpRankings(tester);
  await tester.tap(find.text('看热播'));
  await tester.pumpAndSettle();

  expect(find.text('范围'), findsOneWidget);
  expect(find.text('周期'), findsOneWidget);
  expect(find.byType(ChoiceChip), findsNWidgets(5));
  await tester.tap(find.widgetWithText(ChoiceChip, '周榜'));
  await tester.pumpAndSettle();

  final query = fixture.adapter.requests.last.uri.queryParameters;
  expect(query['filter_by'], 'high_score');
  expect(query['period'], 'weekly');
});

testWidgets('综合排行榜没有演员月榜且类型映射从 0 开始', (tester) async {
  final fixture = await _pumpRankings(tester);
  await tester.tap(find.text('有码'));
  await tester.pumpAndSettle();

  expect(find.text('演员月榜'), findsNothing);
  expect(fixture.adapter.requests.last.uri.queryParameters['type'], '0');
});

testWidgets('离开已加载 Tab 后返回时保留内容且不重复请求', (tester) async {
  final fixture = await _pumpRankings(tester);
  await tester.tap(find.text('看热播'));
  await tester.pumpAndSettle();
  final playbackCount = fixture.adapter.requests
      .where((request) => request.path == Endpoints.rankingsPlayback)
      .length;

  await tester.tap(find.text('有码'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('看热播'));
  await tester.pumpAndSettle();

  expect(find.text('Hot Movie'), findsOneWidget);
  expect(
    fixture.adapter.requests
        .where((request) => request.path == Endpoints.rankingsPlayback)
        .length,
    playbackCount,
  );
});

testWidgets('看热播筛选在窄屏大字体下不溢出', (tester) async {
  await _pumpRankings(tester, textScaleFactor: 1.5);
  await tester.tap(find.text('看热播'));
  await tester.pumpAndSettle();

  expect(tester.takeException(), isNull);
});
```

- [ ] **Step 2: 运行排行榜 Widget 测试确认 RED**

Run: `flutter test test/features/rankings/rankings_screen_test.dart`

Expected: FAIL，当前为空网格、使用 `SegmentedButton`，且有码映射为 `1`。

- [ ] **Step 3: 修正 Tab 类型和周期**

将 Tab 子项改为：

```dart
const _Top250Tab(),
const _HotPlayTab(),
const _RankTab(type: '0'),
const _RankTab(type: '1'),
const _RankTab(type: '2'),
const _RankTab(type: '3'),
```

`_RankTab` 只定义以下固定选项：

```dart
static const periods = [
  (label: '日榜', value: 'daily'),
  (label: '周榜', value: 'weekly'),
  (label: '月榜', value: 'monthly'),
];
```

各 Tab State 混入 `AutomaticKeepAliveClientMixin`，`wantKeepAlive => true`，并在 `build` 首行调用 `super.build(context)`；在 `dispose` 中释放控制器。

- [ ] **Step 4: 实现看热播两行 ChoiceChip**

用私有 `_FilterChipRow` 组合：

```dart
_FilterChipRow(
  label: '范围',
  options: [
    (label: '高分', value: 'high_score'),
    (label: '全部', value: 'all'),
  ],
  value: filterBy,
  onSelected: onFilterChanged,
)
```

第二行使用 `daily`、`weekly`、`monthly`。私有组件实现为：

```dart
class _FilterChipRow extends StatelessWidget {
  const _FilterChipRow({
    required this.label,
    required this.options,
    required this.value,
    required this.onSelected,
  });

  final String label;
  final List<({String label, String value})> options;
  final String value;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 40,
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ),
        for (final option in options)
          ChoiceChip(
            label: Text(option.label),
            selected: value == option.value,
            onSelected: (_) => onSelected(option.value),
          ),
      ],
    );
  }
}
```

筛选回调更新字段后调用：

```dart
await _controller.reloadWith(_fetchPage);
```

其中 `_fetchPage(int page)` 对播放榜忽略 `page`，综合榜把 `page` 传给服务。

- [ ] **Step 5: 运行排行榜 Widget 测试确认 GREEN**

Run: `flutter test test/features/rankings/rankings_screen_test.dart`

Expected: PASS。

- [ ] **Step 6: 提交排行榜 Tab 优化**

```bash
git add lib/features/rankings/screens/rankings_screen.dart test/features/rankings/rankings_screen_test.dart
git commit -m "feat: improve ranking tabs and loading"
```

---

### Task 5: 实现 Top250 底部筛选抽屉

**Files:**
- Modify: `lib/features/rankings/screens/rankings_screen.dart`
- Modify: `test/features/rankings/rankings_screen_test.dart`

**Interfaces:**
- Consumes: Task 3 的 `getTop250` 参数。
- Produces: `Top250Filter` 不可变值对象、`_Top250FilterSheet`、仅在 Top250 显示的 AppBar 筛选按钮。

- [ ] **Step 1: 写出筛选入口与抽屉失败测试**

增加测试：

```dart
testWidgets('Top250 筛选抽屉包含完整选项并保持打开', (tester) async {
  final fixture = await _pumpRankings(tester, loggedIn: true);

  expect(find.byTooltip('筛选 Top250'), findsOneWidget);
  await tester.tap(find.byTooltip('筛选 Top250'));
  await tester.pumpAndSettle();

  expect(find.text('筛选'), findsOneWidget);
  expect(find.text(DateTime.now().year.toString()), findsOneWidget);
  await tester.drag(find.byType(DraggableScrollableSheet), const Offset(0, -600));
  await tester.pumpAndSettle();
  expect(find.text('2008'), findsOneWidget);
  expect(find.text('起始排名'), findsOneWidget);
  expect(find.text('未标「看过」'), findsOneWidget);

  await tester.tap(find.widgetWithText(ChoiceChip, '欧美'));
  await tester.pump();
  expect(find.byType(BottomSheet), findsOneWidget);
  final query = fixture.adapter.requests.last.uri.queryParameters;
  expect(query['type'], 'video_type');
  expect(query['type_value'], '2');

  await tester.tap(
    find.widgetWithText(ChoiceChip, DateTime.now().year.toString()),
  );
  await tester.pump();
  final yearQuery = fixture.adapter.requests.last.uri.queryParameters;
  expect(yearQuery['type'], 'year');
  expect(yearQuery['type_value'], DateTime.now().year.toString());

  await tester.tap(find.byType(SwitchListTile));
  await tester.pump();
  expect(
    fixture.adapter.requests.last.uri.queryParameters['ignore_watched'],
    'true',
  );
});

testWidgets('Top250 起始排名控制请求与展示排名', (tester) async {
  final fixture = await _pumpRankings(tester, loggedIn: true);
  await tester.tap(find.byTooltip('筛选 Top250'));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(ChoiceChip, '51'));
  await tester.pump();

  expect(fixture.adapter.requests.last.uri.queryParameters['start_rank'], '51');
  expect(find.byType(BottomSheet), findsOneWidget);
});

testWidgets('筛选按钮仅在 Top250 Tab 显示', (tester) async {
  await _pumpRankings(tester);
  expect(find.byTooltip('筛选 Top250'), findsOneWidget);

  await tester.tap(find.text('看热播'));
  await tester.pumpAndSettle();

  expect(find.byTooltip('筛选 Top250'), findsNothing);
});
```

- [ ] **Step 2: 运行抽屉测试确认 RED**

Run: `flutter test test/features/rankings/rankings_screen_test.dart --plain-name Top250`

Expected: FAIL，AppBar 中不存在筛选按钮。

- [ ] **Step 3: 添加 Top250 筛选状态**

在 rankings screen 内定义：

```dart
@immutable
class Top250Filter {
  const Top250Filter({
    this.type = 'all',
    this.typeValue = '',
    this.startRank = 1,
    this.ignoreWatched = false,
  });

  final String type;
  final String typeValue;
  final int startRank;
  final bool ignoreWatched;

  Top250Filter copyWith({
    String? type,
    String? typeValue,
    int? startRank,
    bool? ignoreWatched,
  }) => Top250Filter(
    type: type ?? this.type,
    typeValue: typeValue ?? this.typeValue,
    startRank: startRank ?? this.startRank,
    ignoreWatched: ignoreWatched ?? this.ignoreWatched,
  );
}
```

`_RankingsPageState` 持有 `_top250Filter`，把它传给 `_Top250Tab(filter: _top250Filter)`；抽屉的 `onChanged` 更新同一状态。`_Top250TabState.didUpdateWidget` 比较四个字段，只在筛选值变化时调用 `reloadWith`。TabController listener 只在 index 变化完成时刷新 AppBar action，不通过 `GlobalKey` 耦合父子 State。

- [ ] **Step 4: 构建 Material 3 底部抽屉**

使用：

```dart
showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) => _Top250FilterSheet(
    value: _top250Filter,
    onChanged: (value) => setState(() => _top250Filter = value),
  ),
);
```

抽屉内容明确使用 `DraggableScrollableSheet(expand: false)` 包裹 `ListView`。`_Top250FilterSheet` 使用自身 StatefulWidget 立即更新选中态。类型选项为全部、有码、无码、欧美、FC2；年份为：

```dart
final years = [
  for (var year = DateTime.now().year; year >= 2008; year--) year,
];
```

类型和年份共享一个选中维度；起始排名固定为 `1, 51, 101, 151, 201`；底部使用 `SwitchListTile`。每次变更先更新 sheet 本地值，再调用父级 `onChanged`，不调用 `Navigator.pop`。

Sheet 内统一通过以下方法提交即时选择：

```dart
void _emit(Top250Filter value) {
  setState(() => _value = value);
  widget.onChanged(value);
}

ChoiceChip(
  label: const Text('欧美'),
  selected: _value.type == 'video_type' && _value.typeValue == '2',
  onSelected: (_) => _emit(
    _value.copyWith(type: 'video_type', typeValue: '2'),
  ),
)

ChoiceChip(
  label: Text(year.toString()),
  selected: _value.type == 'year' && _value.typeValue == year.toString(),
  onSelected: (_) => _emit(
    _value.copyWith(type: 'year', typeValue: year.toString()),
  ),
)

ChoiceChip(
  label: Text(startRank.toString()),
  selected: _value.startRank == startRank,
  onSelected: (_) => _emit(_value.copyWith(startRank: startRank)),
)

SwitchListTile(
  title: const Text('未标「看过」'),
  subtitle: const Text('仅查看还未被标记「看过」的影片'),
  value: _value.ignoreWatched,
  onChanged: (value) => _emit(_value.copyWith(ignoreWatched: value)),
)
```

- [ ] **Step 5: 使用 Top250 参数重新加载并正确显示排名**

`_Top250TabState.didUpdateWidget` 在筛选变化时调用 `reloadWith`。Top250 请求忽略控制器传入的 page：

```dart
Future<PagedResult<MovieSummary>> _fetchPage(int _) {
  final api = ApiClient.instanceOrNull;
  if (api == null) {
    return Future.value(
      const PagedResult(
        items: <MovieSummary>[],
        currentPage: 1,
        totalPages: 1,
        total: 0,
      ),
    );
  }
  return RankingService(api).getTop250(
    startRank: widget.filter.startRank,
    type: widget.filter.type,
    typeValue: widget.filter.typeValue,
    ignoreWatched: widget.filter.ignoreWatched,
  );
}
```

列表排名使用：

```dart
rank: widget.filter.startRank + index
```

Top250 的 `ListenableBuilder` 按以下顺序渲染状态：

```dart
if (_controller.error != null && _controller.items.isEmpty) {
  return ErrorRetryWidget(
    message: _controller.error.toString(),
    onRetry: _controller.refresh,
  );
}
if (_controller.isLoading && _controller.items.isEmpty) {
  return const Center(child: CircularProgressIndicator());
}
return RefreshIndicator(
  onRefresh: _controller.refresh,
  child: ListView.builder(
    itemCount: _controller.items.length +
        (_controller.isLoading && _controller.items.isNotEmpty ? 1 : 0),
    itemBuilder: (context, index) {
      if (index == _controller.items.length) {
        return const Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        );
      }
      return MovieListTile(
        movie: _controller.items[index],
        rank: widget.filter.startRank + index,
      );
    },
  ),
);
```

控制器在 `dispose` 时释放。

- [ ] **Step 6: 运行全部排行榜测试确认 GREEN**

Run: `flutter test test/features/rankings/rankings_screen_test.dart test/api_integration_test.dart`

Expected: PASS。

- [ ] **Step 7: 提交 Top250 筛选**

```bash
git add lib/features/rankings/screens/rankings_screen.dart test/features/rankings/rankings_screen_test.dart
git commit -m "feat: add Top250 filter sheet"
```

---

### Task 6: 格式化、回归验证与 ADB 样式验收

**Files:**
- Verify: `lib/core/widgets/pagination_controller.dart`
- Verify: `lib/core/widgets/movie_grid_view.dart`
- Verify: `lib/features/rankings/services/ranking_service.dart`
- Verify: `lib/features/rankings/screens/rankings_screen.dart`
- Verify: `test/core/widgets/pagination_controller_test.dart`
- Verify: `test/core/widgets/movie_grid_view_test.dart`
- Verify: `test/api_integration_test.dart`
- Verify: `test/features/rankings/rankings_screen_test.dart`

**Interfaces:**
- Consumes: Tasks 1-5 的最终代码。
- Produces: 测试、静态分析和 Android 设备视觉证据。

- [ ] **Step 1: 格式化本任务文件**

Run:

```bash
dart format \
  lib/core/widgets/pagination_controller.dart \
  lib/core/widgets/movie_grid_view.dart \
  lib/features/rankings/services/ranking_service.dart \
  lib/features/rankings/screens/rankings_screen.dart \
  test/core/widgets/pagination_controller_test.dart \
  test/core/widgets/movie_grid_view_test.dart \
  test/api_integration_test.dart \
  test/features/rankings/rankings_screen_test.dart
```

Expected: formatter exit 0。

- [ ] **Step 2: 运行聚焦回归测试**

Run:

```bash
flutter test \
  test/core/widgets/pagination_controller_test.dart \
  test/core/widgets/movie_grid_view_test.dart \
  test/features/rankings/rankings_screen_test.dart \
  test/api_integration_test.dart
```

Expected: PASS。

- [ ] **Step 3: 运行静态分析和完整测试**

Run: `flutter analyze`

Expected: `No issues found!`

Run: `flutter test`

Expected: PASS；若被与本任务无关的既有脏改动或环境权限阻断，记录精确失败测试和原因，不把它报告为本功能通过。

- [ ] **Step 4: 确认设备并启动应用**

使用 `mcp__adb_tool.get_packages` 确认 `xxx.porn.jdb`，使用 `mcp__adb_tool.execute_adb_shell_command` 执行：

```text
getprop sys.boot_completed
am start -n xxx.porn.jdb/.MainActivity
```

若设备未安装最新构建，运行 `flutter run -d <adb_tool 对应设备> --debug`，等待 Flutter 输出应用已启动后再继续。

- [ ] **Step 5: 用 adb_tool 完成 UI 路径**

依次调用：

1. `mcp__adb_tool.get_uilayout` 找到“排行榜”底栏坐标。
2. `input tap <排行榜中心坐标>`。
3. `mcp__adb_tool.get_screenshot` 保存排行榜首屏证据。
4. 通过 `get_uilayout` 和 `input tap` 依次打开看热播、有码、无码、欧美、FC2。
5. 在看热播截图确认“范围/高分/全部”和“周期/日榜/周榜/月榜”两行圆角标签。
6. 返回 Top250，点击语义为“筛选 Top250”的按钮。
7. 截图确认抽屉、拖动把手、类型/年份/起始排名/开关。
8. 点击“欧美”，再次获取 UI layout，确认抽屉仍存在。
9. 打开有码、无码、欧美并检查 UI layout 中不存在“演员月榜”。

- [ ] **Step 6: 检查最终差异**

Run:

```bash
git diff --check
git status --short
git log --oneline -6
```

Expected: 无空白错误；工作区只包含明确说明的任务修改，或在按任务提交后保持干净。
