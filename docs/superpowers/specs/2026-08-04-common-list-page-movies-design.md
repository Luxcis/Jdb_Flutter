# 通用列表页影片接口与展示设计

## 目标

让综合搜索的系列、片商、导演、清单、番号五个实体点击后进入的 `CommonListPage` 真正调用 `/api/v1/movies/tags` 获取影片，用现有瀑布流网格分页展示；筛选默认含磁链、排序默认热度（清单默认存入时间）；筛选与排序分两行各占满整行。

## 范围

本次包含：

- 为 `/api/v1/movies/tags` 建立统一的强类型分页数据源（`TagMoviesDataSource`/`TagMoviesService`/`UnavailableTagMoviesDataSource`）。
- 为 `Series`/`Maker`/`Director`/`Code` 模型补充 `type` 字段，搜索结果解析时保留该字段。
- `CommonListPage` 接收 `type`、`category`、`id` 与可选数据源注入口，内部管理筛选、排序状态与分页。
- 筛选与排序调整为两行，分别占满整行；排序选项按实体类别不同。
- 排序方向切换：仅 `sort_by=release`（发布日期/清单创建时间）支持正序/倒序，其他固定倒序。
- 搜索结果页导航时传入真实实体类型与 ID（清单固定 `type=0`）。

本次不新增实体详情页，不修改影片 Tab 行为，不新增依赖。

## 接口契约

固定调用：

```text
GET /api/v1/movies/tags
filter_by={type}:{category}:{id}[:{filter}]
sort_by={release|update|score|hit|want_watch_count|watched_count|digit}
[order_by={asc|desc}]  仅 sort_by=release 时传
page={page}
limit=48
```

`filter_by` 段位说明：

| 段位 | 名称 | 说明 |
| --- | --- | --- |
| 第1段 | type | 实体类型 0~4（有码/无码/欧美/FC2/动漫）。来自搜索结果实体返回值；清单固定为 0 |
| 第2段 | category | `s`=系列、`m`=片商、`d`=导演、`l`=清单、`c`=番号 |
| 第3段 | id | 实体 ID |
| 第4段 | filter | 可选：`p`=可播放、`m`=含磁链、`c`=字幕；全部则不传第 4 段 |

### 排序选项（按类别）

系列/片商/导演（默认热度）：

| UI 选项 | sort_by | 方向 |
| --- | --- | --- |
| 发布日期 | `release` | 可切正序/倒序（默认倒序） |
| 评分 | `score` | 倒序 |
| 热度（默认） | `hit` | 倒序 |
| 想看人数 | `want_watch_count` | 倒序 |
| 看过人数 | `watched_count` | 倒序 |

番号（默认热度，额外含番号排序）：

| UI 选项 | sort_by | 方向 |
| --- | --- | --- |
| 发布日期 | `release` | 可切正序/倒序（默认倒序） |
| 评分 | `score` | 倒序 |
| 热度（默认） | `hit` | 倒序 |
| 想看人数 | `want_watch_count` | 倒序 |
| 看过人数 | `watched_count` | 倒序 |
| 番号 | `digit` | 倒序 |

清单（默认存入时间，仅三个选项）：

| UI 选项 | sort_by | 方向 |
| --- | --- | --- |
| 存入时间（默认） | `update` | 倒序 |
| 创建时间 | `release` | 倒序（不可切换） |
| 评分 | `score` | 倒序 |

筛选映射（UI → filter 段，默认含磁链）：

| UI 选项 | filter 段 |
| --- | --- |
| 全部 | 不传 |
| 可播放 | `p` |
| 含磁链（默认） | `m` |
| 字幕 | `c` |

集合键为 `movies`（兼容 `movies/items`）。分页元数据兼容 `current_page`、`total_pages`、`total_count`/`total`。

## 服务设计

新增 `lib/features/common/services/tag_movies_service.dart`，公开接口只暴露：

```dart
abstract interface class TagMoviesDataSource {
  Future<PagedResult<MovieSummary>> getMovies({
    required int type,
    required String category,
    required String id,
    required String filter,
    required String sortBy,
    String orderBy = 'desc',
    int page = 1,
  });
}
```

