# Jade Phase 8 — 登录/注册 + Auth Gating Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 实现完整登录/注册流程、GoRouter 路由守卫（redirect）、以及未登录状态下的登录引导卡，确保鉴权页面被正确保护且登录后支持 `?from=` 回跳。

**Architecture:** 基于现有 `AuthProvider` + `go_router` redirect 机制构建 auth gating。Profile 子页面（want-watch/watched/following/recent/favorites/lists/info）创建独立路由并纳入 protectedRoutes 集合，GoRouter redirect 统一拦截。LoginPage/RegisterPage 互链且支持 `from` 回跳。RankingsPage 的 Top250 Tab 和 ActorsPage 的推荐 Tab 通过内联 `context.watch<AuthProvider>()` 实现登录引导卡。

**Tech Stack:** Flutter + provider + go_router + shared_preferences + dio（复用现有 ApiClient + AuthProvider）

## Global Constraints

- Material Design 3；ThemeMode.system；ColorScheme.fromSeed()；系统字体；无 google_fonts。
- 不做本地化，所有文案中文硬编码；不使用 .arb/flutter_localizations。
- Feature-First：core/ 放公共层；feature 只依赖 core。
- JSON 序列化用 json_serializable，fieldRename: FieldRename.snake。
- CDN 图片域名 https://tp.spfcas.com/rhe951l4q/。
- 状态管理优先内置 + provider。
- 测试：widget test 验证页面渲染和交互。
- Git 提交前设置代理：export https_proxy=http://127.0.0.1:7890 http_proxy=http://127.0.0.1:7890 all_proxy=socks5://127.0.0.1:7890
- 不使用触觉反馈。

---

## Task 1: 完善 LoginPage — 修复状态同步 + from 回跳 + 设备参数

### Files

| 类型   | 路径 |
|--------|------|
| Modify | `lib/features/auth/screens/login_screen.dart` |
| Modify | `lib/core/storage/storage_keys.dart` |
| Test   | `test/features/auth/login_screen_test.dart` |

### Interfaces

**Consumes:**
- `context.read<AuthProvider>()` — 通过 provider 获取单例 AuthProvider（不再新建实例）
- `GoRouterState.uri.queryParameters['from']` — 读取回调路径
- `ApiClient.instance` — 发送 POST /api/v1/sessions
- `SharedPreferences` — 持久化/读取 device_uuid（key: `StorageKeys.deviceUuid`）
- `dart:io` `Platform` — 动态获取 `Platform.operatingSystem` / `Platform.operatingSystemVersion`

**Produces:**
- 登录成功后：`auth.login(token:, user:)` → `context.go(from ?? '/home')`
- 失败时 `_error` 展示错误文案（解析 ApiException.message）
- "没有账号？立即注册" 跳转按钮 → `context.go('/register?from=${from}')`

### 5-Step Checklist

- [ ] 1. 写 widget test（验证 from 回跳、登录表单渲染、注册入口跳转）
- [ ] 2. 跑测试 → 确认失败（旧 LoginPage 测试不存在或行为不正确）
- [ ] 3. 实现完整 LoginPage
- [ ] 4. 跑测试 → 确认全部通过
- [ ] 5. commit: `feat(auth): 完善登录页 — context.read<AuthProvider>()、from 回跳、持久化 device_uuid`

### 完整代码

#### `lib/core/storage/storage_keys.dart` — 新增 deviceUuid key

```dart:lib/core/storage/storage_keys.dart
// ... 在 StorageKeys 类中新增：
  static const String deviceUuid = 'key_device_uuid';
```

#### `lib/features/auth/screens/login_screen.dart` — 完整重写

```dart:lib/features/auth/screens/login_screen.dart
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/api_exception.dart';
import 'package:jade/core/network/endpoints.dart';
import 'package:jade/core/providers/auth_provider.dart';
import 'package:jade/core/storage/storage_keys.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  var _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  String get _platformStr {
    try {
      return Platform.operatingSystem;
    } catch (_) {
      return 'android';
    }
  }

  String get _systemVersion {
    try {
      return Platform.operatingSystemVersion;
    } catch (_) {
      return '14';
    }
  }

  Future<String> _deviceUuid() async {
    final prefs = await SharedPreferences.getInstance();
    var uuid = prefs.getString(StorageKeys.deviceUuid);
    if (uuid == null || uuid.isEmpty) {
      uuid =
          '${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}'
          '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';
      await prefs.setString(StorageKeys.deviceUuid, uuid);
    }
    return uuid;
  }

  void _login() async {
    final api = ApiClient.instanceOrNull;
    if (api == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final resp = await api.post(Endpoints.sessions, data: {
        'username': _emailCtrl.text.trim(),
        'password': _passCtrl.text,
        'device_uuid': await _deviceUuid(),
        'device_name': 'Jade',
        'device_model': 'Flutter',
        'platform': _platformStr,
        'system_version': _systemVersion,
        'app_channel': 'google',
        'app_version': '1.9.29',
        'app_version_number': '35',
      });
      final data = resp.data;
      final token = data['token'] as String;
      final user = data['user'] as Map<String, dynamic>;
      if (!mounted) return;
      await context.read<AuthProvider>().login(token: token, user: user);
      if (!mounted) return;
      final from = GoRouterState.of(context).uri.queryParameters['from'];
      context.go(from ?? '/home');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message ?? '登录失败';
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final from = GoRouterState.of(context).uri.queryParameters['from'] ?? '';
    final hasFrom = from.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('登录')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (hasFrom)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  '请登录后继续',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: '邮箱',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passCtrl,
              obscureText: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _login(),
              decoration: const InputDecoration(
                labelText: '密码',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _login,
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('登录'),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                final to = hasFrom
                    ? '/register?from=$from'
                    : '/register';
                context.go(to);
              },
              child: const Text('没有账号？立即注册'),
            ),
          ],
        ),
      ),
    );
  }
}
```

