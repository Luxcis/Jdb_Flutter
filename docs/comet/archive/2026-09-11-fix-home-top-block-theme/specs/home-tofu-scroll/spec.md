# Home Tofu Scroll（首页顶部豆腐块入口）

## 概述

首页顶部横向滚动的功能入口条（`TofuScroll`），位于首页搜索框下方，提供七个功能入口卡片。归档后本能力为修复主题实时响应问题的完整行为规格。

## 入口数据

`TofuScroll.items` 为常量入口列表，顺序与配置如下（保持不变）：

| 顺序 | 文案 | 图标 | 路由 | 跳转方式 |
| --- | --- | --- | --- | --- |
| 1 | 看热播 | play_circle | `/rankings?tab=hot` | `go`（替换） |
| 2 | AV资讯 | article | `/articles` | `push` |
| 3 | 看短评 | reviews | `/reviews` | `push` |
| 4 | 找磁链 | link | `/search/magnet` | `push` |
| 5 | 系列 | collections | `/series` | `push` |
| 6 | 片商 | business | `/makers` | `push` |
| 7 | 导演 | person | `/directors` | `push` |

## 布局与视觉

- 整体高度 88，横向 `ListView`，内边距 8，卡片间距 8。
- 每个入口为 72×72 圆角卡片（圆角 10），`Card` margin 为 0，elevation 2，阴影色 `Colors.black.withValues(alpha: 0.16)`，裁切为抗锯齿圆角。
- 卡片背景色取当前主题 `colorScheme.surface`，边框色取 `colorScheme.outlineVariant`。
- 每个入口图标使用各自既有的固定彩色（不随主题变化），图标尺寸 24；文字样式取主题 `textTheme.bodySmall`。
- 测试锚点不变：每个卡片使用 `Key('tofu-<文案>')`。

## 主题实时响应（本次修复的核心行为）

组件 `build()` 必须在自身构建过程中直接建立对 `Theme` 的 Inherited 依赖（解析 `colorScheme` 与文字样式后再传入子项构建闭包），保证元素生命周期中（含 deactivate→reactivate 后的重建）始终持有并恢复主题依赖注册。禁止将唯一的 `Theme.of(context)` 调用留在懒加载 itemBuilder 闭包内部。

### Scenario: 浅色切换深色实时生效

Given 应用处于浅色模式且首页已展示豆腐块
When 通过设置页将外观模式切换为深色（不重启应用）
Then 豆腐块卡片背景立即变为深色主题的 surface 色、边框变为深色主题的 outlineVariant 色，不保留任何浅色 surface 残留

### Scenario: 深色切换浅色实时恢复

Given 应用处于深色模式且首页已展示豆腐块
When 通过设置页将外观模式切换为浅色（不重启应用）
Then 豆腐块卡片背景立即恢复为浅色主题的 surface 色

### Scenario: 跟随系统模式下实时跟随

Given 外观模式为"跟随系统"（ThemeMode.system）且首页已展示豆腐块
When 系统在浅色与深色之间切换
Then 豆腐块卡片配色实时跟随系统亮度变化

### Scenario: 主题切换不破坏交互与内容

Given 豆腐块已随主题完成实时切换
When 用户点击任一入口卡片
Then 跳转行为与既有路由表一致（看热播为 go 替换、其余为 push），图标与文字正常显示

## 交互

- 点击入口按上表路由跳转；除"看热播"外均保留返回栈（push）。
- 卡片点击涟漪效果（InkWell）保持现状。

## 测试要求

- 存在真实链路回归测试：经 `mainForTest` 完成启动进入首页后切换 `ThemeProvider.themeMode`，断言豆腐块卡片颜色实时切换（该用例在修复前失败、修复后通过）。
- 既有 `test/features/home/tofu_scroll_test.dart` 与 `home_screen_test.dart` 全部用例继续通过。
