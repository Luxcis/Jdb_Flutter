# 设置页线路切换实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在设置页（`/profile/settings`）实现 API 域名线路切换：点击「线路选择」弹出底部弹窗，可选「自动（推荐）」或某个具体域名；手动选择立即生效（`ApiClient.swapBaseUrl`）并持久化，重启保持；手动模式下禁用 608 自动轮转。

**Architecture:** 扩展 `DomainManager` 为唯一状态源，新增 `LineMode { auto, manual }` 与 `select()`/`selectAuto()`；手动模式由 `rotate()` 返回 `false` 表达，`DomainSwitchInterceptor` 零改动；`StorageKeys.line`（`key_line`）持久化模式；`ProfileSettingsPage` 用 `context.watch<DomainManager>()` 实时刷新 subtitle，弹窗选择后调用 `ApiClient.instance.swapBaseUrl` 立即生效。

**Tech Stack:** Flutter、Dart、Material 3、Provider、`SharedPreferences`、`DomainManager`/`DomainSwitchInterceptor`/`ApiClient`、`flutter_test`。

## Global Constraints

- 线路模式持久化键 `StorageKeys.line`：值 `'auto'` 表示自动，否则为手动域名 URL。
- `applyStartup()`：手动域名仍在新列表则保持 `manual`，否则回退 `auto` 并切主域名。
- `rotate()`：`manual` 模式直接返回 `false`，不改动 `currentUrl`。
- 弹窗选项显示 host（去掉 `https://` 前缀）；选中行用 `Icons.check` 高亮，不使用 `RadioListTile`（避免版本弃用）。
- `apiDomains` 为空时弹窗仅显示兜底域名 `AppConstants.fallbackBaseUrl`。
- 每次提交只暂存任务列出的文件；不修改 ARB，中文文案按项目约定硬编码。
- 手动切换后需同步 `ApiClient` baseUrl（设置页调用 `ApiClient.instance.swapBaseUrl(dm.currentUrl)`）。

---

### Task 1: DomainManager 线路模式

**Files:**
- Modify: `lib/core/network/domain_manager.dart`
- Modify: `test/core/network/domain_manager_test.dart`

**Interfaces:**
- Produces: `enum LineMode { auto, manual }`；`DomainManager` 新增 `lineMode`/`isAutoMode` getter、`select(String url)`、`selectAuto()`；`rotate()` 增加手动守卫；`load()`/`applyStartup()` 处理模式恢复与保持。

- [ ] **Step 1: 编写失败测试**

在 `test/core/network/domain_manager_test.dart` 末尾追加：

```dart
test('select 切换到手动线路并持久化', () async {
  final prefs = await SharedPreferences.getInstance();
  final dm = await DomainManager.load(prefs);
  await dm.applyStartup(BackupDomains(
    apiDomains: ['https://jdforrepam.com', 'https://b.com'],
  ));
  await dm.select('https://b.com');
  expect(dm.lineMode, LineMode.manual);
  expect(dm.isAutoMode, isFalse);
  expect(dm.currentUrl, 'https://b.com');
  expect(prefs.getString(StorageKeys.line), 'https://b.com');
});

test('selectAuto 恢复自动与主域名并持久化', () async {
  final prefs = await SharedPreferences.getInstance();
  final dm = await DomainManager.load(prefs);
  await dm.applyStartup(BackupDomains(
    apiDomains: ['https://jdforrepam.com', 'https://b.com'],
  ));
  await dm.select('https://b.com');
  await dm.selectAuto();
  expect(dm.lineMode, LineMode.auto);
  expect(dm.isAutoMode, isTrue);
  expect(dm.currentUrl, 'https://jdforrepam.com');
  expect(prefs.getString(StorageKeys.line), 'auto');
});

test('manual 模式下 rotate 返回 false 且不改动 currentUrl', () async {
  final prefs = await SharedPreferences.getInstance();
  final dm = await DomainManager.load(prefs);
  await dm.applyStartup(BackupDomains(
    apiDomains: ['https://jdforrepam.com', 'https://b.com'],
  ));
  await dm.select('https://b.com');
  expect(await dm.rotate(), isFalse);
  expect(dm.currentUrl, 'https://b.com');
});

test('applyStartup 在手动域名仍存在时保持手动选择', () async {
  final prefs = await SharedPreferences.getInstance();
  final dm = await DomainManager.load(prefs);
  await dm.applyStartup(BackupDomains(
    apiDomains: ['https://jdforrepam.com', 'https://b.com'],
  ));
  await dm.select('https://b.com');
  await dm.applyStartup(BackupDomains(
    apiDomains: ['https://jdforrepam.com', 'https://b.com', 'https://c.com'],
  ));
  expect(dm.lineMode, LineMode.manual);
  expect(dm.currentUrl, 'https://b.com');
});

test('applyStartup 在手动域名失效时回退自动并切主域名', () async {
  final prefs = await SharedPreferences.getInstance();
  final dm = await DomainManager.load(prefs);
  await dm.applyStartup(BackupDomains(
    apiDomains: ['https://jdforrepam.com', 'https://b.com'],
  ));
  await dm.select('https://b.com');
  await dm.applyStartup(BackupDomains(
    apiDomains: ['https://jdforrepam.com', 'https://c.com'],
  ));
  expect(dm.lineMode, LineMode.auto);
  expect(dm.currentUrl, 'https://jdforrepam.com');
  expect(prefs.getString(StorageKeys.line), 'auto');
});

test('load 从 SP 恢复手动模式与手动域名', () async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(StorageKeys.baseUrl, 'https://b.com');
  await prefs.setStringList(StorageKeys.apiDomains, [
    'https://jdforrepam.com',
    'https://b.com',
  ]);
  await prefs.setString(StorageKeys.line, 'https://b.com');
  final dm = await DomainManager.load(prefs);
  expect(dm.lineMode, LineMode.manual);
  expect(dm.currentUrl, 'https://b.com');
});

test('load 缺省 line 为 auto', () async {
  final prefs = await SharedPreferences.getInstance();
  final dm = await DomainManager.load(prefs);
  expect(dm.lineMode, LineMode.auto);
  expect(dm.isAutoMode, isTrue);
});
```

