# 综合搜索实体 Tab 设计

## 目标

补齐综合搜索结果页除“影片”外的六个 Tab。演员、系列、片商、导演、清单、番号均通过 `GET /api/v2/search` 按类型请求数据，并使用项目现有分页控制器实现接近底部时自动加载。系列、片商、导演、番号使用新的无斑马纹名称列表；演员复用演员页网格；清单复用影片详情的相关清单样式。

## 范围

本次包含：

- 为 `actor`、`series`、`maker`、`director`、`list`、`code` 建立统一的搜索服务与分页解析。
- 为系列、片商、导演、番号建立通用列表行组件。
- 为清单建立与影片详情相关清单一致的分页列表。
- 为实体结果接入点击行为：演员进入演员详情，其余实体进入 `CommonListPage`。
- 调整 `CommonListPage` 的数据源契约，使筛选、排序和分页真正参与请求。
- 为所有 Tab 提供首屏加载、空状态、首屏错误重试、尾部加载和尾部错误重试。

本次不新增独立的系列、片商、导演、番号或清单详情页面，也不改变影片 Tab 已确认的筛选行为。

## 搜索接口契约

所有实体搜索固定调用：

```text
GET /api/v2/search
q={keyword}
type={actor|series|maker|director|list|code}
page={page}
limit=48
```

集合键映射如下：

| Tab | type | 响应集合键 | 模型 |
| --- | --- | --- | --- |
| 演员 | `actor` | `actors` | `ActorSummary` |
| 系列 | `series` | `series` | `Series` |
| 片商 | `maker` | `makers` | `Maker` |
| 导演 | `director` | `directors` | `Director` |
| 清单 | `list` | `lists` | `ListModel` |
| 番号 | `code` | `codes` | `Code` |

`videos_count`、`movie_count`、`movies_count` 均规范化为模型的 `movieCount`。清单另外兼容 `views_count` 与 `viewed_count`。番号名称兼容接口的 `name`、`number` 和 `id` 字段。

### 分页兼容

非影片分支在部分服务端版本中缺少 `current_page`、`total_pages` 或 `total`，并可能忽略 `page` 返回重复数据。客户端采用以下规则：

1. 有 `current_page` 和 `total_pages` 时优先使用服务端值。
2. 缺少总页数时，本页返回 48 条才允许尝试下一页；少于 48 条立即结束。
3. 每个 Tab 的分页会话按实体 ID 去重。
4. 下一页没有新增 ID 时返回空增量并结束分页，防止重复结果和无限请求。
5. 切换 Tab 保留各自的控制器、已加载数据、页码和错误状态。

## 组件设计

### 通用名称数量行

新增公开组件，构造接口只暴露：

```dart
SearchEntityListTile({
  required String name,
  required int count,
  required VoidCallback onTap,
})
```

组件用于系列、片商、导演和番号：

- 单行显示 `名称 (数量)`。
- 名称使用主题主文字样式，数量使用 `onSurfaceVariant` 灰色。
- 所有行使用相同的 `surface` 背景，不使用斑马纹。
- 行间使用主题分隔线。
- 不增加副标题和右侧箭头。
- 整行可点击并调用 `onTap`。

列表容器监听滚动通知，在距底部小于 200 像素时调用分页控制器加载下一页。

### 演员 Tab

演员结果解析为 `ActorSummary`，展示层直接复用 `ActorGridView` 与 `ActorCard`。点击演员执行：

```text
/actor/{actor.id}
```

演员网格沿用现有首屏错误、加载、尾部加载、尾部重试和响应式列数行为。

### 清单 Tab

清单结果解析为 `ListModel`，列表视觉与影片详情“相关清单”一致：

- 标题为加粗清单名称。
- 副标题为 `{movieCount} 部影片，被查看 {viewedCount} 次`。
- 右侧显示进入箭头。
- 行间使用分隔线，不使用斑马纹。

相关清单的行样式抽成共享组件，搜索清单和影片详情共同使用，避免两份样式逐渐不一致。

## 公共列表页导航

演员之外的实体结果点击后，通过 `MaterialPageRoute` 打开 `CommonListPage`。页面标题使用搜索结果名称，数据源通过 `/api/v1/movies/tags` 请求影片。

实体过滤条件前缀：

