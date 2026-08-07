# 首页导演页功能设计

## 背景

首页豆腐块中已有「导演」入口（`TofuItem`，route `/directors`），但 `/directors`
当前指向占位页 `_SimpleListPage`，展示 8 条假数据。本次实现真实导演页面：2 个
分类 Tab、分页列表，列表展示与搜索结果中的「导演」Tab 一致。

## 目标

- 点击首页「导演」进入导演页面，替换占位页。
- 页面 2 个 Tab：有码、欧美。
- 每个 Tab 调用 `/api/v1/directors`，分别传 `type=0`（有码）、`type=2`（欧美）。
- 列表展示与搜索结果导演列表一致（名称 + 括号数量）。
- 点击条目打开影片列表，行为与搜索结果一致：`CommonListPage(category: 'd')`。
- 每个 Tab 独立分页加载，支持上拉加载更多、错误重试与空态。

## 接口契约（以用户提供的 OpenAPI 附件为准）

### GET /api/v1/directors（导演列表）

query 参数：

- `type`（必填，string）：0=有码、2=欧美。
- `page`（可选，int，从 1 开始）。
- `limit`（可选，int，APK 中固定传 48；服务端默认 10，上限 50）。

响应 `data` 为导演列表信封：

```json
{
  "directors": [
    { "id": "AqK", "type": "0", "name": "K太郎", "videos_count": 3122 }
  ],
  "current_page": 1
}
```

### 分页

示例响应不含 `total_pages`/`total` 字段。沿用 `apiPageResult` 的启发式判定：
返回条数满 `limit` 推断还有下一页（`totalPages = currentPage + 1`），不满则
到底。每页 `limit = 48`，与搜索结果一致。

## 共享归一化（core 层）

在 `lib/core/network/api_data.dart` 新增 `normalizeDirectorJson`，把
`videos_count`/`movies_count` 映射为 `Director.movieCount`（`movie_count`），
并兜底 `id`/`name`/`type`。`SearchEntityService.getDirectors` 复用该函数，
消除私有 `_namedEntityJson` 对 director 的重复逻辑（series 仍用原函数）。

## 页面结构

`lib/features/directors/`（Feature-First，新建 feature）：

```
lib/features/directors/
├── screens/directors_page.dart    # DirectorsPage：TabBar + TabBarView
├── services/director_service.dart # DirectorService + 数据源接口（含不可用实现）
└── index.dart                     # 仅导出 DirectorsPage
```

### DirectorsPage

- `AppBar` 标题「导演」。
- `TabBar`（`isScrollable: true` 防窄屏溢出）：有码、欧美。
- `TabBarView` 内 2 个分页列表，每个 Tab 独立的 `PaginationController` 与滚动
  位置，用 `AutomaticKeepAliveClientMixin` 保活（沿用 series/makers 页面成熟模式）。
- 每个 Tab：`fetchPage = (page) => service.getDirectors(type: t, page: page)`，
  条目 `EntityListTile(name: name, count: movieCount)`。
- 列表：`PaginatedListView` + 分隔线，滚动触底 `fetchMore()`；首屏失败
  `ErrorRetryWidget`；空态「暂无导演」。

### 数据模型

复用 `lib/core/models/director.dart` 的 `Director`（`id`/`name`/`movieCount`/`type`）。
`/api/v1/directors` 返回 `videos_count`，用 `normalizeDirectorJson` 映射到 `movieCount`。

### 服务

`DirectorService(ApiClient)`：

- `Future<PagedResult<Director>> getDirectors({required int type, int page = 1, int limit = 48})`

沿用 `MakerService` 的分页解析模式（`apiPageResult`，集合键 `directors`）。
同时提供 `DirectorDataSource` 抽象与 `UnavailableDirectorDataSource`（测试注入用），
页面在 `ApiClient.instanceOrNull` 为空时回退不可用实现。

## 路由

`lib/core/router/app_router.dart` 中 `/directors` 的 `_SimpleListPage(title: '导演')`
替换为 `DirectorsPage`。首页豆腐块入口已存在（`TofuItem` route `/directors`），
无需改动。

## 错误与空态

- 首屏加载失败：`ErrorRetryWidget`（消息 + 重试）。
- 空列表：「暂无导演」。
- 尾部加载失败：列表尾显示「重试」按钮（`PaginatedListView` 现有行为）。

## 测试计划

1. `test/core/network/api_data_test.dart`：新增 `normalizeDirectorJson` 用例
   （`videos_count → movieCount`、缺失字段兜底）。
2. `test/features/directors/director_service_test.dart`：
   - 请求参数断言：`getDirectors` 发 `{type, page, limit}`，type 映射 0/2。
   - 解析断言：`videos_count → movieCount`、`type` 保留。
   - 无 `total_pages` 时满 48 条允许下一页、少于 48 条停止。
3. `test/features/directors/directors_page_test.dart`：
   - 2 个 Tab 渲染；默认加载有码（type=0）；切 Tab 触发对应 type 请求。
   - 条目显示名称与（数量）。
   - 点击导演条目进入 `CommonListPage`（title「导演 - 名称」、category 'd'）。
   - 切回 Tab 保留列表状态（保活，不重复请求）。
4. `test/features/home/tofu_scroll_test.dart`：补充「导演」豆腐块存在且点击
   进入 `/directors` 的断言。

## 不做的事（YAGNI）

- 不做导演详情页（`/api/v1/directors/{id}` 与收藏接口，后续按需接入）。
- 不引入下拉刷新（搜索结果导演 Tab 无此能力，保持一致）。
- 页面不加搜索框/筛选（保持最小范围）。
- 不重构 series/makers 页面。