- [ ] **Step 2: 运行测试确认 RED**

Run: `flutter test test/core/network/domain_manager_test.dart`
Expected: FAIL，报错 `LineMode` 未定义、`select`/`selectAuto` 等方法不存在。

- [ ] **Step 3: 实现 DomainManager 扩展**

`lib/core/network/domain_manager.dart` 完整更新：

```dart
// lib/core/network/domain_manager.dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jade/core/constants/app_constants.dart';
import 'package:jade/core/models/startup.dart';
import 'package:jade/core/storage/storage_keys.dart';

/// 线路模式：自动（608 自动轮转）或手动（固定域名，禁用轮转）。
enum LineMode { auto, manual }

/// 域名动态切换状态机。
///
/// 从 startup API 解密 [BackupDomains] 后写入，同时管理 API 域名轮转和 CDN 端点。
class DomainManager extends ChangeNotifier {
  DomainManager._({required SharedPreferences prefs}) : _prefs = prefs {
    _currentUrl = AppConstants.fallbackBaseUrl;
    _apiDomains = const [];
  }

  final SharedPreferences _prefs;

  late String _currentUrl;
  List<String> _apiDomains = const [];
  int _index = 0;
  String? _imageEndpoint;
  LineMode _lineMode = LineMode.auto;

  /// 当前 API base URL。
  String get currentUrl => _currentUrl;

  /// 当前 API 域名列表。
  List<String> get apiDomains => List.unmodifiable(_apiDomains);

  /// 图片 CDN 端点，优先来自 startup，否则使用兜底值。
  String get imageEndpoint => _imageEndpoint ?? AppConstants.fallbackImageCdn;

  /// 当前线路模式。
  LineMode get lineMode => _lineMode;

  /// 是否自动线路模式。
  bool get isAutoMode => _lineMode == LineMode.auto;

  /// 是否位于主域名（列表第一个，即 startup 返回的首个 apiDomain）。
  bool get isOnMainDomain =>
      _apiDomains.isNotEmpty && _currentUrl == _apiDomains.first;

  /// 启动加载：SP 有则恢复，否则使用兜底域名。
  static Future<DomainManager> load(SharedPreferences prefs) async {
    final dm = DomainManager._(prefs: prefs);
    final stored = prefs.getStringList(StorageKeys.apiDomains);
    final url = prefs.getString(StorageKeys.baseUrl);
    final line = prefs.getString(StorageKeys.line);
    if (stored != null && stored.isNotEmpty) {
      dm._apiDomains = List<String>.from(stored);
      dm._index = 0;
      dm._currentUrl = url ?? stored.first;
    } else {
      dm._currentUrl = url ?? AppConstants.fallbackBaseUrl;
    }
    if (line != null && line != 'auto') {
      dm._lineMode = LineMode.manual;
      dm._currentUrl = line;
    }
    return dm;
  }

  /// 写入 startup 接口返回的域名列表，保持手动选择或回退自动。
  Future<void> applyStartup(BackupDomains data) async {
    final previousUrl = _currentUrl;
    final wasManual = _lineMode == LineMode.manual;
    _apiDomains = List<String>.from(data.apiDomains);
    _index = 0;
    if (wasManual && _apiDomains.contains(previousUrl)) {
      _currentUrl = previousUrl;
    } else {
      _lineMode = LineMode.auto;
      _currentUrl = _apiDomains.isNotEmpty ? _apiDomains.first : _currentUrl;
    }
    _imageEndpoint = data.imageEndpoint;
    await _persist();
    notifyListeners();
  }

  /// 手动选择固定线路域名。
  Future<void> select(String url) async {
    _lineMode = LineMode.manual;
    _currentUrl = url;
    await _prefs.setString(StorageKeys.line, url);
    await _persist();
    notifyListeners();
  }

  /// 恢复自动线路并切回主域名。
  Future<void> selectAuto() async {
    _lineMode = LineMode.auto;
    if (_apiDomains.isNotEmpty) {
      _currentUrl = _apiDomains.first;
    }
    await _prefs.setString(StorageKeys.line, 'auto');
    await _persist();
    notifyListeners();
  }

  /// 轮转到下一个备用域名。返回 false 表示无可用备用域名或手动模式。
  Future<bool> rotate() async {
    if (_lineMode == LineMode.manual) return false;
    if (_apiDomains.length <= 1) return false;
    _index = (_index + 1) % _apiDomains.length;
    _currentUrl = _apiDomains[_index];
    await _persist();
    notifyListeners();
    return true;
  }

  Future<void> _persist() async {
    await _prefs.setString(StorageKeys.baseUrl, _currentUrl);
    await _prefs.setStringList(StorageKeys.apiDomains, _apiDomains);
  }
}
```

