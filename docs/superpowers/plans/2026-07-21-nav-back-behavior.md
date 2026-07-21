# 导航返回行为优化 — 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 修复系统返回键行为：子页面返回上一页，首页/Tab 页双重确认退出

**Architecture:** MainShell 改为 StatefulWidget + PopScope 拦截返回键实现双重确认；所有子页面跳转从 `context.go()` 改为 `context.push()` 建立正常导航栈

**Tech Stack:** Flutter, go_router, Dart SDK `dart:io` (SystemNavigator), `package:flutter/services.dart`

## Global Constraints

- 所有子页面跳转使用 `context.push()` 替代 `context.go()`
- 登录成功/注册成功/退出登录保持 `context.go()`（清栈合理）
- 双重确认退出阈值：2 秒
- SnackBar 文案："再按一次退出应用"
- AppBar 返回按钮利用 `automaticallyImplyLeading: true` 默认值，无需额外改动
- 无新增依赖

---

## File Structure

| 文件 | 职责 | 改动类型 |
|------|------|---------|
| `lib/core/widgets/main_shell.dart` | Tab 容器，PopScope 双重确认退出 | 重写 |
| `lib/features/home/widgets/tofu_scroll.dart` | 首页快捷入口导航 | 1 处替换 |
| `lib/features/home/screens/home_screen.dart` | 首页推荐/最新卡片导航 | 2 处替换 |
| `lib/features/movie_detail/screens/movie_detail_screen.dart` | 影片详情内子导航 | 3 处替换 |
| `lib/features/actors/screens/actors_screen.dart` | 演员列表导航 | 2 处替换 |
| `lib/features/actors/screens/actor_detail_screen.dart` | 演员详情内电影导航 | 1 处替换 |
| `lib/features/profile/screens/profile_screen.dart` | 个人中心子页面导航 | 10 处替换 |
| `lib/features/profile/screens/profile_sub_pages.dart` | profile 通用列表项导航 | 1 处替换 |
| `lib/features/auth/screens/login_screen.dart` | 登录页→注册页 | 1 处替换 |
| `lib/features/auth/screens/register_screen.dart` | 注册页→登录页 | 1 处替换 |
| `lib/core/widgets/login_guide_card.dart` | 未登录引导→登录页 | 1 处替换 |

---

### Task 1: MainShell — PopScope 双重返回确认

**Files:**
- Modify: `lib/core/widgets/main_shell.dart`

**Interfaces:**
- Produces: `MainShell` 改为 `StatefulWidget`，构造函数签名不变 `MainShell({super.key, required this.navigationShell})`

- [ ] **Step 1: 替换 main_shell.dart 为带 PopScope 的 StatefulWidget**

将 `lib/core/widgets/main_shell.dart` 全文替换为：

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  State<MainShell> createState() => _MainShellState();
}

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
        bottomNavigationBar: NavigationBar(
          selectedIndex: widget.navigationShell.currentIndex,
          onDestinationSelected: (i) => widget.navigationShell.goBranch(
            i,
            initialLocation: i == widget.navigationShell.currentIndex,
          ),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home), label: '首页'),
            NavigationDestination(icon: Icon(Icons.bar_chart), label: '排行榜'),
            NavigationDestination(icon: Icon(Icons.category), label: '类别'),
            NavigationDestination(icon: Icon(Icons.people), label: '演员'),
            NavigationDestination(icon: Icon(Icons.person), label: '我的'),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: 运行静态分析验证**

```bash
cd /Users/luxcis/data/workspace/Flutter/Jdb_Flutter && dart analyze lib/core/widgets/main_shell.dart
```

Expected: No issues found.

- [ ] **Step 3: 提交**

```bash
export https_proxy=http://127.0.0.1:7890 http_proxy=http://127.0.0.1:7890 all_proxy=socks5://127.0.0.1:7890
cd /Users/luxcis/data/workspace/Flutter/Jdb_Flutter
git add lib/core/widgets/main_shell.dart
git commit -m "$(cat <<'EOF'
feat: add double-press-to-exit on tab pages via PopScope

EOF
)"
```

---

### Task 2: Home feature — go → push

**Files:**
- Modify: `lib/features/home/widgets/tofu_scroll.dart:36`
- Modify: `lib/features/home/screens/home_screen.dart:70,129`

**Interfaces:**
- Consumes: 无前置依赖
- Produces: 首页所有子页面跳转使用 `context.push()`

