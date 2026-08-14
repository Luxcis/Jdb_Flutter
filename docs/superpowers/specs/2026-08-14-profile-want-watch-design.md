# “我的－我想看的”页面设计

## 目标

实现“我的－我想看的”页面：调用已评价电影接口获取当前用户想看的影片，沿用现有影片页的 `MovieCard` 三列网格、下拉刷新、错误重试和接近底部自动分页；移除导航栏筛选按钮，并在影片类型 Tab 下方增加两组 `SortSegmented` 控件。

## 范围

本次包含：

- 为 `GET /api/v2/users/review_movies` 建立 profile feature 内的数据源与服务。
- 新增独立的“我想看的”页面并接管 `/profile/want-watch` 路由。
- 保留“全部/有码/无码/欧美/FC2/动漫”六个影片类型 Tab，每个 Tab 独立保存分页数据和滚动位置。
- 在 Tab 下方增加“添加时间/发行时间”和“倒序/正序”两组排序控件。
- 复用 `MovieGridView` 与 `MovieCard` 展示影片。
- 增加接口契约、分页、排序、Tab 和页面结构测试。

本次不实现“我看过的”或“近期浏览”，不修改其现有路由行为，不新增筛选条件，不修改 `MovieCard` 的公共行为，不新增依赖。

## 接口契约

固定调用：

```text
GET /api/v2/users/review_movies
status=want_watch
type={all|0|1|2|3|4}
sort_by={create|release}
order_by={desc|asc}
page={page}
limit=24
```

参数映射：

| UI | API 参数 |
| --- | --- |
| 我想看的 | `status=want_watch` |
| 全部 | `type=all` |
| 有码 | `type=0` |
| 无码 | `type=1` |
| 欧美 | `type=2` |
| FC2 | `type=3` |
| 动漫 | `type=4` |
| 添加时间 | `sort_by=create` |
| 发行时间 | `sort_by=release` |
| 倒序 | `order_by=desc` |
| 正序 | `order_by=asc` |

默认排序为 `sort_by=create&order_by=desc`。

成功响应由现有 `ResponseInterceptor` 解开 `{success, data}` 信封后，服务从 `data.movies` 解析 `MovieSummary`，并读取 `current_page`。附件接口没有声明 `total_pages` 或 `total_count`，因此复用 `apiPageResult` 的满页推断：本页达到 24 条时允许请求下一页，少于 24 条时停止分页；若服务端实际返回分页总数字段，继续优先采用该字段。

影片字段先经过 `normalizeMovieSummaryJson`，再由 `MovieSummary.fromJson` 解析，保持封面、标题、番号、评分和发布日期等字段与其他影片页面一致。

## 服务设计

新增 `lib/features/profile/services/review_movies_service.dart`：

```dart
abstract interface class ReviewMoviesDataSource {
  Future<PagedResult<MovieSummary>> getMovies({
    required String status,
    required String type,
    required String sortBy,
    required String orderBy,
    int page = 1,
  });
}
```

- `ReviewMoviesService` 使用现有 `ApiClient` 和 `Endpoints.usersReviewMoviesV2`。
- 服务固定 `limit=24`，并完整发送 `status/type/sort_by/order_by/page/limit`。
- `UnavailableReviewMoviesDataSource` 用于测试或 API 客户端尚不可用时，返回当前页空结果，避免页面初始化崩溃。
- 数据源保留 `status` 参数以准确描述接口能力，但本次页面仅传 `want_watch`，不接管“我看过的”页面。

## 页面与状态设计

新增 `lib/features/profile/screens/profile_review_movies_page.dart`，公开 `ProfileReviewMoviesPage`。构造参数包含：

- `title`：本次固定为“我想看的”。
- `status`：本次固定为 `want_watch`。
- 可选 `ReviewMoviesDataSource`：测试注入口；生产环境从 `ApiClient.instanceOrNull` 创建真实或不可用数据源。

页面结构：

1. `AppBar` 只显示标题，不显示筛选按钮，也不挂载 `FilterDrawer`。
2. `AppBar.bottom` 保留可横向滚动的六个 `Tab`。
3. `body` 使用 `Column`：
   - 第一行是占满可用宽度的紧凑型 `SortSegmented<String>`，选项为“添加时间/发行时间”。
   - 第二行是占满可用宽度的紧凑型 `SortSegmented<String>`，选项为“倒序/正序”。
   - 下方 `Expanded` 放置 `TabBarView`。
