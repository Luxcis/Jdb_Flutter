# Top250 Infinite Scroll Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让 Top250 保持现有单列排行榜样式，并在接近列表底部时按 `start_rank` 自动追加后续排名，直至第 250 名。

**Architecture:** 复用现有 `PaginationController<MovieSummary>` 的串行加载、错误和请求代际隔离能力，在 `_Top250TabState` 中把逻辑页码映射为每 50 名递增的 `start_rank`。Top250 页面用滚动通知触发 `fetchMore()`，并单独渲染追加加载、追加失败重试状态；服务层和共享分页控制器不加入 Top250 专用逻辑。

**Tech Stack:** Flutter、Dart、Provider、Dio、GoRouter、`flutter_test`、现有 `FakeAdapter`

## Global Constraints

- `/api/v1/movies/top` 每批最多请求 50 条，只使用 `start_rank` 控制范围，不发送 `page`。
- 选择起始排名 1/51/101/151/201 后，从该排名继续加载，最多到第 250 名。
- 距离底部约 200 逻辑像素时自动加载。
- 追加加载或失败时保留现有列表；失败提供底部重试入口。
- 下拉刷新、筛选变化和登录状态变化继续使用现有请求代际隔离。
- 保持现有单列布局、筛选抽屉、影片详情导航和其他排行榜 Tab 行为。
- 遵循 Material Design 3、系统明暗主题和 Feature-First 结构。
- 用户文案直接使用中文硬编码，不新增 ARB 或本地化依赖。
- 不新增依赖，不使用触觉反馈。

---

## File Map

- `lib/features/rankings/screens/rankings_screen.dart`
  - 将 Top250 逻辑页映射为实际 `start_rank`。
  - 监听接近列表底部事件。
  - 展示追加加载和追加失败重试 footer。
- `test/features/rankings/rankings_screen_test.dart`
  - 为测试夹具增加可配置的 Top250 响应序列。
  - 覆盖自动追加、起始排名、250 边界、短页、加载 footer 和失败重试。
- `test/api_integration_test.dart`
  - 仅作为现有接口契约回归验证；不需要修改，既有测试已断言 `limit=50` 且请求不含 `page`。

### Task 1: Top250 排名范围分页与自动追加

**Files:**
- Modify: `test/features/rankings/rankings_screen_test.dart`
- Modify: `lib/features/rankings/screens/rankings_screen.dart:156-245`

**Interfaces:**
- Consumes: `PaginationController<MovieSummary>.fetchMore()`、`RankingService.getTop250({int startRank, String type, String typeValue, bool ignoreWatched, int limit})`
- Produces: `_Top250TabState._fetchPage(int page)` 返回本地逻辑分页的 `PagedResult<MovieSummary>`；Top250 列表使用 `Key('top250-list')` 和 `Key('top250-loading-more')`

- [ ] **Step 1: 为测试夹具增加 Top250 多页响应构造器**

在测试 import 区加入：

```dart
import 'package:jade/core/widgets/movie_list_tile.dart';
```

在 `test/features/rankings/rankings_screen_test.dart` 的夹具定义前加入：

```dart
Map<String, dynamic> _top250Response(int startRank, int count) => {
  'success': 1,
  'data': {
    'movies': [
      for (var index = 0; index < count; index++)
        {
          'id': 'top-${startRank + index}',
          'number': 'TOP-${startRank + index}',
          'title': 'Top Movie ${startRank + index}',
          'cover_url': 'cover.jpg',
        },
    ],
  },
};
```

给 `_pumpRankings` 增加可选参数，并在注册 `Endpoints.moviesTop` 默认响应前优先配置序列：

```dart
Future<_RankingFixture> _pumpRankings(
  WidgetTester tester, {
  Duration responseDelay = Duration.zero,
  bool loggedIn = true,
  double textScaleFactor = 1,
  bool withRouter = false,
  int initialTabIndex = 0,
  List<Map<String, dynamic>>? top250Responses,
}) async {
  if (top250Responses != null) {
    adapter.enqueueSequence(
      Endpoints.moviesTop,
      top250Responses,
    );
  } else {
    adapter.enqueue(Endpoints.moviesTop, {
      'success': 1,
      'data': {
        'movies': [
          {
            'id': 'top-movie',
            'number': 'ABC-001',
            'title': 'Ranked Movie',
            'cover_url': 'cover.jpg',
          },
        ],
        'current_page': 1,
        'total_pages': 1,
        'total': 1,
      },
    });
  }
  for (final path in [
    Endpoints.rankingsPlayback,
    Endpoints.rankings,
  ]) {
    adapter.enqueue(path, {
      'success': 1,
      'data': {
        'movies': [
          {
            'id': path == Endpoints.rankingsPlayback
                ? 'hot-movie'
                : 'ranked-movie',
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
}
```