- [ ] **Step 1: 修改 tofu_scroll.dart**

将 `lib/features/home/widgets/tofu_scroll.dart` 第 36 行的 `context.go` 改为 `context.push`：

```dart
// 第 36 行，修改前：
          onTap: () => context.go(items[i].route),
// 修改后：
          onTap: () => context.push(items[i].route),
```

- [ ] **Step 2: 修改 home_screen.dart — 推荐卡片**

将 `lib/features/home/screens/home_screen.dart` 第 70 行：

```dart
// 修改前：
                    onTap: () => context.go('/movie/${p.recommends[i].id}'),
// 修改后：
                    onTap: () => context.push('/movie/${p.recommends[i].id}'),
```

- [ ] **Step 3: 修改 home_screen.dart — 网格卡片**

将 `lib/features/home/screens/home_screen.dart` 第 129 行：

```dart
// 修改前：
            onTap: () => context.go('/movie/${items[i].id}'),
// 修改后：
            onTap: () => context.push('/movie/${items[i].id}'),
```

- [ ] **Step 4: 运行静态分析验证**

```bash
cd /Users/luxcis/data/workspace/Flutter/Jdb_Flutter && dart analyze lib/features/home/
```

Expected: No issues found.

- [ ] **Step 5: 提交**

```bash
export https_proxy=http://127.0.0.1:7890 http_proxy=http://127.0.0.1:7890 all_proxy=socks5://127.0.0.1:7890
cd /Users/luxcis/data/workspace/Flutter/Jdb_Flutter
git add lib/features/home/widgets/tofu_scroll.dart lib/features/home/screens/home_screen.dart
git commit -m "$(cat <<'EOF'
refactor: use context.push() for home page sub-navigation

EOF
)"
```

---

### Task 3: Movie detail — go → push

**Files:**
- Modify: `lib/features/movie_detail/screens/movie_detail_screen.dart:229,264,300`

**Interfaces:**
- Consumes: 无前置依赖
- Produces: 影片详情页内子导航使用 `context.push()`

- [ ] **Step 1: 修改 movie_detail_screen.dart — 演员跳转 (L229)**

```dart
// 修改前：
                          onTap: () => context.go('/actor/${d.actors[i].id}'),
// 修改后：
                          onTap: () => context.push('/actor/${d.actors[i].id}'),
```

- [ ] **Step 2: 修改 movie_detail_screen.dart — TA还出演过 (L264)**

```dart
// 修改前：
                                context.go('/movie/${_mayAlsoLike[i].id}'),
// 修改后：
                                context.push('/movie/${_mayAlsoLike[i].id}'),
```

- [ ] **Step 3: 修改 movie_detail_screen.dart — 你可能也喜欢 (L300)**

```dart
// 修改前：
                                context.go('/movie/${_mayAlsoLike[i].id}'),
// 修改后：
                                context.push('/movie/${_mayAlsoLike[i].id}'),
```

- [ ] **Step 4: 运行静态分析验证**

```bash
cd /Users/luxcis/data/workspace/Flutter/Jdb_Flutter && dart analyze lib/features/movie_detail/
```

Expected: No issues found.

- [ ] **Step 5: 提交**

```bash
export https_proxy=http://127.0.0.1:7890 http_proxy=http://127.0.0.1:7890 all_proxy=socks5://127.0.0.1:7890
cd /Users/luxcis/data/workspace/Flutter/Jdb_Flutter
git add lib/features/movie_detail/screens/movie_detail_screen.dart
git commit -m "$(cat <<'EOF'
refactor: use context.push() for movie detail sub-navigation

EOF
)"
```

---

### Task 4: Actors feature — go → push

**Files:**
- Modify: `lib/features/actors/screens/actors_screen.dart:119,171`
- Modify: `lib/features/actors/screens/actor_detail_screen.dart:132`

**Interfaces:**
- Consumes: 无前置依赖
- Produces: 演员相关页面子导航使用 `context.push()`

- [ ] **Step 1: 修改 actors_screen.dart — 网格列表 (L119)**

```dart
// 修改前：
          onTap: () => context.go('/actor/${actors[i].id}'),
// 修改后：
          onTap: () => context.push('/actor/${actors[i].id}'),
```

- [ ] **Step 2: 修改 actors_screen.dart — 列表视图 (L171)**

```dart
// 修改前：
      onActorTap: (actor) => context.go('/actor/${actor.id}'),
// 修改后：
      onActorTap: (actor) => context.push('/actor/${actor.id}'),
```

