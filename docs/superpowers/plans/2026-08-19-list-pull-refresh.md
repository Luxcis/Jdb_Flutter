# 列表下拉刷新逻辑优化实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 统一所有列表的下拉刷新行为：下拉松手后保留旧列表，用顶部 loading 指示器表示刷新中，成功后整体替换为新数据并隐藏指示器。

**架构：** 修改 `PaginationController` 的刷新语义（用当次有效的 `_pendingRefresh` 标志替代一次性 `_replaceOnSuccess`，`refresh()` 默认保留内容），统一 5 处下拉刷新入口，并为 reviews/rankings 两处补充顶部 `LinearProgressIndicator`。

**技术栈：** Flutter / Dart，`ChangeNotifier` + `RefreshIndicator` + `LinearProgressIndicator`，`flutter_test`（含 `FakeAdapter`）。

**规格：** `docs/superpowers/specs/2026-08-19-list-pull-refresh-design.md`

---

## 文件结构

| 文件 | 职责 | 变更 |
| --- | --- | --- |
| `lib/core/widgets/pagination_controller.dart` | 分页状态核心；刷新语义（保留旧列表、当次替换） | 修改 |
| `lib/core/widgets/movie_grid_view.dart` | 影片网格 + 下拉刷新（约 15 个页面共用） | 修改 |
| `lib/core/widgets/actor_grid_view.dart` | 演员网格 + 下拉刷新（已正确） | 不改 |
| `lib/features/articles/screens/articles_screen.dart` | AV 资讯列表（已正确） | 不改 |
| `lib/features/reviews/screens/reviews_screen.dart` | 看短评列表 + 下拉刷新 | 修改 |
| `lib/features/rankings/screens/rankings_screen.dart` | 排行榜 Top250 列表 + 下拉刷新 | 修改 |
| `test/core/widgets/pagination_controller_test.dart` | 控制器刷新语义单测 | 修改 |
| `test/core/widgets/movie_grid_view_test.dart` | 网格下拉刷新 UI 单测 | 修改 |
| `test/features/reviews/reviews_screen_test.dart` | 看短评刷新 UI 单测 | 修改 |
| `test/features/rankings/rankings_screen_test.dart` | Top250 刷新 UI 单测 | 修改 |

---

### 任务 1：`PaginationController` 刷新语义——保留旧列表 + 当次替换

**文件：**
- 修改：`lib/core/widgets/pagination_controller.dart:6-85`
- 测试：`test/core/widgets/pagination_controller_test.dart`

- [ ] **步骤 1：编写失败的测试（连续多次 refresh 均保留 + 成功后替换）**

在 `test/core/widgets/pagination_controller_test.dart` 的 `main()` 末尾追加：

```dart
  test('连续多次 refresh 都保留旧内容并整体替换', () async {
    var requestCount = 0;
    final controller = PaginationController<int>(
      fetch: (_) async {
        requestCount++;
        if (requestCount == 1) return _page([1]);
        if (requestCount == 2) return _page([2]);
        return _page([3]);
      },
    );
    addTearDown(controller.dispose);
    await controller.fetchMore();

    await controller.refresh();
    expect(controller.items, [2]);
    expect(controller.isRefreshing, isFalse);

    await controller.refresh();
    expect(controller.items, [3]);
    expect(controller.isRefreshing, isFalse);
  });

  test('refresh 默认保留旧内容，成功后整体替换', () async {
    var requestCount = 0;
    final pending = Completer<PagedResult<int>>();
    final controller = PaginationController<int>(
      fetch: (_) {
        requestCount++;
        if (requestCount == 1) return Future.value(_page([1]));
        return pending.future;
      },
    );
    addTearDown(controller.dispose);
    await controller.fetchMore();

    final refresh = controller.refresh();
    expect(controller.items, [1]);
    expect(controller.isRefreshing, isTrue);

    pending.complete(_page([2]));
    await refresh;
    expect(controller.items, [2]);
    expect(controller.error, isNull);
    expect(controller.isRefreshing, isFalse);
  });
```

（第二个测试用 `Completer` 制造"刷新中保留旧内容"的时序断言；`refresh()` 会重新调用 `_fetch`，因此 fetch 闭包按请求次数区分：第一次返回 `[1]`，第二次返回 `pending.future`。）

- [ ] **步骤 2：运行测试验证失败**

运行：`flutter test test/core/widgets/pagination_controller_test.dart`
预期：FAIL——`refresh` 默认 `preserveItems=false`，`controller.refresh()` 后 `items` 被清空，`isRefreshing` 为 false；第二个用例 `requestCount` 首次调用即返回 `pending.future` 而非 `[1]`。

