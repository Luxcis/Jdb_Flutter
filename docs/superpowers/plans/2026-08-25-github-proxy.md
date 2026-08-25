# 设置页「GitHub 代理」功能实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 在设置页「当前版本」上方新增 GitHub 代理设置（下拉框选择代理），代理值持久化到 SharedPreferences，并让「检查更新」的 API 请求与 APK 下载在代理前缀非空时拼接代理地址。

**架构：** 代理值存入 `SettingsProvider`（ChangeNotifier + SharedPreferences，新增 `githubProxy` 字段与 `StorageKey`）。引入两个纯函数 `buildGitHubUrl`（prepend 代理）与 `normalizeGithubProxy`（自定义代理未以 `/` 结尾时自动补齐），让 `UpdateChecker` / `UpdateInstaller` 各自接收 `proxy` 参数在拼接真实 URL 前处理。UI 在 `ProfileSettingsPage` 的「当前版本」上方插入 `GitHub 代理` ListTile，点击弹出 BottomSheet（复用「线路选择」风格），含「自定义…」AlertDialog 输入。

**技术栈：** Flutter / Dart、`shared_preferences`（持久化，已有）、`provider`（状态管理，已有）、`http`（更新请求，已有）。无需新增依赖。

**设计文档：** `docs/superpowers/specs/2026-08-25-github-proxy-design.md`

---

## 文件结构

| 文件 | 职责 |
|------|------|
| `lib/core/storage/storage_keys.dart` | **修改**：新增 `githubProxy` 常量 |
| `lib/core/providers/settings_provider.dart` | **修改**：新增 `githubProxy` 字段/getter/读写 |
| `lib/features/profile/services/update_service.dart` | **修改**：新增 `buildGitHubUrl`、`normalizeGithubProxy`；`UpdateChecker`/`UpdateInstaller` 增加 `proxy` 构造参数并拼接 |
| `lib/features/profile/screens/profile_sub_pages.dart` | **修改**：`ProfileSettingsPage` 插入 `GitHub 代理` ListTile + `_openGithubProxyPicker`（BottomSheet + 自定义 AlertDialog）；更新流程注入 `SettingsProvider.githubProxy` |
| `test/core/providers/settings_provider_test.dart` | **修改**：追加 `githubProxy` 相关用例 |
| `test/features/profile/update_service_test.dart` | **修改**：追加 `normalizeGithubProxy`/`buildGitHubUrl`/proxy 拼接用例 |
| `test/features/profile/profile_sub_pages_test.dart` | **修改**：追加 `GitHub 代理` 单元格与弹窗选择用例 |

---

### 任务 1：数据层（StorageKey + SettingsProvider）

**文件：**
- 修改：`lib/core/storage/storage_keys.dart`
- 修改：`lib/core/providers/settings_provider.dart`
- 测试：`test/core/providers/settings_provider_test.dart`

- [ ] **步骤 1：编写失败的测试**

在 `test/core/providers/settings_provider_test.dart` 的 `main()` 内追加：

```dart
test('GitHub 代理默认关闭（空串）', () async {
  final prefs = await SharedPreferences.getInstance();
  final provider = await SettingsProvider.create(prefs);

  expect(provider.githubProxy, '');
});

test('恢复已保存的 GitHub 代理', () async {
  SharedPreferences.setMockInitialValues({
    StorageKeys.githubProxy: 'https://hub.luxcis.top/',
  });
  final prefs = await SharedPreferences.getInstance();
  final provider = await SettingsProvider.create(prefs);

  expect(provider.githubProxy, 'https://hub.luxcis.top/');
});

test('切换 GitHub 代理后持久化并通知监听者', () async {
  final prefs = await SharedPreferences.getInstance();
  final provider = await SettingsProvider.create(prefs);
  var notifications = 0;
  provider.addListener(() => notifications++);

  await provider.setGithubProxy('https://gh-proxy.com/');

  expect(provider.githubProxy, 'https://gh-proxy.com/');
  expect(prefs.getString(StorageKeys.githubProxy), 'https://gh-proxy.com/');
  expect(notifications, 1);
});
```

