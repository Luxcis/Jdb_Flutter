# 导航返回行为优化 — 设计文档

> 日期: 2026-07-21
> 状态: 已确认

## 1. 问题描述

当前项目所有页面跳转统一使用 `context.go()`（go_router 的路由栈替换式导航），导致系统返回键行为异常：

- **子页面按返回**：因路由栈被替换，无法回退到上一页，直接退出应用
- **首页按返回**：直接退出应用，无二次确认

## 2. 设计目标

1. 子页面按系统返回键 → 返回上一页面（利用 `Navigator` 栈）
2. 首页/Tab 页按返回键 → 显示 SnackBar "再按一次退出应用"，2秒内再次按则退出
3. 子页面顶部导航栏 → 利用 `automaticallyImplyLeading: true`（默认），`push` 导航后自动显示返回箭头

## 3. 方案概述

两步改动，职责分离：

```
MainShell (Tab 容器)                 各子页面
┌─────────────────────┐            ┌──────────────────┐
│ PopScope 拦截返回键  │            │ context.push()    │
│ 双重确认 → 退出应用  │            │ 建立 Navigator 栈 │
└─────────────────────┘            └──────────────────┘
```

## 4. 详细设计

### 4.1 MainShell — 双重返回确认

**文件:** `lib/core/widgets/main_shell.dart`

- 从 `StatelessWidget` 改为 `StatefulWidget`
- 用 `PopScope` 包裹 `Scaffold`，`canPop: false`
- `onPopInvokedWithResult` 中判断：
  - `didPop == true` → Navigator 已处理（子页面已 pop），不干预
  - `didPop == false` → 已在栈底，执行双重确认
- 双重确认逻辑：
  - 记录上次按返回的时间戳 `_lastBackPress`
  - 如果距离上次 < 2 秒 → `SystemNavigator.pop()` 退出
  - 否则 → 显示 `SnackBar(content: Text('再按一次退出应用'))`，更新 `_lastBackPress`

```dart
// 伪代码示意
class MainShell extends StatefulWidget { ... }

class _MainShellState extends State<MainShell> {
  DateTime? _lastBackPress;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final now = DateTime.now();
        if (_lastBackPress != null &&
            now.difference(_lastBackPress!) < const Duration(seconds: 2)) {
          SystemNavigator.pop();
          return;
        }
        _lastBackPress = now;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('再按一次退出应用')),
        );
      },
      child: Scaffold(
        body: widget.navigationShell,
        bottomNavigationBar: NavigationBar(...),
      ),
    );
  }
}
```

### 4.2 导航调用改造 — `context.go()` → `context.push()`

#### 改为 `push` 的场景（23 处）

| 文件 | 行号 | 导航目标 | 说明 |
|------|------|---------|------|
| `tofu_scroll.dart` | 36 | 9 个快捷入口 | 首页快捷跳转 |
| `home_screen.dart` | 70 | `/movie/:id` | 推荐卡片 |
| `home_screen.dart` | 129 | `/movie/:id` | 最新上架卡片 |
| `movie_detail_screen.dart` | 229 | `/actor/:id` | 演员头像 |
| `movie_detail_screen.dart` | 264 | `/movie/:id` | 推荐影片 |
| `movie_detail_screen.dart` | 300 | `/movie/:id` | 推荐影片 |
| `actors_screen.dart` | 119 | `/actor/:id` | 演员列表 |
| `actors_screen.dart` | 171 | `/actor/:id` | 演员列表 |
| `actor_detail_screen.dart` | 132 | `/movie/:id` | 演员参演影片 |
| `profile_screen.dart` | 25 | `/login` | 未登录引导 |
| `profile_screen.dart` | 32 | `/profile/settings` | 设置 |
| `profile_screen.dart` | 81-118 | profile 子页面 | 7 个子页面入口 |
| `profile_sub_pages.dart` | 370 | 动态路由 | 通用列表项 |
| `login_screen.dart` | 153 | `/register` | 去注册 |
| `register_screen.dart` | 175 | `/login` | 去登录 |
| `login_guide_card.dart` | 39 | `/login` | 未登录引导 |

#### 保持 `go` 的场景（3 处）

| 文件 | 行号 | 原因 |
|------|------|------|
| `login_screen.dart` | 70 | 登录成功后清栈跳转目标页 |
| `register_screen.dart` | 80 | 注册成功后清栈跳转登录页 |
| `profile_screen.dart` | 125 | 退出登录后清栈跳转首页 |

## 5. AppBar 返回按钮

所有子页面 AppBar 使用默认 `automaticallyImplyLeading: true`，当 Navigator 栈中有历史记录时自动显示返回箭头。改为 `context.push()` 后，导航栈自然建立，返回箭头自动生效，无需额外改动。

## 6. 边界情况

- **深层导航链**（首页 → 影片详情 → 演员详情 → 影片详情）：`push` 建立正常栈，逐层返回
- **登录/注册互跳**：改为 `push`，用户可在这两页间自由往返
- **退出登录**：保持 `go`，清空栈后跳转首页
- **冷启动直接进入子页面**（如 deep link）：按返回时 `didPop == false`，触发双重确认退出

## 7. 影响范围

- 改动文件：11 个
- 新增依赖：无
- 路由配置（`app_router.dart`）：无改动
- 破坏性变更：无（导航行为从替换栈变为推入栈，用户体验改善）
