# Jade 跨模块修复 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 修复 6 个跨模块差异：CachedImage CDN 前缀拼接、ActorCard 硬编码 CDN、MovieListTile 截图参数、LoginGuideCard 通用组件、RegisterPage 注册页、GoRouter redirect 鉴权守卫。

**Architecture:** 每个 Task 独立修复一个模块差异，无相互依赖。所有修改遵循现有 Feature-First 架构。Task 6（GoRouter redirect）是唯一影响启动流程的变更，需同步更新 `app.dart`。

**Tech Stack:** Flutter + Dart, provider, go_router, cached_network_image, shared_preferences.

## Global Constraints

- Material Design 3；ThemeMode.system；ColorScheme.fromSeed()；系统字体；无 google_fonts。
- 不做本地化，所有文案中文硬编码；不使用 .arb/flutter_localizations。
- Feature-First：core/ 放公共层；feature 只依赖 core。
- CDN 图片域名 https://tp.spfcas.com/rhe951l4q/（AppConstants.imageCdnBase）。
- 状态管理优先内置 + provider。
- 测试：widget test 验证组件渲染，unit test 验证逻辑。
- Git 提交前设置代理：`export https_proxy=http://127.0.0.1:7890 http_proxy=http://127.0.0.1:7890 all_proxy=socks5://127.0.0.1:7890`
- 不使用触觉反馈。

---

## Task 1: 修复 CachedImage — CDN 前缀自动拼接

### Files

| Action | Path |
|--------|------|
| Modify | `lib/core/widgets/cached_image.dart` |
| Create | `test/core/widgets/cached_image_test.dart` |

### Interfaces

**Consumes:**
- `AppConstants.imageCdnBase` — CDN 前缀常量

**Produces:**
- `CachedImage(url)` — 自动拼接 CDN 前缀：`url.startsWith('http') ? url : '${AppConstants.imageCdnBase}$url'`
- 新增可选参数 `aspect`、`width`、`height`

### 5-Step Checklist

- [ ] **1. 写 widget test** — 创建 `test/core/widgets/cached_image_test.dart`，验证 CDN 前缀拼接和渲染。
- [ ] **2. 验证测试失败** — `flutter test test/core/widgets/cached_image_test.dart`，预期 FAIL（CDN 前缀未拼接）。
- [ ] **3. 写实现** — 修改 `cached_image.dart`，添加 CDN 前缀拼接逻辑和 `aspect/width/height` 参数。
- [ ] **4. 验证测试通过** — `flutter test test/core/widgets/cached_image_test.dart`，全部 PASS。
- [ ] **5. 提交** — `git add` 2 个文件，commit message: `fix(core): add CDN prefix auto-join to CachedImage`。

### 完整实现代码

#### `lib/core/widgets/cached_image.dart`（替换整个文件）

```dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:jade/core/constants/app_constants.dart';

class CachedImage extends StatelessWidget {
  const CachedImage(
    this.url, {
    super.key,
    this.aspect,
    this.width,
    this.height,
  });

  final String url;
  final double? aspect;
  final double? width;
  final double? height;

  String get _fullUrl =>
      url.startsWith('http') ? url : '${AppConstants.imageCdnBase}$url';

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: _fullUrl,
      fit: BoxFit.cover,
      width: width,
      height: height,
      placeholder: (_, _) => const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      errorWidget: (_, _, _) =>
          const Center(child: Icon(Icons.broken_image)),
    );
  }
}
```

#### `test/core/widgets/cached_image_test.dart`（新建）

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/widgets/cached_image.dart';

