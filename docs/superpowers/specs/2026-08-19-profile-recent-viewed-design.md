# 我的-近期浏览页面设计

日期：2026-08-19
状态：已批准（用户逐节确认）

## 1. 背景与目标

「我的」页的「近期浏览」入口（`lib/features/profile/screens/profile_screen.dart` 第 108 行）目前跳转到 `/profile/recent`，该路由（`lib/core/router/app_router.dart` 第 317 行）渲染的是占位骨架 `ProfileMovieCollectionPage`（TabController + 空分页，尚未接真实数据）。

本次实现完整功能：

1. **近期浏览列表**：三列宫格 `MovieCard`，自动分页加载（滚动到底加载下一页），复用现有 `MovieGridView`。
2. **清空近期浏览**：顶部导航栏右侧删除按钮，点击弹窗确认后调用 DELETE `/api/v1/users/recent_viewed` 清空数据并刷新列表。

## 2. 接口契约

`GET /api/v1/users/recent_viewed?page=1&limit=48`

响应 `data`：

```json
{
  "movies": [{
    "id": "string",
    "number": "string",
    "title": "string",
    "origin_title": "string",
    "thumb_url": "string",
    "cover_url": "string",
    "duration": 0,
    "magnets_count": 0,
    "can_play": false,
    "play_subtitle": 0,
    "has_preview_video": false,
    "has_cnsub": false,
    "has_preview_images": false,
    "release_date": "string",
    "new_magnets": false,
    "preview_images": []
  }]
}
```

`DELETE /api/v1/users/recent_viewed`：清空当前用户近期浏览，无请求体。

> 响应仅有 `movies` 数组，无 `total_pages`/`current_page`/`total` 字段。分页采用项目现有 `apiPageResult` 的「满页推断」启发式：当页返回条数等于 `limit` 时视为存在下一页，否则为末页。

## 3. 需求决策（已确认）

| 决策点 | 结论 |
|--------|------|
| 分页契约 | **按满页推断**：复用 `apiPageResult` 启发式，与现有列表页一致 |
| 删除交互 | **AppBar 右上角删除图标 + AlertDialog**（取消/清空），与设置页「清除缓存」确认弹窗一致 |
| 清空后反馈 | **SnackBar「已清空近期浏览」** + 刷新列表；失败 SnackBar「清空失败，请稍后重试」，不清列表 |
| 实现方案 | **方案 A：独立 service + 新页面**，复用 `MovieGridView`；不改造 `ProfileMovieCollectionPage`（其 tab 语义为「想看/看过」多分类，与单列表近期浏览冲突） |
| 每页条数 | `limit = 48`（接口文档示例值） |

## 4. 文件变更

### 4.1 新增 `lib/features/profile/services/recent_viewed_service.dart`

对齐现有 `ReviewMoviesDataSource` 模式（抽象数据源 + API 实现 + 可注入测试）：

```dart
/// 近期浏览数据源抽象，便于测试注入。
abstract interface class RecentViewedDataSource {
  /// 取得一页近期浏览影片；[page] 从 1 开始。
  Future<PagedResult<MovieSummary>> getRecentViewed({int page = 1});

  /// 清空当前用户的全部近期浏览记录。
  Future<void> clearRecentViewed();
}

/// 基于 API 客户端的近期浏览数据源实现。
class RecentViewedService implements RecentViewedDataSource {
  RecentViewedService(this._api);

  static const _pageSize = 48;
  final ApiClient _api;

  @override
  Future<PagedResult<MovieSummary>> getRecentViewed({int page = 1}) async {
    final response = await _api.get(
      Endpoints.usersRecentViewed,
      queryParameters: {'page': page, 'limit': _pageSize},
    );
    return apiPageResult(
      response.data,
      keys: const ['movies'],
      page: page,
      pageSize: _pageSize,
      fromJson: (json) => MovieSummary.fromJson(normalizeMovieSummaryJson(json)),
    );
  }

  @override
  Future<void> clearRecentViewed() async {
    await _api.delete(Endpoints.usersRecentViewed);
  }
}
```