- [ ] **步骤 2：运行测试验证失败**

运行：`flutter test test/core/providers/settings_provider_test.dart`
预期：FAIL，报错 `The getter 'githubProxy' isn't defined for the class 'SettingsProvider'`。

- [ ] **步骤 3：实现 StorageKey 常量**

在 `lib/core/storage/storage_keys.dart` 的 `StorageKeys` 类新增一行：

```dart
static const String githubProxy = 'key_github_proxy';
```

- [ ] **步骤 4：实现 SettingsProvider 读写**

修改 `lib/core/providers/settings_provider.dart`：

```dart
class SettingsProvider extends ChangeNotifier {
  SettingsProvider._(this._prefs);
  final SharedPreferences _prefs;
  bool _blurMovieImages = true;
  String _githubProxy = '';

  bool get blurMovieImages => _blurMovieImages;
  String get githubProxy => _githubProxy;

  static Future<SettingsProvider> create(SharedPreferences prefs) async {
    final p = SettingsProvider._(prefs);
    p._blurMovieImages = prefs.getBool(StorageKeys.blurMovieImages) ?? true;
    p._githubProxy = prefs.getString(StorageKeys.githubProxy) ?? '';
    return p;
  }

  Future<void> setBlurMovieImages(bool value) async {
    _blurMovieImages = value;
    await _prefs.setBool(StorageKeys.blurMovieImages, value);
    notifyListeners();
  }

  Future<void> setGithubProxy(String value) async {
    _githubProxy = value;
    await _prefs.setString(StorageKeys.githubProxy, value);
    notifyListeners();
  }
}
```

- [ ] **步骤 5：运行测试验证通过**

运行：`flutter test test/core/providers/settings_provider_test.dart`
预期：PASS（新增 3 个用例全部通过）。

- [ ] **步骤 6：Commit**

```bash
git add lib/core/storage/storage_keys.dart lib/core/providers/settings_provider.dart test/core/providers/settings_provider_test.dart
git commit -m "feat(settings): add githubProxy setting to SettingsProvider"
```

---

### 任务 2：URL 拼接纯函数与更新服务接入代理

**文件：**
- 修改：`lib/features/profile/services/update_service.dart`
- 测试：`test/features/profile/update_service_test.dart`

- [ ] **步骤 1：编写失败的测试**

在 `test/features/profile/update_service_test.dart` 的 `main()` 内追加：

```dart
group('buildGitHubUrl', () {
  test('空代理原样返回', () {
    expect(
      buildGitHubUrl('', 'https://api.github.com/a'),
      'https://api.github.com/a',
    );
  });

  test('非空代理前缀拼接', () {
    expect(
      buildGitHubUrl('https://hub.luxcis.top/', 'https://api.github.com/a'),
      'https://hub.luxcis.top/https://api.github.com/a',
    );
  });
});

group('normalizeGithubProxy', () {
  test('空串保持不变', () {
    expect(normalizeGithubProxy(''), '');
  });
  test('已以 / 结尾保持不变', () {
    expect(
      normalizeGithubProxy('https://hub.luxcis.top/'),
      'https://hub.luxcis.top/',
    );
  });
  test('未以 / 结尾自动补齐', () {
    expect(
      normalizeGithubProxy('https://hub.luxcis.top'),
      'https://hub.luxcis.top/',
    );
  });
});
```

在 `group('UpdateChecker', ...)` 内追加：

```dart
test('配置代理时请求 URL 拼接代理前缀', () async {
  final checker = UpdateChecker(
    currentVersion: '0.9.2',
    proxy: 'https://hub.luxcis.top/',
    client: MockClient((request) async {
      expect(
        request.url.toString(),
        'https://hub.luxcis.top/https://api.github.com/repos/Luxcis/Jdb_Flutter/releases/latest',
      );
      return http.Response('{}', 200,
          headers: {'content-type': 'application/json'});
    }),
  );

  final result = await checker.check();

  // 空 release JSON -> tagName '' -> Version.parse 失败 -> hasUpdate=false
  expect(result.hasUpdate, isFalse);
});
```

