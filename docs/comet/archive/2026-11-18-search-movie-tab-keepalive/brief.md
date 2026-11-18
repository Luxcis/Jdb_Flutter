# 目标

关键词搜索结果页（`/search/results?q=<关键词>`）中，在 Tab 之间切换时「影片」Tab 不再刷新：切走时不销毁状态，切回时保留已加载的影片列表、分页进度、筛选条件与滚动位置，不重复向数据源发起请求。

# 范围

- 「影片」Tab 的页面状态在 `TabBarView` 切换时保持存活：切到其他 Tab 不销毁，切回不重建、不重新加载。
- 切回「影片」Tab 时不重置分页游标、不清空已加载条目、不重复请求数据源。
- 「影片」Tab 的类型/筛选/排序选择，以及影片网格的滚动位置，在切换 Tab 后保持切换前的状态。
- 其他 6 个 Tab（演员、系列、片商、导演、清单、番号）现有的状态保持行为不变。
- 页面级刷新路径保持不变：提交新关键词仍整体重建结果页并按新词从第一页加载；下拉刷新、切换筛选条件、加载更多、加载失败重试的行为不变。

## 目录结构

### 修改

- lib/features/search/widgets/search_result_tabs.dart — 为 `_MovieSearchTabState` 混入 `AutomaticKeepAliveClientMixin`（`wantKeepAlive => true`，`build` 中调用 `super.build(context)`），与 `_ActorSearchTabState`、`_PaginatedEntitySearchTabState` 对齐；不改变 `MovieSearchTab` 的构造参数、请求逻辑与筛选逻辑。

### 新建

- test/features/search/search_results_tab_state_test.dart — 覆盖切换 Tab 不重复请求、筛选与滚动位置保留、其他 Tab 状态保持的 widget 测试（注入 fake 影片/实体数据源）。

# 非目标

- 不改搜索结果页的页面标识与重建规则：提交新关键词仍以完整 URI 作为页面键整体重建，各 Tab 以新关键词重新加载。
- 不改动其他 Tab 的数据加载、分页与去重逻辑，不改 `PaginationController`、`SearchPageSession`、`MovieGridView` 的实现。
- 不改磁链搜索结果页（`/search/magnet/results`，无 Tab 结构）。
- 不为「影片」Tab 新增缓存过期、定时刷新、跨页面/跨关键词缓存或离线存储机制。
- 不改动筛选条 UI、下拉刷新交互与加载失败重试入口。

# 验收示例

- 在关键词搜索结果页从「影片」Tab 切到「演员」Tab 再切回「影片」Tab，影片数据源在此期间不再收到新的分页请求，网格内容与切换前一致。
- 在「影片」Tab 向下滚动影片网格后切到其他 Tab 再切回，网格滚动位置保持在切换前的位置（不回到顶部）。
- 在「影片」Tab 选择类型筛选「有码」后切到其他 Tab 再切回，筛选条仍显示「有码」为选中态，且不触发重新加载。
- 在「影片」Tab 与「演员」Tab 之间往返切换，演员数据源不被重复请求，演员列表保持切换前的状态。
- 在结果页提交新关键词后，页面仍整体重建，「影片」Tab 以新关键词从第一页重新加载并回到「影片」Tab。
- 首次进入关键词搜索结果页时，URL 中的关键词仍写入搜索历史，且各 Tab 仍以该关键词加载数据。

# 约束与不变量

- 复用 Flutter 内置 `AutomaticKeepAliveClientMixin` 机制，不引入第三方缓存依赖或新的状态管理方案。
- 保持 `MovieSearchTab` 现有行为：首次创建即加载第一页、筛选变更调用 `reloadWith` 重新加载、下拉刷新与加载更多沿用 `PaginationController`。
- 保持「页面键由完整 URI（含 query 参数）决定」的既有重建规则（见 `docs/comet/specs/search-results/spec.md`）；本次改动只影响同一页面内的 Tab 切换，不影响新关键词导致的页面重建。
- 保活状态只随页面销毁释放，不跨页面、跨关键词复用。
- 测试运行避免隐式 `pub get` 重写 `pubspec.lock`：使用 `--no-pub` 或镜像源变量（`PUB_HOSTED_URL=https://pub.flutter-io.cn`）。

# 决策

- D1：为「影片」Tab 增加 `AutomaticKeepAliveClientMixin`，而不是在 Tab 切换回调中缓存列表数据或改造页面级缓存。理由：其余 6 个 Tab 已使用同一机制，行为一致、改动最小；保活同时自动保留分页游标、筛选状态与滚动位置，无需额外状态传递。
- D2：不把该行为做成可配置开关（其他 Tab 均无开关），避免引入无用配置项。
- D3：不新增“切换 Tab 时刷新”的手势或按钮；需要刷新时用户仍可下拉刷新（既有 `RefreshIndicator`）。
- D4：验收用 fake 数据源的请求计数与可视状态断言实现，不依赖真实网络；新关键词重建与搜索历史写入沿用既有测试作为回归保护。

# 验证预期

- `flutter analyze` 无新增告警。
- 新增 `test/features/search/search_results_tab_state_test.dart` 全部通过，且 `test/features/search/` 现有测试与 `test/core/widgets/review_selection_search_test.dart` 不回归。