- [ ] **Step 2: 写自动追加与加载 footer 的失败测试**

在排行榜 Widget 测试中加入：

```dart
testWidgets('Top250 滚动接近底部后按排名追加下一批', (tester) async {
  final fixture = await _pumpRankings(
    tester,
    top250Responses: [
      _top250Response(1, 50),
      _top250Response(51, 50),
    ],
  );
  await _pumpRankingFrame(tester);
  fixture.adapter.responseDelay = const Duration(seconds: 1);

  await tester.drag(
    find.byKey(const Key('top250-list')),
    const Offset(0, -10000),
  );
  await tester.pump();

  expect(find.text('Top Movie 50'), findsOneWidget);
  expect(find.byKey(const Key('top250-loading-more')), findsOneWidget);
  expect(
    fixture.adapter.requests
        .where((request) => request.path == Endpoints.moviesTop)
        .last
        .uri
        .queryParameters['start_rank'],
    '51',
  );

  await tester.pump(const Duration(seconds: 1));
  await _pumpRankingFrame(tester);
  await tester.drag(
    find.byKey(const Key('top250-list')),
    const Offset(0, -200),
  );
  await tester.pump();
  expect(find.text('Top Movie 51'), findsOneWidget);
});
```

- [ ] **Step 3: 运行测试并确认因尚未分页而失败**

Run:

```bash
flutter test test/features/rankings/rankings_screen_test.dart --plain-name "Top250 滚动接近底部后按排名追加下一批"
```

Expected: FAIL，找不到 `top250-list` 或 `top250-loading-more`，且没有发出 `start_rank=51` 的第二次请求。

- [ ] **Step 4: 实现逻辑页到排名范围的映射**

在 `_Top250TabState` 中加入常量，并让 `_fetchPage` 使用传入页码：

```dart
static const _pageSize = 50;
static const _maxRank = 250;

int get _logicalTotalPages =>
    ((_maxRank - widget.filter.startRank + 1) / _pageSize).ceil();

Future<PagedResult<MovieSummary>> _fetchPage(int page) async {
  final api = ApiClient.instanceOrNull;
  if (api == null) return _emptyMoviePage(page: page);
  final result = await RankingService(api).getTop250(
    startRank: widget.filter.startRank + (page - 1) * _pageSize,
    type: widget.filter.type,
    typeValue: widget.filter.typeValue,
    ignoreWatched: widget.filter.ignoreWatched,
    limit: _pageSize,
  );
  final isLastPage =
      result.items.length < _pageSize || page >= _logicalTotalPages;
  return PagedResult(
    items: result.items,
    currentPage: page,
    totalPages: isLastPage ? page : _logicalTotalPages,
    total: _maxRank - widget.filter.startRank + 1,
  );
}
```

该本地 `currentPage` 必须从 1 开始，与 `PaginationController` 的 `_page + 1` 一致；不要使用接口响应中的 `current_page` 或发送 `page`。

- [ ] **Step 5: 实现滚动触发和追加加载 footer**

把 Top250 的 `RefreshIndicator` 包在滚动通知中，并给列表增加一个 footer 位置：

```dart
return NotificationListener<ScrollNotification>(
  onNotification: (notification) {
    if (notification is ScrollEndNotification &&
        notification.metrics.extentAfter < 200) {
      _controller.fetchMore();
    }
    return false;
  },
  child: RefreshIndicator(
    onRefresh: _controller.refresh,
    child: ListView.builder(
      key: const Key('top250-list'),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount:
          _controller.items.length + (_controller.isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _controller.items.length) {
          return const Padding(
            key: Key('top250-loading-more'),
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final movie = _controller.items[index];
        return MovieListTile(
          movie: movie,
          rank: widget.filter.startRank + index,
          onTap: () => context.push('/movie/${movie.id}'),
        );
      },
    ),
  ),
);
```

首次加载仍由 build 前面的居中进度环分支处理，因此 footer 只会在已有列表时出现。

- [ ] **Step 6: 运行聚焦测试并确认通过**

Run:

```bash
dart format lib/features/rankings/screens/rankings_screen.dart test/features/rankings/rankings_screen_test.dart
flutter test test/features/rankings/rankings_screen_test.dart --plain-name "Top250 滚动接近底部后按排名追加下一批"
```

Expected: PASS。

- [ ] **Step 7: 提交核心自动加载**

```bash
git add lib/features/rankings/screens/rankings_screen.dart test/features/rankings/rankings_screen_test.dart
git commit -m "feat: add Top250 infinite scrolling"
```

