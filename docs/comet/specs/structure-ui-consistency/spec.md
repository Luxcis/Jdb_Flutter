# Capability: structure-ui-consistency（结构边界与 UT 一致性修复）

本能力描述本 change 归档后项目的路由位置、services 分层、确认弹窗收口与 UI 主题/无障碍一致性的完整行为。

## 路由位置

Scenario: 路由迁出 core
- GIVEN 项目按 RULES.md 组织为 core + features 两层
- WHEN 查看依赖方向
- THEN `lib/core/` 下不 import 任何 feature 代码
- AND 路由实现位于 `lib/router/app_router.dart`，`app.dart`、`main.dart` 与测试经新路径引用
- AND 应用启动、登录守卫跳转、深链参数行为与迁移前一致

## services 分层

Scenario: screen 数据访问经 services
- GIVEN features 中任意 screen 或 feature 内 widget 需要调用 API
- WHEN 读取其数据访问代码
- THEN 引用来自本 feature `services/`（或经 feature index 导出的能力），不出现 `ApiClient.instanceOrNull`
- AND `lib/main.dart` 装配与 `core/widgets`（cached_image、review_tile）的既有使用保持现状

Scenario: 新增 service 保持模式一致
- GIVEN 某个 feature 原本缺少 services 层（如 articles、makers、directors、rankings、search）
- WHEN 为其新建 service
- THEN 结构遵循既有 `*_service.dart` 模式（final ApiClient _api + 实例化）
- AND 网络路径、解析、分页逻辑与本 change 前的 screen 内联逻辑逐行为等价

Scenario: 未登录/失败空态不变
- GIVEN 未登录或 ApiClient 尚未初始化时进入列表、搜索、文章等页面
- WHEN 页面渲染
- THEN 展示与改动前相同的未登录/错误/空态，重试行为不变

## 确认弹窗

Scenario: 统一确认弹窗
- GIVEN 用户在收藏删除、列表删除、退出登录等入口点击触发确认
- WHEN 弹窗弹出
- THEN 展示原有标题、内容与"取消/确定"按钮文案
- AND 取消返回 null、确定返回 true，调用方分支行为不变
- AND 各页不再各自手写 `showDialog<bool>` + AlertDialog 样板

## 主题一致性

Scenario: 中性文字随主题
- GIVEN 通用组件（EmptyState、ErrorRetryWidget、MovieCard、MovieListTile、LoginGuideCard、文章卡片/详情、个人页）渲染弱化文字
- WHEN 主题切换亮/暗模式
- THEN 文字颜色来自 ColorScheme（onSurfaceVariant/outline 系），不再使用固定 `Colors.grey`

Scenario: 错误语义用错误色
- GIVEN 登录/注册错误提示或文章分类胶囊等错误语义元素渲染
- WHEN 主题切换或错误色 token 调整
- THEN 颜色来自 `colorScheme.error`/`errorContainer`，与主题错误色一致

Scenario: 刻意配色保留
- GIVEN FavoriteButton 红心、TopRankingTile 与 RatingBadge 复刻官方配色
- WHEN 主题切换
- THEN 这些固定颜色保持不变（收藏隐喻与官方样式的既有设计）

## 无障碍语义

Scenario: 网格卡片按钮语义
- GIVEN 影片网格 MovieCard 或首页推荐轮播卡片渲染
- WHEN 开启屏幕阅读器遍历
- THEN 卡片以按钮语义播报，label 含影片标题
- AND 点击导航、视觉展示与改动前一致

## 演员网格去重

Scenario: 列数计算单点
- GIVEN 演员网格（手动筛选页与通用 ActorGridView）按可用宽度渲染
- WHEN 计算网格列数
- THEN 计算逻辑仅存在于 actor_grid_view.dart 一处并被两处复用
- AND 两种入口的列数、卡距、滚动行为与改动前一致

## 回归保障

Scenario: 全量检查通过
- GIVEN 完成 Change7/8/9/10 修复
- WHEN 运行 `flutter analyze --no-pub` 与 `flutter test`
- THEN analyze 零告警、全量测试通过，既有行为回归无破坏
