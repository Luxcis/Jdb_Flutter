# 通用列表页影片接口与展示设计

## 目标

让综合搜索的系列、片商、导演、清单、番号五个实体点击后进入的 `CommonListPage` 真正调用 `/api/v1/movies/tags` 获取影片，用现有瀑布流网格分页展示；筛选默认含磁链、排序默认热度。

## 范围

本次包含：

- 为 `/api/v1/movies/tags` 建立统一的强类型分页数据源（`TagMoviesDataSource`/`TagMoviesService`/`UnavailableTagMoviesDataSource`）。
- 为 `Series`/`Maker`/`Director`/`Code` 模型补充 `type` 字段，搜索结果解析时保留该字段。
- `CommonListPage` 接收 `type`、`category`、`id` 与可选数据源注入口，内部管理筛选、排序状态与分页。
- 搜索结果页导航时传入真实实体类型与 ID（清单固定 `type=0`）。
- 筛选默认含磁链、排序默认热度。

本次不新增实体详情页，不修改影片 Tab 行为，不新增依赖。

## 接口契约

固定调用：

```text
GET /api/v1/movies/tags
filter_by={type}:{category}:{id}[:{filter}]
sort_by={release|hit|score}
[order_by=desc]  仅 sort_by=release 时传
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

排序映射（UI → API）：

| UI 选项 | sort_by |
| --- | --- |
| 最新 | `release` |
| 热门（默认） | `hit` |
| 评分 | `score` |

筛选映射（UI → filter 段）：

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
    int page = 1,
  });
}
```

- `TagMoviesService` 固定 `limit=48`；`filter_by` 无筛选时拼接为 `{type}:{category}:{id}`，有筛选时追加 `:{filter}`；`order_by=desc` 仅 `sort_by == 'release'` 时携带。
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

- `_filter` 默认 `'magnet'`（含磁链），`_sort` 默认 `'hot'`（热度）。
- fetch 闭包按当前 `_filter`/`_sort` 映射为 API 参数调用 `dataSource.getMovies`。
- 筛选/排序变化后 `setState` 并 `_ctrl.reloadWith(_fetchPage)`。
- 保留 `SortSegmented`（compact）、`SortSelect`、`MovieGridView`（瀑布流 + 接近底部自动分页 + 下拉刷新 + 尾部加载/重试）。
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
- `sort_by=hit` 不携带 `order_by`；`sort_by=release` 携带 `order_by=desc`。
- `movies` 集合解析为 `MovieSummary`，分页元数据存在时按元数据计算下一页。
- 缺少 `total_pages` 时按 48 条阈值推断下一页。

### 页面测试

- `CommonListPage` 首屏请求携带 `filter=m`、`sort_by=hit`（默认含磁链、默认热度）。
- 切换筛选（如全部）后请求 `filter_by` 去掉第 4 段并重新从第一页加载。
- 切换排序（如最新）后请求 `sort_by=release` 并携带 `order_by=desc`。
- 瀑布流 `MovieGridView` 接近底部自动加载下一页。
- 首屏加载、空状态、首屏重试、尾部加载与尾部重试沿用现有行为。
- 搜索结果页各实体点击后进入 `CommonListPage` 并携带正确 `type/category/id`。

### 最终验证

运行搜索相关聚焦测试、公共列表页测试、完整 `flutter test` 和 `flutter analyze`。
