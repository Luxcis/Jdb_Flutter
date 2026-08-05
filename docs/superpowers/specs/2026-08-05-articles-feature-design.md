# AV资讯功能设计

## 目标

实现首页豆腐块「AV资讯」功能：点击后打开资讯列表页，展示资讯卡片流；
点击卡片打开资讯详情页，展示标题、作者、分类、发布日期与正文。

## 范围

- 新增 feature `lib/features/articles/`（模型、服务、列表页、详情页、卡片）。
- 替换 `app_router.dart` 中 `/articles` 占位页 `_SimpleListPage` 为真实列表页，
  新增 `/articles/:id` 详情路由。
- 迁移并扩展 `lib/core/models/article.dart`（当前无任何引用）至 feature 模型。
- 新增依赖 `flutter_html`（详情正文 HTML 渲染）。
- 同步更新相关测试。

不做的事：

- 不实现瀑布流（按需求改为全宽竖向列表卡片）。
- 不展示详情页的 `related_movies` 相关影片（需求未要求）。
- 不改动首页豆腐块 `TofuScroll`（「AV资讯」入口与 `/articles` 路由已存在）。
- 不实现资讯收藏、评论等额外功能。

## 现状

- 豆腐块 `TofuScroll` 已含「AV资讯」项，route 为 `/articles`（`lib/features/home/widgets/tofu_scroll.dart`）。
- `/articles` 路由已注册但指向占位页 `_SimpleListPage`（`lib/core/router/app_router.dart`）。
- `Endpoints.articles = '/api/v1/articles'` 常量已存在（`lib/core/network/endpoints.dart`）。
- `lib/core/models/article.dart` 仅 4 字段（id/title/coverUrl/publishDate），无任何业务引用。
- 项目无瀑布流依赖；列表页标准模式为
  `PaginationController` + `NotificationListener` + `RefreshIndicator` +
  首屏 loading/error/empty 状态机（参考 `MovieGridView`、`ActorGridView`）。

### 接口（openapi v1.9.35-verified-20260720）

- `GET /api/v1/articles?page=N&limit=48`，需 jdsignature。
  返回 `data = { articles: [...], current_page }`，无 `total_pages` / `total` 字段。
  列表项字段：`id`(integer)、`title`、`cover_url`、`author`(object)、`category`、
  `released_at`。
- `GET /api/v1/articles/{article_id}`，需 jdsignature。
  返回 `data` 字段：`id`、`title`、`origin_name`、`origin_url`、`cover_url`、
  `author`(object)、`category`、`image_domain`、`content`(HTML)、`released_at`、
  `related_movies`。

## 方案

### 1. 数据模型（`lib/features/articles/models/article.dart`）

使用 `json_serializable`（`fieldRename: FieldRename.snake`，`createToJson: false`），
遵循现有模型规范。

- `ArticleSummary`（列表项）：
  - `id`（String，`apiString` 归一化）
  - `title`（String）
  - `coverUrl`（String?）
  - `author`（String?，容错 String / `{name: ...}` / `{username: ...}` 对象）
  - `category`（String?）
  - `releasedAt`（String?）
- `ArticleDetail`（详情）：继承 summary 字段 + `originName`、`originUrl`、
  `imageDomain`、`content`（HTML 字符串）。`relatedMovies` 不解析（YAGNI）。

normalize 函数 `normalizeArticleSummaryJson` / `normalizeArticleDetailJson`
放入 `lib/core/network/api_data.dart`（与 `normalizeMovieSummaryJson` 等并列）。

迁移：删除 `lib/core/models/article.dart` 及其 `.g.dart`（无引用）。

### 2. 服务层（`lib/features/articles/services/article_service.dart`）

参考 `TagMoviesService` 模式：

```dart
class ArticleService {
  static const _pageSize = 48;

  // GET /api/v1/articles?page=N&limit=48
  Future<PagedResult<ArticleSummary>> getArticles({int page = 1}) async {
    // items: data['articles'] -> normalizeArticleSummaryJson -> ArticleSummary.fromJson
    // currentPage = apiInt(data['current_page'], page)
    // totalPages = currentPage + (items.length >= 48 ? 1 : 0)  // 无 total_pages 字段推断
  }

  // GET /api/v1/articles/{id}
  Future<ArticleDetail> getArticleDetail(String id) async {
    // data -> normalizeArticleDetailJson -> ArticleDetail.fromJson
  }
}
```

