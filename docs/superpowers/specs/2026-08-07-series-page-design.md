# 首页系列页功能设计

## 背景

首页豆腐块中已有「系列」入口（`TofuItem`，route `/series`），但 `/series`
当前指向占位页 `_SimpleListPage`，展示 8 条假数据。本次实现真实系列页面：5 个
分类 Tab、分页列表，列表展示与搜索结果中的「系列」Tab 一致，番号 Tab 额外显示
接口返回的 `description` 副标题。

## 目标

- 点击首页「系列」进入系列页面，替换占位页。
- 页面 5 个 Tab：番号、有码、无码、欧美、动漫。
- 番号 Tab 调用 `/api/v1/series/letters`；其余 Tab 调用 `/api/v1/series`，
  分别传 `type=0`（有码）、`type=1`（无码）、`type=2`（欧美）、`type=4`（动漫）。
- 列表展示与搜索结果系列列表一致（名称/字母 + 括号数量）；番号 Tab 条目额外以
  副标题展示接口的 `description`。
- 点击条目打开影片列表，行为与搜索结果一致：系列 → `CommonListPage(category: 's')`，
  番号 → `CommonListPage(category: 'c')`。
- 每个 Tab 独立分页加载，支持上拉加载更多、错误重试与空态。

## 接口契约（以用户提供的 OpenAPI 附件为准）

### GET /api/v1/series/letters（系列番号）

query：`page`（从 1 开始，可选）、`limit`（每页条数，可选，示例 48）。

响应 `data` 为 `LettersListEntity`：

```json
{
  "letters": [
    {
      "id": "IPX",
      "letter": "IPX",
      "type": 0,
      "description": "IdeaPocket美少女夢工廠",
      "videos_count": 998,
      "views_count": 3593620
    }
  ],
  "current_page": 1
}
```

### GET /api/v1/series（系列列表）

query：`page`（可选）、`limit`（可选）、`type`（必填，string）。

`type` 可选值（以用户附件为准，仓库 OpenAPI 中 3=FC2 的旧说明被本设计覆盖）：

| Tab | type |
| --- | --- |
| 有码 | `0` |
| 无码 | `1` |
| 欧美 | `2` |
| 动漫 | `4` |

响应 `data` 为 `SeriesListEntity`：

```json
{
  "series": [
    {
      "id": "rY2v",
      "type": 0,
      "name": "【初撮り】ネットでAV応募→AV体験撮影",
      "videos_count": 1100
    }
  ],
  "current_page": 1
}
```

### 分页

两个接口的示例响应均不含 `total_pages`/`total` 字段。沿用 `TagMoviesService` 的
启发式判定：返回条数满 `limit` 推断还有下一页（`totalPages = currentPage + 1`），
不满则到底。每页 `limit = 48`，与搜索结果一致。

## 组件提升（共享层）

系列页要“列表展示同搜索结果中的系列列表”，而 `SearchEntityListTile` 与
`SearchPaginatedListView` 当前位于 search feature 内部。按 RULES.md（feature 只依赖
core，feature 之间不互相依赖）提升到共享层：

1. `SearchEntityListTile` → `lib/core/widgets/entity_list_tile.dart`
   `EntityListTile`：保留 `name`/`count`/`onTap`，新增可选 `subtitle`（番号 Tab 展示
   `description`）。search feature 更新 import。
2. `SearchPaginatedListView` → `lib/core/widgets/paginated_list_view.dart`
   `PaginatedListView<T>`：仅依赖 core 组件（`PaginationController`、
   `EmptyState`、`ErrorRetryWidget`），行为不变。search feature 更新 import。

## 页面结构

`lib/features/series/`（Feature-First，新建 feature）：

```
lib/features/series/
├── models/series_letter.dart    # SeriesLetter 模型
├── screens/series_page.dart     # SeriesPage：TabBar + TabBarView
├── services/series_service.dart # SeriesService + 数据源接口（含不可用实现）
└── index.dart                   # 仅导出 SeriesPage
```

### SeriesPage

