# JDB Requirements Alignment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 2026-07-21 项目设计需求落实为可追踪规范、可导航页面骨架和关键页面行为修正。

**Architecture:** 复用现有 Feature-First 结构、go_router 顶层路由和 `core/widgets` 共享组件。真实接口接入继续通过现有 service 层推进，本计划优先补齐路由、Tab、筛选 schema、个人中心子页面与演员详情，避免一次性重写已完成的网络和模型层。

**Tech Stack:** Flutter ^3.8.0、Material 3、go_router、provider、dio、json_serializable、flutter_test。

## Global Constraints

- Material Design 3；`ThemeMode.system` 自动切换；`ColorScheme.fromSeed()`；系统字体；无 google_fonts。
- 不做本地化，所有文案中文硬编码；不使用 `.arb`/`flutter_localizations`。
- 不使用触觉反馈。
- Feature-First：`core/` + `features/<name>/{screens,widgets,models,services,index.dart}`；feature 只依赖 core。
- 列表页优先使用 `PaginationController<T>`、`MovieGridView`、`ActorGridView`、`MovieListTile`。

---

## File Structure

- Create: `docs/main/jdb-product-spec.md`，保存最新产品规范。
- Create: `docs/main/api/api-reference.md`，恢复并聚焦动态域名与 API 总览。
- Modify: `lib/core/router/routes.dart`，补充演员详情、搜索/通用入口与个人中心子路由常量。
- Modify: `lib/core/router/app_router.dart`，把空白 `_GatedPage` 换成真实页面。
- Modify: `lib/features/actors/screens/actors_screen.dart`，调整 Tab 与筛选入口。
- Create: `lib/features/actors/screens/actor_detail_screen.dart`，实现演员详情骨架与影片分页。
- Modify: `lib/features/actors/index.dart`，导出演员详情页。
- Modify: `lib/features/categories/screens/categories_screen.dart`，为不同 Tab 提供独立排序与筛选 schema。
- Create: `lib/features/profile/screens/profile_sub_pages.dart`，实现个人中心子页面骨架。
- Modify: `lib/features/profile/index.dart`，导出个人中心子页面。
- Modify: `lib/features/search/screens/search_screen.dart`，补齐搜索初始态与 7 个结果 Tab。
- Modify: `lib/features/common/screens/common_list_page.dart`，补齐排序下拉与默认筛选。
- Test: `test/features/actors/actors_screen_test.dart`，覆盖演员 Tab。
- Test: `test/features/profile/profile_sub_pages_test.dart`，覆盖个人资料、收藏、设置子页面。
- Test: `test/core/router/app_router_requirements_test.dart`，覆盖关键新增路由。

## Tasks

### Task 1: 文档规范

- [x] 写入 `docs/main/jdb-product-spec.md`，逐项固化 0-10 需求。
- [x] 写入 `docs/main/api/api-reference.md`，明确域名动态切换状态机、认证、响应格式与接口分组。

### Task 2: RED 测试

- [ ] 新增演员页 widget 测试，期望出现 `推荐/有码(女)/有码(男)/无码/欧美(女)/欧美(男)`。
- [ ] 新增个人中心子页面测试，期望 `个人资料`、`我的收藏`、`设置` 页面展示需求中的 cell。
- [ ] 新增路由测试，期望 `/actor/sample`、`/profile/info`、`/profile/favorites`、`/search` 可渲染。
- [ ] 运行测试，确认新增测试在实现前失败或暴露现有缺口。

### Task 3: 路由与页面实现

- [ ] 在 `routes.dart` 补齐路径常量和 protected routes。
- [ ] 在 `app_router.dart` 接入演员详情、搜索辅助入口、通用列表入口、个人中心子页面。
- [ ] 实现 `ActorDetailPage`，在无 `ApiClient` 时展示空影片网格但保留详情结构。
- [ ] 实现 `profile_sub_pages.dart`，用 cell、Tab、网格/列表骨架覆盖需求。

### Task 4: 页面行为对齐

- [ ] 调整演员页 Tab 与列表类型映射。
- [ ] 调整类别页排序/筛选 schema 为按 Tab 动态变化。
- [ ] 调整搜索页为 7 个结果 Tab，初始态展示近期热搜与历史搜索。
- [ ] 调整通用页默认筛选为 `含磁链`，并补充排序下拉。

### Task 5: GREEN 与验证

- [ ] 运行 `dart format` 格式化改动文件。
- [ ] 运行新增测试，确认通过。
- [ ] 运行相关既有测试，确认核心导航未回归。
- [ ] 运行 `flutter analyze`，记录剩余问题。