- [ ] **Step 4: 运行测试确认 GREEN**

Run: `flutter test test/core/network/domain_manager_test.dart`
Expected: PASS（新旧用例全部通过）。

- [ ] **Step 5: Commit**

```bash
git add lib/core/network/domain_manager.dart test/core/network/domain_manager_test.dart
git commit -m "feat(network): add manual line mode to DomainManager"
```

### Task 2: 拦截器手动模式回归测试

**Files:**
- Modify: `test/core/network/interceptors/domain_switch_interceptor_test.dart`

**Interfaces:**
- Consumes: Task 1 的 `rotate()` 手动守卫。
- Produces: 验证 `manual` 模式下 608 错误不轮转、错误原样放行。

- [ ] **Step 1: 编写测试**

在 `test/core/network/interceptors/domain_switch_interceptor_test.dart` 末尾追加：

```dart
test('manual 模式 608 不触发轮转', () async {
  final prefs = await SharedPreferences.getInstance();
  final dm = await DomainManager.load(prefs);
  await dm.applyStartup(BackupDomains(
    apiDomains: ['https://jdforrepam.com', 'https://b.com'],
  ));
  await dm.select('https://b.com');
  final adapter = FakeAdapter();
  adapter.enqueueSequence('/x', [
    {'success': 0, 'action': 'Blocked'},
  ], codes: [608]);
  final dio = Dio(BaseOptions(baseUrl: dm.currentUrl))
    ..httpClientAdapter = adapter;
  final ic = DomainSwitchInterceptor(domainManager: dm, dio: dio);
  dio.interceptors.add(ic);
  var rotated = false;
  ic.onRotated = () => rotated = true;
  await expectLater(dio.get('/x'), throwsDioException);
  expect(rotated, isFalse);
  expect(dm.currentUrl, 'https://b.com');
});
```

- [ ] **Step 2: 运行测试确认通过**

Run: `flutter test test/core/network/interceptors/domain_switch_interceptor_test.dart`
Expected: PASS（`rotate()` 手动守卫已由 Task 1 实现；本测试确认拦截器行为不变）。

- [ ] **Step 3: Commit**

```bash
git add test/core/network/interceptors/domain_switch_interceptor_test.dart
git commit -m "test: cover manual line mode disables 608 rotation"
```

### Task 3: 装配 DomainManager 到 Provider 树

**Files:**
- Modify: `lib/main.dart`

**Interfaces:**
- Produces: `DomainManager` 可通过 `context.watch<DomainManager>()` 访问（设置页依赖）。

- [ ] **Step 1: 在 MultiProvider 注册 DomainManager**

`lib/main.dart` 的 `MultiProvider` 增加一项：

