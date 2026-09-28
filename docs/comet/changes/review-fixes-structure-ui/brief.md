# Outcome

完成六维度代码审查报告中的 P1 问题 7、8、9、10 共四项结构修复，保持全部既有用户可见行为不变（除 MovieCard 等新增的无障碍语义播报），`flutter analyze --no-pub` 零告警，`flutter test` 全量通过。

# Scope

- 问题 7（路由上移）：`lib/core/router/app_router.dart` 移出 core，改为 `lib/router/app_router.dart`（与 `app.dart` 同级的顶层 `lib/router/` 目录）；路由守卫实现随路由文件一并迁移，core 不再 import 任何 feature。`STRUCTURE.md` 同步说明路由目录约定。引用处（app.dart、main.dart、测试等）全部同步更新。
- 问题 8（screen 直连 ApiClient 收敛到 services 层）：features 各 screen 及 feature 内 widget（如 `latest_type_tab.dart`、`rank_tabs.dart`、`top250_tab.dart`）不再直接调用 `ApiClient.instanceOrNull`，数据访问统一经由本 feature 的 `services/`。缺少 service 的 feature（articles、makers、directors、rankings、search、home 分区等）按现有 `*_service.dart` 模式新建。`common_list_screen` 等通用页的 ApiClient 空态分支判断随数据获取上移。例外：`lib/main.dart` 的 dataSource 装配、`lib/core/widgets/cached_image.dart` 的图片端点读取、`lib/core/widgets/review_tile.dart`（core 内部能力）保持现状；`features/index.dart` 对外导出的既有公开面不变，`profile/index.dart` 的 service 泄漏不在本次范围（P2）。
- 问题 9（确认弹窗收口）：`lib/core/widgets` 新增 `ConfirmDialog`（`show` 静态入口，参数 title/message/确认/取消文案），7 处重复的取消/确定 `showDialog<bool>`（profile 5 处、following_screen、profile_settings_screen）全部替换，行为与现有弹窗一致（返回 bool，其余行为不动）。
- 问题 10（Theme 化与语义）：
  - 颜色 Token 化：`Colors.grey`（empty_state、error_retry_widget、login_guide_card、movie_card、movie_list_tile、article_card、article_detail、profile_screen）替换为 `colorScheme.onSurfaceVariant`/`outline` 等；错误语义红色（login_screen、register_screen、article_card 分类胶囊、article_detail）替换为 `colorScheme.error`/`errorContainer`。`favorite_button.dart` 的红心颜色与 `top_ranking_tile.dart`/`rating_badge.dart` 复刻官方的固定配色保持不变。
  - 无障碍：`movie_card.dart` 与 `home/widgets/recommend_carousel.dart` 的裸 `GestureDetector` 改为 `Semantics(button: true)+InkWell`（ActorCard 既有模式），可见行为不变、新增按钮语义播报。
  - 网格去重：演员网格"由宽度推导列数"逻辑收口为单一实现（`actor_grid_view.dart` 为权威），`actors_screen.dart` 复用之，删除复制的 LayoutBuilder 计算。

# Non-goals

- 不处理安全 P1（github proxy、域名白名单）与数据层 P1（api_data 兜底、启动串行）——留给后续 change。
- 不做 `core/router` 静态可变全局状态（_activeRouter 等）的重构，只移动位置不改其实现。
- 不改 `movie_grid_view` 大屏自适应、NavigationRail、字号魔法值、遮罩透明度等 P2/P3 项。
- 不迁移 `register_screen` 的 SharedPreferences 直读（问题 8 之外的事项，另行处理）。
- 不引入新依赖、不改变状态管理框架。

# Acceptance examples

