# 设置页清理与外观/缓存功能实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 删除设置页「默认筛选标签」，实现外观模式（跟随系统/浅色/深色）切换与清除图片缓存（含大小显示）。

**Architecture:** 复用已就绪的 `ThemeProvider`（三态切换 + 持久化 + `MaterialApp.themeMode` 接线），仅在设置页连接 UI。缓存逻辑抽到 core 层 `CacheService` 抽象 + `JdbImageCacheService` 实现（依赖注入，便于测试），设置页注入调用。

**Tech Stack:** Flutter / provider / shared_preferences / flutter_cache_manager / path_provider（新增直接依赖，lock 中已为 2.1.6）

## Global Constraints

- 遵循 **Material Design 3** 规范；设置项样式沿用现有 `ListTile`（leading 图标 + 标题 + subtitle + trailing chevron）。
- 所有文案使用中文硬编码，不做本地化。
- Feature-First 结构：`lib/core/` 放通用能力，core 不依赖 feature；设置页位于 `lib/features/profile/screens/profile_sub_pages.dart`。
- 缓存目录名为 `JdbImageCacheManager.key`（即 `'jdbImageCache'`），不得硬编码其他字符串。
- 不主动发布版本、不主动 bump version。
- 版本号、StorageKeys 等既有约定不因本次改动而变（`ThemeProvider` 内部 key `'theme-mode-index'` 保持不变）。

---

### Task 1: 删除「默认筛选标签」全链路代码

**Files:**
- Modify: `lib/core/providers/settings_provider.dart`
- Modify: `lib/core/storage/storage_keys.dart:10`
- Modify: `lib/features/profile/screens/profile_sub_pages.dart:349`
- Modify: `test/features/profile/profile_sub_pages_test.dart:55`

**Interfaces:**
- Consumes: 无。
- Produces: `SettingsProvider` 仅剩 `blurMovieImages` 与 `setBlurMovieImages`；`StorageKeys` 不再含 `defaultFilterTags`。

- [ ] **Step 1: 确认无其他引用**

Run: `grep -rn "defaultFilterTags\|key_default_filter_tags" lib test`
Expected: 仅命中 `settings_provider.dart`、`storage_keys.dart`、`profile_sub_pages.dart:349`（UI 行）与 `profile_sub_pages_test.dart:55`（断言）。若有多余引用，先记录再一并清理。

- [ ] **Step 2: 清理 `SettingsProvider`**

`lib/core/providers/settings_provider.dart` 修改为：

```dart
// lib/core/providers/settings_provider.dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jade/core/storage/storage_keys.dart';

class SettingsProvider extends ChangeNotifier {
  SettingsProvider._(this._prefs);
  final SharedPreferences _prefs;
  bool _blurMovieImages = true;

  bool get blurMovieImages => _blurMovieImages;

  static Future<SettingsProvider> create(SharedPreferences prefs) async {
    final p = SettingsProvider._(prefs);
    p._blurMovieImages = prefs.getBool(StorageKeys.blurMovieImages) ?? true;
    return p;
  }

  Future<void> setBlurMovieImages(bool value) async {
    _blurMovieImages = value;
    await _prefs.setBool(StorageKeys.blurMovieImages, value);
    notifyListeners();
  }
}
```

（删除 `dart:convert` import、`_defaultFilterTags` 字段、getter、`setDefaultFilterTags()` 与 `create()` 中的加载逻辑。）

- [ ] **Step 3: 清理 `StorageKeys`**

`lib/core/storage/storage_keys.dart` 删除第 10 行：

```dart
  static const String defaultFilterTags = 'key_default_filter_tags';
```

- [ ] **Step 4: 删除设置页 UI 行**

`lib/features/profile/screens/profile_sub_pages.dart` 的 `cells` 列表中删除：

```dart
      const _ProfileCell(title: '默认筛选标签', subtitle: '含磁链', icon: Icons.tune),
```

- [ ] **Step 5: 删除测试断言**

`test/features/profile/profile_sub_pages_test.dart` 删除：

