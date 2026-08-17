# 最新影片列表页设计（最新上架 / 近期磁链更新 → 全部）

> 日期: 2026-08-17
> 状态: 已确认

## 一、背景与目标

首页「最新上架」与「近期磁链更新」两个区块的 `全部` 入口目前没有点击行为。
本次为两者接入同一套影片列表页：

- 点击 `最新上架 > 全部` → 打开「最新影片」列表页（默认筛选 `can_play`）
- 点击 `近期磁链更新 > 全部` → 打开「磁链更新」列表页（默认筛选 `magnets`）

页面顶部为 6 个类型 Tab（全部/有码/无码/欧美/FC2/动漫），Tab 下方同一行内为
筛选控件 `SortSegmented` 与排序控件 `SortSelect`。列表使用现有 `MovieCard` +
`MovieGridView` 固定 3 列网格，滚动自动分页加载。

## 二、已确认需求

| 项 | 结论 |
|---|---|
| 布局 | 复用现有 `MovieGridView`（固定 3 列、宽高比 0.56），**不引入瀑布流依赖** |
| 页面形态 | 单个列表页，query 参数区分入口 |
| Tab 状态 | 6 个 type Tab **各自独立**保存筛选/排序状态 |
| 筛选选项 | 全部 `all` / 可播放 `can_play` / 含磁链 `magnets` / 含字幕 `subtitle` |
| 排序选项 | 仅 发布日期 `release` / 更新时间 `update` 两项 |
| 排序方向 | 不做 asc/desc 切换（release 固定 desc） |
| 默认筛选 | `latest` 入口 → `can_play`；`magnets` 入口 → `magnets` |
| 排序默认 | `update` |
| filter=全部 联动 | 排序强制 `release` 且排序控件禁用（遵循 APK 原版行为） |
| 磁链入口 | 普通列表页，仅默认筛选不同，筛选可自由切换 |
| 空态 | 给 `MovieGridView` 补全局空态（所有使用方受益） |

## 三、API

`GET /api/v1/movies/latest`

| 参数 | 值 | 说明 |
|---|---|---|
| `type` | `all`/`0`/`1`/`2`/`3`/`4` | 全部/有码/无码/欧美/FC2/动漫 |
| `filter_by` | `all`/`can_play`/`magnets`/`subtitle` | 筛选 |
| `sort_by` | `release`/`update` | 排序 |
| `page` | 1 起 | 页码 |
| `limit` | 48 | 每页条数（硬编码） |

请求联动规则（遵循 APK 原版）：

- `filter_by == 'all'` → `sort_by` 强制 `release`
- 否则 → `sort_by` 使用用户选择值

响应信封 `data.movies` / `data.current_page`；分页解析复用
`apiPageResult`（`total_pages` 缺失时按满页推断）。

## 四、架构

### 4.1 新文件

```
lib/features/home/services/latest_movies_service.dart   # API 服务
lib/features/home/screens/latest_movies_page.dart       # 页面（6 Tab 容器）
lib/features/home/widgets/latest_type_tab.dart          # 单个 type Tab（独立 State）
```

### 4.2 服务（LatestMoviesService）

```dart
class LatestMoviesService {
  LatestMoviesService(this._api);
  final ApiClient _api;
  static const _pageSize = 48;

  Future<PagedResult<MovieSummary>> getMovies({
    required String type,
    required String filterBy,
    required String sortBy,
    int page = 1,
  }) async {
    final resp = await _api.get(Endpoints.moviesLatest, queryParameters: {
      'type': type,
      'filter_by': filterBy,
      'sort_by': sortBy,
      'page': page,
      'limit': _pageSize,
    });
    return apiPageResult(
      resp.data,
      keys: const ['movies', 'items'],
      page: page,
      pageSize: _pageSize,
      fromJson: (json) => MovieSummary.fromJson(normalizeMovieSummaryJson(json)),
    );
  }
}
```

数据模型复用 `MovieSummary`，无新增模型。

### 4.3 路由

- `AppRoutes.latestMovies = '/latest-movies'`
- query 参数：`section`（`latest`|`magnets`，默认 `latest`）、`title`（默认「最新影片」）
- `app_router.dart` 注册 GoRoute，从 query 读取参数构造页面

### 4.4 页面（LatestMoviesPage）

```
Scaffold
├── AppBar(title: widget.title, bottom: TabBar(isScrollable: true))
└── TabBarView
    ├── LatestTypeTab(type: 'all',  defaultFilter: _defaultFilter)
    ├── LatestTypeTab(type: '0',   defaultFilter: _defaultFilter)
    ├── LatestTypeTab(type: '1',   defaultFilter: _defaultFilter)
    ├── LatestTypeTab(type: '2',   defaultFilter: _defaultFilter)
    ├── LatestTypeTab(type: '3',   defaultFilter: _defaultFilter)
    └── LatestTypeTab(type: '4',   defaultFilter: _defaultFilter)
```