### Task 2: Top250 停止边界与追加失败重试

**Files:**
- Modify: `test/features/rankings/rankings_screen_test.dart`
- Modify: `lib/features/rankings/screens/rankings_screen.dart:210-260`

**Interfaces:**
- Consumes: Task 1 的 `Key('top250-list')`、逻辑分页返回值和 `PaginationController.error`
- Produces: `_Top250LoadMoreError` 私有 Widget；重试入口 `Key('top250-load-more-retry')`

- [ ] **Step 1: 写短页与第 201 名边界测试**

加入两个 Widget 测试：

```dart
testWidgets('Top250 首批不足 50 条时不再请求', (tester) async {
  final fixture = await _pumpRankings(
    tester,
    top250Responses: [_top250Response(1, 10)],
  );
  await _pumpRankingFrame(tester);
  await tester.drag(
    find.byKey(const Key('top250-list')),
    const Offset(0, -10000),
  );
  await _pumpRankingFrame(tester);

  expect(
    fixture.adapter.requests.where(
      (request) => request.path == Endpoints.moviesTop,
    ),
    hasLength(1),
  );
});

testWidgets('Top250 从 201 开始时加载一批后停止', (tester) async {
  final fixture = await _pumpRankings(
    tester,
    top250Responses: [
      _top250Response(1, 1),
      _top250Response(201, 50),
    ],
  );
  await _pumpRankingFrame(tester);
  await tester.tap(find.byTooltip('筛选 Top250'));
  await tester.pump();
  await _scrollFilterSheetToBottom(tester);
  await tester.tap(find.widgetWithText(ChoiceChip, '201'));
  await _pumpRankingFrame(tester);
  await tester.tapAt(const Offset(8, 8));
  await tester.pump();

  await tester.drag(
    find.byKey(const Key('top250-list')),
    const Offset(0, -10000),
  );
  await _pumpRankingFrame(tester);

  final topRequests = fixture.adapter.requests.where(
    (request) => request.path == Endpoints.moviesTop,
  );
  expect(topRequests, hasLength(2));
  expect(
    topRequests.last.uri.queryParameters['start_rank'],
    '201',
  );
});

testWidgets('Top250 从 51 开始时继续请求 101 且排名连续', (tester) async {
  final fixture = await _pumpRankings(
    tester,
    top250Responses: [
      _top250Response(1, 1),
      _top250Response(51, 50),
      _top250Response(101, 50),
    ],
  );
  await _pumpRankingFrame(tester);
  await tester.tap(find.byTooltip('筛选 Top250'));
  await tester.pump();
  await _scrollFilterSheetToBottom(tester);
  await tester.tap(find.widgetWithText(ChoiceChip, '51'));
  await _pumpRankingFrame(tester);
  await tester.tapAt(const Offset(8, 8));
  await tester.pump();

  await tester.drag(
    find.byKey(const Key('top250-list')),
    const Offset(0, -10000),
  );
  await _pumpRankingFrame(tester);
  await tester.drag(
    find.byKey(const Key('top250-list')),
    const Offset(0, -200),
  );
  await tester.pump();

  final startRanks = fixture.adapter.requests
      .where((request) => request.path == Endpoints.moviesTop)
      .map((request) => request.uri.queryParameters['start_rank'])
      .toList();
  expect(startRanks, ['1', '51', '101']);
  expect(find.text('Top Movie 101'), findsOneWidget);
  final appendedTile = find.ancestor(
    of: find.text('Top Movie 101'),
    matching: find.byType(MovieListTile),
  );
  expect(
    tester.widget<RatingBadge>(
      find.descendant(
        of: appendedTile,
        matching: find.byType(RatingBadge),
      ),
    ).rank,
    101,
  );
});
```

- [ ] **Step 2: 写追加失败保留列表并重试同一批的测试**

```dart
testWidgets('Top250 追加失败时保留列表并可重试同一批', (tester) async {
  final fixture = await _pumpRankings(
    tester,
    top250Responses: [
      _top250Response(1, 50),
      {'success': 0, 'message': 'next page failed'},
      _top250Response(51, 50),
    ],
  );
  await _pumpRankingFrame(tester);

  await tester.drag(
    find.byKey(const Key('top250-list')),
    const Offset(0, -10000),
  );
  await _pumpRankingFrame(tester);

  expect(find.text('Top Movie 50'), findsOneWidget);
  expect(find.byKey(const Key('top250-load-more-retry')), findsOneWidget);

  await tester.tap(find.byKey(const Key('top250-load-more-retry')));
  await _pumpRankingFrame(tester);
  await tester.drag(
    find.byKey(const Key('top250-list')),
    const Offset(0, -200),
  );
  await tester.pump();

  final startRanks = fixture.adapter.requests
      .where((request) => request.path == Endpoints.moviesTop)
      .map((request) => request.uri.queryParameters['start_rank'])
      .toList();
  expect(startRanks, ['1', '51', '51']);
  expect(find.text('Top Movie 51'), findsOneWidget);
});
```

