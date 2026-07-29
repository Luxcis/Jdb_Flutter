# 影片网格默认详情导航实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 删除 `MovieGridView.onMovieTap`，让所有影片网格卡片固定通过 `/movie/:id` 打开影片详情页。

**Architecture:** 导航行为收敛到共享 `MovieGridView`，由网格在构建每张 `MovieCard` 时绑定 `context.push`。仓库内调用方不再决定网格影片的点击行为；独立使用 `MovieCard` 的场景保持不变。

**Tech Stack:** Flutter、Dart、Material 3、go_router、flutter_test

## Global Constraints

- 所有 `MovieGridView` 必须统一点击进入影片详情页，不保留 `onMovieTap` 兼容参数。
- 详情页必须使用 `push` 打开，以保留来源页面的 Tab、筛选、分页数据和滚动位置。
- 不修改 `MovieCard` 的通用点击回调能力。
- 不修改影片详情页的数据加载、布局或错误处理。
- 不新增依赖。
- 只暂存并提交本计划列出的文件，保留其他未提交改动。

---

## 文件结构

- `lib/core/widgets/movie_grid_view.dart`：拥有所有影片网格的固定详情导航行为，并删除旧的回调 API。
- `lib/features/actors/screens/actor_detail_screen.dart`：移除共享网格的旧回调参数和不再需要的路由导入。
- `lib/features/rankings/screens/rankings_screen.dart`：移除两个共享网格的旧回调参数；保留本文件其他独立导航。
- `test/core/widgets/movie_grid_view_test.dart`：验证共享网格点击真实影片卡片后进入正确详情路由。
- `test/features/categories/categories_screen_test.dart`：验证分类页使用共享默认导航，返回后原 Tab 网格仍保留。

### Task 1: 共享影片网格固定打开详情页

**Files:**
- Modify: `test/core/widgets/movie_grid_view_test.dart`
- Modify: `test/features/categories/categories_screen_test.dart`
- Modify: `lib/core/widgets/movie_grid_view.dart`
- Modify: `lib/features/actors/screens/actor_detail_screen.dart`
- Modify: `lib/features/rankings/screens/rankings_screen.dart`

**Interfaces:**
- Consumes: `MovieSummary.id`、`BuildContext`、现有路由 `/movie/:id`
- Produces: `MovieGridView({required PaginationController<MovieSummary> controller, bool showShuffle = false, int crossAxisCount = 3})`
- Produces: 点击任意网格内 `MovieCard` 时执行 `context.push('/movie/${movie.id}')`

- [ ] **Step 1: 在共享组件测试中写默认详情导航失败用例**

在 `test/core/widgets/movie_grid_view_test.dart` 增加 `go_router` 和 `MovieCard` 导入：

```dart
import 'package:go_router/go_router.dart';
import 'package:jade/core/widgets/movie_card.dart';
```

在现有测试组中增加：

```dart
testWidgets('点击影片卡片默认打开对应影片详情页', (tester) async {
  final movie = MovieSummary(
    id: 'movie-42',
    number: 'JDB-042',
    title: '默认导航影片',
    coverUrl: '',
  );
  final controller = PaginationController<MovieSummary>(
    fetch: (_) async => PagedResult(
      items: [movie],
      currentPage: 1,
      totalPages: 1,
      total: 1,
    ),
  );
  addTearDown(controller.dispose);
  await controller.fetchMore();

  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) =>
            Scaffold(body: MovieGridView(controller: controller)),
      ),
      GoRoute(
        path: '/movie/:id',
        builder: (context, state) =>
            Scaffold(body: Text('详情 ${state.pathParameters['id']}')),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.tap(find.byType(MovieCard));
  await tester.pumpAndSettle();

  expect(router.state.uri.path, '/movie/movie-42');
  expect(find.text('详情 movie-42'), findsOneWidget);
});
```

- [ ] **Step 2: 运行共享组件用例并确认红灯**

Run:

```bash
flutter test test/core/widgets/movie_grid_view_test.dart --plain-name "点击影片卡片默认打开对应影片详情页"
```

Expected: FAIL；点击后 `router.state.uri.path` 仍为 `/`，证明当前无默认导航。

- [ ] **Step 3: 在分类页测试中写导航和返回状态失败用例**

在 `test/features/categories/categories_screen_test.dart` 增加：

```dart
import 'package:go_router/go_router.dart';
```

在分类页测试组中增加：