- [ ] **步骤 3：实现 `PaginationController` 变更**

修改 `lib/core/widgets/pagination_controller.dart`：

- 字段：删除 `bool _replaceOnSuccess = false;`，新增 `bool _pendingRefresh = false;`
- `fetchMore` 内替换逻辑（第 38-41 行）改为：

```dart
      _page = result.currentPage;
      if (_pendingRefresh) {
        _pendingRefresh = false;
        _items.clear();
      }
      _items.addAll(result.items);
      _hasMore = _page < result.totalPages;
```

- `reloadWith`（第 55-70 行）改为：

```dart
  Future<void> reloadWith(
    PageFetcher<T> fetch, {
    bool preserveItems = false,
  }) async {
    _generation++;
    _fetch = fetch;
    _page = 0;
    if (!preserveItems) _items.clear();
    _pendingRefresh = preserveItems && _items.isNotEmpty;
    _hasMore = true;
    _isLoading = false;
    _isRefreshing = false;
    _error = null;
    notifyListeners();
    await fetchMore();
  }
```

- `refresh`（第 72-73 行）改为：

```dart
  Future<void> refresh({bool preserveItems = true}) =>
      reloadWith(_fetch, preserveItems: preserveItems);
```

- [ ] **步骤 4：运行测试验证通过**

运行：`flutter test test/core/widgets/pagination_controller_test.dart`
预期：PASS（新增 2 个用例 + 原有 6 个用例全部通过；其中 `preserveItems 刷新在成功前保留旧内容并在成功后替换`、`refresh 可保留旧内容，失败后仍能重试替换` 用例兼容新实现）。

- [ ] **步骤 5：Commit**

```bash
git add lib/core/widgets/pagination_controller.dart test/core/widgets/pagination_controller_test.dart
git commit -m "feat(list): keep old items during pull-to-refresh and replace on success"
```

---

### 任务 2：`MovieGridView` 下拉刷新改为保留内容

**文件：**
- 修改：`lib/core/widgets/movie_grid_view.dart:47`
- 测试：`test/core/widgets/movie_grid_view_test.dart`

- [ ] **步骤 1：编写失败的测试（下拉刷新保留内容 + 顶部指示器显示/隐藏）**

在 `test/core/widgets/movie_grid_view_test.dart` 的 `main()` 末尾追加：

```dart
  testWidgets('下拉刷新保留旧列表并显示顶部指示器，成功后替换', (tester) async {
    var requestCount = 0;
    final pendingRefresh = Completer<PagedResult<MovieSummary>>();
    final firstMovie = MovieSummary(
      id: 'm1',
      number: 'ABC-001',
      title: '第一页影片',
      coverUrl: '',
    );
    final refreshedMovie = MovieSummary(
      id: 'm2',
      number: 'ABC-002',
      title: '刷新后影片',
      coverUrl: '',
    );
    final controller = PaginationController<MovieSummary>(
      fetch: (_) {
        requestCount++;
        if (requestCount == 1) {
          return Future.value(
            PagedResult(
              items: [firstMovie],
              currentPage: 1,
              totalPages: 1,
              total: 1,
            ),
          );
        }
        return pendingRefresh.future;
      },
    );
    addTearDown(controller.dispose);
    await controller.fetchMore();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: MovieGridView(controller: controller)),
      ),
    );
    expect(find.text('第一页影片'), findsOneWidget);

    final refresh = tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator))
        .onRefresh();
    await tester.pump();

    expect(find.text('第一页影片'), findsOneWidget);
    expect(find.byKey(const Key('movie-grid-refreshing')), findsOneWidget);
    expect(find.byKey(const Key('movie-grid-initial-loading')), findsNothing);

    pendingRefresh.complete(
      PagedResult(
        items: [refreshedMovie],
        currentPage: 1,
        totalPages: 1,
        total: 1,
      ),
    );
    await refresh;
    await tester.pump();

    expect(find.text('第一页影片'), findsNothing);
    expect(find.text('刷新后影片'), findsOneWidget);
    expect(find.byKey(const Key('movie-grid-refreshing')), findsNothing);
  });
```

- [ ] **步骤 2：运行测试验证失败**

运行：`flutter test test/core/widgets/movie_grid_view_test.dart`
预期：FAIL——`onRefresh` 传的是 `controller.refresh`（默认 `preserveItems=false`），刷新期间旧列表消失、出现 `movie-grid-initial-loading` 居中 loading。

- [ ] **步骤 3：实现 `MovieGridView` 变更**

修改 `lib/core/widgets/movie_grid_view.dart:47`：

```dart
          child: RefreshIndicator(
            onRefresh: () => controller.refresh(preserveItems: true),
```