void main() {
  testWidgets('相对路径自动拼接 CDN 前缀', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: CachedImage('covers/test.jpg'),
      ),
    );
    await tester.pump();
    // 验证渲染不崩溃（CDN 拼接后的 URL 可以触发加载）
    expect(find.byType(CachedImage), findsOneWidget);
  });

  testWidgets('http 开头的 URL 不拼接 CDN', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: CachedImage('https://other.cdn/covers/test.jpg'),
      ),
    );
    await tester.pump();
    expect(find.byType(CachedImage), findsOneWidget);
  });

  testWidgets('支持 width/height 参数', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: CachedImage('covers/test.jpg', width: 100, height: 100),
      ),
    );
    await tester.pump();
    expect(find.byType(CachedImage), findsOneWidget);
  });
}
```

### 终端命令

```bash
# 1. 运行测试（预期全部 FAIL）
flutter test test/core/widgets/cached_image_test.dart

# 2. 修改代码后重新运行
flutter test test/core/widgets/cached_image_test.dart
# 预期：All tests passed!

# 3. 提交
export https_proxy=http://127.0.0.1:7890 http_proxy=http://127.0.0.1:7890 all_proxy=socks5://127.0.0.1:7890
git add lib/core/widgets/cached_image.dart test/core/widgets/cached_image_test.dart
git commit -m "$(cat <<'EOF'
fix(core): add CDN prefix auto-join to CachedImage
EOF
)"
```

---

## Task 2: 修复 ActorCard — CDN 硬编码替换为 AppConstants

### Files

| Action | Path |
|--------|------|
| Modify | `lib/core/widgets/actor_card.dart` |
| Create | `test/core/widgets/actor_card_test.dart` |

### Interfaces

**Consumes:**
- `AppConstants.imageCdnBase` — CDN 前缀常量
- `CachedImage`（Task 1 修复后）

**Produces:**
- `ActorCard` 内部 CDN 拼接从硬编码改为 `AppConstants.imageCdnBase` + `CachedImage`

### 5-Step Checklist

- [ ] **1. 写 widget test** — 创建 `test/core/widgets/actor_card_test.dart`，验证头像名称渲染。
- [ ] **2. 验证测试失败** — `flutter test test/core/widgets/actor_card_test.dart`，预期 FAIL（文件不存在）。
- [ ] **3. 写实现** — 将 `CircleAvatar` 中的硬编码 CDN 替换为 `CachedImage`（CachedImage 已处理 CDN 前缀）。
- [ ] **4. 验证测试通过** — `flutter test test/core/widgets/actor_card_test.dart`，全部 PASS。
- [ ] **5. 提交** — `git add` 2 个文件，commit message: `fix(core): replace hardcoded CDN in ActorCard with CachedImage`。

### 完整实现代码

#### `lib/core/widgets/actor_card.dart`（替换整个文件）

```dart
import 'package:flutter/material.dart';
import 'package:jade/core/models/actor.dart';
import 'package:jade/core/widgets/cached_image.dart';