- [ ] **Step 3: 修改 actor_detail_screen.dart — 电影跳转 (L132)**

```dart
// 修改前：
              onMovieTap: (movie) => context.go('/movie/${movie.id}'),
// 修改后：
              onMovieTap: (movie) => context.push('/movie/${movie.id}'),
```

- [ ] **Step 4: 运行静态分析验证**

```bash
cd /Users/luxcis/data/workspace/Flutter/Jdb_Flutter && dart analyze lib/features/actors/
```

Expected: No issues found.

- [ ] **Step 5: 提交**

```bash
export https_proxy=http://127.0.0.1:7890 http_proxy=http://127.0.0.1:7890 all_proxy=socks5://127.0.0.1:7890
cd /Users/luxcis/data/workspace/Flutter/Jdb_Flutter
git add lib/features/actors/screens/actors_screen.dart lib/features/actors/screens/actor_detail_screen.dart
git commit -m "$(cat <<'EOF'
refactor: use context.push() for actors feature sub-navigation

EOF
)"
```

---

### Task 5: Profile feature — go → push

**Files:**
- Modify: `lib/features/profile/screens/profile_screen.dart:25,32,81,87,92,97,102,107,112,118`
- Modify: `lib/features/profile/screens/profile_sub_pages.dart:370`

**Interfaces:**
- Consumes: 无前置依赖
- Produces: profile 模块所有子页面导航使用 `context.push()`；退出登录 (L125) 保持 `context.go()`

- [ ] **Step 1: 修改 profile_screen.dart — 未登录引导和设置 (L25, L32)**

```dart
// L25 修改前：
                onPressed: () => context.go('/login?from=%2Fprofile'),
// L25 修改后：
                onPressed: () => context.push('/login?from=%2Fprofile'),

// L32 修改前：
                onTap: () => context.go('/profile/settings'),
// L32 修改后：
                onTap: () => context.push('/profile/settings'),
```

- [ ] **Step 2: 修改 profile_screen.dart — 7 个子页面入口 (L81-L118)**

```dart
// L81 修改前：onTap: () => context.go(AppRoutes.profileWantWatch),
// L81 修改后：onTap: () => context.push(AppRoutes.profileWantWatch),

// L87 修改前：onTap: () => context.go(AppRoutes.profileWatched),
// L87 修改后：onTap: () => context.push(AppRoutes.profileWatched),

// L92 修改前：onTap: () => context.go(AppRoutes.profileFollowing),
// L92 修改后：onTap: () => context.push(AppRoutes.profileFollowing),

// L97 修改前：onTap: () => context.go(AppRoutes.profileFavorites),
// L97 修改后：onTap: () => context.push(AppRoutes.profileFavorites),

// L102 修改前：onTap: () => context.go(AppRoutes.profileLists),
// L102 修改后：onTap: () => context.push(AppRoutes.profileLists),

// L107 修改前：onTap: () => context.go(AppRoutes.profileRecent),
// L107 修改后：onTap: () => context.push(AppRoutes.profileRecent),

// L112 修改前：onTap: () => context.go(AppRoutes.profileInfo),
// L112 修改后：onTap: () => context.push(AppRoutes.profileInfo),

// L118 修改前：onTap: () => context.go('/profile/settings'),
// L118 修改后：onTap: () => context.push('/profile/settings'),
```

- [ ] **Step 3: 确认退出登录保持 go (L125)**

确认 `lib/features/profile/screens/profile_screen.dart` 第 125 行保持 `context.go('/home')` 不变。

- [ ] **Step 4: 修改 profile_sub_pages.dart — 通用列表导航 (L370)**

```dart
// 修改前：
    onTap: route == null ? null : () => context.go(route!),
// 修改后：
    onTap: route == null ? null : () => context.push(route!),
```

- [ ] **Step 5: 运行静态分析验证**

```bash
cd /Users/luxcis/data/workspace/Flutter/Jdb_Flutter && dart analyze lib/features/profile/
```

Expected: No issues found.

- [ ] **Step 6: 提交**

```bash
export https_proxy=http://127.0.0.1:7890 http_proxy=http://127.0.0.1:7890 all_proxy=socks5://127.0.0.1:7890
cd /Users/luxcis/data/workspace/Flutter/Jdb_Flutter
git add lib/features/profile/screens/profile_screen.dart lib/features/profile/screens/profile_sub_pages.dart
git commit -m "$(cat <<'EOF'
refactor: use context.push() for profile feature sub-navigation

EOF
)"
```