```dart
    expect(find.text('默认筛选标签'), findsOneWidget);
```

- [ ] **Step 6: 运行相关测试**

Run: `flutter test test/core/providers/settings_provider_test.dart test/features/profile/profile_sub_pages_test.dart`
Expected: 全部 PASS（默认筛选标签相关的 `settings_provider_test.dart` 本来就不测该字段，不应受影响）。

- [ ] **Step 7: 提交**

```bash
git add lib/core/providers/settings_provider.dart lib/core/storage/storage_keys.dart lib/features/profile/screens/profile_sub_pages.dart test/features/profile/profile_sub_pages_test.dart
git commit -m "refactor(settings): remove default filter tags setting"
```

---

### Task 2: 新增 `CacheService` 与 `formatCacheSize`

**Files:**
- Create: `lib/core/network/cache_service.dart`
- Create: `test/core/network/cache_service_test.dart`
- Modify: `pubspec.yaml`（dependencies 增加 `path_provider`）

**Interfaces:**
- Consumes: `JdbImageCacheManager.instance`（`lib/core/network/image_decryptor.dart`）、`JdbImageCacheManager.key`、flutter_cache_manager 的 `CacheManager`、`getTemporaryDirectory()`（path_provider）。
- Produces:
  - `abstract class CacheService { Future<int> getCacheSizeBytes(); Future<void> clearAll(); }`
  - `class JdbImageCacheService implements CacheService`，构造 `JdbImageCacheService({CacheManager? cacheManager, Future<Directory> Function()? cacheDirectory})`。
  - `String formatCacheSize(int bytes)`：B/KB/MB 分级、一位小数、0 显示 `0 B`。

- [ ] **Step 1: 声明依赖**

`pubspec.yaml` 的 `dependencies` 增加（与 lock 版本 2.1.6 对齐）：

```yaml
  path_provider: ^2.1.6
```

Run: `flutter pub get`
Expected: 成功，`pubspec.lock` 中 `path_provider` 的 `dependency` 由 `transitive` 变为 `direct main`。

- [ ] **Step 2: 编写失败单测**

创建 `test/core/network/cache_service_test.dart`：

```dart
import 'dart:io';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/network/cache_service.dart';

class _FakeCacheManager extends CacheManager {
  _FakeCacheManager() : super(Config('fake-cache-test'));

  int emptyCacheCalls = 0;

  @override
  Future<void> emptyCache() async {
    emptyCacheCalls++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('formatCacheSize', () {
    test('0 字节显示 0 B', () {
      expect(formatCacheSize(0), '0 B');
    });

    test('B 级显示整数', () {
      expect(formatCacheSize(512), '512 B');
    });

    test('KB 级保留一位小数', () {
      expect(formatCacheSize(1536), '1.5 KB');
    });

    test('MB 级保留一位小数', () {
      expect(formatCacheSize((24 * 1024 + 512) * 1024), '24.5 MB');
    });
  });

  group('JdbImageCacheService', () {
    test('缓存目录不存在时大小返回 0', () async {
      final tmp = await Directory.systemTemp.createTemp('cache_service_test');
      addTearDown(() => tmp.delete(recursive: true));

      final service = JdbImageCacheService(
        cacheDirectory: () async => tmp,
        cacheManager: _FakeCacheManager(),
      );

      expect(await service.getCacheSizeBytes(), 0);
    });

    test('统计缓存目录内文件大小之和', () async {
      final tmp = await Directory.systemTemp.createTemp('cache_service_test');
      addTearDown(() => tmp.delete(recursive: true));
      final cacheDir = Directory('${tmp.path}/jdbImageCache');
      await cacheDir.create(recursive: true);
      await File('${cacheDir.path}/a.jpg').writeAsBytes(List.filled(100, 1));
      await File('${cacheDir.path}/b.jpg').writeAsBytes(List.filled(200, 2));

      final service = JdbImageCacheService(
        cacheDirectory: () async => tmp,
        cacheManager: _FakeCacheManager(),
      );

      expect(await service.getCacheSizeBytes(), 300);
    });

    test('clearAll 调用 emptyCache 并清空内存图片缓存', () async {
      final tmp = await Directory.systemTemp.createTemp('cache_service_test');
      addTearDown(() => tmp.delete(recursive: true));
      final manager = _FakeCacheManager();

      final service = JdbImageCacheService(
        cacheDirectory: () async => tmp,
        cacheManager: manager,
      );

      await service.clearAll();

      expect(manager.emptyCacheCalls, 1);
    });
  });
}
```

