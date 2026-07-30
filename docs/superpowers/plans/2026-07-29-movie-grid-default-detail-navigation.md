# 影片卡片默认详情导航实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 删除 `MovieCard.onTap` 和 `MovieGridView.onMovieTap`，让所有影片卡片固定通过 `/movie/:id` 打开影片详情页。

**Architecture:** 导航行为由基础组件 `MovieCard` 统一拥有，卡片使用自身 `MovieSummary.id` 执行 `context.push`。网格、首页和影片详情页只负责提供影片数据，不再传递或覆盖影片卡片点击回调。

**Tech Stack:** Flutter、Dart、Material 3、go_router、flutter_test

## Global Constraints

- 所有 `MovieCard` 必须统一点击进入影片详情页，不保留 `onTap` 兼容参数。
- 所有 `MovieGridView` 不保留 `onMovieTap` 参数，也不得直接调用路由或向卡片传入点击回调。
- 详情页必须使用 `push` 打开，以保留来源页面的 Tab、筛选、分页数据和滚动位置。
- 不修改 `MovieListTile`、演员卡片或其他非 `MovieCard` 组件的点击行为。
- 不修改影片详情页的数据加载、布局或错误处理。
- 不新增依赖。
- 只暂存并提交本计划列出的文件，保留其他未提交改动。

---

## 当前分支状态

分支已在提交 `79e724e` 中删除 `MovieGridView.onMovieTap`，并暂时由 `MovieGridView` 向 `MovieCard.onTap` 传入详情导航。本计划继续把该导航下沉到 `MovieCard`，同时清理所有剩余回调。

## 文件结构

- `lib/core/widgets/movie_card.dart`：拥有所有影片卡片的固定详情导航，并删除 `onTap` API。
- `lib/core/widgets/movie_grid_view.dart`：只负责分页和网格布局，不再导入或调用路由。
- `lib/features/home/screens/home_screen.dart`：首页影片网格只构建 `MovieCard`。
- `lib/features/movie_detail/screens/movie_detail_screen.dart`：相关推荐卡片删除 `onMovieTap` 参数传递链。
- `test/core/widgets/movie_card_test.dart`：直接验证独立 `MovieCard` 的默认详情导航。
- `test/core/widgets/movie_grid_view_test.dart`：保留网格集成导航和滚动分页回归测试。
- `test/features/categories/categories_screen_test.dart`：保留分类页进入详情及返回状态测试。

### Task 1: 将默认详情导航下沉到 `MovieCard`

**Files:**
- Modify: `test/core/widgets/movie_card_test.dart`
- Modify: `lib/core/widgets/movie_card.dart`
- Modify: `lib/core/widgets/movie_grid_view.dart`
- Modify: `lib/features/home/screens/home_screen.dart`
- Modify: `lib/features/movie_detail/screens/movie_detail_screen.dart`

**Interfaces:**
- Consumes: `MovieSummary.id`、`BuildContext`、现有路由 `/movie/:id`
- Produces: `MovieCard({required MovieSummary movie, bool showTitle = true})`
- Produces: `MovieGridView({required PaginationController<MovieSummary> controller, bool showShuffle = false, int crossAxisCount = 3})`
- Produces: 点击任意 `MovieCard` 时执行 `context.push('/movie/${movie.id}')`

- [ ] **Step 1: 用默认导航测试替换旧自定义回调测试**

在 `test/core/widgets/movie_card_test.dart` 增加：

```dart
import 'package:go_router/go_router.dart';
```

删除旧测试：

```dart
testWidgets('MovieCard onTap 回调', (tester) async {
  var tapped = false;
  final movie = MovieSummary(
    id: '1',
    number: 'ABC-001',
    title: 'Tap Me',
    coverUrl: 'x.jpg',
  );
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: MovieCard(movie: movie, onTap: () => tapped = true),
      ),
    ),
  );
  await tester.tap(find.text('Tap Me'));
  expect(tapped, isTrue);
});
```

替换为真实路由测试：

```dart
testWidgets('MovieCard 点击后默认打开对应影片详情页', (tester) async {
  final movie = MovieSummary(
    id: 'movie-42',
    number: 'JDB-042',
    title: '默认导航影片',
    coverUrl: '',
  );
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) =>
            Scaffold(body: MovieCard(movie: movie)),
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
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump();

  expect(router.state.uri.path, '/movie/movie-42');
  expect(find.text('详情 movie-42'), findsOneWidget);
});
```

- [ ] **Step 2: 运行独立卡片测试并确认红灯**

Run:

```bash
flutter test test/core/widgets/movie_card_test.dart --plain-name "MovieCard 点击后默认打开对应影片详情页"
```

Expected: FAIL；点击后 `router.state.uri.path` 仍为 `/`，证明导航仍只存在于网格调用方。

- [ ] **Step 3: 在 `MovieCard` 中实现固定详情导航并删除旧 API**

修改 `lib/core/widgets/movie_card.dart` 的导入：

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
```

将构造函数和字段改为：

```dart
const MovieCard({
  super.key,
  required this.movie,
  this.showTitle = true,
});