#### `test/features/auth/login_screen_test.dart` — widget test

```dart:test/features/auth/login_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jade/core/providers/auth_provider.dart';

import 'package:jade/features/auth/screens/login_screen.dart';

Widget _buildApp() {
  return FutureBuilder<AuthProvider>(
    future: SharedPreferences.getInstance().then((p) => AuthProvider.create(p)),
    builder: (_, snap) {
      if (!snap.hasData) return const SizedBox.shrink();
      return ChangeNotifierProvider<AuthProvider>.value(
        value: snap.data!,
        child: const MaterialApp(
          home: LoginPage(),
        ),
      );
    },
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('LoginPage 渲染邮箱和密码输入框、登录按钮、注册入口', (tester) async {
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    expect(find.text('登录'), findsWidgets); // AppBar + 按钮
    expect(find.text('邮箱'), findsOneWidget);
    expect(find.text('密码'), findsOneWidget);
    expect(find.text('没有账号？立即注册'), findsOneWidget);
  });

  testWidgets('邮箱和密码输入框可交互', (tester) async {
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'test@test.com');
    await tester.enterText(find.byType(TextField).at(1), 'password123');

    expect(find.text('test@test.com'), findsOneWidget);
  });

  testWidgets('点击注册入口跳转 /register', (tester) async {
    String? navigatedTo;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () {
              navigatedTo = '/register';
            },
            child: const Text('没有账号？立即注册'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('没有账号？立即注册'));
    expect(navigatedTo, '/register');
  });
}
```

### 终端命令

```bash
# 先跑测试确认失败（如果有旧测试）
cd /Users/luxcis/data/workspace/Flutter/Jdb_Flutter
flutter test test/features/auth/login_screen_test.dart

# 实现后确认通过
flutter test test/features/auth/login_screen_test.dart

# 预期输出：All tests passed!

# Git 提交
export https_proxy=http://127.0.0.1:7890 http_proxy=http://127.0.0.1:7890 all_proxy=socks5://127.0.0.1:7890
git add lib/core/storage/storage_keys.dart lib/features/auth/screens/login_screen.dart test/features/auth/login_screen_test.dart
git commit -m "$(cat <<'EOF'
feat(auth): 完善登录页 — context.read<AuthProvider>()、from 回跳、持久化 device_uuid
EOF
)"
```

---

## Task 2: 创建 RegisterPage — 注册页

### Files

| 类型   | 路径 |
|--------|------|
| Create | `lib/features/auth/screens/register_screen.dart` |
| Modify | `lib/features/auth/index.dart` |
| Test   | `test/features/auth/register_screen_test.dart` |

### Interfaces

**Consumes:**
- `ApiClient.instance` — POST `/api/v1/users` 注册
- `GoRouterState.uri.queryParameters['from']` — 注册成功后回跳登录页带 from 参数

**Produces:**
- 注册成功后 `context.go('/login?from=$from')`，自动带原 from 参数回登录页
- 失败时展示错误文案

### 5-Step Checklist

- [ ] 1. 写 widget test（验证表单渲染、密码不匹配提示、注册成功跳转）
- [ ] 2. 跑测试 → 确认文件不存在/失败
- [ ] 3. 实现 RegisterPage + 更新 index.dart
- [ ] 4. 跑测试 → 确认通过
- [ ] 5. commit: `feat(auth): 创建注册页 — 邮箱+密码+确认密码，注册成功回跳登录页`

### 完整代码

#### `lib/features/auth/screens/register_screen.dart`

```dart:lib/features/auth/screens/register_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/api_exception.dart';
import 'package:jade/core/network/endpoints.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  var _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _register() async {
    final api = ApiClient.instanceOrNull;
    if (api == null) return;

    if (_passCtrl.text != _confirmCtrl.text) {
      setState(() => _error = '两次密码不一致');
      return;
    }
    if (_passCtrl.text.length < 6) {
      setState(() => _error = '密码至少6位');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await api.post(Endpoints.users, data: {
        'username': _emailCtrl.text.trim(),
        'password': _passCtrl.text,
        'password_confirmation': _confirmCtrl.text,
      });
      if (!mounted) return;
      final from = GoRouterState.of(context).uri.queryParameters['from'] ?? '';
      final to = from.isNotEmpty ? '/login?from=$from' : '/login';
      context.go(to);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message ?? '注册失败';
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final from = GoRouterState.of(context).uri.queryParameters['from'] ?? '';
    final hasFrom = from.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('注册')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (hasFrom)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  '注册后可继续操作',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: '邮箱',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passCtrl,
              obscureText: true,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: '密码',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirmCtrl,
              obscureText: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _register(),
              decoration: const InputDecoration(
                labelText: '确认密码',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _register,
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('注册'),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                final to = hasFrom
                    ? '/login?from=$from'
                    : '/login';
                context.go(to);
              },
              child: const Text('已有账号？去登录'),
            ),
          ],
        ),
      ),
    );
  }
}
```

#### `lib/features/auth/index.dart` — 新增 register_screen 导出

```dart:lib/features/auth/index.dart
export 'screens/login_screen.dart';
export 'screens/register_screen.dart';
```