- [ ] **Step 3: 运行测试确认失败**

Run: `flutter test test/core/network/cache_service_test.dart`
Expected: FAIL（`cache_service.dart` 不存在，编译错误）。

- [ ] **Step 4: 编写实现**

创建 `lib/core/network/cache_service.dart`：

```dart
// lib/core/network/cache_service.dart
import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:jade/core/network/image_decryptor.dart';

/// 缓存服务抽象，便于在测试中注入 fake 实现。
abstract class CacheService {
  /// 返回当前缓存占用字节数。
  Future<int> getCacheSizeBytes();

  /// 清空磁盘与内存中的图片缓存。
  Future<void> clearAll();
}

/// 图片缓存服务：统计并清理 [JdbImageCacheManager] 的磁盘与内存缓存。
class JdbImageCacheService implements CacheService {
  JdbImageCacheService({
    CacheManager? cacheManager,
    Future<Directory> Function()? cacheDirectory,
  }) : _cacheManager = cacheManager ?? JdbImageCacheManager.instance,
       _cacheDirectory = cacheDirectory ?? getTemporaryDirectory;

  final CacheManager _cacheManager;
  final Future<Directory> Function() _cacheDirectory;

  @override
  Future<int> getCacheSizeBytes() async {
    try {
      final base = await _cacheDirectory();
      final dir = Directory('${base.path}/${JdbImageCacheManager.key}');
      if (!await dir.exists()) return 0;
      var total = 0;
      await for (final entity in dir.list(recursive: true)) {
        if (entity is File) {
          total += await entity.length();
        }
      }
      return total;
    } catch (_) {
      return 0;
    }
  }

  @override
  Future<void> clearAll() async {
    await _cacheManager.emptyCache();
    PaintingBinding.instance.imageCache.clear();
  }
}

/// 将字节数格式化为 B/KB/MB（KB/MB 保留一位小数），0 显示 `0 B`。
String formatCacheSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
  return '${(kb / 1024).toStringAsFixed(1)} MB';
}
```

- [ ] **Step 5: 运行测试确认通过**

Run: `flutter test test/core/network/cache_service_test.dart`
Expected: 全部 PASS。

- [ ] **Step 6: 提交**

```bash
git add pubspec.yaml pubspec.lock lib/core/network/cache_service.dart test/core/network/cache_service_test.dart
git commit -m "feat(cache): add cache service with size stats and clear"
```

---

### Task 3: 设置页外观模式切换

**Files:**
- Modify: `lib/features/profile/screens/profile_sub_pages.dart`
- Modify: `test/features/profile/profile_sub_pages_test.dart`

**Interfaces:**
- Consumes: `ThemeProvider`（`themeMode` getter、`setThemeMode(ThemeMode)`，`lib/core/providers/theme_provider.dart`）。
- Produces: 私有 `String _themeModeLabel(ThemeMode mode)` 与 `void _openAppearancePicker(BuildContext context)`；`ProfileSettingsPage` 的「外观模式」cell 变为可交互 `ListTile`。

- [ ] **Step 1: 编写失败 Widget 测试**

`test/features/profile/profile_sub_pages_test.dart` 的 imports 增加：

```dart
import 'package:jade/core/providers/theme_provider.dart';
```

在 `main()` 中新增测试：