- [ ] **Step 3: 运行新增测试并确认失败点**

Run:

```bash
flutter test test/features/rankings/rankings_screen_test.dart --plain-name "Top250 追加失败时保留列表并可重试同一批"
```

Expected: FAIL，已有列表仍显示，但找不到 `top250-load-more-retry`。

- [ ] **Step 4: 增加追加失败 footer**

将 Top250 `ListView.builder` 的 footer 条件改为加载中或已有数据时发生错误：

```dart
final showFooter =
    _controller.isLoading ||
    (_controller.error != null && _controller.items.isNotEmpty);

// ListView.builder:
itemCount: _controller.items.length + (showFooter ? 1 : 0),
itemBuilder: (context, index) {
  if (index == _controller.items.length) {
    if (_controller.isLoading) {
      return const Padding(
        key: Key('top250-loading-more'),
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return _Top250LoadMoreError(onRetry: _controller.fetchMore);
  }
  final movie = _controller.items[index];
  return MovieListTile(
    movie: movie,
    rank: widget.filter.startRank + index,
    onTap: () => context.push('/movie/${movie.id}'),
  );
},
```

在 `_Top250Tab` 之后增加私有 Widget：

```dart
class _Top250LoadMoreError extends StatelessWidget {
  const _Top250LoadMoreError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton.icon(
        key: const Key('top250-load-more-retry'),
        onPressed: onRetry,
        icon: const Icon(Icons.refresh),
        label: const Text('加载失败，点击重试'),
      ),
    );
  }
}
```

`fetchMore()` 在请求失败时不会推进内部页码，因此点击重试会再次请求相同的 `start_rank`。

- [ ] **Step 5: 运行 Top250 新增测试与现有排行榜回归测试**

Run:

```bash
dart format lib/features/rankings/screens/rankings_screen.dart test/features/rankings/rankings_screen_test.dart
flutter test test/features/rankings/rankings_screen_test.dart
flutter test test/api_integration_test.dart --plain-name "GET /api/v1/movies/top → 使用 Top250 专用筛选参数"
```

Expected: 全部 PASS；接口测试继续确认 `limit=50` 且没有 `page`。

- [ ] **Step 6: 提交边界与错误恢复**

```bash
git add lib/features/rankings/screens/rankings_screen.dart test/features/rankings/rankings_screen_test.dart
git commit -m "feat: handle Top250 pagination boundaries"
```

### Task 3: 静态检查、全量回归与 Android 实机样式验证

**Files:**
- Verify: `lib/features/rankings/screens/rankings_screen.dart`
- Verify: `test/features/rankings/rankings_screen_test.dart`
- Verify: `test/api_integration_test.dart`

**Interfaces:**
- Consumes: Task 1–2 的完整 Top250 无限滚动实现
- Produces: 静态分析、全量测试和 ADB 交互验证证据

- [ ] **Step 1: 检查格式和静态分析**

Run:

```bash
dart format --output=none --set-exit-if-changed lib/features/rankings/screens/rankings_screen.dart test/features/rankings/rankings_screen_test.dart
flutter analyze
```

Expected: 格式检查退出码 0，`flutter analyze` 输出 `No issues found!`。

- [ ] **Step 2: 运行全量测试**

Run:

```bash
flutter test
```

Expected: 所有测试 PASS，既有排行榜详情导航、筛选抽屉和其他 Tab 测试不回归。

- [ ] **Step 3: 使用 adb_tool 验证交互和样式**

在已连接的 Android 模拟器或设备上执行：

1. 启动当前工作区应用并进入“排行榜 → Top250”。
2. 确认首批加载时显示进度环，完成后列表正常展示且影片点击仍进入详情页。
3. 连续向上滑动至首批底部，确认旧影片不消失，底部短暂显示进度环，随后追加后续影片。
4. 打开筛选抽屉选择“起始排名 201”，关闭抽屉后滑动到底，确认不会继续发起第 251 名请求。
5. 截取 Top250 首批列表和追加加载后列表画面，检查无空白闪烁、无布局溢出、底部导航未遮挡内容。

- [ ] **Step 4: 检查最终提交范围**

Run:

```bash
git status --short
git log --oneline -3
```

Expected: 仅存在计划允许的文件变更；Task 1、Task 2 提交均位于当前分支，用户无关改动未被暂存或提交。