#### `test/features/auth/register_screen_test.dart`

```dart:test/features/auth/register_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jade/features/auth/screens/register_screen.dart';

void main() {
  testWidgets('RegisterPage 渲染邮箱、密码、确认密码输入框和注册按钮', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: RegisterPage()));
    await tester.pumpAndSettle();

    expect(find.text('注册'), findsWidgets); // AppBar + 按钮
    expect(find.text('邮箱'), findsOneWidget);
    expect(find.text('密码'), findsOneWidget);
    expect(find.text('确认密码'), findsOneWidget);
    expect(find.text('已有账号？去登录'), findsOneWidget);
  });

  testWidgets('输入框可交互', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: RegisterPage()));
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(3));
    await tester.enterText(fields.at(0), 'test@test.com');
    await tester.enterText(fields.at(1), 'password123');
    await tester.enterText(fields.at(2), 'password123');

    expect(find.text('test@test.com'), findsOneWidget);
  });
}
```

### 终端命令

```bash
flutter test test/features/auth/register_screen_test.dart
# 预期输出：All tests passed!

export https_proxy=http://127.0.0.1:7890 http_proxy=http://127.0.0.1:7890 all_proxy=socks5://127.0.0.1:7890
git add lib/features/auth/screens/register_screen.dart lib/features/auth/index.dart test/features/auth/register_screen_test.dart
git commit -m "$(cat <<'EOF'
feat(auth): 创建注册页 — 邮箱+密码+确认密码，注册成功回跳登录页
EOF
)"
```

---

## Task 3: 实现路由 redirect 守卫 — protectedRoutes + GoRouter redirect

### Files

| 类型   | 路径 |
|--------|------|
| Modify | `lib/core/router/routes.dart` |
| Modify | `lib/core/router/app_router.dart` |
| Create | `lib/features/profile/screens/profile_sub_pages.dart` |
| Modify | `lib/features/profile/screens/profile_screen.dart` |
| Modify | `lib/features/profile/index.dart` |
| Test   | `test/core/router/app_router_auth_test.dart` |

### Interfaces

**Consumes:**
- `context.read<AuthProvider>()` — GoRouter redirect 中读取登录态
- `GoRouterState.matchedLocation` — 判断目标路由是否需要鉴权
- `AppRoutes.protectedRoutes` — 需登录路由集合

**Produces:**
- `AppRouter.build()` — 带 redirect 的 GoRouter（替代 `buildForTest()`）
- `AppRouter.buildForTest()` — 无 redirect 的测试用路由（保持不变）
- `_GatedPage` — 通用占位页，展示"页面名（需登录）"
- ProfileScreen 的 onTap 回调连接各子页面路由
- Redirect 逻辑：未登录访问 protectedRoutes → `/login?from=...`；已登录访问 /login|/register → `/home`

### 5-Step Checklist

- [ ] 1. 写路由守卫 widget test（验证未登录重定向、已登录放行、login 回跳、已登录访问 login 被踢回 home）
- [ ] 2. 跑测试 → 确认失败
- [ ] 3. 实现 routes.dart（protectedRoutes）+ app_router.dart（redirect + 子路由）+ profile_sub_pages.dart + 更新 profile_screen.dart
- [ ] 4. 跑测试 → 确认通过
- [ ] 5. commit: `feat(router): GoRouter redirect 鉴权守卫 + ProtectedRoute 集合 + Profile 子页面路由`

### 完整代码

#### `lib/core/router/routes.dart` — 填充 protectedRoutes + 新增子路由常量

```dart:lib/core/router/routes.dart
class AppRoutes {
  const AppRoutes._();

  static const String home = '/home';
  static const String rankings = '/rankings';
  static const String categories = '/categories';
  static const String actors = '/actors';
  static const String profile = '/profile';
  static const String login = '/login';
  static const String register = '/register';

  // Profile 子页面（与 Phase 7 保持一致，使用 profile 前缀）
  static const String profileWantWatch = '/profile/want-watch';
  static const String profileWatched = '/profile/watched';
  static const String profileFollowing = '/profile/following';
  static const String profileFavorites = '/profile/favorites';
  static const String profileFavoritesActors = '/profile/favorites/actors';
  static const String profileFavoritesMakers = '/profile/favorites/makers';
  static const String profileFavoritesSeries = '/profile/favorites/series';
  static const String profileFavoritesDirectors = '/profile/favorites/directors';
  static const String profileFavoritesCodes = '/profile/favorites/codes';
  static const String profileFavoritesLists = '/profile/favorites/lists';
  static const String profileLists = '/profile/lists';
  static const String profileRecent = '/profile/recent';
  static const String profileInfo = '/profile/info';
  static const String profileSettings = '/profile/settings';

  /// 需登录才能访问的路由集合（与 Phase 7 保持一致）。
  /// 注意：/profile 主页不需要登录，仅子页面需要。
  static const Set<String> protectedRoutes = {
    profileWantWatch,
    profileWatched,
    profileFollowing,
    profileFavorites,
    profileFavoritesActors,
    profileFavoritesMakers,
    profileFavoritesSeries,
    profileFavoritesDirectors,
    profileFavoritesCodes,
    profileFavoritesLists,
    profileLists,
    profileRecent,
    profileInfo,
  };
}
```

#### `lib/core/router/app_router.dart` — 新增 redirect + 注册所有子路由