在 `group('UpdateInstaller.download', ...)` 内追加：

```dart
test('配置代理时下载 URL 拼接代理前缀', () async {
  final installer = UpdateInstaller(
    proxy: 'https://hub.luxcis.top/',
    downloadDir: Directory.systemTemp.createTempSync('update_test'),
    client: MockClient((request) async {
      expect(
        request.url.toString(),
        'https://hub.luxcis.top/https://github.com/Luxcis/Jdb_Flutter/releases/download/v0.10.0/app-arm64-v8a-release.apk',
      );
      return http.Response.bytes(List<int>.filled(64, 1), 200,
          headers: {'content-length': '64'});
    }),
  );
  final asset = const GitHubReleaseAsset(
    name: 'app-arm64-v8a-release.apk',
    size: 64,
    downloadUrl:
        'https://github.com/Luxcis/Jdb_Flutter/releases/download/v0.10.0/app-arm64-v8a-release.apk',
  );

  final path = await installer.download(asset);

  expect(await File(path).length(), 64);
});
```

- [ ] **步骤 2：运行测试验证失败**

运行：`flutter test test/features/profile/update_service_test.dart`
预期：FAIL，报错 `The function 'buildGitHubUrl' isn't defined`、`named parameter 'proxy' isn't defined`。

- [ ] **步骤 3：实现纯函数 + 构造参数**

修改 `lib/features/profile/services/update_service.dart`：

文件顶部（`class GitHubReleaseAsset` 之前）新增：

```dart
/// 代理前缀非空时拼接到完整 URL 前，否则原样返回。
String buildGitHubUrl(String proxy, String fullUrl) =>
    proxy.isEmpty ? fullUrl : '$proxy$fullUrl';

/// 规范化代理前缀：空串保留；非空且不以 / 结尾时自动补齐 /。
String normalizeGithubProxy(String proxy) =>
    proxy.isEmpty || proxy.endsWith('/') ? proxy : '$proxy/';
```

`UpdateChecker` 改为：

```dart
class UpdateChecker {
  UpdateChecker({
    required this.currentVersion,
    this.proxy = '',
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String currentVersion;
  final String proxy;
  final http.Client _client;

  static const _apiUrl =
      'https://api.github.com/repos/Luxcis/Jdb_Flutter/releases/latest';

  Uri _releaseUrl() => Uri.parse(buildGitHubUrl(proxy, _apiUrl));

  Future<UpdateCheckResult> check() async {
    final response = await _client.get(_releaseUrl());
    if (response.statusCode != 200) {
      throw Exception('GitHub release 请求失败：HTTP ${response.statusCode}');
    }
    final release = GitHubRelease.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
    final latestVersion = release.tagName.replaceFirst(RegExp(r'^v'), '');
    final hasUpdate = _isNewer(latestVersion, currentVersion);
    return UpdateCheckResult(
      release: release,
      hasUpdate: hasUpdate,
      latestVersion: latestVersion,
    );
  }

  bool _isNewer(String latest, String current) {
    try {
      return Version.parse(latest) > Version.parse(current);
    } on FormatException {
      return false;
    }
  }
}
```

`UpdateInstaller` 改为：