```dart
  testWidgets('外观模式：弹出弹窗选择深色后 themeMode 更新并持久化', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final settings = await SettingsProvider.create(prefs);
    final theme = await ThemeProvider.create();
    final dm = await DomainManager.load(prefs);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: settings),
          ChangeNotifierProvider.value(value: theme),
          ChangeNotifierProvider.value(value: dm),
        ],
        child: const MaterialApp(home: ProfileSettingsPage()),
      ),
    );

    expect(find.text('外观模式'), findsOneWidget);
    expect(find.text('跟随系统'), findsOneWidget); // subtitle

    await tester.tap(find.text('外观模式'));
    await tester.pumpAndSettle();

    expect(find.text('浅色模式'), findsOneWidget);
    expect(find.text('深色模式'), findsOneWidget);

    await tester.tap(find.text('深色模式'));
    await tester.pumpAndSettle();

    expect(theme.themeMode, ThemeMode.dark);
    expect(prefs.getInt('theme-mode-index'), ThemeMode.dark.index);
    expect(find.text('深色模式'), findsOneWidget); // subtitle 更新
  });
```

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/features/profile/profile_sub_pages_test.dart --plain-name "外观模式"`
Expected: FAIL（`ThemeProvider` 未注入到现有测试 → `ProviderNotFoundException`；或 UI 无交互导致找不到弹窗选项）。

- [ ] **Step 3: 更新现有测试装配（注入 ThemeProvider）**

现有 4 个设置页相关测试（`设置页展示原设置项并切换持久化影片图片模糊`、`线路选择：点击弹出弹窗...`、`线路选择：切回自动恢复...`、`线路选择：apiDomains 为空时...`）的 `MultiProvider.providers` 都需增加 ThemeProvider。对每个测试，在 `ChangeNotifierProvider.value(value: settings)` 之后加：

```dart
      ChangeNotifierProvider.value(value: theme),
```

并在该测试 `SharedPreferences.setMockInitialValues({});` 之后加：

```dart
    final theme = await ThemeProvider.create();
```

（`ThemeProvider.create()` 内部会 `SharedPreferences.getInstance()`，mock 已就绪。）

- [ ] **Step 4: 编写 UI 实现**

`lib/features/profile/screens/profile_sub_pages.dart` 的 imports 增加：

```dart
import 'package:jade/core/providers/theme_provider.dart';
```

在文件顶层（`_hostOf` 附近）新增：

```dart
/// 外观模式的展示文案。
String _themeModeLabel(ThemeMode mode) => switch (mode) {
  ThemeMode.system => '跟随系统',
  ThemeMode.light => '浅色模式',
  ThemeMode.dark => '深色模式',
};
```

`ProfileSettingsPage.build` 顶部增加：

```dart
    final themeMode = context.watch<ThemeProvider>().themeMode;
```

`cells` 中「外观模式」cell 替换为：

```dart
      ListTile(
        leading: const Icon(Icons.brightness_6_outlined),
        title: const Text('外观模式'),
        subtitle: Text(_themeModeLabel(themeMode)),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _openAppearancePicker(context),
      ),
```

`ProfileSettingsPage` 类中新增方法：

```dart
  /// 弹出外观模式选择弹窗；选中后立即生效并持久化。
  void _openAppearancePicker(BuildContext context) {
    final theme = context.read<ThemeProvider>();
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                '外观模式',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            for (final mode in ThemeMode.values)
              ListTile(
                title: Text(_themeModeLabel(mode)),
                trailing: theme.themeMode == mode
                    ? const Icon(Icons.check)
                    : null,
                onTap: () {
                  theme.setThemeMode(mode);
                  Navigator.pop(sheetContext);
                },
              ),
          ],
        ),
      ),
    );
  }