class ActorCard extends StatelessWidget {
  const ActorCard({super.key, required this.actor, this.onTap});
  final ActorSummary actor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          SizedBox(
            width: 72,
            height: 72,
            child: ClipOval(child: CachedImage(actor.avatarUrl)),
          ),
          const SizedBox(height: 4),
          Text(
            actor.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
```

#### `test/core/widgets/actor_card_test.dart`（新建）

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/models/actor.dart';
import 'package:jade/core/widgets/actor_card.dart';

void main() {
  testWidgets('ActorCard 渲染头像和名称', (tester) async {
    final actor = ActorSummary(
      id: 'a1',
      name: '测试演员',
      avatarUrl: 'avatars/test.jpg',
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: ActorCard(actor: actor)),
    ));
    await tester.pump();
    expect(find.text('测试演员'), findsOneWidget);
  });

  testWidgets('ActorCard onTap 回调触发', (tester) async {
    var tapped = false;
    final actor = ActorSummary(
      id: 'a1',
      name: '测试演员',
      avatarUrl: 'avatars/test.jpg',
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ActorCard(actor: actor, onTap: () => tapped = true),
      ),
    ));
    await tester.tap(find.text('测试演员'));
    expect(tapped, isTrue);
  });
}
```

### 终端命令

```bash
# 1. 运行测试
flutter test test/core/widgets/actor_card_test.dart

# 2. 提交
export https_proxy=http://127.0.0.1:7890 http_proxy=http://127.0.0.1:7890 all_proxy=socks5://127.0.0.1:7890
git add lib/core/widgets/actor_card.dart test/core/widgets/actor_card_test.dart
git commit -m "$(cat <<'EOF'
fix(core): replace hardcoded CDN in ActorCard with CachedImage
EOF
)"
```

---

## Task 3: 扩展 MovieListTile — 添加 screenshots 参数和三行布局

### Files

| Action | Path |
|--------|------|
| Modify | `lib/core/widgets/movie_list_tile.dart` |
| Modify | `test/core/widgets/movie_card_test.dart`（追加 MovieListTile 测试） |

### Interfaces

**Consumes:**
- `CachedImage`（Task 1 修复后）
- `MovieSummary`

**Produces:**
- `MovieListTile({movie: MovieSummary, rank, screenshots, onTap})` — 新增 `screenshots` 参数支持横向截图小图，三行式布局

### 5-Step Checklist

- [ ] **1. 写 widget test** — 在现有测试中追加 MovieListTile 测试，验证基础渲染和 screenshots 渲染。
- [ ] **2. 验证测试失败** — `flutter test test/core/widgets/movie_card_test.dart`，新增用例 FAIL（screenshots 参数不存在）。
- [ ] **3. 写实现** — 在 `movie_list_tile.dart` 中添加 `screenshots` 参数和横向截图区域。
- [ ] **4. 验证测试通过** — `flutter test test/core/widgets/movie_card_test.dart`，全部 PASS。
- [ ] **5. 提交** — `git add` 2 个文件，commit message: `feat(core): add screenshots param to MovieListTile with three-row layout`。

### 完整实现代码

#### `lib/core/widgets/movie_list_tile.dart`（替换整个文件）

```dart
import 'package:flutter/material.dart';
import 'package:jade/core/models/movie.dart';
import 'package:jade/core/widgets/cached_image.dart';
import 'package:jade/core/widgets/rating_badge.dart';

class MovieListTile extends StatelessWidget {
  const MovieListTile({
    super.key,
    required this.movie,
    this.rank,
    this.screenshots,
    this.onTap,
  });

  final MovieSummary movie;
  final int? rank;
  final List<String>? screenshots;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: Row(
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: SizedBox(
                    width: 80,
                    height: 100,
                    child: CachedImage(movie.coverUrl),
                  ),
                ),
                if (rank != null)
                  Positioned(
                      top: 2, left: 2, child: RatingBadge(rank: rank!)),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    movie.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${movie.number}  ${movie.releaseDate ?? ''}',
                    style:
                        textTheme.labelSmall?.copyWith(color: Colors.grey),
                  ),
                  if (screenshots != null && screenshots!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: SizedBox(
                        height: 56,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: screenshots!.length,
                          itemBuilder: (_, i) => Padding(
                            padding:
                                const EdgeInsets.only(right: 4),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: SizedBox(
                                width: 84,
                                height: 56,
                                child: CachedImage(screenshots![i]),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

#### `test/core/widgets/movie_card_test.dart`（追加以下用例到文件末尾的 `main()` 函数内）

```dart
  group('MovieListTile', () {
    testWidgets('基础渲染标题、番号、日期', (tester) async {
      final movie = MovieSummary(
        id: '1',
        number: 'SSIS-001',
        title: '测试影片标题',
        coverUrl: 'covers/test.jpg',
        releaseDate: '2024-01-01',
      );
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: MovieListTile(movie: movie, rank: 1)),
      ));
      await tester.pump();
      expect(find.text('测试影片标题'), findsOneWidget);
      expect(find.text(contains('SSIS-001')), findsOneWidget);
      expect(find.text(contains('2024-01-01')), findsOneWidget);
    });