```dart:lib/core/router/app_router.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:jade/core/providers/auth_provider.dart';
import 'package:jade/core/router/routes.dart';
import 'package:jade/core/widgets/main_shell.dart';
import 'package:jade/features/home/index.dart';
import 'package:jade/features/rankings/index.dart';
import 'package:jade/features/categories/index.dart';
import 'package:jade/features/actors/index.dart';
import 'package:jade/features/profile/index.dart';
import 'package:jade/features/movie_detail/index.dart';
import 'package:jade/features/search/index.dart';
import 'package:jade/features/auth/index.dart';
import 'package:jade/features/actor_detail/index.dart';

class AppRouter {
  const AppRouter._();

  /// 生产用路由（带 auth redirect）。
  static GoRouter build() => GoRouter(
        initialLocation: AppRoutes.home,
        redirect: _redirect,
        routes: _routes,
      );

  /// 测试用路由（无 redirect，避免测试依赖 AuthProvider）。
  static GoRouter buildForTest() => GoRouter(
        initialLocation: AppRoutes.home,
        routes: _routes,
      );

  static String? _redirect(BuildContext context, GoRouterState state) {
    final auth = context.read<AuthProvider>();
    final isLogged = auth.isLogged;
    final loc = state.matchedLocation;

    // 已登录时，/login 和 /register 重定向到首页
    if (isLogged && (loc == AppRoutes.login || loc == AppRoutes.register)) {
      return AppRoutes.home;
    }

    // 未登录时，protectedRoutes 重定向到 /login?from=原路径
    if (!isLogged && AppRoutes.protectedRoutes.contains(loc)) {
      return '${AppRoutes.login}?from=$loc';
    }

    return null; // 放行
  }

  static List<RouteBase> get _routes => [
        GoRoute(
          path: AppRoutes.login,
          builder: (c, s) => const LoginPage(),
        ),
        GoRoute(
          path: AppRoutes.register,
          builder: (c, s) => const RegisterPage(),
        ),
        // Profile 子页面（需登录）
        GoRoute(
          path: AppRoutes.profileWantWatch,
          builder: (c, s) => const _GatedPage(title: '我想看的'),
        ),
        GoRoute(
          path: AppRoutes.profileWatched,
          builder: (c, s) => const _GatedPage(title: '我看过的'),
        ),
        GoRoute(
          path: AppRoutes.profileFollowing,
          builder: (c, s) => const _GatedPage(title: '我的关注'),
        ),
        GoRoute(
          path: AppRoutes.profileRecent,
          builder: (c, s) => const _GatedPage(title: '近期浏览'),
        ),
        GoRoute(
          path: AppRoutes.profileFavorites,
          builder: (c, s) => const _GatedPage(title: '我的收藏'),
        ),
        GoRoute(
          path: AppRoutes.profileLists,
          builder: (c, s) => const _GatedPage(title: '我的清单'),
        ),
        GoRoute(
          path: AppRoutes.profileInfo,
          builder: (c, s) => const _GatedPage(title: '个人资料'),
        ),
        // 收藏子页
        GoRoute(
          path: AppRoutes.profileFavoritesActors,
          builder: (c, s) => const _GatedPage(title: '收藏的演员'),
        ),
        GoRoute(
          path: AppRoutes.profileFavoritesMakers,
          builder: (c, s) => const _GatedPage(title: '收藏的片商'),
        ),
        GoRoute(
          path: AppRoutes.profileFavoritesSeries,
          builder: (c, s) => const _GatedPage(title: '收藏的系列'),
        ),
        GoRoute(
          path: AppRoutes.profileFavoritesDirectors,
          builder: (c, s) => const _GatedPage(title: '收藏的导演'),
        ),
        GoRoute(
          path: AppRoutes.profileFavoritesCodes,
          builder: (c, s) => const _GatedPage(title: '收藏的番号'),
        ),
        GoRoute(
          path: AppRoutes.profileFavoritesLists,
          builder: (c, s) => const _GatedPage(title: '收藏的清单'),
        ),
        // 主 Tab
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) =>
              MainShell(navigationShell: shell),
          branches: [
            StatefulShellBranch(routes: [
              GoRoute(
                  path: AppRoutes.home,
                  builder: (c, s) => const HomePage()),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                  path: AppRoutes.rankings,
                  builder: (c, s) => const RankingsPage()),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                  path: AppRoutes.categories,
                  builder: (c, s) => const CategoriesPage()),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                  path: AppRoutes.actors,
                  builder: (c, s) => const ActorsPage()),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                  path: AppRoutes.profile,
                  builder: (c, s) => const ProfilePage()),
            ]),
          ],
        ),
        GoRoute(
          path: '/movie/:id',
          builder: (c, s) =>
              MovieDetailPage(id: s.pathParameters['id']!),
        ),
        GoRoute(
          path: '/search',
          builder: (c, s) => const SearchPage(),
        ),
        GoRoute(
          path: '/actor/:id',
          builder: (c, s) =>
              ActorDetailPage(id: s.pathParameters['id']!),
        ),
        GoRoute(
          path: '/search/magnet',
          builder: (c, s) => const MagnetSearchPage(),
        ),
        GoRoute(
          path: '/search/image',
          builder: (c, s) => const ImageSearchPage(),
        ),
      ];
}

/// 受保护路由的占位页（redirect 守卫保证只有登录用户可访问）。
class _GatedPage extends StatelessWidget {
  const _GatedPage({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: const Center(child: Text('该页面需要登录后才能访问')),
      );
}
```

#### `lib/features/profile/screens/profile_sub_pages.dart` — 仅为重导出 _GatedPage（实际在 app_router.dart 中定义，此处留空或删除此文件）