### 3. 资讯卡片（`lib/features/articles/widgets/article_card.dart`）

全宽竖向卡片，卡片间垂直间隔分隔：

- 配图区：`AspectRatio(16/9)` 包裹 `CachedImage`（`fit: BoxFit.cover`），
  加载前浅灰占位（`surfaceContainerHighest` 色）。
- 标题区：左对齐，加粗（w600）深色，`maxLines: 2` + `TextOverflow.ellipsis`。
- 底部信息栏：`Row` 两端对齐：
  - 作者名（灰，`labelSmall`）
  - 分类标签（`category` 非空时显示）：胶囊形（`StadiumBorder`）红底白字
    （红色 `Colors.red` 背景 + 白色文字，比"红底红字"对比度更清晰）
  - 发布时间（浅灰）
  - `category` 为空时不渲染标签，作者与时间正常显示
- 整卡 `InkWell` 点击 → `context.push('/articles/${article.id}')`。
- 深色模式：颜色取 `Theme.of(context)`，自动适配。

### 4. 列表页（`lib/features/articles/screens/articles_screen.dart`）

`ArticlesPage`，参考 `MovieGridView` 状态机：

- `PaginationController<ArticleSummary>`，`initState` 时 `fetchMore()`。
- `Scaffold` + `AppBar('AV资讯')`。
- body 状态机：首屏 loading（`Center` spinner）/ 首屏 error（`ErrorRetryWidget`）/
  空列表（`EmptyState`）/ 正常列表。
- `CustomScrollView` + `SliverList.builder`（全宽卡片，懒加载）。
- `NotificationListener<ScrollNotification>`：`extentAfter < 400` 触发 `fetchMore()`。
- `RefreshIndicator`：下拉刷新（`refresh(preserveItems: true)`）。
- 尾部：加载更多时显示 spinner；加载失败显示「加载失败，点击重试」按钮。

### 5. 详情页（`lib/features/articles/screens/article_detail_screen.dart`）

`ArticleDetailPage`，接收 `id`：

- `Scaffold` + `AppBar('资讯详情')`。
- 加载中 / 失败重试（`ErrorRetryWidget`）状态机。
- 顶部信息区：标题（大字号加粗）、作者 / 分类 / 发布日期（次要信息行）。
- 正文：`flutter_html` 的 `Html` widget 渲染 `content`。
  - 预处理 content：将相对路径的 `<img src="...">` 拼接 `image_domain` 为完整 URL
    （`content` 图片加载依赖）。
  - 深色模式：`Html` 使用 `Theme.of(context).brightness` 适配。

### 6. 路由（`lib/core/router/`）

- `routes.dart`：新增 `static const String articleDetail = '/articles/:id';`。
- `app_router.dart`：
  - `/articles` builder 改为 `ArticlesPage`（保留 `_SimpleListPage` 供 reviews/imageSearch 使用）。
  - 新增 `GoRoute(path: articleDetail, builder: ...)` → `ArticleDetailPage(id: state.pathParameters['id']!)`。

### 7. 依赖

- `flutter pub add flutter_html`：详情正文 HTML 渲染。若存在版本冲突，
  优先以 `flutter pub add` 解析到兼容版本。

## 错误处理

- 列表 / 详情请求失败：首屏 `ErrorRetryWidget` 重试；加载更多失败显示尾部重试按钮；
  下拉刷新失败由 `RefreshIndicator` 承载。
- 封面图加载失败：`CachedImage` 内置 `errorWidget`（broken_image 图标）。
- 空列表：`EmptyState`。

## 数据流

```
首页豆腐块「AV资讯」
  └─ push /articles ──> ArticlesPage（分页拉取列表，无限滚动）
       └─ 点击卡片 ──> push /articles/:id ──> ArticleDetailPage（拉取详情，渲染正文）
```

## 测试

- `article_service_test.dart`：`fake_adapter` 模拟响应，验证请求参数
  （page/limit、path 参数）与解析结果（author 容错、分页推断）。
- `article_card_test.dart`：封面比例、标题省略、分类标签渲染条件、点击跳转。
- `articles_screen_test.dart`：首屏 loading / error 重试 / 数据渲染 / 加载更多分页交互。
- `article_detail_screen_test.dart`：信息区展示、正文渲染、加载失败重试。
- `api_data` 相关 normalize 断言并入现有测试文件。