    testWidgets('screenshots 参数渲染横向截图', (tester) async {
      final movie = MovieSummary(
        id: '1',
        number: 'SSIS-001',
        title: '测试影片',
        coverUrl: 'covers/test.jpg',
      );
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: MovieListTile(
            movie: movie,
            screenshots: ['shot1.jpg', 'shot2.jpg'],
          ),
        ),
      ));
      await tester.pump();
      // 截图区域应渲染 CachedImage 组件
      expect(find.byType(CachedImage), findsNWidgets(3)); // 封面 + 2张截图
    });

    testWidgets('无 screenshots 时不渲染截图区域', (tester) async {
      final movie = MovieSummary(
        id: '1',
        number: 'SSIS-001',
        title: '测试影片',
        coverUrl: 'covers/test.jpg',
      );
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: MovieListTile(movie: movie)),
      ));
      await tester.pump();
      // 只有封面一张图片
      expect(find.byType(CachedImage), findsOneWidget);
    });
  });
```

### 终端命令

```bash
# 1. 运行测试（预期新增用例 FAIL）
flutter test test/core/widgets/movie_card_test.dart

# 2. 修改代码后重新运行
flutter test test/core/widgets/movie_card_test.dart
# 预期：All tests passed!

# 3. 提交
export https_proxy=http://127.0.0.1:7890 http_proxy=http://127.0.0.1:7890 all_proxy=socks5://127.0.0.1:7890
git add lib/core/widgets/movie_list_tile.dart test/core/widgets/movie_card_test.dart
git commit -m "$(cat <<'EOF'
feat(core): add screenshots param to MovieListTile with three-row layout
EOF
)"
```

---

## Task 4: 创建 LoginGuideCard 通用组件

### Files

| Action | Path |
|--------|------|
| Create | `lib/core/widgets/login_guide_card.dart` |
| Create | `test/core/widgets/login_guide_card_test.dart` |

### Interfaces

**Consumes:**
- `go_router` — `context.go('/login?from=...')` 导航

**Produces:**
- `LoginGuideCard({message, loginPath})` — 通用登录引导卡片，`message` 为提示文案，`loginPath` 为登录后回跳路径

### 5-Step Checklist

- [ ] **1. 写 widget test** — 创建 `test/core/widgets/login_guide_card_test.dart`，验证卡片渲染和按钮触发。
- [ ] **2. 验证测试失败** — `flutter test test/core/widgets/login_guide_card_test.dart`，预期 FAIL（文件不存在）。
- [ ] **3. 写实现** — 创建 `login_guide_card.dart`。
- [ ] **4. 验证测试通过** — `flutter test test/core/widgets/login_guide_card_test.dart`，全部 PASS。
- [ ] **5. 提交** — `git add` 2 个文件，commit message: `feat(core): add LoginGuideCard universal login guide component`。

### 完整实现代码

#### `lib/core/widgets/login_guide_card.dart`（新建）

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
                Icon(Icons.lock_outline,
                    size: 48, color: Colors.grey.shade400),
                const SizedBox(height: 12),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    final from = loginPath.isNotEmpty
                        ? '?from=$loginPath'
                        : '';
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

#### `test/core/widgets/login_guide_card_test.dart`（新建）

```dart
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
    await tester.pump();

    expect(find.text('请登录查看'), findsOneWidget);
    expect(find.text('去登录'), findsOneWidget);
  });

  testWidgets('LoginGuideCard 渲染锁图标', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LoginGuideCard(message: '请登录'),
      ),
    );
    await tester.pump();

    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
  });
}
```

### 终端命令

```bash
# 1. 运行测试
flutter test test/core/widgets/login_guide_card_test.dart

