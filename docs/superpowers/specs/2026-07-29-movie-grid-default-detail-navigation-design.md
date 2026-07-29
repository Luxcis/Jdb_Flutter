# 影片卡片默认详情导航设计

## 背景

`MovieCard` 是影片网格、首页推荐和影片详情相关推荐共同复用的基础卡片。当前详情导航由各调用方分别传入 `onTap` 或 `onMovieTap`，导致未传回调的卡片不可点击，也让相同的详情跳转逻辑分散在多个页面。

本次修改将详情导航下沉到 `MovieCard`，让所有影片卡片具备一致且不可覆盖的点击行为。

## 目标

- 点击任意 `MovieCard` 后打开该影片的详情页。
- 使用路由栈打开详情页，返回后保留来源页面的 Tab、筛选、分页数据和滚动位置。
- 删除 `MovieCard.onTap` 和 `MovieGridView.onMovieTap`，避免调用方继续覆盖统一行为。
- 清理现有页面中重复的影片详情导航参数和回调。

## 非目标

- 不修改影片详情页的数据加载、布局或错误处理。
- 不修改 `MovieListTile`、演员卡片或其他非 `MovieCard` 组件的点击行为。
- 不重构影片列表、分页或整体路由架构。
- 不新增依赖。

## 架构与组件变更

### `MovieCard`

- 删除构造函数中的 `onTap` 参数和对应字段。
- 引入 `go_router`。
- `GestureDetector.onTap` 固定使用当前影片的 `id` 执行 `context.push('/movie/${movie.id}')`。
- `showTitle`、封面比例、缩略图选择和卡片布局保持不变。

### `MovieGridView`

- 删除构造函数中的 `onMovieTap` 参数和对应字段。
- 不引入或调用路由 API。
- 网格只负责分页、布局和构建 `MovieCard(movie: movie)`。

### 页面调用方

- 排行榜和演员详情删除传给 `MovieGridView` 的 `onMovieTap`。
- 首页影片网格删除传给 `MovieCard` 的显式详情回调。
- 影片详情页删除 `_MovieDetailTabs`、`_BasicInfoTab` 和 `_MovieRowSection` 之间的 `onMovieTap` 参数传递链；相关推荐行只构建 `MovieCard`。
- 页面若仍有演员、登录、列表或其他导航用途，则保留 `go_router` 导入；仅在完全无其他用途时删除。

## 数据与导航流程

1. 调用方使用 `MovieCard(movie: movie)` 展示影片。
2. 用户点击卡片。
3. `MovieCard` 读取自身 `MovieSummary.id`。
4. `MovieCard` 通过 `context.push('/movie/${movie.id}')` 将详情页压入路由栈。
5. `AppRouter` 使用 `/movie/:id` 创建 `MovieDetailPage`。
6. 用户返回时弹出详情页，来源页面及其状态继续保留。

这里使用 `push` 而不是 `go`，因为详情页是来源页面之上的临时层级，返回操作需要恢复原页面状态。

## 错误与边界处理

- `MovieSummary.id` 是现有详情接口和路由的必填标识，本次不新增空值或格式转换逻辑。
- 详情页请求失败继续由现有详情页错误状态处理。
- `MovieCard` 在生产环境中均位于应用的 `GoRouter` 上下文内。
- 不保留自定义点击回调；需要不同交互的业务不得复用 `MovieCard` 绕过统一详情行为。

## 测试设计

### `MovieCard` 组件测试

在 `movie_card_test.dart` 中使用真实 `GoRouter`：

- 初始页面展示包含固定影片 ID 的独立 `MovieCard`。
- 点击卡片。
- 推进路由动画。
- 断言当前路由和详情测试页面对应 `/movie/<id>`。
- 删除旧的自定义 `onTap` 回调测试。

该测试直接保护卡片的统一导航契约，可捕获删除默认点击行为、使用错误影片 ID 或导航到错误路径等回归。

### 网格与分类页回归测试

- `MovieGridView` 测试验证网格中的真实卡片仍可进入对应详情页，同时网格自身不再传入点击回调。
- 分类页测试验证点击分类影片进入详情，返回后分类页和原 Tab 网格仍存在。
- 现有滚动分页测试使用完整拖动手势并保留 400px 自动加载契约，避免可点击卡片加入手势竞技后测试停在边界外。

### 页面调用方验证

- 运行首页、影片详情、排行榜、演员详情相关测试，验证删除回调参数后行为与编译保持正常。
- 使用 `flutter analyze` 覆盖没有独立组件测试的调用路径。

### 全量验证

- 运行定向红绿测试。
- 运行全量 `flutter test`。
- 运行 `flutter analyze`。
- 运行格式化和 `git diff --check`。

## 兼容性

这是一次有意的内部 API 收敛。所有仓库内 `MovieCard.onTap` 和 `MovieGridView.onMovieTap` 调用方将同时更新，不保留已废弃参数或兼容分支。