final MovieSummary movie;
final bool showTitle;
```

将点击行为改为：

```dart
return GestureDetector(
  onTap: () => context.push('/movie/${movie.id}'),
  child: Card(
    // 保持现有卡片布局不变。
  ),
);
```

- [ ] **Step 4: 让 `MovieGridView` 只构建默认卡片**

在 `lib/core/widgets/movie_grid_view.dart` 删除：

```dart
import 'package:go_router/go_router.dart';
```

将网格 `itemBuilder` 改为：

```dart
itemBuilder: (context, index) =>
    MovieCard(movie: controller.items[index]),
```

网格不得再设置 `MovieCard.onTap` 或直接执行 `context.push`。

- [ ] **Step 5: 清理首页的重复卡片回调**

在 `lib/features/home/screens/home_screen.dart` 的 `_buildGrid` 中改为：

```dart
delegate: SliverChildBuilderDelegate(
  (_, index) => MovieCard(movie: items[index]),
  childCount: items.length > 9 ? 9 : items.length,
),
```

本文件仍有其他详情导航调用，保留 `go_router` 导入。

- [ ] **Step 6: 删除影片详情页的 `onMovieTap` 参数传递链**

在 `MovieDetailPage` 构建 `_MovieDetailTabs` 时删除：

```dart
onMovieTap: (movie) => context.push('/movie/${movie.id}'),
```

从 `_MovieDetailTabs` 的构造函数和字段中删除：

```dart
required this.onMovieTap,
final ValueChanged<MovieSummary> onMovieTap;
```

构建 `_BasicInfoTab` 时不再传递 `onMovieTap`：

```dart
_BasicInfoTab(
  detail: detail,
  onSaveToList: onSaveToList,
  onActorTap: onActorTap,
),
```

从 `_BasicInfoTab` 的构造函数和字段中删除：

```dart
required this.onMovieTap,
final ValueChanged<MovieSummary> onMovieTap;
```

两个相关推荐分区改为：

```dart
_MovieRowSection(title: 'TA还出演过', movies: detail.actorMovies)
```

```dart
_MovieRowSection(title: '你可能也喜欢', movies: detail.relativeMovies)
```

将 `_MovieRowSection` 收敛为：

```dart
const _MovieRowSection({
  required this.title,
  required this.movies,
});

final String title;
final List<MovieSummary> movies;
```

卡片构建改为：

```dart
child: MovieCard(
  movie: movies[index],
  showTitle: false,
),
```

本文件仍有演员和认证等其他导航用途，保留 `go_router` 导入。

- [ ] **Step 7: 格式化本次调整文件**

Run:

```bash
dart format lib/core/widgets/movie_card.dart lib/core/widgets/movie_grid_view.dart lib/features/home/screens/home_screen.dart lib/features/movie_detail/screens/movie_detail_screen.dart test/core/widgets/movie_card_test.dart
```

Expected: formatter exits with code 0.

- [ ] **Step 8: 运行独立卡片测试并确认绿灯**

Run:

```bash
flutter test test/core/widgets/movie_card_test.dart --plain-name "MovieCard 点击后默认打开对应影片详情页"
```

Expected: PASS；独立卡片进入 `/movie/movie-42`。

- [ ] **Step 9: 运行卡片、网格和来源页面相关回归测试**

Run:

```bash
flutter test test/core/widgets/movie_card_test.dart test/core/widgets/movie_grid_view_test.dart test/features/categories/categories_screen_test.dart test/features/home/home_screen_test.dart test/features/movie_detail/movie_detail_screen_test.dart test/features/rankings/rankings_screen_test.dart
```

Expected: 所有相关测试 PASS；网格和分类页仍可进入详情，首页及影片详情相关推荐删除回调后无编译错误。

- [ ] **Step 10: 检查旧 API 已彻底清理**

Run:

```bash
rg -n "MovieCard\\([^)]*onTap|onMovieTap" lib test
```

Expected: 不再发现 `MovieCard.onTap` 或 `MovieGridView.onMovieTap` 调用。影片详情页中与其他内部组件相关的同名参数若仍存在，应逐项确认并仅保留非 `MovieCard` 业务；本计划定义的 `_MovieDetailTabs`、`_BasicInfoTab`、`_MovieRowSection` 链必须无匹配。

- [ ] **Step 11: 运行全量验证**

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

- [ ] **Step 12: 检查范围并提交**

Run:

```bash
git status --short
git diff -- lib/core/widgets/movie_card.dart lib/core/widgets/movie_grid_view.dart lib/features/home/screens/home_screen.dart lib/features/movie_detail/screens/movie_detail_screen.dart test/core/widgets/movie_card_test.dart
```

只暂存这五个文件：

```bash
git add lib/core/widgets/movie_card.dart lib/core/widgets/movie_grid_view.dart lib/features/home/screens/home_screen.dart lib/features/movie_detail/screens/movie_detail_screen.dart test/core/widgets/movie_card_test.dart
git commit -m "refactor: move movie detail navigation to card"
```