- A1: `lib/core/` 下（含子目录）不存在任何 `import ... features/` 或 `package:jade/features/` 引用；路由实现位于 `lib/router/app_router.dart`，`app.dart`/`main.dart`/相关测试的引用全部更新且应用可正常启动。
- A2: `STRUCTURE.md` 与实际目录一致，说明 `lib/router/` 的新位置与"core 不依赖 feature"约定的达成。
- A3: `lib/features/` 下除各自 feature 的 `index.dart` 与 `services/` 外，不存在直接引用 `ApiClient.instanceOrNull` 的代码（profile 最近浏览 service 经 index 导出的既有例外保持现状，详见 Decisions）。
- A4: 新增 service 的 feature（articles、makers、directors、rankings、home 分区、search 等）遵循既有 `*_service.dart` 结构（final ApiClient _api + 实例化模式），无逻辑改写、分页与解析行为不变。
- A5: `common_list_screen` 等页面的"未登录/无连接"空态、错误态展示行为与改动前一致。
- A6: 新增 `ConfirmDialog` 于 `lib/core/widgets`；7 处旧弹窗代码删除并替换为统一入口，各处确认弹窗的标题、内容、按钮文案与"取消返回 null / 确定返回 true"语义完整保留。
- A7: `empty_state`、`error_retry_widget`、`movie_card`、`movie_list_tile` 等通用组件不再出现 `Colors.grey`/`Colors.red` 字面量；亮暗两模式下相应文字颜色随 ColorScheme 变化；`favorite_button` 红心与评分/榜单固定配色未被改动。
- A8: `MovieCard` 与首页推荐轮播卡片使用 `Semantics(button: true)` + InkWell；点击导航、卡片视觉与改动前一致；无障碍树中该卡片播报为按钮（label 含标题）。
- A9: 演员网格列数计算仅存在于 `actor_grid_view.dart` 一处；`actors_screen.dart` 渲染结果（列数、卡距、滚动）与改动前一致。
- A10: `flutter analyze --no-pub` 零告警；`flutter test` 全量通过；受影响场景补必要回归测试（ConfirmDialog 行为等价、service 抽取沿用既有 FakeAdapter 测试）。

# Constraints and invariants

- 保持 `pubspec.lock` 不动（禁止 pub get/pub upgrade 重写）。
- 既有全部用户可见行为（导航、列表、模糊开关、收藏、主题切换）不变；仅新增无障碍语义播报。
- 遵循 RULES.md 目录约定：feature 内只动 screens/widgets/models/services/index.dart；新能力上提 core 只进 `core/widgets`/`core/utils`。
- 每完成一个 feature 的 ApiClient 收敛即运行该 feature 相关测试，避免大改后一次性返工。
- 不触碰本 change 之外的 P1/P2 问题代码（改动只限上述文件集及其直接引用面）。

# Decisions

- D1: 路由位置选 `lib/router/`（顶层），core/router 整体迁出——"core 不依赖 feature"优先；路径常量随路由一并迁移。
- D2: 问题 8 采取全量收敛（所有 feature 的 screen/widget 数据访问走 services），不做渐进半修；新增 service 属实现选择，按现有模式命名。
- D3: `review_tile.dart`（core widget 里的点赞/鉴态）保持 ApiClient 使用现状——它是 core 内部能力，不违反依赖方向；其行为不动。
- D4: `favorite_button.dart` 的红色保留：红心是刻意的收藏隐喻而非错误语义（既有结论），不改。
- D5: ConfirmDialog 只封装现有两种用法（七处全部为删除/登出类确认），不改按钮样式与布局（维持 TextButton 现状），不引入危险色高亮。
- D6: `main.dart:71` dataSource 与 `cached_image.dart` 的 instanceOrNull/domainManager 使用为 core/main 的合法组装点，不收敛。
- D7: 来源覆盖：需求来自本会话审查报告（P1 问题 7/8/9/10，无外部文件），Scope 即完整有效需求集合，全部映射至验收 A1-A10。

# Open questions

（无 [blocking] 项——范围与行为差异均已由审查报告与仓库现状确定。）

# Verification expectations

- `flutter analyze --no-pub` 零告警。
- `flutter test` 全量通过（约 900 项）。
- A1/A3/A6 由 grep 与引用检查证明；A5/A6/A8/A9 以既有 widget 测试 + 新增回归测试证明。
