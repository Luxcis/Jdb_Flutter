# 列表下拉刷新逻辑优化设计

日期：2026-08-19
状态：待审查

## 背景与问题

项目中所有分页列表均基于 `PaginationController` 实现下拉刷新（`RefreshIndicator`）。
当前 `reloadWith` 在刷新前会**无条件清空 `_items`**（除非调用方显式传
`preserveItems: true`），导致用户下拉松手后：

- 当前列表被清空；
- 页面中间出现居中的 `CircularProgressIndicator` loading 动画；
- 刷新完成后才整体替换为新数据。

期望行为：

- 下拉松手后**保留原有列表数据**；
- 使用下拉刷新时的 **loading 图标动画（顶部指示器）表示刷新中**，不在页面中间
  展示 loading；
- 刷新成功后**用新列表数据替换旧列表数据**；
- 刷新结束后**收回隐藏顶部 loading 图标动画**。

另外，现有 `preserveItems` 标志是**一次性**的：`_replaceOnSuccess` 在首次刷新
成功后即被清掉，第二次下拉刷新会再次清空列表（回归缺陷，见
`pagination_controller.dart` 第 38-41 行）。

## 范围

涉及以下 5 处下拉刷新入口（全部基于 `PaginationController`）：

| 位置 | 现状 | 问题 |
| --- | --- | --- |
| `lib/core/widgets/movie_grid_view.dart`（封面网格：首页、排行、分类、搜索、近期浏览、我的收藏、往期推荐明细等约 15 个页面共用） | `controller.refresh`（默认清空） | 松手后清空列表 + 居中 loading |
| `lib/core/widgets/actor_grid_view.dart`（演员网格） | `refresh(preserveItems: true)` | 已正确，保留 |
| `lib/features/articles/screens/articles_screen.dart`（AV 资讯） | `refresh(preserveItems: true)` | 已正确，保留 |
| `lib/features/reviews/screens/reviews_screen.dart`（看短评） | `controller.refresh`（默认清空） | 松手后清空列表 + 居中 loading |
| `lib/features/rankings/screens/rankings_screen.dart`（Top250） | `controller.refresh`（默认清空） | 松手后清空列表 + 居中 loading |

不影响：

- 首次加载（列表为空）——仍显示居中 loading（正确）；
- 筛选 / 排序 / 标签切换触发 `reloadWith`（**参数变化语义**）——仍清空列表并显示
  居中 loading（这是预期的"切换条件重新查询"行为，不是下拉刷新）；
- 加载更多（`fetchMore`）——仍追加尾部数据。

## 设计

### 1. `PaginationController` 语义调整（核心）

文件：`lib/core/widgets/pagination_controller.dart`

- **刷新（已有列表）永远保留旧列表**。`reloadWith` 新增内部状态
  `_pendingRefresh`（bool），替代一次性 `_replaceOnSuccess`：

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

  `fetchMore` 中：

  ```dart
  final result = await fetch(requestedPage);
  if (generation != _generation) return;
  _page = result.currentPage;
  if (_pendingRefresh) {
    _pendingRefresh = false;   // 本次刷新有效，之后不再清空
    _items.clear();
  }
  _items.addAll(result.items);
  _hasMore = _page < result.totalPages;
  ```

  `_pendingRefresh` 只对**当次**刷新请求生效，不会影响下一次刷新（下一次
  `reloadWith` 会按 `preserveItems` 重新设置）；已清除旧的一次性标志
  `_replaceOnSuccess`。

- `refresh()` 默认行为改为保留内容：

  ```dart
  Future<void> refresh({bool preserveItems = true}) =>
      reloadWith(_fetch, preserveItems: preserveItems);
  ```

- `reloadWith` 的 `preserveItems` 参数保留（现有调用点
  `actor_movie_controller.dart`、`category_tab_controller.dart`、
  `review_movies_tab_controller.dart` 等在筛选/排序切换时显式传
  `preserveItems: true`——注意这些是**参数变化**场景，本设计不改变它们：它们
  仍需保留旧列表 + 顶部指示器，即与下拉刷新一致）。`reloadWith` 不带
  `preserveItems` 的调用点（如 `my_lists_page.dart` 排序切换、搜索条件变化）仍
  清空列表，属于预期的"条件变化重新查询"。

- 错误处理不变：刷新失败保留旧列表与 `error`（现有逻辑），由列表页尾重试按钮
  兜底。

### 2. UI 层统一

所有下拉刷新入口统一调用保留语义：

- `movie_grid_view.dart`：`onRefresh: () => controller.refresh(preserveItems: true)`
- `reviews_screen.dart`：`onRefresh: () => _controller.refresh(preserveItems: true)`
- `rankings_screen.dart`（Top250）：`onRefresh: () => _controller.refresh(preserveItems: true)`
- `actor_grid_view.dart`、`articles_screen.dart` 已正确，保持不变。

刷新中的 UI 反馈（已有，无需新增）：

- `movie_grid_view.dart`、`actor_grid_view.dart`、`articles_screen.dart` 在
  `isRefreshing` 时显示顶部 `LinearProgressIndicator`（顶部 loading 条）；
- `reviews_screen.dart`、`rankings_screen.dart` 目前**没有**顶部指示器，刷新中
  仅有 `RefreshIndicator` 自带的旋转图标（松手后仍显示直到 `onRefresh` Future
  完成）。为满足"使用下拉操作时出现的 loading 图标动画表示刷新中"，这两处
  补充与 `movie_grid_view` 相同的顶部 `LinearProgressIndicator`（
  `isRefreshing` 时显示，刷新完成后自动隐藏）。

### 3. 测试（先写测试，TDD）

- `test/core/widgets/pagination_controller_test.dart`：
  - `refresh` 默认（`preserveItems` 缺省）在刷新成功前保留旧内容，成功后整体替换；
  - **连续多次 `refresh` 都保留旧内容**（回归：一次性标志缺陷）；
  - 刷新失败保留旧内容（已有用例保留）。
- `test/core/widgets/movie_grid_view_test.dart`：
  - 下拉刷新（`RefreshIndicator.onRefresh`）期间旧内容保留、顶部
    `LinearProgressIndicator` 显示、无居中 loading；
  - 刷新成功后旧内容被新内容替换、顶部指示器隐藏。
- `test/core/widgets/actor_grid_view_test.dart`：已有用例覆盖保留刷新，保持通过。
- `test/features/reviews`、`test/features/rankings`：若有相关用例，补充顶部指示器
  断言（如有需要）。

## 验证方式

- `flutter test`（全部用例通过）；
- `dart analyze`（无新增告警）。

## 不做的事（YAGNI）

- 不引入新的第三方下拉刷新库（`RefreshIndicator` 已满足需求）；
- 不改变首次加载、加载更多、参数变化（筛选/排序）的既有行为；
- 不为 `ReviewsPage` / `RankingsPage` 引入自定义刷新动画，仅复用现有的
  `LinearProgressIndicator` 模式。