```dart
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: themeProvider),
      ChangeNotifierProvider.value(value: authProvider),
      ChangeNotifierProvider.value(value: settingsProvider),
      ChangeNotifierProvider.value(value: startupProvider),
      ChangeNotifierProvider.value(value: apiClient.domainManager),
      ChangeNotifierProvider(create: (_) => SearchHistoryStore(prefs)),
    ],
    child: const MyApp(),
  );
```

- [ ] **Step 2: 运行入口与启动相关测试**

Run: `flutter test test/app_test.dart test/core/providers/startup_provider_test.dart`
Expected: PASS，装配不影响现有启动流程。

- [ ] **Step 3: Commit**

```bash
git add lib/main.dart
git commit -m "feat: expose DomainManager to provider tree"
```

### Task 4: 设置页线路选择 UI

**Files:**
- Modify: `lib/features/profile/screens/profile_sub_pages.dart:315-349`
- Modify: `test/features/profile/profile_sub_pages_test.dart`
- Modify: `lib/core/network/api_client.dart`（无需改动，确认 `swapBaseUrl` 可被设置页调用）

**Interfaces:**
- Consumes: `DomainManager`（provider）、`ApiClient.instance.swapBaseUrl`。
- Produces: 可交互「线路选择」项 + 底部弹窗；subtitle 实时显示「自动」或当前域名 host。

- [ ] **Step 1: 编写失败 Widget 测试**

先更新 `test/features/profile/profile_sub_pages_test.dart` 头部 imports：

```dart
import 'package:jade/core/models/startup.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/domain_manager.dart';
import 'package:jade/core/providers/auth_provider.dart';
```

然后替换 `设置页展示原设置项并切换持久化影片图片模糊` 用例的 pump 部分（补 DomainManager provider），并在文件末尾追加两个新用例。

先更新既有用例：`SharedPreferences.setMockInitialValues({});` 之后增加：

```dart
    final dm = await DomainManager.load(prefs);
```

并将 `await tester.pumpWidget(...)` 替换为：

```dart
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: settings),
          ChangeNotifierProvider.value(value: dm),
        ],
        child: const MaterialApp(home: ProfileSettingsPage()),
      ),
    );
```

（保留该用例原有断言与 SwitchListTile 交互；页面中「线路选择」subtitle 此时为「自动」。）

追加新用例：

```dart
testWidgets('线路选择：点击弹出弹窗，选中域名后 subtitle 更新并提示', (tester) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final settings = await SettingsProvider.create(prefs);
  final auth = await AuthProvider.create(prefs);
  await ApiClient.create(prefs: prefs, tokenProvider: auth, onAuthError: () {});
  final dm = ApiClient.instance.domainManager;
  await dm.applyStartup(BackupDomains(
    apiDomains: ['https://jdforrepam.com', 'https://backup1.com'],
  ));

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: dm),
      ],
      child: const MaterialApp(home: ProfileSettingsPage()),
    ),
  );

  expect(find.text('线路选择'), findsOneWidget);
  expect(find.text('自动'), findsOneWidget); // subtitle

  await tester.tap(find.text('线路选择'));
  await tester.pumpAndSettle();

  expect(find.text('自动（推荐）'), findsOneWidget);
  expect(find.text('backup1.com'), findsOneWidget);

  await tester.tap(find.text('backup1.com'));
  await tester.pumpAndSettle();

  expect(dm.lineMode, LineMode.manual);
  expect(dm.currentUrl, 'https://backup1.com');
  expect(find.text('backup1.com'), findsOneWidget); // subtitle 更新
  expect(find.text('已切换到 backup1.com'), findsOneWidget); // SnackBar
});

testWidgets('线路选择：切回自动恢复 subtitle 与主域名', (tester) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final settings = await SettingsProvider.create(prefs);
  final auth = await AuthProvider.create(prefs);
  await ApiClient.create(prefs: prefs, tokenProvider: auth, onAuthError: () {});
  final dm = ApiClient.instance.domainManager;
  await dm.applyStartup(BackupDomains(
    apiDomains: ['https://jdforrepam.com', 'https://backup1.com'],
  ));
  await dm.select('https://backup1.com');

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: dm),
      ],
      child: const MaterialApp(home: ProfileSettingsPage()),
    ),
  );

  expect(find.text('backup1.com'), findsOneWidget); // subtitle 为手动域名

  await tester.tap(find.text('线路选择'));
  await tester.pumpAndSettle();

  await tester.tap(find.text('自动（推荐）'));
  await tester.pumpAndSettle();

  expect(dm.isAutoMode, isTrue);
  expect(dm.currentUrl, 'https://jdforrepam.com');
  expect(find.text('自动'), findsOneWidget);
  expect(find.text('已切换到自动线路'), findsOneWidget);
});
```