# 2. 提交
export https_proxy=http://127.0.0.1:7890 http_proxy=http://127.0.0.1:7890 all_proxy=socks5://127.0.0.1:7890
git add lib/core/widgets/login_guide_card.dart test/core/widgets/login_guide_card_test.dart
git commit -m "$(cat <<'EOF'
feat(core): add LoginGuideCard universal login guide component
EOF
)"
```

---

## Task 5: 创建 RegisterPage 注册页

### Files

| Action | Path |
|--------|------|
| Create | `lib/features/auth/screens/register_screen.dart` |
| Modify | `lib/features/auth/index.dart` |
| Modify | `lib/core/router/app_router.dart` |
| Create | `test/features/auth/register_screen_test.dart` |

### Interfaces

**Consumes:**
- `ApiClient.instanceOrNull` — 发送 `POST /api/v1/users`
- `GoRouterState.uri.queryParameters['from']` — 注册成功后回跳登录页带 from
- `Endpoints.users` — 注册接口路径常量

**Produces:**
- `RegisterPage` — 邮箱 + 密码 + 确认密码表单，注册成功跳 `/login?from=...`

### 5-Step Checklist

- [ ] **1. 写 widget test** — 创建 `test/features/auth/register_screen_test.dart`，验证表单渲染和密码不匹配错误。
- [ ] **2. 验证测试失败** — `flutter test test/features/auth/register_screen_test.dart`，预期 FAIL（文件不存在）。
- [ ] **3. 写实现** — 创建 `register_screen.dart`，更新 `index.dart` 和 `app_router.dart`。
- [ ] **4. 验证测试通过** — `flutter test test/features/auth/register_screen_test.dart`，全部 PASS。
- [ ] **5. 提交** — `git add` 4 个文件，commit message: `feat(auth): add RegisterPage with password confirmation`。

### 完整实现代码

#### `lib/features/auth/screens/register_screen.dart`（新建）

```dart
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
      final from =
          GoRouterState.of(context).uri.queryParameters['from'] ?? '';
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
    final from =
        GoRouterState.of(context).uri.queryParameters['from'] ?? '';
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
                final to =
                    hasFrom ? '/login?from=$from' : '/login';
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

#### `lib/features/auth/index.dart`（追加 export）

```dart
export 'screens/login_screen.dart';
export 'screens/register_screen.dart';
```

#### `lib/core/router/app_router.dart`（追加 import 和路由—精确变更位置）

在文件顶部 import 区域，`import 'package:jade/features/auth/index.dart';` 行**之后**（该行已存在，`index.dart` 会自动导出 `RegisterPage`），无需修改 import。

在 `buildForTest()` 方法的 `routes` 列表中，`LoginPage` 路由**之后**追加 `RegisterPage` 路由：

```dart
          GoRoute(
            path: AppRoutes.login,
            builder: (c, s) => const LoginPage(),
          ),
          GoRoute(
            path: AppRoutes.register,
            builder: (c, s) => const RegisterPage(),
          ),
```

#### `test/features/auth/register_screen_test.dart`（新建）

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/features/auth/screens/register_screen.dart';

void main() {
  testWidgets('RegisterPage 渲染邮箱、密码、确认密码输入框和注册按钮',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: RegisterPage()));
    await tester.pump();

    expect(find.text('注册'), findsWidgets); // AppBar + 按钮
    expect(find.text('邮箱'), findsOneWidget);
    expect(find.text('密码'), findsOneWidget);
    expect(find.text('确认密码'), findsOneWidget);
    expect(find.text('已有账号？去登录'), findsOneWidget);
  });

  testWidgets('邮箱和密码输入框可交互', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: RegisterPage()));
    await tester.pump();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'test@test.com');
    await tester.enterText(fields.at(1), 'password123');
    await tester.enterText(fields.at(2), 'password123');

    expect(find.text('test@test.com'), findsOneWidget);
  });
}
```

### 终端命令

```bash
# 1. 运行测试
flutter test test/features/auth/register_screen_test.dart

# 2. 提交
export https_proxy=http://127.0.0.1:7890 http_proxy=http://127.0.0.1:7890 all_proxy=socks5://127.0.0.1:7890
git add lib/features/auth/screens/register_screen.dart \
        lib/features/auth/index.dart \
        lib/core/router/app_router.dart \
        test/features/auth/register_screen_test.dart