- Tab 文案：`['全部', '有码', '无码', '欧美', 'FC2', '动漫']`
- `_defaultFilter`：`section == 'magnets' ? 'magnets' : 'can_play'`

### 4.5 单个 Tab（LatestTypeTab）

`StatefulWidget` + `AutomaticKeepAliveClientMixin`（切 Tab 保留状态与已加载数据）。

内部状态：

- `_filter`：初始 `widget.defaultFilter`
- `_sort`：初始 `'update'`
- `PaginationController<MovieSummary> _controller`（`fetch: _fetchPage`）

`_fetchPage` 请求参数：

- `type = widget.type`
- `filterBy = _filter`
- `sortBy = _filter == 'all' ? 'release' : _sort`

UI 布局（仿 CommonListPage）：

```
Column
├── Padding(SortSegmented<String>  // 筛选，key: 'latest-tab-filter'
│     options: 全部/可播放/含磁链/含字幕)
├── Padding(Row
│     ├── SortSelect<String>       // 排序，key: 'latest-tab-sort'
│     │     options: 发布日期(release)/更新时间(update)
│     │     onChanged: _filter == 'all' ? null : _changeSort
│     └── （无方向按钮）)
└── Expanded(MovieGridView(controller: _controller))
```

筛选/排序联动：

- `_filter == 'all'`：`SortSelect.onChanged = null`（禁用），显示「发布日期」，
  请求时 `sort_by = 'release'`
- 其余：`SortSelect` 可用，请求时 `sort_by = _sort`
- 筛选切换：`_controller.reloadWith(_fetchPage)`（清空列表重新加载）
- 排序切换：`_controller.reloadWith(_fetchPage)`

### 4.6 首页入口

```dart
SectionHeader(
  title: '最新上架',
  trailing: '全部',
  onTrailing: () => context.push('/latest-movies?section=latest&title=最新影片'),
),
SectionHeader(
  title: '近期磁链更新',
  trailing: '全部',
  onTrailing: () => context.push('/latest-movies?section=magnets&title=磁链更新'),
),
```

### 4.7 MovieGridView 空态

`MovieGridView` 在 `items.isEmpty && !isLoading && error == null` 时显示
`EmptyState`（默认文案「暂无数据」）。现有测试不受影响（有数据或 loading）。

## 五、错误处理

全部复用 `MovieGridView` 与 `PaginationController` 现有能力：

- 首屏失败：`ErrorRetryWidget` + `controller.refresh`
- 加载更多失败：底部「加载失败，点击重试」
- 空数据：新补的 `EmptyState`
- API 不可用（`ApiClient.instanceOrNull == null`）：与现有页面一致，
  返回空结果（见 `UnavailableTagMoviesDataSource` 模式），页面显示空态

## 六、测试计划

### 新增

`test/features/home/latest_movies_service_test.dart`

- query 参数正确（type/filter_by/sort_by/page/limit）
- 分页解析正确（current_page/total_pages 回退）

`test/features/home/latest_movies_page_test.dart`

- 6 个 Tab 渲染正确
- 默认筛选：`section=latest` → can_play；`section=magnets` → magnets
- 切换 Tab 请求对应 type
- 每 Tab 独立状态（Tab A 改筛选不影响 Tab B）
- filter=全部时：排序控件禁用 + 请求强制 release
- filter=其他时：排序可选，请求用所选 sort

`test/core/widgets/movie_grid_view_test.dart`（追加）

- 空数据（非 loading/error）显示 `EmptyState`

### 修改

`test/features/home/home_screen_test.dart`

- 点击「最新上架 > 全部」跳转 `/latest-movies?section=latest&title=最新影片`
- 点击「近期磁链更新 > 全部」跳转 `/latest-movies?section=magnets&title=磁链更新`

## 七、涉及文件汇总

| 文件 | 操作 |
|---|---|
| `lib/core/router/routes.dart` | 修改：+`latestMovies` 常量 |
| `lib/core/router/app_router.dart` | 修改：+路由 |
| `lib/core/widgets/movie_grid_view.dart` | 修改：+空态 |
| `lib/features/home/services/latest_movies_service.dart` | 新增 |
| `lib/features/home/screens/latest_movies_page.dart` | 新增 |
| `lib/features/home/widgets/latest_type_tab.dart` | 新增 |
| `lib/features/home/screens/home_screen.dart` | 修改：2 个 SectionHeader 加 onTrailing |
| `test/features/home/latest_movies_service_test.dart` | 新增 |
| `test/features/home/latest_movies_page_test.dart` | 新增 |
| `test/core/widgets/movie_grid_view_test.dart` | 修改：+空态测试 |
| `test/features/home/home_screen_test.dart` | 修改：+跳转测试 |

## 八、范围外（YAGNI）

- 不引入瀑布流/水槽布局依赖
- 不做 asc/desc 方向切换
- 不加 score/hit/want_watch_count/watched_count 排序项
- 不做每 Tab 独立的排序方向记忆
- 不动 `CommonListPage` 现有行为