```

（`ThemeMode.values` 顺序即 system/light/dark。）

- [ ] **Step 5: 运行测试确认通过**

Run: `flutter test test/features/profile/profile_sub_pages_test.dart`
Expected: 全部 PASS（含新增外观模式测试与既有线路/模糊测试）。

- [ ] **Step 6: 提交**

```bash
git add lib/features/profile/screens/profile_sub_pages.dart test/features/profile/profile_sub_pages_test.dart
git commit -m "feat(settings): add appearance mode picker"
```

---

### Task 4: 设置页清除缓存（含大小显示）

**Files:**
- Modify: `lib/features/profile/screens/profile_sub_pages.dart`
- Modify: `test/features/profile/profile_sub_pages_test.dart`

**Interfaces:**
- Consumes: `CacheService`、`JdbImageCacheService`、`formatCacheSize`（Task 2 产出）。
- Produces: `ProfileSettingsPage` 转为 `StatefulWidget`，可选参数 `CacheService? cacheService`；「清除缓存」cell 显示大小，点击弹确认对话框后清除并提示。

- [ ] **Step 1: 编写失败 Widget 测试**

`test/features/profile/profile_sub_pages_test.dart` 的 imports 增加：

```dart
import 'package:jade/core/network/cache_service.dart';
```

在 `main()` 内、`void main() {` 之后新增 fake 类：

```dart
class _FakeCacheService implements CacheService {
  _FakeCacheService({this.size = 0});

  int size;
  int clearAllCalls = 0;

  @override
  Future<int> getCacheSizeBytes() async => size;

  @override
  Future<void> clearAll() async {
    clearAllCalls++;
    size = 0;
  }
}
```

新增测试：

```dart
  testWidgets('清除缓存：显示大小，确认后调用 clearAll 并归零提示', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final settings = await SettingsProvider.create(prefs);
    final theme = await ThemeProvider.create();
    final dm = await DomainManager.load(prefs);
    final cacheService = _FakeCacheService(size: (24 * 1024 + 512) * 1024);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: settings),
          ChangeNotifierProvider.value(value: theme),
          ChangeNotifierProvider.value(value: dm),
        ],
        child: MaterialApp(
          home: ProfileSettingsPage(cacheService: cacheService),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('清除缓存'), findsOneWidget);
    expect(find.text('24.5 MB'), findsOneWidget);

    await tester.tap(find.text('清除缓存'));
    await tester.pumpAndSettle();

    expect(find.text('清除图片缓存？'), findsOneWidget);

    await tester.tap(find.text('清除'));
    await tester.pumpAndSettle();

    expect(cacheService.clearAllCalls, 1);
    expect(find.text('0 B'), findsOneWidget);
    expect(find.text('缓存已清除'), findsOneWidget);
  });
```

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/features/profile/profile_sub_pages_test.dart --plain-name "清除缓存"`
Expected: FAIL（`ProfileSettingsPage` 尚无 `cacheService` 参数，编译错误）。

- [ ] **Step 3: 转为 StatefulWidget 并实现**

`lib/features/profile/screens/profile_sub_pages.dart` 的 imports 增加：

```dart
import 'package:jade/core/network/cache_service.dart';
```

`ProfileSettingsPage` 类替换为：