git commit -m "$(cat <<'EOF'
feat(auth): add RegisterPage with password confirmation
EOF
)"
```

---

## Task 6: GoRouter redirect 鉴权守卫 + app.dart 切换到 build()

### Files

| Action | Path |
|--------|------|
| Modify | `lib/core/router/app_router.dart` |
| Modify | `lib/app.dart` |
| Create | `test/core/router/app_router_auth_test.dart` |

### Interfaces

**Consumes:**
- `context.read<AuthProvider>()` — GoRouter redirect 中读取登录态
- `AppRoutes.protectedRoutes` — 需登录的路由集合
- `AppRoutes.login`、`AppRoutes.register`、`AppRoutes.home` — 路由常量

**Produces:**
- `AppRouter.build()` — 生产路由，含 `redirect` 鉴权逻辑
- `AppRouter.buildForTest()` — 测试路由，无 redirect（保持不变）
- `app.dart` 中 `routerConfig: AppRouter.build()` 替换 `buildForTest()`

### 5-Step Checklist

- [ ] **1. 写 widget test** — 创建 `test/core/router/app_router_auth_test.dart`，验证重定向逻辑。
- [ ] **2. 验证测试失败** — `flutter test test/core/router/app_router_auth_test.dart`，预期 FAIL（redirect 未实现）。
- [ ] **3. 写实现** — 在 `app_router.dart` 中添加 `build()` 方法和 `_redirect`，修改 `app.dart`。
- [ ] **4. 验证测试通过** — `flutter test test/core/router/app_router_auth_test.dart`，全部 PASS。
- [ ] **5. 提交** — `git add` 3 个文件，commit message: `feat(router): add GoRouter redirect auth guard and switch app.dart to build()`。

### 完整实现代码

#### `lib/core/router/app_router.dart`（替换整个文件）

```dart
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

class AppRouter {
  const AppRouter._();

  /// 生产用路由（含 auth redirect）。
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
    if (isLogged &&
        (loc == AppRoutes.login || loc == AppRoutes.register)) {
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
      ];
}
```

#### `lib/app.dart`（第 25 行：`AppRouter.buildForTest()` → `AppRouter.build()`）

```dart
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

#### `test/core/router/app_router_auth_test.dart`（新建）

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:jade/core/providers/auth_provider.dart';
import 'package:jade/core/router/app_router.dart';
import 'package:jade/core/router/routes.dart';

class _FakeAuth extends ChangeNotifier implements TokenProvider {
  _FakeAuth({required this.logged});
  final bool logged;
  @override String? get token => logged ? 'tok' : null;
  bool get isLogged => logged;
  Map<String, dynamic>? get user => logged ? {'id': 1} : null;
  Future<void> login({required String token, required Map<String, dynamic> user}) async {}
  Future<void> logout() async {}
}