---

### Task 6: Auth feature cross-nav — go → push

**Files:**
- Modify: `lib/features/auth/screens/login_screen.dart:153`
- Modify: `lib/features/auth/screens/register_screen.dart:175`

**Interfaces:**
- Consumes: 无前置依赖
- Produces: 登录/注册页之间互跳使用 `context.push()`；登录成功 (L70) / 注册成功 (L80) 保持 `context.go()`

- [ ] **Step 1: 修改 login_screen.dart — 去注册 (L153)**

```dart
// 修改前：
                context.go(to);
// 修改后：
                context.push(to);
```

- [ ] **Step 2: 修改 register_screen.dart — 去登录 (L175)**

```dart
// 修改前：
                context.go(to);
// 修改后：
                context.push(to);
```

- [ ] **Step 3: 确认登录/注册成功保持 go**

确认 `login_screen.dart` L70 `context.go(from.isNotEmpty ? from : '/home')` 和 `register_screen.dart` L80 `context.go(to)` 保持 `go` 不变。

- [ ] **Step 4: 运行静态分析验证**

```bash
cd /Users/luxcis/data/workspace/Flutter/Jdb_Flutter && dart analyze lib/features/auth/
```

Expected: No issues found.

- [ ] **Step 5: 提交**

```bash
export https_proxy=http://127.0.0.1:7890 http_proxy=http://127.0.0.1:7890 all_proxy=socks5://127.0.0.1:7890
cd /Users/luxcis/data/workspace/Flutter/Jdb_Flutter
git add lib/features/auth/screens/login_screen.dart lib/features/auth/screens/register_screen.dart
git commit -m "$(cat <<'EOF'
refactor: use context.push() for auth cross-navigation

EOF
)"
```

---

### Task 7: Login guide card — go → push

**Files:**
- Modify: `lib/core/widgets/login_guide_card.dart:39`

**Interfaces:**
- Consumes: 无前置依赖
- Produces: 未登录引导卡片跳转使用 `context.push()`

- [ ] **Step 1: 修改 login_guide_card.dart**

```dart
// 修改前：
                    context.go('/login$from');
// 修改后：
                    context.push('/login$from');
```

- [ ] **Step 2: 运行静态分析验证**

```bash
cd /Users/luxcis/data/workspace/Flutter/Jdb_Flutter && dart analyze lib/core/widgets/login_guide_card.dart
```

Expected: No issues found.

- [ ] **Step 3: 提交**

```bash
export https_proxy=http://127.0.0.1:7890 http_proxy=http://127.0.0.1:7890 all_proxy=socks5://127.0.0.1:7890
cd /Users/luxcis/data/workspace/Flutter/Jdb_Flutter
git add lib/core/widgets/login_guide_card.dart
git commit -m "$(cat <<'EOF'
refactor: use context.push() for login guide card navigation

EOF
)"
```

---

### Task 8: 全量静态分析 + 手动验证

**Files:**
- 无代码改动

- [ ] **Step 1: 运行全量静态分析**

```bash
cd /Users/luxcis/data/workspace/Flutter/Jdb_Flutter && dart analyze
```

Expected: No issues found.

- [ ] **Step 2: 手动验证清单**

在设备/模拟器上运行应用，逐一验证以下场景：

1. **首页按返回键** → 显示 SnackBar "再按一次退出应用"；2 秒内再按 → 退出应用
2. **首页 → 影片详情 → 按返回** → 回到首页
3. **首页 → 影片详情 → 演员详情 → 按返回** → 回到影片详情 → 再按返回 → 回到首页
4. **首页 → "我的" Tab → 设置 → 按返回** → 回到"我的" Tab
5. **"我的" Tab → 我想看的（需登录）→ 登录页 → 按返回** → 回到"我的" Tab
6. **登录页 → 去注册 → 按返回** → 回到登录页
7. **注册页 → 去登录 → 按返回** → 回到注册页
8. **登录成功后** → 跳转到目标页面（from 参数），不回到登录页
9. **退出登录** → 跳转到首页，按返回不回到"我的"
10. **子页面 AppBar** → 左侧显示返回箭头，点击可返回

- [ ] **Step 3: 如有问题修复后提交**

```bash
git add -A
git commit -m "$(cat <<'EOF'
chore: fix issues found in manual verification

EOF
)"
```
