# 首页分区独立加载设计

## 目标

取消首页整页 loading 与整页错误页，让“佳片推荐”“最新上架”“近期磁链更新”三个分区各自独立加载、独立展示 loading 占位、独立失败重试，互不影响。首屏立即渲染搜索栏、豆腐块与三个分区标题，网络请求仍在后台并行进行。

## 范围

- `HomeProvider` 为三个分区分别维护 `items / isLoading / error` 状态。
- `HomePage` 移除整页转圈与整页错误分支，改为分区级 loading 占位与分区级错误重试。
- 新增 Provider 单测与 Widget 测试覆盖分区独立加载、独立失败、独立重试。

不新增依赖，不修改路由目标，不调整影片卡片、`TofuScroll`、`SectionHeader` 的视觉，不改变“换一组”分页请求参数（`/api/v1/movies/latest`，`type=all`，`sort_by=update`，`order_by=desc`，`limit=9`；最新上架 `filter_by=can_play`，磁链更新 `filter_by=magnets`）。

## 现状问题

`HomeProvider.loadAll()` 用单一 `_isLoading`/`_error` 通过 `Future.wait` 并行等待三个分区请求，任一失败即整体失败。`HomePage.build()` 在 `p == null || p.isLoading` 时整页转圈、`p.error != null` 时整页错误页，搜索栏、豆腐块与所有分区都被挡住；重试也只能整页重来。

“换一组”已经是分区级独立状态（`isLatestRefreshing` / `isMagnetRefreshing`、独立页码、失败保留旧数据 + SnackBar），本设计沿用该模式并保持其行为不变。

## 状态设计

`HomeProvider` 为每个分区维护一组独立字段，并用 `HomeSection` 记录聚合状态：

```dart
enum HomeSectionKind { recommends, latest, magnets }

class HomeSection {
  final List<MovieSummary> items;
  final bool isLoading;
  final String? error;
}
```

- `loadAll()` 并发发起三个分区请求（保持现有并行），但每个分区各自提交结果，互不等待、互不失败。
- 分区首次加载失败：该分区 `error` 非空、`isLoading` 为 false，其余分区正常。
- `retrySection(kind)`：只重发该分区的第 1 页请求；成功则清空 `error` 并填充数据。
- 换一组失败：维持现状（保留当前页码与影片、不写入分区 `error`，页面用 SnackBar 提示），与分区首次加载失败语义区分。
- 空列表属于成功响应，页面显示现有空状态。

## 视觉设计

- `HomePage` 始终渲染 `Scaffold + SafeArea + CustomScrollView`，搜索栏与 `TofuScroll` 常驻可见，三个 `SectionHeader` 始终显示。
- 分区加载中：在分区标题下方渲染固定高度的居中 `CircularProgressIndicator` 占位（推荐区高度约 220，网格区约三行卡片高度），与现有简单加载风格一致，不做骨架屏。
- 分区失败：在分区标题下方渲染分区级错误与“重试”按钮（复用 `ErrorRetryWidget` 于固定高度容器中），点击只重载该分区；其余分区正常渲染。
- 分区成功且有数据：渲染现有内容（推荐区 `PageView` 轮播、网格 + “换一组”按钮）。

## 组件边界

- `HomeProvider`：维护三个分区的独立数据、加载、错误状态与页码，提供 `loadAll`、`retrySection`、`reshuffleLatest`、`reshuffleMagnets`。
- `HomePage`：按分区状态渲染占位 / 错误重试 / 内容，触发分区级加载与重试。
- `HomeService`：接口不变。

不将网络逻辑放入 widget，不在页面里维护请求状态。

## 测试策略

### Provider 单测

- 三个分区独立加载：各分区有独立 `isLoading`，一个分区请求挂起时其余分区已就绪。
- 单分区失败不影响其它分区：失败分区 `error` 非空，其余分区数据正常。
- `retrySection` 只重发该分区请求，成功后清空错误并填充数据。
- 现有换一组测试（页码递增、防重复请求、失败保留旧数据）全部保持通过。

### Widget 测试

- 首屏不再整页转圈：搜索栏、`TofuScroll`、三个分区标题立即可见。
- 分区加载中显示占位 `CircularProgressIndicator`。
- 单分区失败显示分区级错误与重试按钮，其它分区内容正常；点击重试后仅该分区重新请求并恢复。
- 现有测试（SafeArea、两个换一组、换组请求参数、换组失败 SnackBar）保持通过。

### 验证命令

先跑 `test/features/home` 聚焦测试，再跑全量 `flutter test` 与 `flutter analyze`，最后 `git diff --check`。
