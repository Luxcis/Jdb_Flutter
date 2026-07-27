# 登录/注册页返回行为修复 — 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 登录/注册页在 redirect/go 进入时按返回键不退出应用，而是跳回来源页

**Architecture:** 给 LoginPage 和 RegisterPage 各自加 `PopScope(canPop: true)` 兜底，`didPop == true` 不干预，`didPop == false` 用 `from` 参数跳回

**Tech Stack:** Flutter, go_router

## Global Constraints

- Push 进入的返回行为不变（`didPop == true` 时不干预）
- `from` 参数从 `GoRouterState.of(context).uri.queryParameters['from']` 读取
- 无 `from` 参数时：登录页 → `/home`，注册页 → `/login`
- 使用 `context.go()` 做兜底跳转（清栈合理，避免残留登录页）

---

## File Structure

| 文件 | 职责 | 改动 |
|------|------|------|
| `lib/features/auth/screens/login_screen.dart` | LoginPage 加 PopScope 兜底 | 包裹 Scaffold |
| `lib/features/auth/screens/register_screen.dart` | RegisterPage 加 PopScope 兜底 | 包裹 Scaffold |

---

### Task 1: LoginPage — PopScope 兜底

**Files:**
- Modify: `lib/features/auth/screens/login_screen.dart`

- [ ] **Step 1: 在 build 方法中包裹 PopScope**

`login_screen.dart` 中 `from`/`hasFrom` 已在第 88-89 行声明。将第 91 行的 `return Scaffold(...)` 改为 `PopScope` 包裹：

```dart
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        context.go(hasFrom ? from : '/home');
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('登录')),
        body: Padding(
```

- [ ] **Step 2: 运行静态分析验证**

```bash
cd /Users/luxcis/data/workspace/Flutter/Jdb_Flutter && dart analyze lib/features/auth/screens/login_screen.dart
```

Expected: No issues found.

- [ ] **Step 3: 提交**

```bash
export https_proxy=http://127.0.0.1:7890 http_proxy=http://127.0.0.1:7890 all_proxy=socks5://127.0.0.1:7890
cd /Users/luxcis/data/workspace/Flutter/Jdb_Flutter
git add lib/features/auth/screens/login_screen.dart
git commit -m "$(cat <<'EOF'
fix: add PopScope fallback for login page back navigation

EOF
)"
```

---

### Task 2: RegisterPage — PopScope 兜底

**Files:**
- Modify: `lib/features/auth/screens/register_screen.dart`

- [ ] **Step 1: 在 build 方法中包裹 PopScope**

`register_screen.dart` 中 `from`/`hasFrom` 已在第 97-99 行声明。将第 101 行的 `return Scaffold(...)` 改为 `PopScope` 包裹：

```dart
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        context.go(hasFrom ? from : '/login');
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('注册')),
        body: Padding(
```

- [ ] **Step 2: 运行静态分析验证**

```bash
cd /Users/luxcis/data/workspace/Flutter/Jdb_Flutter && dart analyze lib/features/auth/screens/register_screen.dart
```

Expected: No issues found.

- [ ] **Step 3: 提交**

```bash
export https_proxy=http://127.0.0.1:7890 http_proxy=http://127.0.0.1:7890 all_proxy=socks5://127.0.0.1:7890
cd /Users/luxcis/data/workspace/Flutter/Jdb_Flutter
git add lib/features/auth/screens/register_screen.dart
git commit -m "$(cat <<'EOF'
fix: add PopScope fallback for register page back navigation

EOF
)"
```

---

### Task 3: 全量静态分析 + 手动验证

- [ ] **Step 1: 运行全量静态分析**

```bash
cd /Users/luxcis/data/workspace/Flutter/Jdb_Flutter && dart analyze
```

Expected: No issues found.

- [ ] **Step 2: 手动验证清单**

1. **个人中心 → 登录 → 按返回** → 回到个人中心
2. **注册页 → 登录 → 按返回** → 回到注册页
3. **访问保护页面被 redirect 到登录 → 按返回** → 回到来源页（from 参数指定的页面）
4. **登录成功** → 跳转目标页，不回到登录页
5. **注册页 → 登录 → 去注册 → 按返回** → 回到登录页
6. **登录页 → 去注册 → 按返回** → 回到登录页