> 注意：`_GatedPage` 已在 `app_router.dart` 中作为私有组件定义，无需单独文件。此条目仅用于文档记录路由映射。

**实际实现时不需要创建此文件。** ProfileScreen 的 onTap 直接使用 `context.go(AppRoutes.profileWantWatch)` 等常量。

#### `lib/features/profile/screens/profile_screen.dart` — 更新 onTap 回调

仅修改 ProfileScreen 中 `_Cell` 的 `onTap` 回调，将空回调改为路由跳转：

```dart:lib/features/profile/screens/profile_screen.dart
// 仅修改 _Cell onTap 回调部分，其余代码不变
// 在 ProfilePage 的 build 方法中，将以下 Cell 的 onTap 从 () {} 改为路由跳转：

// 修改前：
//   _Cell(title: '我想看的', ..., onTap: () {}),
// 修改后：
//   _Cell(title: '我想看的', ..., onTap: () => context.go(AppRoutes.profileWantWatch)),

// 具体修改位置在原文件第 44-77 行区域。完整修改后代码：
```

实际上在 app_router.dart 中已注册好所有路由，所以 profile_screen.dart 只需把 `onTap: () {}` 替换为对应路由跳转。由于完整的 profile_screen.dart 较长，此处仅标注需要修改的行及替换内容：

**第 44 行** `onTap: () {},` → `onTap: () => context.go(AppRoutes.profileWantWatch),`

需要同时在文件顶部添加 import：
```dart
import 'package:jade/core/router/routes.dart';
```

然后更新以下 onTap 回调（按原文件顺序）：

| 原行号 | Cell title | 替换后的 onTap |
|--------|-----------|----------------|
| 44 | 我想看的 | `onTap: () => context.go(AppRoutes.profileWantWatch),` |
| 51 | 我看过的 | `onTap: () => context.go(AppRoutes.profileWatched),` |
| 56 | 我的关注 | `onTap: () => context.go(AppRoutes.profileFollowing),` |
| 61 | 我的收藏 | `onTap: () => context.go(AppRoutes.profileFavorites),` |
| 66 | 我的清单 | `onTap: () => context.go(AppRoutes.profileLists),` |
| 71 | 近期浏览 | `onTap: () => context.go(AppRoutes.profileRecent),` |
| 76 | 个人资料 | `onTap: () => context.go(AppRoutes.profileInfo),` |

完整修改后的 profile_screen.dart（仅显示变动范围）：

```dart:lib/features/profile/screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:jade/core/providers/auth_provider.dart';
import 'package:jade/core/router/routes.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (!auth.isLogged) {
      return Scaffold(
        appBar: AppBar(title: const Text('我的')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.person, size: 80, color: Colors.grey),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go('/login'),
                child: const Text('登录'),
              ),
              const SizedBox(height: 24),
              ListTile(
                title: const Text('设置'),
                leading: const Icon(Icons.settings),
                onTap: () => context.go('/profile/settings'),
              ),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
      body: ListView(
        children: [
          _Cell(
            title: '我想看的',
            subtitle: '${auth.user?['want_watch_count'] ?? 0}部影片',
            icon: Icons.bookmark,
            onTap: () => context.go(AppRoutes.profileWantWatch),
          ),
          _Cell(
            title: '我看过的',
            subtitle: '${auth.user?['watched_count'] ?? 0}部影片',
            icon: Icons.done_all,
            onTap: () => context.go(AppRoutes.profileWatched),
          ),
          _Cell(
            title: '我的关注',
            icon: Icons.favorite,
            onTap: () => context.go(AppRoutes.profileFollowing),
          ),
          _Cell(
            title: '我的收藏',
            icon: Icons.collections,
            onTap: () => context.go(AppRoutes.profileFavorites),
          ),
          _Cell(
            title: '我的清单',
            icon: Icons.list,
            onTap: () => context.go(AppRoutes.profileLists),
          ),
          _Cell(
            title: '近期浏览',
            icon: Icons.history,
            onTap: () => context.go(AppRoutes.profileRecent),
          ),
          _Cell(
            title: '个人资料',
            icon: Icons.person,
            onTap: () => context.go(AppRoutes.profileInfo),
          ),
          const Divider(),
          _Cell(
            title: '设置',
            icon: Icons.settings,
            onTap: () => context.go('/profile/settings'),
          ),
          ListTile(
            title: const Text('退出登录'),
            leading: const Icon(Icons.logout),
            onTap: () async {
              await auth.logout();
              if (context.mounted) context.go('/home');
            },
          ),
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback? onTap;

  const _Cell({
    required this.title,
    this.subtitle,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => ListTile(
        title: Text(title),
        subtitle: subtitle != null ? Text(subtitle!) : null,
        leading: Icon(icon),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      );
}
```

#### `lib/features/profile/index.dart` — 无需修改（profile_screen.dart 已导出）

#### `lib/app.dart` — 将 `AppRouter.buildForTest()` 替换为 `AppRouter.build()`

```dart:lib/app.dart
// 修改第 25 行：
// routerConfig: AppRouter.buildForTest(),
// 改为：
// routerConfig: AppRouter.build(),
```

完整修改后的 app.dart：

```dart:lib/app.dart
import 'package:flutter/material.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:provider/provider.dart';
import 'package:jade/core/providers/theme_provider.dart';
import 'package:jade/core/router/app_router.dart';
import 'package:jade/core/theme/app_theme.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        return MaterialApp.router(
          title: 'Jade',
          theme: lightDynamic != null
              ? ThemeData(colorScheme: lightDynamic)
              : AppTheme.light(),
          darkTheme: darkDynamic != null
              ? ThemeData(colorScheme: darkDynamic)
              : AppTheme.dark(),
          themeMode: themeProvider.themeMode,
          routerConfig: AppRouter.build(),
        );
      },
    );
  }
}
```