```dart
testWidgets('点击分类影片进入详情且返回后保留当前网格', (tester) async {
  final source = _FakeSource();
  final router = GoRouter(
    initialLocation: '/categories',
    routes: [
      GoRoute(
        path: '/categories',
        builder: (context, state) => CategoriesPage(dataSource: source),
      ),
      GoRoute(
        path: '/movie/:id',
        builder: (context, state) =>
            Scaffold(body: Text('详情 ${state.pathParameters['id']}')),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pump();
  await tester.pump();

  await tester.tap(find.byType(MovieCard).first);
  await tester.pumpAndSettle();

  expect(router.state.uri.path, '/movie/0-1');
  expect(find.text('详情 0-1'), findsOneWidget);

  router.pop();
  await tester.pumpAndSettle();

  expect(router.state.uri.path, '/categories');
  expect(find.byKey(const Key('category-tab-grid-0')), findsOneWidget);
});
```

- [ ] **Step 4: 运行分类页用例并确认红灯**

Run:

```bash
flutter test test/features/categories/categories_screen_test.dart --plain-name "点击分类影片进入详情且返回后保留当前网格"
```

Expected: FAIL；点击后仍位于 `/categories`，证明分类页尚未获得详情导航。

- [ ] **Step 5: 在共享网格中实现固定导航并删除旧 API**

修改 `lib/core/widgets/movie_grid_view.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
```

将构造函数和字段收敛为：

```dart
const MovieGridView({
  super.key,
  required this.controller,
  this.showShuffle = false,
  this.crossAxisCount = 3,
});

final PaginationController<MovieSummary> controller;
final bool showShuffle;
final int crossAxisCount;
```

将 `SliverGrid.builder` 的 `itemBuilder` 改为：

```dart
itemBuilder: (context, index) {
  final movie = controller.items[index];
  return MovieCard(
    movie: movie,
    onTap: () => context.push('/movie/${movie.id}'),
  );
},
```

- [ ] **Step 6: 清理所有旧 `onMovieTap` 调用方**

在 `lib/features/actors/screens/actor_detail_screen.dart` 中把影片区域改为：

```dart
Expanded(child: MovieGridView(controller: _moviesController)),
```

若删除该回调后文件中已无其他 `go_router` API，删除：

```dart
import 'package:go_router/go_router.dart';
```

在 `lib/features/rankings/screens/rankings_screen.dart` 的热播网格和综合排行榜网格中都改为：

```dart
Expanded(child: MovieGridView(controller: _controller)),
```

该文件仍有独立 `MovieCard` 导航，保留 `go_router` 导入。

- [ ] **Step 7: 格式化改动文件**

Run:

```bash
dart format lib/core/widgets/movie_grid_view.dart lib/features/actors/screens/actor_detail_screen.dart lib/features/rankings/screens/rankings_screen.dart test/core/widgets/movie_grid_view_test.dart test/features/categories/categories_screen_test.dart
```

Expected: formatter exits with code 0.

- [ ] **Step 8: 运行两个新用例并确认绿灯**

Run:

```bash
flutter test test/core/widgets/movie_grid_view_test.dart --plain-name "点击影片卡片默认打开对应影片详情页"
flutter test test/features/categories/categories_screen_test.dart --plain-name "点击分类影片进入详情且返回后保留当前网格"
```

Expected: 两个命令均 PASS；共享网格进入 `/movie/movie-42`，分类页进入 `/movie/0-1` 且返回后恢复 `/categories`。

- [ ] **Step 9: 运行相关回归测试**

Run:

```bash
flutter test test/core/widgets/movie_grid_view_test.dart test/features/categories/categories_screen_test.dart test/features/rankings/rankings_screen_test.dart
```

Expected: 所有相关测试 PASS，且排行榜旧回调清理后无编译错误；演员详情调用方由后续 `flutter analyze` 覆盖编译检查。

- [ ] **Step 10: 运行全量验证**

Run:

```bash
flutter test
flutter analyze
git diff --check
```

Expected:

- `flutter test` 全部 PASS。
- `flutter analyze` 输出 `No issues found!`。
- `git diff --check` 无输出。

- [ ] **Step 11: 检查范围并提交**

Run:

```bash
git status --short
git diff -- lib/core/widgets/movie_grid_view.dart lib/features/actors/screens/actor_detail_screen.dart lib/features/rankings/screens/rankings_screen.dart test/core/widgets/movie_grid_view_test.dart test/features/categories/categories_screen_test.dart
```

只暂存这五个文件：

```bash
git add lib/core/widgets/movie_grid_view.dart lib/features/actors/screens/actor_detail_screen.dart lib/features/rankings/screens/rankings_screen.dart test/core/widgets/movie_grid_view_test.dart test/features/categories/categories_screen_test.dart
git commit -m "feat: open movie grid cards in detail"
```
