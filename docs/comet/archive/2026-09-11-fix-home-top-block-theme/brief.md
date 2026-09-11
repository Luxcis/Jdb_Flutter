# 目标

修复样式问题：首页顶部豆腐块（TofuScroll，"看热播/AV资讯/看短评/找磁链/系列/片商/导演"七个入口卡片）在深色、浅色模式之间不能实时切换，必须重启应用才会更新配色。修复后，豆腐块的配色（卡片背景、边框、阴影以及图标/文字可读性）随应用主题实时变化，与其他首页组件（如顶部搜索框）行为一致。

# 范围

- 修复 `lib/features/home/widgets/tofu_scroll.dart` 的主题依赖缺失问题：组件当前只在懒加载的 `ListView.separated` `itemBuilder` 闭包内调用 `Theme.of(context)`，自身 `build()` 不建立任何 Inherited 依赖；在元素经历 deactivate→reactivate（依赖注册被框架清空）后，组件重建时不会重新注册主题依赖，从此不再响应任何主题切换，直到重启应用。
- 修复方式遵循 `HomeSearchBar` 的既有模式（其实证行为正常）：在 `build()` 顶部直接调用 `Theme.of(context)` 建立主题依赖，并将解析出的配色/文字样式传入 itemBuilder 闭包使用。
- 新增回归测试：通过真实应用启动链路（`mainForTest` + 启动完成后进入首页）验证切换 themeMode 后豆腐块卡片颜色实时变化；该用例在修复前可稳定复现（卡片颜色保持浅色不变）。

## 调查结论（根因证据）

- 复现：真实链路 widget 测试中 `setThemeMode(ThemeMode.dark)` 后，`MaterialApp.themeMode` 已变为 dark、`Theme` 数据已更新、同页 const 子组件 `HomeSearchBar` 实时变色，但豆腐块 `Card.color` 保持浅色 surface 不变（连续多次稳定复现）。
- 元素诊断：`TofuScroll` 的 Element `toString()` 显示无任何 `dependencies` 注册，而同页 `HomeSearchBar(dependencies: [InheritedCupertinoTheme, _InheritedTheme, _LocalizationsScope...])` 注册齐全。
- 框架机制：`Element.activate()` 会清空 `_dependencies`；若此后元素重建时自身不调用 `dependOnInheritedWidgetOfExactType`（`TofuScroll.build` 只构造 ListView，`Theme.of` 位于懒加载 itemBuilder 闭包内，子项在复用场景下不会重新构建），依赖注册永久缺失，组件对后续所有 Inherited 变化（含主题）失聪。

# 非目标

- 不重构应用主题系统（ThemeProvider、MaterialApp 接入方式维持现状）。
- 不做全应用范围的同类模式审计或批量修改其他组件；仅当豆腐块修复涉及共享代码时才触碰其他文件。
- 不改变豆腐块的入口、路由跳转、卡片尺寸、图标与文案。
- 不处理首次启动时主题持久化加载（该链路已正常）。

# 验收示例

- A1: 应用内切换外观模式为深色后，不重启应用，首页顶部豆腐块卡片背景与边框立即变为深色配色（浅色 surface 不再保留）。
- A2: 应用内切换外观模式为浅色后，不重启应用，豆腐块卡片立即恢复浅色配色（深色 surface 不再保留）。
- A3: 外观模式为"跟随系统"（ThemeMode.system）时，系统深浅色切换后，豆腐块配色实时跟随系统变化。
- A4: 主题切换后，豆腐块的图标、文字仍清晰可读，卡片点击路由行为与现状一致（看热播 → /rankings?tab=hot，其余为 push 跳转）。
- A5: 现有 `test/features/home/` 全部用例与 `flutter analyze` 保持通过（回归保护）。

# 约束与不变量

- 不修改 `pubspec.lock`（本机 pub 会改写源，使用 `--no-pub`）。
- 不改变 TofuScroll 的公开 API（`TofuItem`、`TofuScroll.items`、`Key('tofu-<label>')` 测试锚点保持不变）。
- 豆腐块视觉尺寸（72 方块、88 行高、间距 8、圆角 10）与现有 elevation/阴影效果维持现状。
- 主题切换实时性修复不得引入额外重建风暴（利用既有 Inherited 依赖机制，不引入手动监听或定时刷新）。

# 决策

- D1: 根因判定为 TofuScroll 自身 build 缺少主题 Inherited 依赖（证据见"调查结论"），而非主题切换链路（ThemeProvider → MaterialApp.themeMode → Theme）故障；该链路经真实链路测试验证工作正常。
- D2: 修复模式采用 `HomeSearchBar` 既有模式：在 `build()` 顶部解析 `Theme.of(context)` 并将配色传入 itemBuilder 闭包。理由：同页实证对照显示该模式在相同的组件树与元素生命周期下始终保持主题响应。
- D3: 范围限定为豆腐块组件本身 + 回归测试；不做全应用同类模式批量排查（用户报告与观察到的故障仅此一处）。

# 待解决问题

（无 — 当前无阻塞用户决定。）

# 验证预期

- 新增回归测试（真实链路）覆盖 A1：启动进入首页 → 初始浅色 surface → `setThemeMode(dark)` → 断言豆腐块 Card.color 实时变为深色 surface；修复前该用例失败（复现），修复后通过。
- 新增/扩展用例覆盖 A3：ThemeMode.system 下改变 `platformBrightnessTestValue` 后豆腐块颜色实时跟随。
- 运行 `flutter test test/features/home/`（含既有 tofu_scroll_test、home_screen_test）全部通过。
- 运行 `flutter analyze` 无新增问题。