- `AppBar` 标题「系列」。
- `TabBar`（`isScrollable: true` 防窄屏溢出）：番号、有码、无码、欧美、动漫。
- `TabBarView` 内 5 个分页列表，每个 Tab 独立的 `PaginationController` 与滚动位置，
  用 `AutomaticKeepAliveClientMixin` 保活（沿用 rankings/reviews 页面成熟模式）。
- 番号 Tab：`fetchPage = (page) => service.getLetters(page: page)`，
  条目 `EntityListTile(name: letter, count: videosCount, subtitle: description)`。
- 其余 Tab：`fetchPage = (page) => service.getSeries(type: t, page: page)`，
  条目 `EntityListTile(name: name, count: movieCount)`。
- 列表：`PaginatedListView` + 分隔线，滚动触底 `fetchMore()`；首屏失败
  `ErrorRetryWidget`；空态「暂无系列」/「暂无番号」。

### 数据模型

- 复用 `lib/core/models/series.dart` 的 `Series`（`id`/`name`/`movieCount`/`type`）。
  `/api/v1/series` 返回 `videos_count`，用归一化 json 映射到 `movieCount`
  （与 `SearchEntityService._namedEntityJson` 相同的 `movie_count ?? movies_count ??
  videos_count` 逻辑，系列页服务内私有实现，不跨 feature 引用）。
- 新增 `SeriesLetter`：`id`、`letter`、`description`、`videosCount`、`viewsCount`、
  `type`，snake_case 映射。

### 服务

`SeriesService(ApiClient)`：

- `Future<PagedResult<SeriesLetter>> getLetters({int page = 1, int limit = 48})`
- `Future<PagedResult<Series>> getSeries({required String type, int page = 1, int limit = 48})`

沿用 `SearchEntityService` 的分页解析模式（`apiMap`/`apiList`/`apiInt`，缺
`total_pages` 时用满条数启发式）。同时提供 `SeriesDataSource` 抽象与
`UnavailableSeriesDataSource`（测试注入用），页面在 `ApiClient.instanceOrNull`
为空时回退不可用实现。

## 路由

`lib/core/router/app_router.dart` 中 `/series` 的 `_SimpleListPage(title: '系列')`
替换为 `SeriesPage`。首页豆腐块入口已存在，无需改动。

## 错误与空态

- 首屏加载失败：`ErrorRetryWidget`（消息 + 重试）。
- 空列表：番号 Tab「暂无番号」，其余 Tab「暂无系列」。
- 尾部加载失败：列表尾显示「重试」按钮（`PaginatedListView` 现有行为）。

## 测试计划

1. `test/features/series/series_service_test.dart`
   - 请求参数断言：`getLetters` 发 `{page, limit}`；`getSeries` 发
     `{type, page, limit}`，type 映射 0/1/2/4。
   - 解析断言：letters 解析 `description`/`videos_count`/`views_count`；series 解析
     `videos_count → movieCount`。
   - 无 `total_pages` 时满 48 条允许下一页、少于 48 条停止。
2. `test/features/series/series_page_test.dart`
   - 5 个 Tab 渲染；切 Tab 触发对应接口（番号 → letters，其余 → 对应 type）。
   - 番号 Tab 条目显示 `description` 副标题。
   - 点击系列条目跳转 `CommonListPage`（title「系列 - 名称」）；点击番号条目跳转
     「番号 - 字母」。
3. `test/core/widgets/entity_list_tile_test.dart`（原
   `search_entity_list_tile_test.dart` 迁移 + 副标题用例）。
4. 更新 search 相关测试引用（`search_screen_test.dart` 中对
   `SearchEntityListTile` 的引用）。

## 不做的事（YAGNI）

- 不做系列详情页（`/api/v1/series/{series_id}` 与收藏接口，后续按需接入）。
- 不实现片商/导演占位页（`/makers`、`/directors` 仍为 `_SimpleListPage`）。
- 不引入下拉刷新（搜索结果系列 Tab 无此能力，保持一致）。