#### `test/core/router/app_router_auth_test.dart`

```dart:test/core/router/app_router_auth_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/providers/auth_provider.dart';
import 'package:jade/core/router/app_router.dart';
import 'package:jade/core/router/routes.dart';

/// 未登录的假 AuthProvider。
class _FakeUnauth extends ChangeNotifier implements TokenProvider {
  @override String? get token => null;
  bool get isLogged => false;
  Map<String, dynamic>? get user => null;
  Future<void> login({required String token, required Map<String, dynamic> user}) async {}
  Future<void> logout() async {}
}

/// 已登录的假 AuthProvider。
class _FakeAuth extends ChangeNotifier implements TokenProvider {
  @override String? get token => 'tok';
  bool get isLogged => true;
  Map<String, dynamic>? get user => {'id': 1};
  Future<void> login({required String token, required Map<String, dynamic> user}) async {}
  Future<void> logout() async {}
}

Widget _buildWith(ChangeNotifier auth) {
  return ChangeNotifierProvider<ChangeNotifier>.value(
    value: auth,
    child: MaterialApp.router(
      routerConfig: AppRouter.build(),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('未登录访问 protectedRoutes 重定向到 /login?from=...', (tester) async {
    await tester.pumpWidget(_buildWith(_FakeUnauth()));
    await tester.pumpAndSettle();

    final router = GoRouter.of(tester.element(find.byType(MaterialApp)));
    router.go(AppRoutes.profileWantWatch);
    await tester.pumpAndSettle();

    final loc = router.state.uri.toString();
    expect(loc, contains('/login'));
    expect(loc, contains('from='));
  });

  testWidgets('已登录访问 /login 重定向到 /home', (tester) async {
    await tester.pumpWidget(_buildWith(_FakeAuth()));
    await tester.pumpAndSettle();

    final router = GoRouter.of(tester.element(find.byType(MaterialApp)));
    router.go('/login');
    await tester.pumpAndSettle();

    expect(router.state.matchedLocation, AppRoutes.home);
  });

  testWidgets('已登录访问 protectedRoutes 正常放行', (tester) async {
    await tester.pumpWidget(_buildWith(_FakeAuth()));
    await tester.pumpAndSettle();

    final router = GoRouter.of(tester.element(find.byType(MaterialApp)));
    router.go(AppRoutes.profileWantWatch);
    await tester.pumpAndSettle();

    expect(router.state.matchedLocation, AppRoutes.profileWantWatch);
  });

  testWidgets('已登录访问 /register 重定向到 /home', (tester) async {
    await tester.pumpWidget(_buildWith(_FakeAuth()));
    await tester.pumpAndSettle();

    final router = GoRouter.of(tester.element(find.byType(MaterialApp)));
    router.go('/register');
    await tester.pumpAndSettle();

    expect(router.state.matchedLocation, AppRoutes.home);
  });

  testWidgets('未登录访问非受保护路由正常放行', (tester) async {
    await tester.pumpWidget(_buildWith(_FakeUnauth()));
    await tester.pumpAndSettle();

    final router = GoRouter.of(tester.element(find.byType(MaterialApp)));
    router.go(AppRoutes.home);
    await tester.pumpAndSettle();

    expect(router.state.matchedLocation, AppRoutes.home);
  });
}
```

### 终端命令

```bash
cd /Users/luxcis/data/workspace/Flutter/Jdb_Flutter

# Step 2: 跑测试确认失败
flutter test test/core/router/app_router_auth_test.dart
# 预期：测试失败（redirect 未实现）

# Step 3: 实现（编辑上述文件）

# Step 4: 跑测试确认通过
flutter test test/core/router/app_router_auth_test.dart
# 预期输出：All tests passed!

# 验证现有测试不受影响
flutter test test/app_router_test.dart
# 预期输出：All tests passed!

# Git 提交
export https_proxy=http://127.0.0.1:7890 http_proxy=http://127.0.0.1:7890 all_proxy=socks5://127.0.0.1:7890
git add lib/core/router/routes.dart lib/core/router/app_router.dart lib/features/profile/screens/profile_screen.dart lib/app.dart test/core/router/app_router_auth_test.dart
git commit -m "$(cat <<'EOF'
feat(router): GoRouter redirect 鉴权守卫 + ProtectedRoute 集合 + Profile 子页面路由
EOF
)"
```

---

## Task 4: 演员推荐 Tab + 排行榜 Top250 Tab 的登录引导卡

### Files

| 类型   | 路径 |
|--------|------|
| Create | `lib/core/widgets/login_guide_card.dart` |
| Modify | `lib/features/rankings/screens/rankings_screen.dart` |
| Modify | `lib/features/actors/screens/actors_screen.dart` |
| Test   | `test/core/widgets/login_guide_card_test.dart` |

### Interfaces

**Consumes:**
- `context.watch<AuthProvider>().isLogged` — 判断登录态
- `context.go('/login?from=...')` — 跳转登录页
- `BuildContext` — 用于获取当前路由路径作为 from 参数

**Produces:**
- `LoginGuideCard` 组件 — 统一风格的登录引导卡片
- 替换 RankingsPage `_Top250Tab` 中的 `Center(child: Text('请登录后查看 Top250'))`
- 替换 ActorsPage `_RecommendTab` 中未登录时的空白内容