| 实体 | `filter_by` 基础值 |
| --- | --- |
| 系列 | `{type}:s:{id}` |
| 片商 | `{type}:m:{id}` |
| 导演 | `{type}:d:{id}` |
| 番号 | `0:c:{id}` |
| 清单 | `0:l:{id}` |

基础筛选后缀：

| 选择项 | 后缀 |
| --- | --- |
| 全部 | `:` |
| 可播放 | `:p` |
| 含磁链 | `:m` |
| 字幕 | `:c` |

`CommonListPage` 的数据源接口调整为同时接收 `page`、`filter` 和 `sort`：

```dart
typedef CommonListDataSource = Future<PagedResult<MovieSummary>> Function({
  required int page,
  required String filter,
  required String sort,
});
```

页面保留现有四个筛选项和三个排序项。筛选值 `all/playable/magnet/subtitle` 分别映射到上表中的 `:`、`:p`、`:m`、`:c`。排序值按以下规则映射到 `/api/v1/movies/tags` 的 `sort_by`：

| 页面值 | 接口值 |
| --- | --- |
| `date` | `release` |
| `hot` | `hit` |
| `rating` | `score` |

发布日期排序额外发送 `order_by=desc`，每页固定发送 `limit=48`。为保持公共页当前行为，默认筛选继续使用 `magnet`，默认排序继续使用 `date`。筛选或排序变化时通过 `reloadWith` 从第一页重新加载，滚动分页继续由 `MovieGridView` 和 `PaginationController` 完成。实体搜索结果中的 `type` 用于系列、片商和导演的过滤条件前缀；番号和清单固定使用类型 `0`。

`/api/v1/movies/tags` 响应按 `movies`、`current_page`、`total_pages` 和 `total` 解析；缺少总页数时沿用每页 48 条的终止规则。

## 状态与错误处理

每个实体 Tab 使用独立的 `PaginationController`：

- 首次请求中：居中显示进度条。
- 首次请求失败：显示错误信息和重试按钮。
- 成功但无数据：显示明确的空结果状态。
- 追加请求中：已加载列表保持可见，尾部显示小型进度条。
- 追加请求失败：已加载列表保持可见，尾部显示重试按钮并重试相同页码。
- 页面销毁时释放全部分页控制器。

一次搜索关键词发生变化时，路由创建新的 `SearchResultsPage`，各 Tab 重新建立分页会话，不混用旧关键词数据。

## 文件边界

- 搜索服务：构造 `/api/v2/search` 请求并解析六类强类型结果。
- 分页会话：记录已见实体 ID，兼容缺少分页元数据和重复页面。
- 通用名称数量行：只负责名称、数量与点击事件。
- 通用实体分页列表：只负责列表状态、滚动触发和尾部状态。
- 共享清单行：统一搜索清单与影片详情相关清单外观。
- `SearchResultsPage`：组装各 Tab、服务和导航闭包，不再直接解析动态 Map。
- `CommonListPage`：接收筛选感知的数据源并展示影片网格。

## 测试与验收

### 服务测试

- 六个实体类型均发送正确的 `q`、`type`、`page`、`limit=48`。
- 六个响应集合键均解析为对应模型。
- 数量、名称和清单查看次数的兼容字段解析正确。
- 服务端分页元数据存在时按元数据计算下一页。
- 缺少分页元数据时按 48 条阈值计算下一页。
- 重复页被去重并停止分页。

### 组件与页面测试

- `SearchEntityListTile` 通过名称、数量和点击回调三个接口工作。
- 名称和括号数量同行展示，数量使用次要颜色，所有行背景一致。
- 演员 Tab 使用 `ActorGridView` 并进入演员详情。
- 系列、片商、导演、番号进入对应 `CommonListPage`。
- 清单样式与相关清单一致并进入 `CommonListPage`。
- 首屏加载、空状态、首屏错误重试、尾部加载和尾部错误重试均可见且可操作。
- 滚动接近底部后发送下一页请求，切换 Tab 后保留已加载状态。
- `CommonListPage` 的筛选、排序变更会以新条件从第一页重新加载，滚动会加载后续页。

### 最终验证

运行搜索相关聚焦测试、公共列表页测试、影片详情相关清单回归测试、完整 `flutter test` 和 `flutter analyze`。最后使用 ADB 在模拟器上验证六个 Tab 请求、滚动追加、实体点击和公共列表页筛选分页。