- `TagMoviesService` 固定 `limit=48`；`filter_by` 无筛选时拼接为 `{type}:{category}:{id}`，有筛选时追加 `:{filter}`。
- `sort_by` 直传；`order_by` 仅 `sort_by == 'release'` 时携带，其他排序不传 `order_by`。
- 影片解析复用 `normalizeMovieSummaryJson` 与 `MovieSummary.fromJson`，分页推断与 `CategoryService`/`ActorService.getActorMovies` 一致。
- `UnavailableTagMoviesDataSource` 的 `getMovies` 返回当前页空 `PagedResult`。

## 模型改动

`Series`、`Maker`、`Director`、`Code` 增加 `final int type`（默认 0）。`SearchEntityService` 的 `_namedEntityJson` 与 `_codeJson` 规范化时补充 `'type': apiInt(json['type'], 0)`，保留搜索结果已返回的 type 字段。

## 页面设计

`CommonListPage` 构造参数扩展：

```dart
CommonListPage({
  required String title,
  required int type,
  required String category,
  required String id,
  TagMoviesDataSource? dataSource, // 测试注入口；默认按 ApiClient.instanceOrNull 解析
})
```

- 布局改为两行，每行占满整行：
  1. 第一行：`SortSegmented` 筛选（全部/可播放/含磁链/字幕），`compact` + `expanded` 占满整行，默认含磁链。
  2. 第二行：排序下拉 `SortSelect` 占满整行，右侧方向切换按钮。
- 排序选项由 `category` 决定：普通实体五项、番号六项（含"番号"）、清单三项（存入时间/创建时间/评分）。
- 排序默认值：普通实体与番号默认热度（`hit`），清单默认存入时间（`update`）。
- 方向切换按钮（`IconButton`，如 `arrow_downward`/`arrow_upward`）：仅当当前排序为普通实体的"发布日期"（`sortBy == 'release'` 且 `category != 'l'`）时可用，点击在 `asc`/`desc` 间切换；清单"创建时间"虽映射 `release` 但固定倒序不可切换，其他排序禁用或隐藏。
- fetch 闭包按当前 `_filter`/`_sort`/`_orderBy` 映射为 API 参数调用 `dataSource.getMovies`；筛选/排序/方向变化后 `setState` 并 `_ctrl.reloadWith(_fetchPage)`。
- 保留 `MovieGridView`（瀑布流 + 接近底部自动分页 + 下拉刷新 + 尾部加载/重试）。
- `dispose` 释放 `PaginationController`。

## 导航改动

搜索结果页 `_openCommonList` 传入实体 `type`、`category`、`id`：

| Tab | category | type 来源 |
| --- | --- | --- |
| 系列 | `s` | `item.type` |
| 片商 | `m` | `item.type` |
| 导演 | `d` | `item.type` |
| 清单 | `l` | 固定 `0` |
| 番号 | `c` | `item.type` |

删除占位 `_emptyMoviePage`。

## 测试与验收

### 服务测试

- `filter_by` 无筛选时为 `{type}:{category}:{id}`，有筛选时追加 `:{filter}`。
- `sort_by=hit` 不携带 `order_by`；`sort_by=release` 携带 `order_by` 且值随参数。
- `movies` 集合解析为 `MovieSummary`，分页元数据存在时按元数据计算下一页。
- 缺少 `total_pages` 时按 48 条阈值推断下一页。

### 页面测试

- 筛选与排序分两行，各自占满整行（`SortSegmented` 与 `SortSelect` 均 `expanded`）。
- 首屏请求携带 `filter=m`；普通实体默认 `sort_by=hit`、清单默认 `sort_by=update`。
- 排序选项按类别正确：番号含"番号"（`digit`）、清单仅三项。
- 切换筛选（如全部）后 `filter_by` 去掉第 4 段并重新从第一页加载。
- 切换排序（如评分）后 `sort_by=score` 且不携带 `order_by`。
- 选中普通实体"发布日期"时方向按钮可用，点击后请求 `order_by=asc`；清单"创建时间"及所有其他排序方向按钮不可用。
- 瀑布流 `MovieGridView` 接近底部自动加载下一页。
- 首屏加载、空状态、首屏重试、尾部加载与尾部重试沿用现有行为。
- 搜索结果页各实体点击后进入 `CommonListPage` 并携带正确 `type/category/id`。

### 最终验证

运行搜索相关聚焦测试、公共列表页测试、完整 `flutter test` 和 `flutter analyze`。
