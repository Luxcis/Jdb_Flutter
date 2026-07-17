## Task 12 完成报告

### Status: ✅ 完成

### Commit
- **Hash:** `0e2dade`
- **Message:** `feat(core/router): add go_router StatefulShellRoute with 5 placeholder tabs`

### 实现内容

1. **routes.dart** — `AppRoutes` 路径常量（home, rankings, categories, actors, profile, login），`protectedRoutes` 为空集合供后续填充。
2. **app_router.dart** — `AppRouter.buildForTest()` 使用 `StatefulShellRoute.indexedStack`，5 个分支各含一个 `GoRoute`，初始路径为 `/home`。
3. **main_shell.dart** — `MainShell` 包含 `Scaffold` + Material 3 `NavigationBar`（5 个 `NavigationDestination`），通过 `goBranch` 切换 tab。
4. **5 个占位 Screen** — 每个 feature 一个 `StatelessWidget`，`Scaffold(body: Center(child: Text('XXX')))`。
5. **index.dart** — 每个 feature 目录导出对应的 Screen。

### Test 结果
- **2/2 通过**
  - `AppRouter 默认渲染首页占位` — 验证首页文本和 NavigationBar 存在
  - `点击排行榜 Tab 切换` — 验证点击排行榜后显示排行榜占位文本

### 注意事项
- 测试中 `find.text('首页')` 使用 `findsAtLeastNWidgets(1)` 而非 `findsOneWidget`，因为 NavigationBar 的 label 也是"首页"，与 Center 文本重复匹配。
- go_router 14.x 使用 `StatefulShellRoute.indexedStack`。

### Report 路径
- `/Users/luxcis/data/workspace/Flutter/Jdb_Flutter/.superpowers/sdd/task-12-report.md`
- Brief: `/Users/luxcis/data/workspace/Flutter/Jdb_Flutter/.superpowers/sdd/task-12-brief.md`