- [ ] **步骤 4：运行测试验证通过**

运行：`flutter test test/core/widgets/movie_grid_view_test.dart`
预期：PASS（新增用例 + 原有 7 个用例全部通过）。

- [ ] **步骤 5：Commit**

```bash
git add lib/core/widgets/movie_grid_view.dart test/core/widgets/movie_grid_view_test.dart
git commit -m "feat(movie-grid): keep items during pull-to-refresh"
```

---

### 任务 3：`ReviewsPage` 下拉刷新保留内容 + 顶部指示器

**文件：**
- 修改：`lib/features/reviews/screens/reviews_screen.dart:120-121`
- 测试：`test/features/reviews/reviews_screen_test.dart`

- [ ] **步骤 1：编写失败的测试（下拉刷新保留内容 + 顶部指示器显示/隐藏）**

在 `test/features/reviews/reviews_screen_test.dart` 的 `main()` 末尾追加：

```dart
  testWidgets('下拉刷新保留短评列表并显示顶部指示器，成功后替换', (tester) async {
    final adapter = await _pumpReviews(tester);
    adapter.responseDelay = const Duration(milliseconds: 200);
    adapter.enqueueSequence(
      Endpoints.reviewsHotly,
      [_pageResponse(1), _pageResponse(1, start: 1)],
    );
    await _pumpUntil(tester, () => find.byType(ReviewTile).evaluate().isNotEmpty);
    expect(find.text('内容0'), findsOneWidget);

    final refresh = tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator))
        .onRefresh();
    await tester.pump();

    expect(find.text('内容0'), findsOneWidget);
    expect(find.byKey(const Key('reviews-refreshing')), findsOneWidget);

    adapter.responseDelay = Duration.zero;
    await _pumpUntil(
      tester,
      () => adapter.requests.length >= 2,
    );

    expect(find.text('内容0'), findsNothing);
    expect(find.text('内容1'), findsOneWidget);
    expect(find.byKey(const Key('reviews-refreshing')), findsNothing);
  });
```

- [ ] **步骤 2：运行测试验证失败**

运行：`flutter test test/features/reviews/reviews_screen_test.dart`
预期：FAIL——`onRefresh` 用 `_controller.refresh`（默认清空），刷新期间旧列表消失；且不存在 `Key('reviews-refreshing')`。

- [ ] **步骤 3：实现 `ReviewsPage` 变更**

修改 `lib/features/reviews/screens/reviews_screen.dart`：

- 第 120-121 行改为：

```dart
        return RefreshIndicator(
          onRefresh: () => _controller.refresh(preserveItems: true),
```

- 将 `RefreshIndicator` 的 child 由 `NotificationListener` 改为 `Stack`（与 `MovieGridView` 模式一致）：在 `ListView.separated` 外包一层 `Stack`，并在其后追加顶部指示器：

```dart
          child: Stack(
            children: [
              NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification is ScrollEndNotification &&
                      notification.metrics.extentAfter < 200 &&
                      _controller.error == null) {
                    _controller.fetchMore();
                  }
                  return false;
                },
                child: ListView.separated(
                  key: Key('hot-reviews-${widget.period.value}'),
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: _controller.items.length + (showFooter ? 1 : 0),
                  separatorBuilder: (_, _) => const Divider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                  ),
                  itemBuilder: (context, index) {
                    if (index == _controller.items.length) {
                      if (_controller.isLoading) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      return Center(
                        child: TextButton.icon(
                          onPressed: _controller.fetchMore,
                          icon: const Icon(Icons.refresh),
                          label: const Text('加载失败，点击重试'),
                        ),
                      );
                    }
                    return ReviewTile(review: _controller.items[index]);
                  },
                ),
              ),
              if (_controller.isRefreshing)
                const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(
                    key: Key('reviews-refreshing'),
                  ),
                ),
            ],
          ),
```

注意：修改后需将 `showFooter` 变量定义保留在 `RefreshIndicator` 之前（`final showFooter = _controller.isLoading || _controller.error != null;`），其余代码不变。

- [ ] **步骤 4：运行测试验证通过**

运行：`flutter test test/features/reviews/reviews_screen_test.dart`
预期：PASS（新增用例 + 原有 5 个用例全部通过）。

- [ ] **步骤 5：Commit**

```bash
git add lib/features/reviews/screens/reviews_screen.dart test/features/reviews/reviews_screen_test.dart
git commit -m "feat(reviews): keep items during pull-to-refresh with top indicator"
```

---

### 任务 4：`RankingsPage` Top250 下拉刷新保留内容 + 顶部指示器