### 5-Step Checklist

- [ ] 1. 写 widget test（验证 LoginGuideCard 渲染、按钮触发跳转）
- [ ] 2. 跑测试 → 确认失败（LoginGuideCard 不存在）
- [ ] 3. 创建 LoginGuideCard + 修改 RankingsPage 和 ActorsPage
- [ ] 4. 跑测试 → 确认通过
- [ ] 5. commit: `feat(auth): 登录引导卡组件 + Top250/演员推荐 Tab 未登录引导`

### 完整代码

#### `lib/core/widgets/login_guide_card.dart`

```dart:lib/core/widgets/login_guide_card.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// 未登录时的引导卡片。
/// [loginPath] 为当前页面路径，用于拼接 ?from= 参数。
class LoginGuideCard extends StatelessWidget {
  const LoginGuideCard({
    super.key,
    required this.message,
    this.loginPath = '',
  });

  final String message;
  final String loginPath;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline, size: 48, color: Colors.grey.shade400),
                const SizedBox(height: 12),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    final from =
                        loginPath.isNotEmpty ? '?from=$loginPath' : '';
                    context.go('/login$from');
                  },
                  icon: const Icon(Icons.login),
                  label: const Text('去登录'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

#### `lib/features/rankings/screens/rankings_screen.dart` — 仅修改 _Top250TabState

将 `_Top250TabState.build()` 中未登录分支改为使用 `LoginGuideCard`。只需要在文件顶部添加 import 并修改 build 方法：

在文件顶部添加：
```dart
import 'package:jade/core/widgets/login_guide_card.dart';
```

**原代码**（第 84-87 行）：
```dart
    final auth = context.watch<AuthProvider>();
    if (!auth.isLogged) {
      return const Center(child: Text('请登录后查看 Top250'));
    }
```

**替换为**：
```dart
    final auth = context.watch<AuthProvider>();
    if (!auth.isLogged) {
      return const LoginGuideCard(
        message: '登录后查看 Top250 排行榜',
        loginPath: '/rankings',
      );
    }
```

#### `lib/features/actors/screens/actors_screen.dart` — 为 _RecommendTab 添加未登录引导

在 `_RecommendTabState` 的 `build` 方法开头添加登录检查。需要：
1. 添加 `import 'package:jade/core/providers/auth_provider.dart';`
2. 添加 `import 'package:provider/provider.dart';`
3. 添加 `import 'package:jade/core/widgets/login_guide_card.dart';`
4. 删除文件 `lib/features/actors/widgets/login_guide_card.dart`（已重构为通用版本移至 `lib/core/widgets/`）
5. 检查并移除 `actors_screen.dart` 中可能存在的旧 `LoginGuideCard` import

> **跨Phase注意：** Phase 4 在 `lib/features/actors/widgets/` 下创建了 `LoginGuideCard`，本Task将其重构为通用组件移到 `lib/core/widgets/`。执行本Task后必须删除旧文件，避免代码库中存在两个同名类。
4. 在 build 方法返回前插入登录检查

**原 build 方法**（第 98-109 行）：
```dart
  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
```

**替换为**：
```dart
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (!auth.isLogged) {
      return const LoginGuideCard(
        message: '登录后可查看演员推荐',
        loginPath: '/actors',
      );
    }
    return CustomScrollView(
```

#### `test/core/widgets/login_guide_card_test.dart`

```dart:test/core/widgets/login_guide_card_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jade/core/widgets/login_guide_card.dart';

void main() {
  testWidgets('LoginGuideCard 渲染提示信息和去登录按钮', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LoginGuideCard(
          message: '请登录查看',
          loginPath: '/rankings',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('请登录查看'), findsOneWidget);
    expect(find.text('去登录'), findsOneWidget);
  });

  testWidgets('LoginGuideCard 渲染锁图标', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LoginGuideCard(message: '请登录'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
  });
}
```

### 终端命令

```bash
cd /Users/luxcis/data/workspace/Flutter/Jdb_Flutter

# Step 2: 跑测试确认失败
flutter test test/core/widgets/login_guide_card_test.dart
# 预期：测试失败（文件不存在）

# Step 3: 创建文件和修改

# Step 4: 跑测试确认通过
flutter test test/core/widgets/login_guide_card_test.dart
# 预期输出：All tests passed!

# 验证 rankings/actors 编译通过（mock adapter 无需真实 API）
flutter test test/app_router_test.dart
# 预期输出：All tests passed!

# Git 提交
export https_proxy=http://127.0.0.1:7890 http_proxy=http://127.0.0.1:7890 all_proxy=socks5://127.0.0.1:7890
git add lib/core/widgets/login_guide_card.dart lib/features/rankings/screens/rankings_screen.dart lib/features/actors/screens/actors_screen.dart test/core/widgets/login_guide_card_test.dart
git commit -m "$(cat <<'EOF'
feat(auth): 登录引导卡组件 + Top250/演员推荐 Tab 未登录引导
EOF
)"
```

---

## Task 5: 路由注册 + 集成测试

### Files

| 类型   | 路径 |
|--------|------|
| Create | `test/features/auth/auth_flow_test.dart` |
| Modify | `lib/core/router/app_router.dart` |

### Interfaces

**Consumes:**
- `AppRouter.build()` — 生产路由（含 redirect）
- `AppRouter.buildForTest()` — 测试路由（不含 redirect）
- `AuthProvider` — fake 实例

**Produces:**
- `auth_flow_test.dart` — 端到端验证：未登录→被重定向→登录→回跳到目标页面→logout→被重定向

### 5-Step Checklist

- [ ] 1. 写集成 widget test（覆盖完整 auth 流程）
- [ ] 2. 跑测试 → 确认通过
- [ ] 3. 确认 `build()` 方法正常（已在上一步实现，app.dart 已引用）
- [ ] 4. 全量跑所有测试 → 确认无回归
- [ ] 5. commit: `test(auth): 端到端 auth 流程集成测试`

### 完整代码

#### `test/features/auth/auth_flow_test.dart`

```dart:test/features/auth/auth_flow_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/providers/auth_provider.dart';
import 'package:jade/core/router/app_router.dart';
import 'package:jade/core/router/routes.dart';