```dart
class UpdateInstaller {
  UpdateInstaller({
    this.proxy = '',
    http.Client? client,
    Directory? downloadDir,
  })  : _client = client ?? http.Client(),
        _downloadDir = downloadDir;

  final String proxy;
  final http.Client _client;
  final Directory? _downloadDir;

  GitHubReleaseAsset pickAsset(
    GitHubRelease release,
    List<String> supportedAbis,
  ) {
    for (final abi in supportedAbis) {
      for (final asset in release.assets) {
        if (asset.name.contains(abi)) return asset;
      }
    }
    return release.assets.first;
  }

  Future<String> download(
    GitHubReleaseAsset asset, {
    void Function(int received, int total)? onProgress,
  }) async {
    final dir = _downloadDir ?? await getApplicationDocumentsDirectory();
    final targetDir = Directory('${dir.path}/update');
    await targetDir.create(recursive: true);

    final request = http.Request(
      'GET',
      Uri.parse(buildGitHubUrl(proxy, asset.downloadUrl)),
    );
    final streamed = await _client.send(request);
    if (streamed.statusCode != 200) {
      throw Exception('APK 下载失败：HTTP ${streamed.statusCode}');
    }
    final total = streamed.contentLength ?? asset.size;
    final file = File('${targetDir.path}/app-jade.apk');
    final sink = file.openWrite();
    var received = 0;
    await for (final chunk in streamed.stream) {
      received += chunk.length;
      sink.add(chunk);
      onProgress?.call(received, total);
    }
    await sink.close();
    return file.path;
  }
}
```

- [ ] **步骤 4：运行测试验证通过**

运行：`flutter test test/features/profile/update_service_test.dart`
预期：PASS（既有 + 新增用例全部通过）。

- [ ] **步骤 5：Commit**

```bash
git add lib/features/profile/services/update_service.dart test/features/profile/update_service_test.dart
git commit -m "feat(update): proxy-aware UpdateChecker/UpdateInstaller + URL helpers"
```

---

### 任务 3：设置页「GitHub 代理」单元格 + 弹窗选择

**文件：**
- 修改：`lib/features/profile/screens/profile_sub_pages.dart`
- 测试：`test/features/profile/profile_sub_pages_test.dart`

- [ ] **步骤 1：编写失败的测试**

在 `test/features/profile/profile_sub_pages_test.dart` 的 `main()` 内追加两个用例：

```dart
testWidgets('GitHub 代理：默认不使用代理，点击弹出弹窗选择后保存', (tester) async {
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
      child: MaterialApp(
        home: ProfileSettingsPage(cacheService: _FakeCacheService()),
      ),
    ),
  );

  expect(find.text('GitHub 代理'), findsOneWidget);
  expect(find.text('不使用代理'), findsOneWidget);

  await tester.tap(find.text('GitHub 代理'));
  await tester.pumpAndSettle();

  expect(find.text('https://hub.luxcis.top/'), findsOneWidget);
  expect(find.text('https://gh-proxy.com/'), findsOneWidget);
  expect(find.text('自定义…'), findsOneWidget);

  await tester.tap(find.text('https://hub.luxcis.top/'));
  await tester.pumpAndSettle();

  expect(settings.githubProxy, 'https://hub.luxcis.top/');
  expect(prefs.getString(StorageKeys.githubProxy), 'https://hub.luxcis.top/');
  // subtitle 更新为 host
  expect(find.text('hub.luxcis.top'), findsOneWidget);
});

testWidgets('GitHub 代理：自定义地址弹窗输入并规范化保存', (tester) async {
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
      child: MaterialApp(
        home: ProfileSettingsPage(cacheService: _FakeCacheService()),
      ),
    ),
  );

  await tester.tap(find.text('GitHub 代理'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('自定义…'));
  await tester.pumpAndSettle();

  await tester.enterText(
    find.byType(TextField),
    'https://mirror.example.com/proxy',
  );
  await tester.tap(find.text('确定'));
  await tester.pumpAndSettle();

  // 自动补齐 / 结尾
  expect(settings.githubProxy, 'https://mirror.example.com/proxy/');
  expect(
    prefs.getString(StorageKeys.githubProxy),
    'https://mirror.example.com/proxy/',
  );
});
```

- [ ] **步骤 2：运行测试验证失败**

运行：`flutter test test/features/profile/profile_sub_pages_test.dart`
预期：FAIL，报错 `Expected: exactly one matching candidate ... but found none`（找不到「GitHub 代理」）。