**文件：**
- 修改：`lib/features/rankings/screens/rankings_screen.dart:248-282`
- 测试：`test/features/rankings/rankings_screen_test.dart`

- [ ] **步骤 1：编写失败的测试（Top250 下拉刷新保留内容 + 顶部指示器）**

在 `test/features/rankings/rankings_screen_test.dart` 的 `main()` 末尾追加：

```dart
  testWidgets('Top250 下拉刷新保留列表并显示顶部指示器', (tester) async {
    final fixture = await _pumpRankings(
      tester,
      initialTabIndex: 0,
      responseDelay: const Duration(milliseconds: 200),
      top250Responses: [
        {
          'success': 1,
          'data': {
            'movies': [
              {
                'id': 'top-1',
                'number': 'TOP-1',
                'title': 'First Movie',
                'cover_url': 'cover.jpg',
              },
            ],
            'current_page': 1,
            'total_pages': 1,
            'total': 1,
          },
        },
        {
          'success': 1,
          'data': {
            'movies': [
              {
                'id': 'top-2',
                'number': 'TOP-2',
                'title': 'Second Movie',
                'cover_url': 'cover.jpg',
              },
            ],
            'current_page': 1,
            'total_pages': 1,
            'total': 1,
          },
        },
      ],
    );
    await _pumpRankingFrame(tester);
    expect(find.text('First Movie'), findsOneWidget);

    final refresh = tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator))
        .onRefresh();
    await tester.pump();

    expect(find.text('First Movie'), findsOneWidget);
    expect(find.byKey(const Key('top250-refreshing')), findsOneWidget);

    fixture.adapter.responseDelay = Duration.zero;
    await _pumpRankingFrame(tester);

    expect(find.text('First Movie'), findsNothing);
    expect(find.text('Second Movie'), findsOneWidget);
    expect(find.byKey(const Key('top250-refreshing')), findsNothing);
  });
```

注意：`top250Responses` 传入 `_pumpRankings` 时按入队顺序返回，`enqueueSequence` 耗尽后回退到 `enqueue`（无 stub 时返回 `{'success': 0}`），因此刷新恰好消费第二份响应。

- [ ] **步骤 2：运行测试验证失败**

运行：`flutter test test/features/rankings/rankings_screen_test.dart`
预期：FAIL——`onRefresh` 用 `_controller.refresh`（默认清空），刷新期间旧列表消失；且不存在 `Key('top250-refreshing')`。

- [ ] **步骤 3：实现 `RankingsPage` 变更**

修改 `lib/features/rankings/screens/rankings_screen.dart`：

- 第 248-249 行改为：

```dart
        return RefreshIndicator(
          onRefresh: () => _controller.refresh(preserveItems: true),
```

- 将 `RefreshIndicator` 的 child 由 `NotificationListener` 改为 `Stack`（与 `MovieGridView` 模式一致）：在 `ListView.builder` 外包一层 `Stack`，并在其后追加顶部指示器：

```dart
          child: Stack(
            children: [
              NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification is ScrollEndNotification &&
                      notification.metrics.extentAfter < 200 &&
                      _controller.error == null) {
                    _controller.fetchMore();
                  }
                  return false;
                },
                child: ListView.builder(
                  key: const Key('top250-list'),
                  physics: const AlwaysScrollableScrollPhysics(),
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
                ),
              ),
              if (_controller.isRefreshing)
                const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(
                    key: Key('top250-refreshing'),
                  ),
                ),
            ],
          ),
```

注意：修改后需将 `showFooter` 变量定义保留在 `RefreshIndicator` 之前（`final showFooter = _controller.isLoading || (_controller.error != null && _controller.items.isNotEmpty);`），其余代码不变。

- [ ] **步骤 4：运行测试验证通过**

运行：`flutter test test/features/rankings/rankings_screen_test.dart`
预期：PASS（新增用例 + 原有 12 个用例全部通过）。

- [ ] **步骤 5：Commit**

```bash
git add lib/features/rankings/screens/rankings_screen.dart test/features/rankings/rankings_screen_test.dart
git commit -m "feat(rankings): keep items during pull-to-refresh with top indicator"
```

---

### 任务 5：全量验证

- [ ] **步骤 1：运行全部测试**

运行：`flutter test`
预期：PASS（全部用例通过，无超时失败）。

- [ ] **步骤 2：静态分析**

运行：`dart analyze`
预期：No issues found（无新增告警；若 `dart` 不可用则运行 `flutter analyze`）。

- [ ] **步骤 3：Commit（若存在未提交的格式调整）**

```bash
git status --short
git add -A
git commit -m "chore: format after pull-to-refresh changes"
```

（仅当 `git status` 有输出时执行；无输出则跳过本步。）