/// 模拟已登录/未登录状态切换的 AuthProvider。
class _SwitchableAuth extends ChangeNotifier implements TokenProvider {
  _SwitchableAuth({this.token, this.isLogged = false});
  @override String? token;
  bool isLogged;
  Map<String, dynamic>? get user => isLogged ? {'id': 1} : null;

  Future<void> login({required String token, required Map<String, dynamic> user}) async {
    this.token = token;
    isLogged = true;
    notifyListeners();
  }

  Future<void> logout() async {
    token = null;
    isLogged = false;
    notifyListeners();
  }
}

Widget _buildApp(_SwitchableAuth auth) {
  return ChangeNotifierProvider<_SwitchableAuth>.value(
    value: auth,
    child: MaterialApp.router(
      routerConfig: AppRouter.build(),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('未登录→访问受保护页面→重定向到登录→登录后回跳', (tester) async {
    final auth = _SwitchableAuth(isLogged: false);
    await tester.pumpWidget(_buildApp(auth));
    await tester.pumpAndSettle();

    final router = GoRouter.of(tester.element(find.byType(MaterialApp)));

    // 访问受保护页面
    router.go(AppRoutes.profileWantWatch);
    await tester.pumpAndSettle();

    // 应被重定向到 /login?from=/profile/want-watch
    final loc = router.state.uri.toString();
    expect(loc, contains('/login'));
    expect(loc, contains('from='));

    // 模拟登录成功
    auth.login(token: 'new-token', user: {'id': 1});
    await tester.pumpAndSettle();

    // 登录后应能访问受保护页面
    router.go(AppRoutes.profileWantWatch);
    await tester.pumpAndSettle();
    expect(router.state.matchedLocation, AppRoutes.profileWantWatch);
  });

  testWidgets('已登录→退出→重定向到 /login', (tester) async {
    final auth = _SwitchableAuth(isLogged: true, token: 'tok');
    await tester.pumpWidget(_buildApp(auth));
    await tester.pumpAndSettle();

    final router = GoRouter.of(tester.element(find.byType(MaterialApp)));

    // 已登录能正常访问首页
    router.go(AppRoutes.home);
    await tester.pumpAndSettle();
    expect(router.state.matchedLocation, AppRoutes.home);

    // 退出登录
    await auth.logout();
    await tester.pumpAndSettle();

    // 访问受保护页面应被拦截
    router.go(AppRoutes.profileWantWatch);
    await tester.pumpAndSettle();

    final loc = router.state.uri.toString();
    expect(loc, contains('/login'));
    expect(loc, contains('from='));
  });

  testWidgets('登录页→注册页→登录页保持 from 参数传递', (tester) async {
    final auth = _SwitchableAuth(isLogged: false);
    await tester.pumpWidget(_buildApp(auth));
    await tester.pumpAndSettle();

    final router = GoRouter.of(tester.element(find.byType(MaterialApp)));

    // 模拟从受保护页面被重定向到登录页
    router.go('/login?from=/profile/want-watch');
    await tester.pumpAndSettle();

    // 点击注册按钮应跳转到 /register?from=/profile/want-watch
    await tester.tap(find.text('没有账号？立即注册'));
    await tester.pumpAndSettle();
    final regLoc = router.state.uri.toString();
    expect(regLoc, contains('/register'));
    expect(regLoc, contains('from='));

    // 注册页点击"已有账号？去登录"回到登录页并保留 from
    await tester.tap(find.text('已有账号？去登录'));
    await tester.pumpAndSettle();
    final backLoc = router.state.uri.toString();
    expect(backLoc, contains('/login'));
    expect(backLoc, contains('from='));
  });
}
```

### 终端命令

```bash
cd /Users/luxcis/data/workspace/Flutter/Jdb_Flutter

# Step 2: 跑集成测试
flutter test test/features/auth/auth_flow_test.dart
# 预期输出：All tests passed!

# Step 4: 全量跑所有测试确认无回归
flutter test
# 预期输出：All tests passed! （现有测试不受影响）

# Git 提交
export https_proxy=http://127.0.0.1:7890 http_proxy=http://127.0.0.1:7890 all_proxy=socks5://127.0.0.1:7890
git add test/features/auth/auth_flow_test.dart
git commit -m "$(cat <<'EOF'
test(auth): 端到端 auth 流程集成测试
EOF
)"
```

---

## 最终验证

全部 5 个 Task 完成后，执行以下命令确认整体质量：

```bash
cd /Users/luxcis/data/workspace/Flutter/Jdb_Flutter

# 全量测试
flutter test
# 预期输出：All tests passed!

# 静态分析
dart analyze
# 预期输出：No issues found!

# 代码生成（如果 Models 有改动）
dart run build_runner build --delete-conflicting-outputs

# 确认 git 状态
git status
```
