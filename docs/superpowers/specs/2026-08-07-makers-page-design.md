# 首页片商页功能设计

## 背景

首页豆腐块中已有「片商」入口（`TofuItem`，route `/makers`），但 `/makers`
当前指向占位页 `_SimpleListPage`，展示 8 条假数据。本次实现真实片商页面：5 个
分类 Tab、分页列表，列表展示与搜索结果中的「片商」Tab 一致。

## 目标

- 点击首页「片商」进入片商页面，替换占位页。
- 页面 5 个 Tab：有码、无码、欧美、FC2、动漫。
- 每个 Tab 调用 `/api/v1/makers`，分别传 `type=0`（有码）、`type=1`（无码）、
  `type=2`（欧美）、`type=3`（FC2）、`type=4`（动漫）。
- 列表展示与搜索结果片商列表一致（名称 + 括号数量）。
- 点击条目打开影片列表，行为与搜索结果一致：`CommonListPage(category: 'm')`。
- 每个 Tab 独立分页加载，支持上拉加载更多、错误重试与空态。

## 接口契约（以用户提供的 OpenAPI 附件为准）

### GET /api/v1/makers（制作商列表）

query 参数：

- `type`（必填，string）：0=有码、1=无码、2=欧美、3=FC2、4=动漫。
- `page`（可选，int，从 1 开始）。
- `limit`（可选，int，APK 中固定传 48）。

响应 `data` 为 `MakersListEntity`：

```json
{
  "makers": [
    { "id": "xZyO", "type": 1, "name": "Heydouga", "videos_count": 25645 }
  ],
  "current_page": 1
}
```

### 分页

示例响应不含 `total_pages`/`total` 字段。沿用 `apiPageResult` 的启发式判定：
返回条数满 `limit` 推断还有下一页（`totalPages = currentPage + 1`），不满则
到底。每页 `limit = 48`，与搜索结果一致。

## 共享归一化（core 层）

在 `lib/core/network/api_data.dart` 新增 `normalizeMakerJson`，把
`videos_count`/`movies_count` 映射为 `Maker.movieCount`（`movie_count`），
并兜底 `id`/`name`/`type`。`SearchEntityService.getMakers` 复用该函数，
消除私有 `_namedEntityJson` 对 maker 的重复逻辑（series/director 仍用原函数）。

## 页面结构

`lib/features/makers/`（Feature-First，新建 feature）：

```
lib/features/makers/
├── screens/makers_page.dart     # MakersPage：TabBar + TabBarView
├── services/maker_service.dart  # MakerService + 数据源接口（含不可用实现）
└── index.dart                   # 仅导出 MakersPage
```

### MakersPage

- `AppBar` 标题「片商」。
- `TabBar`（`isScrollable: true` 防窄屏溢出）：有码、无码、欧美、FC2、动漫。
- `TabBarView` 内 5 个分页列表，每个 Tab 独立的 `PaginationController` 与滚动
  位置，用 `AutomaticKeepAliveClientMixin` 保活（沿用 series 页面成熟模式）。
- 每个 Tab：`fetchPage = (page) => service.getMakers(type: t, page: page)`，
  条目 `EntityListTile(name: name, count: movieCount)`。
- 列表：`PaginatedListView` + 分隔线，滚动触底 `fetchMore()`；首屏失败
  `ErrorRetryWidget`；空态「暂无片商」。

### 数据模型

复用 `lib/core/models/maker.dart` 的 `Maker`（`id`/`name`/`movieCount`/`type`）。
`/api/v1/makers` 返回 `videos_count`，用 `normalizeMakerJson` 映射到 `movieCount`。

### 服务

`MakerService(ApiClient)`：

- `Future<PagedResult<Maker>> getMakers({required int type, int page = 1, int limit = 48})`

沿用 `SearchEntityService` 的分页解析模式（`apiPageResult`，集合键 `makers`）。
同时提供 `MakerDataSource` 抽象与 `UnavailableMakerDataSource`（测试注入用），
页面在 `ApiClient.instanceOrNull` 为空时回退不可用实现。

## 路由

`lib/core/router/app_router.dart` 中 `/makers` 的 `_SimpleListPage(title: '片商')`
替换为 `MakersPage`（`/directors` 仍保留占位页）。首页豆腐块入口已存在，无需改动。

同时更新 `lib/core/network/endpoints.dart` 中 `/api/v1/makers` 过时的
「服务端Bug：无论传什么 type 值均返回 HTTP 500」备注——该备注来自 7 月 20 日
验证，与用户今日提供的 OpenAPI 规格（含完整示例与 type 0-4 说明）冲突，
以用户附件为准，移除过期备注。

## 错误与空态

- 首屏加载失败：`ErrorRetryWidget`（消息 + 重试）。
- 空列表：「暂无片商」。
- 尾部加载失败：列表尾显示「重试」按钮（`PaginatedListView` 现有行为）。

## 测试计划

1. `test/core/network/api_data_test.dart`：新增 `normalizeMakerJson` 用例
   （`videos_count → movieCount`、缺失字段兜底）。
2. `test/features/makers/maker_service_test.dart`：
   - 请求参数断言：`getMakers` 发 `{type, page, limit}`，type 映射 0/1/2/3/4。
   - 解析断言：`videos_count → movieCount`。
   - 无 `total_pages` 时满 48 条允许下一页、少于 48 条停止。
3. `test/features/makers/makers_page_test.dart`：
   - 5 个 Tab 渲染；默认加载有码（type=0）；切 Tab 触发对应 type 请求。
   - 条目显示名称与（数量）。
   - 点击片商条目进入 `CommonListPage`（title「片商 - 名称」）。
   - 切回 Tab 保留列表状态（保活，不重复请求）。
4. `test/features/home/tofu_scroll_test.dart`：补充「片商」豆腐块存在且点击
   进入 `/makers` 的断言。

## 不做的事（YAGNI）

- 不做片商详情页（`/api/v1/makers/{maker_id}` 与收藏接口，后续按需接入）。
- 不实现导演占位页（`/directors` 仍为 `_SimpleListPage`）。
- 不引入下拉刷新（搜索结果片商 Tab 无此能力，保持一致）。
- 页面不加搜索框/筛选（保持最小范围）。
