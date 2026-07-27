# 登录/注册页返回行为修复 — 设计文档

> 日期: 2026-07-27
> 状态: 已确认

## 1. 问题描述

先前导航优化将大部分页面跳转从 `context.go()` 改为 `context.push()`，但登录/注册页有两类入口仍会清空导航栈：

**登录页入口分析：**

| # | 入口 | 导航方式 | 返回行为 |
|---|------|---------|---------|
| 1 | 个人中心"登录/注册" | `push` ✓ | 正常 pop |
| 2 | 未登录引导卡片 | `push` ✓ | 正常 pop |
| 3 | 注册页"去登录" | `push` ✓ | 正常 pop |
| 4 | 访问受保护页面被 redirect | 路由级 redirect | **退出应用** |
| 5 | API 鉴权错误 `goLoginForAuthError()` | `router.go()` | **退出应用** |

注册页同理。入口 4、5 清空了导航栈，导致按返回键直接退出。

## 2. 设计目标

登录页/注册页按返回键统一行为：优先返回来源页，兜底跳转首页。

## 3. 方案

在 `LoginPage` 和 `RegisterPage` 各自加 `PopScope(canPop: true)` 兜底。

### 3.1 LoginPage

```dart
// 在 Scaffold 外包一层 PopScope
return PopScope(
  canPop: true,
  onPopInvokedWithResult: (didPop, _) {
    if (didPop) return; // push 进入，Navigator 已处理
    final from = GoRouterState.of(context).uri.queryParameters['from'] ?? '';
    context.go(from.isNotEmpty ? from : '/home');
  },
  child: Scaffold(
    appBar: AppBar(title: const Text('登录')),
    body: /* 原有 body */,
  ),
);
```

### 3.2 RegisterPage

同样结构，`from` 参数由注册页传递：

```dart
return PopScope(
  canPop: true,
  onPopInvokedWithResult: (didPop, _) {
    if (didPop) return;
    final from = GoRouterState.of(context).uri.queryParameters['from'] ?? '';
    context.go(from.isNotEmpty ? from : '/login');
  },
  child: Scaffold(
    appBar: AppBar(title: const Text('注册')),
    body: /* 原有 body */,
  ),
);
```

## 4. 边界情况

- **push 进入（入口 1-3）**: `didPop == true`，不干预，正常 pop
- **redirect/go 进入（入口 4-5）**: `didPop == false`，用 `from` 参数跳回目标页
- **无 `from` 参数**: 登录页 → `/home`，注册页 → `/login`
- **已登录用户误入登录/注册页**: 路由级 `_redirect` 已处理（直接跳首页）

## 5. 影响范围

- 改动文件：2 个（`login_screen.dart`、`register_screen.dart`）
- 每个约 10 行新增代码
- 无破坏性变更