> `Endpoints.usersRecentViewed = '/api/v1/users/recent_viewed'` 已存在于 `lib/core/network/endpoints.dart` 第 35 行，无需新增。

### 4.2 新增 `lib/features/profile/screens/profile_recent_viewed_page.dart`

`ProfileRecentViewedPage`（StatefulWidget）：

- 持有 `PaginationController<MovieSummary>`，`fetch` 为 `RecentViewedService.getRecentViewed`。
- `initState` 中 `fetchMore()` 加载首页。
- 登录守卫：`context.watch<AuthProvider>()`，未登录显示 `LoginGuideCard`（与 `_Top250Tab` 的 `didChangeDependencies` 模式一致；路由外层已有 `_AuthGuard` 负责未登录跳转）。
- 页面主体：`MovieGridView(controller: _controller)` —— 三列宫格、自动分页、下拉刷新、空态/错误重试全部复用。
- AppBar：
  - `title: Text('近期浏览')`
  - `actions: [IconButton(Icons.delete_outline, tooltip: '清空近期浏览')]`
  - 删除按钮在列表为空时仍可点击（空态下清空无副作用，YAGNI 不做禁用态）。

清空流程 `_confirmAndClear()`：

1. `showDialog<bool>` AlertDialog：标题「清空近期浏览？」，内容「将删除全部浏览记录，此操作不可恢复。」，按钮「取消」/「清空」。
2. 确认后调用 `dataSource.clearRecentViewed()`。
3. 成功 → `_controller.reloadWith(_fetchPage)` 刷新（列表变为空态）→ SnackBar「已清空近期浏览」。
4. 失败 → SnackBar「清空失败，请稍后重试」，不清列表。

### 4.3 修改 `lib/core/router/app_router.dart`

`/profile/recent` 路由的 `child` 从 `ProfileMovieCollectionPage(title: '近期浏览')` 改为 `ProfileRecentViewedPage()`（保持 `_AuthGuard` 包裹不变）。

## 5. 错误处理与边界

| 场景 | 处理 |
|------|------|
| 首页加载失败 | `MovieGridView` 现有 `ErrorRetryWidget`（错误 + 重试） |
| 加载更多失败 | `MovieGridView` 现有「加载失败，点击重试」 |
| 下拉刷新失败 | 保留旧列表 + 顶部错误提示（`MovieGridView` 现有行为） |
| 清空失败 | SnackBar 提示，列表保持不变 |
| 未登录访问 | `_AuthGuard` 跳登录页；页面内 `AuthProvider` watch 兜底显示 `LoginGuideCard` |
| 列表为空 | `MovieGridView` 现有 `EmptyState`「暂无数据」 |

## 6. 测试

### 6.1 service 单测 `test/features/profile/recent_viewed_service_test.dart`

注入 fake `Dio`/adapter（对齐 `test/core/network/api_client_test.dart` 模式）：

1. `getRecentViewed` 满页（48 条）→ `hasMore` 为真（`totalPages = page + 1`）。
2. `getRecentViewed` 不满页（10 条）→ `totalPages = page`，无下一页。
3. `getRecentViewed` 空数组 → 空结果，`totalPages = page`。
4. `clearRecentViewed` 发出 DELETE 请求到 `/api/v1/users/recent_viewed`。

### 6.2 widget 测试 `test/features/profile/profile_recent_viewed_page_test.dart`

注入 fake `RecentViewedDataSource`（内存实现）：

1. 加载成功后显示三列宫格 `MovieCard`。
2. 点删除图标 → 弹 AlertDialog；点「取消」→ 不调用 `clearRecentViewed`。
3. 点删除图标 → 点「清空」→ 调用 `clearRecentViewed`，列表刷新为空态，显示 SnackBar。
4. 空列表时点「清空」→ 仍调用接口且无异常。