```dart
class ProfileSettingsPage extends StatefulWidget {
  const ProfileSettingsPage({super.key, this.cacheService});

  final CacheService? cacheService;

  @override
  State<ProfileSettingsPage> createState() => _ProfileSettingsPageState();
}

class _ProfileSettingsPageState extends State<ProfileSettingsPage> {
  late final CacheService _cacheService =
      widget.cacheService ?? JdbImageCacheService();
  int? _cacheSizeBytes;

  @override
  void initState() {
    super.initState();
    _loadCacheSize();
  }

  Future<void> _loadCacheSize() async {
    final size = await _cacheService.getCacheSizeBytes();
    if (!mounted) return;
    setState(() => _cacheSizeBytes = size);
  }

  Future<void> _confirmAndClearCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('清除图片缓存？'),
        content: const Text('将删除已下载的图片封面与剧照。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('清除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _cacheService.clearAll();
      if (!mounted) return;
      setState(() => _cacheSizeBytes = 0);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('缓存已清除')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('清除失败，请稍后重试')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final blurMovieImages = context.select<SettingsProvider, bool>(
      (settings) => settings.blurMovieImages,
    );
    final dm = context.watch<DomainManager>();
    final themeMode = context.watch<ThemeProvider>().themeMode;
    final cells = <Widget>[
      ListTile(
        leading: const Icon(Icons.brightness_6_outlined),
        title: const Text('外观模式'),
        subtitle: Text(_themeModeLabel(themeMode)),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _openAppearancePicker(context),
      ),
      SwitchListTile(
        secondary: const Icon(Icons.blur_on_outlined),
        title: const Text('影片图片模糊'),
        subtitle: const Text('模糊影片封面与剧照'),
        value: blurMovieImages,
        onChanged: context.read<SettingsProvider>().setBlurMovieImages,
      ),
      ListTile(
        leading: const Icon(Icons.swap_horiz),
        title: const Text('线路选择'),
        subtitle: Text(dm.isAutoMode ? '自动' : _hostOf(dm.currentUrl)),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _openLinePicker(context),
      ),
      ListTile(
        leading: const Icon(Icons.cleaning_services_outlined),
        title: const Text('清除缓存'),
        subtitle: Text(
          _cacheSizeBytes == null ? '计算中…' : formatCacheSize(_cacheSizeBytes!),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: _confirmAndClearCache,
      ),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView.separated(
        itemCount: cells.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (_, index) => cells[index],
      ),
    );
  }

  /// 弹出外观模式选择弹窗；选中后立即生效并持久化。
  void _openAppearancePicker(BuildContext context) {
    final theme = context.read<ThemeProvider>();
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                '外观模式',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            for (final mode in ThemeMode.values)
              ListTile(
                title: Text(_themeModeLabel(mode)),
                trailing: theme.themeMode == mode
                    ? const Icon(Icons.check)
                    : null,
                onTap: () {
                  theme.setThemeMode(mode);
                  Navigator.pop(sheetContext);
                },
              ),
          ],
        ),
      ),
    );
  }

  /// 弹出线路选择弹窗；选中后立即生效并提示。
  void _openLinePicker(BuildContext context) {
    final dm = context.read<DomainManager>();
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => _LinePickerSheet(
        domainManager: dm,
        onSelected: (String? url) {
          if (url == null) return;
          final isAuto = url == 'auto';
          if (isAuto) {
            unawaited(dm.selectAuto());
          } else {
            unawaited(dm.select(url));
          }
          ApiClient.instance.swapBaseUrl(dm.currentUrl);
          Navigator.pop(sheetContext);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isAuto ? '已切换到自动线路' : '已切换到 ${_hostOf(url)}'),
            ),
          );
        },
      ),
    );
  }
}
```

（`_LinePickerSheet`、`_CellScaffold`、`_ProfileCell` 保持原实现不动。）

- [ ] **Step 4: 运行测试确认通过**

Run: `flutter test test/features/profile/profile_sub_pages_test.dart`
Expected: 全部 PASS（含清除缓存、外观模式、线路、模糊测试）。

- [ ] **Step 5: 提交**

```bash
git add lib/features/profile/screens/profile_sub_pages.dart test/features/profile/profile_sub_pages_test.dart
git commit -m "feat(settings): add cache size display and clear action"
```

---

### Task 5: 全量静态分析与测试验证

**Files:**
- 无代码改动。

**Interfaces:**
- Consumes: 前 4 个任务的全部产出。

- [ ] **Step 1: 静态分析**

Run: `flutter analyze`
Expected: 无 error / warning / info（既有代码应保持零告警；若有与本计划无关的既有告警，记录并说明，不擅自修改）。

- [ ] **Step 2: 全量测试**

Run: `flutter test`
Expected: 全部 PASS。若存在与本计划无关的既有失败，如实记录失败用例与原因，不掩盖。

- [ ] **Step 3: 收尾检查**

Run: `git status` 与 `git log --oneline -5`
Expected: 工作区干净；日志包含本计划 4 个提交（`refactor(settings): remove default filter tags setting`、`feat(cache): add cache service with size stats and clear`、`feat(settings): add appearance mode picker`、`feat(settings): add cache size display and clear action`）。