- [ ] **步骤 3：实现单元格 + 弹窗**

修改 `lib/features/profile/screens/profile_sub_pages.dart`：

**a)** 在类内新增 `_openGithubProxyPicker` 方法（放在 `_openLinePicker` 之后）：

```dart
/// 弹出 GitHub 代理选择弹窗；选中后立即生效并持久化。
void _openGithubProxyPicker(BuildContext context) {
  final settingsProvider = context.read<SettingsProvider>();
  showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) => _GithubProxyPickerSheet(
      settingsProvider: settingsProvider,
    ),
  );
}
```

**b)** 在 build 的 `cells` 列表中，「当前版本」ListTile **上方**插入一行（放在「清除缓存」之后、「当前版本」之前）：

```dart
ListTile(
  leading: const Icon(Icons.public),
  title: const Text('GitHub 代理'),
  subtitle: Text(_githubProxyLabel(githubProxy)),
  trailing: const Icon(Icons.chevron_right),
  onTap: () => _openGithubProxyPicker(context),
),
```

**c)** 在 `build` 开头读取 `githubProxy`（紧跟其它 watch/select）并加入依赖，使 subtitle 能随选择刷新：

```dart
final githubProxy = context.select<SettingsProvider, String>(
  (s) => s.githubProxy,
);
```

**d)** 新增 `_GithubProxyPickerSheet` 与 `_githubProxyLabel`、`_githubProxyOptions`（放在文件底部，`_LinePickerSheet` 之后）：

```dart
const _githubProxyOptions = [
  'https://hub.luxcis.top/',
  'https://gh-proxy.com/',
];

/// GitHub 代理对应的展示文案。
String _githubProxyLabel(String proxy) {
  if (proxy.isEmpty) return '不使用代理';
  return proxy
      .replaceFirst(RegExp(r'^https?://'), '')
      .replaceFirst(RegExp(r'/$'), '');
}

/// GitHub 代理选择底部弹窗：不使用 + 内置选项 + 自定义。
class _GithubProxyPickerSheet extends StatelessWidget {
  const _GithubProxyPickerSheet({required this.settingsProvider});

  final SettingsProvider settingsProvider;

  Future<void> _selectCustom(BuildContext sheetContext) async {
    final controller = TextEditingController(
      text: settingsProvider.githubProxy,
    );
    final value = await showDialog<String>(
      context: sheetContext,
      builder: (dialogContext) => AlertDialog(
        title: const Text('自定义 GitHub 代理'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.url,
          hintText: 'https://example.com/mirror/',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null) return;
    final normalized = normalizeGithubProxy(value.trim());
    if (normalized.isEmpty) return;
    await settingsProvider.setGithubProxy(normalized);
    if (sheetContext.mounted) Navigator.pop(sheetContext);
  }

  @override
  Widget build(BuildContext context) {
    final current = settingsProvider.githubProxy;
    final isCustom =
        current.isNotEmpty && !_githubProxyOptions.contains(current);
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'GitHub 代理',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          ListTile(
            title: const Text('不使用代理'),
            trailing: current.isEmpty ? const Icon(Icons.check) : null,
            onTap: () {
              settingsProvider.setGithubProxy('');
              Navigator.pop(context);
            },
          ),
          for (final proxy in _githubProxyOptions)
            ListTile(
              title: Text(proxy),
              trailing: current == proxy ? const Icon(Icons.check) : null,
              onTap: () {
                settingsProvider.setGithubProxy(proxy);
                Navigator.pop(context);
              },
            ),
          ListTile(
            title: const Text('自定义…'),
            trailing: isCustom ? const Icon(Icons.check) : null,
            onTap: () => _selectCustom(context),
          ),
        ],
      ),
    );
  }
}
```

**e)** 确认 `profile_sub_pages.dart` 已导入 `SettingsProvider`（第 13 行已有 `import 'package:jade/core/providers/settings_provider.dart';`）。