4. 每个 Tab 页面使用 `AutomaticKeepAliveClientMixin`，拥有独立的 `PaginationController<MovieSummary>` 和 `MovieGridView`，因此分页结果、加载状态和滚动位置互不污染。
5. Tab 首次实际构建时才请求第一页；切回已访问 Tab 不重复首屏请求。

页面持有共享排序状态。任一排序控件变化时：

- 当前和已初始化的 Tab 从第一页重新加载。
- 未访问 Tab 只更新后续首次请求使用的排序值，不因排序切换提前发起网络请求。
- 已有影片在刷新期间继续显示；新请求成功后整体替换，失败时保留旧影片并展示现有重试入口。
- 重复点击当前已选值不发起请求。

`MovieGridView` 继续负责：

- 使用 `MovieCard` 渲染影片。
- 下拉刷新当前 Tab。
- 当滚动位置距底部小于 400px 时自动获取下一页。
- 首屏加载、首屏错误重试、尾部加载和尾部错误重试。
- 点击卡片后由 `MovieCard` 打开对应详情页。

页面销毁时释放 `TabController` 和所有分页控制器。

## 路由改动

`/profile/want-watch` 的认证守卫保持不变，仅把其子页面替换为：

```dart
ProfileReviewMoviesPage(
  title: '我想看的',
  status: 'want_watch',
)
```

`/profile/watched` 与 `/profile/recent` 继续使用当前占位页面，避免本次需求扩展到未请求功能。

## 错误与空数据

- 网络和解析异常交给 `PaginationController` 捕获。
- 首屏失败由 `MovieGridView` 展示 `ErrorRetryWidget`。
- 追加失败时保留已加载影片并展示“加载失败，点击重试”。
- 排序刷新失败时保留旧排序结果，用户可以重试。
- 空数据沿用现有影片网格的空列表表现，不新增独立文案或组件。
- 快速连续切换排序时依赖 `PaginationController` 的 generation 机制丢弃过期响应，避免旧请求覆盖新选择。

## 测试与验收

### 服务测试

- 请求路径为 `Endpoints.usersReviewMoviesV2`。
- 首屏完整携带 `status=want_watch`、`type=all`、`sort_by=create`、`order_by=desc`、`page=1`、`limit=24`。
- `movies` 正确解析为 `MovieSummary`。
- `current_page` 正确保留。
- 缺少 `total_pages` 时，24 条结果允许第二页，少于 24 条时停止。

### 页面测试

- 标题为“我想看的”，存在六个 Tab。
- 不存在筛选图标、筛选 tooltip 和 `FilterDrawer`。
- 两个 `SortSegmented` 位于 Tab 下方，默认分别选中 `create` 与 `desc`。
- 页面使用 `MovieGridView`，返回影片时能找到 `MovieCard`。
- 首屏请求使用 `type=all`。
- 切换到“无码”后首次请求使用 `type=1`，切回已访问 Tab 保留该 Tab 状态。
- 切换“发行时间”后从第一页请求 `sort_by=release`。
- 切换“正序”后从第一页请求 `order_by=asc`。
- 接近列表底部时请求第二页并追加影片。
- 快速排序切换时过期响应不能覆盖最终选择。

### 最终验证

依次运行：

1. 新增的服务测试。
2. 新增的页面 Widget 测试与现有 profile 子页面测试。
3. `MovieGridView`、`MovieCard` 和分页控制器回归测试。
4. 完整 `flutter test`。
5. `flutter analyze`。
6. `git diff --check`。

## 完成标准

- “我的－我想看的”能从真实接口加载并自动分页。
- 所有影片均通过 `MovieCard` 展示，视觉和详情导航与其他影片页面一致。
- 导航栏不再显示筛选按钮。
- 两组排序控件的参数、默认值和刷新行为与接口文档一致。
- 六个 Tab 的请求参数和分页状态互相独立。
- 不影响“我看过的”“近期浏览”及其他影片页面。
