# 首页看短评功能设计

## 背景

首页豆腐块中已有「看短评」入口（`TofuItem`，route `/reviews`），但 `/reviews`
当前指向占位页 `_SimpleListPage`，展示 8 条假数据。本次实现真实短评页面：6 个周期
Tab、分页热评列表，并把影片详情页的私有短评卡片提取为共享 `ReviewTile` 组件，在其
评价内容上方增加影片信息区。

## 目标

- 点击首页「看短评」进入短评页面，替换占位页。
- 页面 6 个 Tab：最新、上周热评、月度热评、季度热评、年度热评、全部，分别对应接口
  周期 `latest`、`weekly`、`monthly`、`quarterly`、`yearly`、`all`。
- 热评列表复用共享 `ReviewTile`，卡片顶部展示影片信息（封面、标题、番号、发布日期）。
- 每个 Tab 独立分页加载，支持上拉加载更多、下拉刷新、错误重试与空态。

## 接口契约（实测确认）

`GET /api/v1/reviews/hotly`，query：`period`（必填）、`page`（从 1 开始）、`limit`。

### 周期取值

以官方客户端 APK 反编译（`hot_comment_presenter.dart` 字符串表）与实测接口双重确认：

| Tab | period |
| --- | --- |
| 最新 | `latest` |
| 上周热评 | `weekly` |
| 月度热评 | `monthly` |
| 季度热评 | `quarterly` |
| 年度热评 | `yearly` |
| 全部 | `all` |

### 响应结构

`data.reviews` 为评论数组，每条评论携带嵌套 `movie` 对象（实测 100% 携带）：

```json
{
  "id": 242751665,
  "username": "zy520_jj",
  "watched_count": 65,
  "content": "...",
  "score": 5,
  "likes_count": 400,
  "liked": false,
  "created_at": "2026-07-31T13:17:35.000Z",
  "movie": {
    "id": "GZQMqq",
    "number": "CAWB-012",
    "title": "【FANZA限定】...",
    "origin_title": "【FANZA限定】...",
    "score": "4.56",
    "thumb_url": "https://tp.spfcas.com/.../GZQMqq.jpg",
    "release_date": "2026-08-05"
  }
}
```

注意：影片详情页的 `/api/v1/movies/{id}/reviews` 评论**不返回** `movie` 字段，因此
`ReviewTile` 的影片信息区由数据驱动（存在 `movie` 才渲染），详情页行为不变。

### 分页

该接口响应不含 `current_page`/`total_pages`/`total` 字段。实测超界页码服务端会收敛到
末尾页。客户端采用「返回条数不足 `limit` 即视为到底」的启发式判定 `hasMore`：

- 返回条数 == `limit` → `totalPages = page + 1`（还有下一页）。
- 返回条数 < `limit` → `totalPages = page`（已是最后一页）。

## 页面结构

`lib/features/reviews/`（Feature-First）：

```
lib/features/reviews/
├── screens/reviews_screen.dart   # ReviewsPage：TabBar + TabBarView
├── services/reviews_service.dart # ReviewsService.getHotReviews
└── index.dart                    # 仅导出 ReviewsPage
```

### ReviewsPage

- `AppBar` 标题「看短评」。
- `TabBar`（`isScrollable: true` 防窄屏溢出）：最新、上周热评、月度热评、季度热评、
  年度热评、全部。
- `TabBarView` 内 6 个 `_HotReviewList`，每个 Tab 独立的 `PaginationController<Review>`
  与滚动位置，用 `AutomaticKeepAliveClientMixin` 保活（沿用 rankings 页面成熟模式）。
- 列表：`ListView.separated` + 分隔线，底部触发 `fetchMore()` 上拉加载；`RefreshIndicator`
  下拉刷新；错误态 `ErrorRetryWidget`；空态「暂无短评」。
- 每页 `limit = 20`。

## ReviewTile 组件改造

将影片详情页私有 `_ReviewTile` 提取为共享组件 `lib/core/widgets/review_tile.dart`，
影片详情页改用它（删除私有副本，行为不变）。新增可选影片信息区，按需求草图布局：

```
封面  │ 影片标题（最多两行，超出省略）
72×96 │ 番号 / 发布日期
────────────── 分隔线 ──────────────
原评价组件内容（作者、评分、内容、点赞/时间）
```

- 封面：`thumb_url`，无封面时显示占位；保持比例不裁剪拉伸。
- 标题：最多两行 `TextOverflow.ellipsis`。
- 番号与发布日期以「`番号 / 日期`」同行展示；任一缺失时只显示有值部分。
- 影片信息区仅在 `review.movie` 非空时渲染；详情页评论无 `movie`，故详情页卡片不变。
- 卡片整体可点击：有 `movie` 时跳转 `/movie/{movie.id}`（与 `MovieCard` 默认详情导航
  一致），无 `movie` 时不可点击。

## 数据模型与服务

`lib/core/models/review.dart` 扩展：

- 新增 `ReviewMovie`：`id`(String)、`number`、`title`、`originTitle`、`score`(String?)、
  `thumbUrl`、`releaseDate`（均 String?，`thumb_url`/`release_date`/`origin_title`
  snake_case 映射）。
- `Review` 增加 `final ReviewMovie? movie;`。

`lib/core/network/api_data.dart` 的 `normalizeReviewJson` 补充 `movie` 解析
（复用 `apiString` 兼容 id 为整数或字符串）。

`ReviewsService.getHotReviews({required String period, int page = 1, int limit = 20})`
返回 `PagedResult<Review>`，按上述启发式填充 `totalPages`。

## 路由

`lib/core/router/app_router.dart` 中 `/reviews` 由 `_SimpleListPage` 占位改为
`ReviewsPage`；`lib/core/router/routes.dart` 不变；`tofu_scroll.dart` 的「看短评」
入口不变。

## 测试与验收

- Service 单测：6 个 period 参数透传；`movie` 字段解析（含无 movie、id 为整数）；
  分页启发式（满页→还有下一页，不足 limit→到底）。
- `ReviewTile` Widget 测试：影片信息区渲染（封面/标题/番号/发布日期）；标题两行省略；
  无 movie 不渲染头部且不可点击；有点击跳转 `/movie/{id}`。
- 短评页面 Widget 测试：默认选中「最新」并请求 `period=latest`；切换 Tab 请求对应
  period；上拉加载下一页（page+1）；错误态重试；空态文案。
- 路由测试：`/reviews` 渲染 `ReviewsPage`（替换占位页）。

验收后运行 `flutter analyze` 与相关 `flutter test`。