- [ ] **步骤 4：运行测试验证通过**

运行：`flutter test test/features/profile/profile_sub_pages_test.dart`
预期：PASS（新增 2 个用例 + 既有用例全部通过）。

- [ ] **步骤 5：Commit**

```bash
git add lib/features/profile/screens/profile_sub_pages.dart test/features/profile/profile_sub_pages_test.dart
git commit -m "feat(settings): add GitHub proxy cell with bottom-sheet picker"
```

---

### 任务 4：更新流程注入代理（检查更新 + 下载）

**文件：**
- 修改：`lib/features/profile/screens/profile_sub_pages.dart`

- [ ] **步骤 1：修改 `_checkForUpdate` 注入代理**

定位到 `_checkForUpdate`（当前构造 `_checker.check()`）。把它改为从 `SettingsProvider` 读取代理并构造 `UpdateChecker`：

```dart
Future<void> _checkForUpdate() async {
  if (_checkingUpdate) return;
  setState(() => _checkingUpdate = true);
  try {
    final proxy = context.read<SettingsProvider>().githubProxy;
    final checker = UpdateChecker(
      currentVersion: _appVersion == '…' ? '0.0.0' : _appVersion,
      proxy: proxy,
    );
    final result = await checker.check();
    if (!mounted) return;
    if (!result.hasUpdate) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已是最新版本')));
      return;
    }
    await _showUpdateDialog(result);
  } catch (_) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('检查更新失败，请稍后重试')));
  } finally {
    if (mounted) setState(() => _checkingUpdate = false);
  }
}
```

- [ ] **步骤 2：移除不再需要的 `_updateChecker` 字段与 `_checker` getter**

删除类中下列两处（它们只被 `_checkForUpdate` 使用，现改为内联构造）：

```dart
UpdateChecker? _updateChecker;
```

```dart
/// 延迟创建更新检查器，确保使用加载完成的版本号。
UpdateChecker get _checker => _updateChecker ??=
    UpdateChecker(currentVersion: _appVersion == '…' ? '0.0.0' : _appVersion);
```

并清理 `_loadAppVersion` 中 `setState` 内的 `_updateChecker = null;`（行首位置），保留 `_appVersion = version;`：

```dart
setState(() {
  _appVersion = version;
});
```

- [ ] **步骤 3：修改 `_downloadAndInstall` 注入代理**

定位到 `_downloadAndInstall`（当前 `final installer = UpdateInstaller();`）。改为：

```dart
Future<void> _downloadAndInstall(
  UpdateCheckResult result,
  void Function(int received, int total) onProgress,
) async {
  final deviceInfo = await DeviceInfoPlugin().androidInfo;
  final proxy = context.read<SettingsProvider>().githubProxy;
  final installer = UpdateInstaller(proxy: proxy);
  final asset = installer.pickAsset(
    result.release,
    deviceInfo.supportedAbis,
  );
  final path = await installer.download(asset, onProgress: onProgress);
  if (!mounted) return;
  final opened = await OpenFilex.open(path);
  if (!mounted) return;
  if (opened.type != ResultType.done) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('安装包已下载，请在通知栏/文件管理器中安装')),
    );
  }
}
```

- [ ] **步骤 4：运行分析验证无编译错误**

运行：`flutter analyze lib/features/profile/screens/profile_sub_pages.dart lib/features/profile/services/update_service.dart lib/core/providers/settings_provider.dart`
预期：no issues/found（无 error）。若报 `unused`，确认 `_updateChecker`/`_checker` 已删净。

- [ ] **步骤 5：运行相关测试**

运行：`flutter test test/core/providers/settings_provider_test.dart test/features/profile/update_service_test.dart test/features/profile/profile_sub_pages_test.dart`
预期：全部 PASS。

- [ ] **步骤 6：Commit**

```bash
git add lib/features/profile/screens/profile_sub_pages.dart
git commit -m "feat(settings): wire githubProxy into update check and download"
```

---