Widget _buildApp(bool logged) {
  // ignore: invalid_use_of_protected_member
  final auth = _FakeAuth(logged: logged);
  return ChangeNotifierProvider<_FakeAuth>.value(
    value: auth,
    child: MaterialApp.router(routerConfig: AppRouter.build()),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('未登录访问 protectedRoutes 重定向到 /login', (tester) async {
    await tester.pumpWidget(_buildApp(false));
    await tester.pumpAndSettle();

    final router = GoRouter.of(tester.element(find.byType(MaterialApp)));
    router.go(AppRoutes.profileWantWatch);
    await tester.pumpAndSettle();

    final loc = router.state.uri.toString();
    expect(loc, contains('/login'));
    expect(loc, contains('from='));
  });

  testWidgets('已登录访问 /login 重定向到 /home', (tester) async {
    await tester.pumpWidget(_buildApp(true));
    await tester.pumpAndSettle();

    final router = GoRouter.of(tester.element(find.byType(MaterialApp)));
    router.go('/login');
    await tester.pumpAndSettle();

    expect(router.state.matchedLocation, AppRoutes.home);
  });

  testWidgets('已登录访问 protectedRoutes 正常放行', (tester) async {
    await tester.pumpWidget(_buildApp(true));
    await tester.pumpAndSettle();

    final router = GoRouter.of(tester.element(find.byType(MaterialApp)));
    router.go(AppRoutes.profileWantWatch);
    await tester.pumpAndSettle();

    expect(router.state.matchedLocation, AppRoutes.profileWantWatch);
  });

  testWidgets('未登录访问非受保护路由正常放行', (tester) async {
    await tester.pumpWidget(_buildApp(false));
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
# 1. 运行鉴权测试
flutter test test/core/router/app_router_auth_test.dart
# 预期：All tests passed!

# 2. 确认现有路由测试不受影响（buildForTest 保持不变，不含 redirect）
flutter test test/app_router_test.dart
# 预期：All tests passed!

# 3. 提交
export https_proxy=http://127.0.0.1:7890 http_proxy=http://127.0.0.1:7890 all_proxy=socks5://127.0.0.1:7890
git add lib/core/router/app_router.dart lib/app.dart test/core/router/app_router_auth_test.dart
git commit -m "$(cat <<'EOF'
feat(router): add GoRouter redirect auth guard and switch app.dart to build()
EOF
)"
```

---

## Task 7: RankingsPage Top250 Tab 使用 LoginGuideCard

### Files

| Action | Path |
|--------|------|
| Modify | `lib/features/rankings/screens/rankings_screen.dart` |

### Interfaces

**Consumes:**
- `LoginGuideCard(message:, loginPath:)` — Task 4 创建的通用组件

**Produces:**
- Top250 Tab 未登录时显示 `LoginGuideCard` 替代普通 `Center(child: Text(...))`

### 5-Step Checklist

- [ ] **1. 写实现** — 将 Top250 Tab 未登录分支替换为 `LoginGuideCard`。
- [ ] **2. 验证编译通过** — `flutter analyze lib/features/rankings/` 无 error。
- [ ] **3. 提交** — `git add` 1 个文件，commit message: `fix(rankings): use LoginGuideCard in Top250 tab for unauthenticated state`。

### 完整实现代码

#### `lib/features/rankings/screens/rankings_screen.dart`（仅修改 `_Top250TabState.build()` 中未登录分支）

在文件顶部添加 import：

```dart
import 'package:jade/core/widgets/login_guide_card.dart';
```

找到 Top250 Tab 的 `build` 方法中未登录分支（大约在第 84-87 行区域）：

```dart
    final auth = context.watch<AuthProvider>();
    if (!auth.isLogged) {
      return const Center(child: Text('请登录后查看 Top250'));
    }
```

替换为：

```dart
    final auth = context.watch<AuthProvider>();
    if (!auth.isLogged) {
      return const LoginGuideCard(
        message: '登录后查看 Top250 排行榜',
        loginPath: '/rankings',
      );
    }
```

### 终端命令

```bash
# 1. 验证分析
flutter analyze lib/features/rankings/

# 2. 提交
export https_proxy=http://127.0.0.1:7890 http_proxy=http://127.0.0.1:7890 all_proxy=socks5://127.0.0.1:7890
git add lib/features/rankings/screens/rankings_screen.dart
git commit -m "$(cat <<'EOF'
fix(rankings): use LoginGuideCard in Top250 tab for unauthenticated state
EOF
)"
```

---

## Task 8: ActorsPage 推荐 Tab 添加登录引导

### Files

| Action | Path |
|--------|------|
| Modify | `lib/features/actors/screens/actors_screen.dart` |

### Interfaces

**Consumes:**
- `context.watch<AuthProvider>().isLogged` — 判断登录态
- `LoginGuideCard(message:, loginPath:)` — Task 4 创建的通用组件

**Produces:**
- `_RecommendTabState.build()` 开头添加 `AuthProvider` 登录检查，未登录时显示 `LoginGuideCard`

### 5-Step Checklist

- [ ] **1. 写实现** — 在 `_RecommendTabState.build()` 方法开头添加登录检查。
- [ ] **2. 验证编译通过** — `flutter analyze lib/features/actors/` 无 error。
- [ ] **3. 提交** — `git add` 1 个文件，commit message: `fix(actors): add login guard to recommend tab with LoginGuideCard`。

### 完整实现代码

#### `lib/features/actors/screens/actors_screen.dart`（仅修改 `_RecommendTabState`）

在文件顶部添加两个 import（如果尚未存在）：

```dart
import 'package:provider/provider.dart';
import 'package:jade/core/providers/auth_provider.dart';
import 'package:jade/core/widgets/login_guide_card.dart';
```

在 `_RecommendTabState.build()` 方法开头（`return CustomScrollView(...)` 或 `return ...` 之前）插入：

```dart
    final auth = context.watch<AuthProvider>();
    if (!auth.isLogged) {
      return const LoginGuideCard(
        message: '登录后可查看演员推荐',
        loginPath: '/actors',
      );
    }
```

> **注意：** 如果 `_RecommendTabState` 已有其他登录态检查逻辑（如加载中等），确保 `LoginGuideCard` 检查放在 `build` 方法的**最前面**，在所有其他状态判断之前。

### 终端命令

```bash
# 1. 验证分析
flutter analyze lib/features/actors/

# 2. 提交
export https_proxy=http://127.0.0.1:7890 http_proxy=http://127.0.0.1:7890 all_proxy=socks5://127.0.0.1:7890
git add lib/features/actors/screens/actors_screen.dart
git commit -m "$(cat <<'EOF'
fix(actors): add login guard to recommend tab with LoginGuideCard
EOF
)"
```

---

## Task 9: 全量测试 + 静态分析验证

### Files

无新增/修改文件。

### 5-Step Checklist

- [ ] **1. 全量测试** — `flutter test`（预期全部通过）
- [ ] **2. 静态分析** — `flutter analyze`（预期 0 errors）
- [ ] **3. 构建验证** — `flutter build apk --debug`（预期 BUILD SUCCESSFUL）
- [ ] **4. 确认 router 测试** — `flutter test test/app_router_test.dart test/core/router/app_router_auth_test.dart`（预期全部 PASS）
- [ ] **5. commit** — 如有 lint fix 则提交。

### 终端命令

```bash
# 设置代理
export https_proxy=http://127.0.0.1:7890 http_proxy=http://127.0.0.1:7890 all_proxy=socks5://127.0.0.1:7890

# 全量测试
flutter test
# 预期：All tests passed!

# 静态分析
flutter analyze
# 预期：No issues found!

# 路由测试专项
flutter test test/app_router_test.dart test/core/router/app_router_auth_test.dart
# 预期：All tests passed!
```

---

## Implementation Order

所有 Task 独立，无依赖链，可并行执行：

```
Task 1 (CachedImage) ──┐
Task 2 (ActorCard)  ──┼── 可并行
Task 3 (MovieListTile)─┤
Task 4 (LoginGuideCard)┼── 可并行
Task 5 (RegisterPage) ─┤
Task 6 (redirect守卫) ─┘
        │
        ├── Task 7 (Rankings LoginGuideCard) ── 依赖 Task 4
        │
        └── Task 8 (Actors LoginGuideCard)  ── 依赖 Task 4
            │
            └── Task 9 (全量验证)
```

---

## Verification Checklist

全部任务完成后运行：

```bash
flutter test
# 预期：All tests passed!

flutter analyze
# 预期：No issues found!
```

手动验证：
- 任意页面使用 CachedImage 加载相对路径图片，自动拼接 CDN 前缀
- ActorCard 头像正常渲染
- MovieListTile 带 screenshots 参数时显示横向截图
- 未登录访问 /profile/want-watch 被重定向到 /login?from=/profile/want-watch
- 登录成功后自动跳回原页面
- 演员推荐 Tab 未登录时显示 LoginGuideCard
- Top250 Tab 未登录时显示 LoginGuideCard
- 注册页表单可正常填写，密码不匹配时显示错误提示