- [ ] **Step 2: 运行测试确认 RED**

Run: `flutter test test/features/profile/profile_sub_pages_test.dart`
Expected: FAIL——`DomainManager` 未引入/未暴露 provider，或「线路选择」不可点击、弹窗不存在。

- [ ] **Step 3: 实现设置页 UI**

更新 `lib/features/profile/screens/profile_sub_pages.dart`：

1) 文件顶部追加 import（`profile_sub_pages.dart` 当前无这三个包）：

```dart
import 'package:jade/core/constants/app_constants.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/domain_manager.dart';
```

2) 文件末尾追加顶层辅助函数：

```dart
/// 去掉 URL 的协议前缀，仅显示 host。
String _hostOf(String url) => url.replaceFirst(RegExp(r'^https?://'), '');
```

3) 将 `ProfileSettingsPage` 整体替换为：

```dart
class ProfileSettingsPage extends StatelessWidget {
  const ProfileSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final blurMovieImages = context.select<SettingsProvider, bool>(
      (settings) => settings.blurMovieImages,
    );
    final dm = context.watch<DomainManager>();
    final cells = <Widget>[
      const _ProfileCell(
        title: '外观模式',
        subtitle: '跟随系统',
        icon: Icons.brightness_6_outlined,
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
      const _ProfileCell(title: '默认筛选标签', subtitle: '含磁链', icon: Icons.tune),
      const _ProfileCell(title: '清除缓存', icon: Icons.cleaning_services_outlined),
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
            dm.selectAuto();
          } else {
            dm.select(url);
          }
          ApiClient.instance.swapBaseUrl(dm.currentUrl);
          Navigator.pop(sheetContext);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isAuto ? '已切换到自动线路' : '已切换到 ${_hostOf(url)}',
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 线路选择底部弹窗：自动 + 各域名单选行。
class _LinePickerSheet extends StatelessWidget {
  const _LinePickerSheet({required this.domainManager, required this.onSelected});

  final DomainManager domainManager;
  final void Function(String? url) onSelected;

  @override
  Widget build(BuildContext context) {
    final dm = domainManager;
    final domains = dm.apiDomains.isNotEmpty
        ? dm.apiDomains
        : const [AppConstants.fallbackBaseUrl];
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('线路选择', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          ListTile(
            title: const Text('自动（推荐）'),
            subtitle: const Text('请求失败时自动切换可用线路'),
            trailing: dm.isAutoMode ? const Icon(Icons.check) : null,
            onTap: () => onSelected('auto'),
          ),
          const Divider(height: 1),
          for (final url in domains)
            ListTile(
              title: Text(_hostOf(url)),
              trailing:
                  !dm.isAutoMode && dm.currentUrl == url
                      ? const Icon(Icons.check)
                      : null,
              onTap: () => onSelected(url),
            ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: 运行测试确认 GREEN**

Run: `flutter test test/features/profile/profile_sub_pages_test.dart`
Expected: PASS（既有设置页用例 + 两个新线路用例全部通过）。

- [ ] **Step 5: Commit**

```bash
git add lib/features/profile/screens/profile_sub_pages.dart test/features/profile/profile_sub_pages_test.dart
git commit -m "feat(settings): add line switch picker to settings page"
```

### Task 5: 静态分析、测试回归与收尾

**Files:**
- Modify: 无（仅验证）

- [ ] **Step 1: 静态分析**

Run: `flutter analyze`
Expected: No issues found（无新增 warning/error）。

- [ ] **Step 2: 运行完整测试套件**

Run: `flutter test`
Expected: 全部通过；如实记录任何与本次改动无关的既有失败。

- [ ] **Step 3: 检查未提交改动并提交收尾**

Run: `git status --short`
Expected: 仅剩本计划未提交的文件（若有）；确认无遗留改动后：

```bash
git add <剩余相关文件>
git commit -m "chore: finalize line switch feature"
```

## 自检记录

- 规格覆盖度：规格「组件职责」四节对应 Task 1/3/4；「测试与验收」7 条对应 Task 1（1-5）、Task 2（6）、Task 4（7）；「装配」对应 Task 3；「切换流程」「错误处理」由 Task 1 `applyStartup`/`load` 与 Task 4 弹窗兜底分支覆盖。
- 占位符扫描：无 TODO/待定；所有代码块为完整实现。
- 类型一致性：`LineMode.auto/manual`、`select(url)`、`selectAuto()`、`isAutoMode`、`_hostOf(url)` 在各任务中命名一致；`StorageKeys.line` 语义（`'auto'` 或域名 URL）在 Task 1 与 Task 4 一致。
