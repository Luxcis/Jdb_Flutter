# 设置页「检查更新」功能实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 在设置页「当前版本」行右侧添加「检查更新」按钮，查询 GitHub `Luxcis/Jdb_Flutter` latest release，有新版则弹窗展示更新日志并支持下载安装 APK。

**架构：** 新增 `UpdateChecker`（查询 release + 版本比较）与 `UpdateInstaller`（ABI 匹配 + 下载 + 调起系统安装器）两个可注入服务，UI 改动集中在 `ProfileSettingsPage`。「检查更新」按钮在 ListTile trailing，弹窗展示版本号 + 更新日志 + 下载进度。

**技术栈：** Flutter / Dart 3.8、`http`（GitHub API + APK 下载）、`open_filex`（系统安装器）、`pub_semver`（语义化版本比较，已在传递依赖中）、`device_info_plus`（ABI 检测，已有）、`path_provider`（下载目录，已有）。

**设计文档：** `docs/superpowers/specs/2026-08-18-settings-check-update-design.md`

---

## 文件结构

| 文件 | 职责 |
|------|------|
| `lib/features/profile/services/update_service.dart` | **新建**：`GitHubRelease`、`GitHubReleaseAsset`、`UpdateCheckResult` 模型 + `UpdateChecker` + `UpdateInstaller` |
| `lib/features/profile/screens/profile_sub_pages.dart` | **修改**：`ProfileSettingsPage` 增加「检查更新」按钮、更新弹窗、下载进度逻辑 |
| `android/app/src/main/AndroidManifest.xml` | **修改**：添加 `REQUEST_INSTALL_PACKAGES` 权限 |
| `pubspec.yaml` | **修改**：新增 `http`、`open_filex` 依赖 |
| `test/features/profile/update_service_test.dart` | **新建**：`UpdateChecker` / `UpdateInstaller` 单元测试 |

---

### 任务 1：新增依赖

**文件：**
- 修改：`pubspec.yaml`
- 修改：`pubspec.lock`（由 `flutter pub get` 自动更新）

- [ ] **步骤 1：添加依赖**

运行：

```bash
flutter pub add http open_filex
```

预期：`pubspec.yaml` dependencies 出现 `http: ^1.2.0` 与 `open_filex: ^4.7.0`，`pub get` 成功，无版本冲突。

> 说明：`pub_semver` 已在传递依赖中（pubspec.lock line 819），直接用无需显式添加；如需显式声明再运行 `flutter pub add pub_semver`。

- [ ] **步骤 2：验证依赖解析**

运行：`flutter pub deps | grep -E "http|open_filex|pub_semver"`
预期：三行均出现，无错误。

- [ ] **步骤 3：Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "chore: add http and open_filex dependencies"
```

---

### 任务 2：UpdateService 模型与 UpdateChecker

**文件：**
- 创建：`lib/features/profile/services/update_service.dart`
- 测试：`test/features/profile/update_service_test.dart`

- [ ] **步骤 1：编写失败的测试**

创建 `test/features/profile/update_service_test.dart`：

```dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jade/features/profile/services/update_service.dart';

/// 构造一个 fake http.Client，返回固定 release JSON。
http.Client _fakeClient(String body, {int status = 200}) {
  return MockClient((request) async {
    expect(request.url.toString(),
        'https://api.github.com/repos/Luxcis/Jdb_Flutter/releases/latest');
    if (status != 200) {
      return http.Response('error', status);
    }
    return http.Response(body, 200,
        headers: {'content-type': 'application/json'});
  });
}

const _releaseJson = '''
{
  "tag_name": "v0.10.0",
  "name": "v0.10.0",
  "body": "## What's Changed\\n* feat: new stuff",
  "assets": [
    {
      "name": "app-arm64-v8a-release.apk",
      "size": 36009801,
      "browser_download_url":
          "https://github.com/Luxcis/Jdb_Flutter/releases/download/v0.10.0/app-arm64-v8a-release.apk"
    },
    {
      "name": "app-armeabi-v7a-release.apk",
      "size": 33092905,
      "browser_download_url":
          "https://github.com/Luxcis/Jdb_Flutter/releases/download/v0.10.0/app-armeabi-v7a-release.apk"
    },
    {
      "name": "app-x86_64-release.apk",
      "size": 40898231,
      "browser_download_url":
          "https://github.com/Luxcis/Jdb_Flutter/releases/download/v0.10.0/app-x86_64-release.apk"
    }
  ]
}
''';

void main() {
  group('GitHubRelease JSON 解析', () {
    test('解析 tagName/body/assets', () {
      final release = GitHubRelease.fromJson(
        jsonDecode(_releaseJson) as Map<String, dynamic>,
      );

      expect(release.tagName, 'v0.10.0');
      expect(release.body, contains('feat: new stuff'));
      expect(release.assets, hasLength(3));
      expect(release.assets.first.name, 'app-arm64-v8a-release.apk');
      expect(release.assets.first.size, 36009801);
      expect(
        release.assets.first.downloadUrl,
        contains('app-arm64-v8a-release.apk'),
      );
    });
  });

  group('UpdateChecker', () {
    test('远端版本更高时 hasUpdate=true', () async {
      final checker = UpdateChecker(
        client: _fakeClient(_releaseJson),
        currentVersion: '0.9.2',
      );

      final result = await checker.check();

      expect(result.hasUpdate, isTrue);
      expect(result.latestVersion, '0.10.0');
      expect(result.release.tagName, 'v0.10.0');
    });

    test('版本相同或更低时 hasUpdate=false', () async {
      final sameJson = _releaseJson.replaceFirst('v0.10.0', 'v0.9.2');
      final checker = UpdateChecker(
        client: _fakeClient(sameJson),
        currentVersion: '0.9.2',
      );

      final result = await checker.check();

      expect(result.hasUpdate, isFalse);
      expect(result.latestVersion, '0.9.2');
    });

    test('HTTP 非 200 抛出异常', () async {
      final checker = UpdateChecker(
        client: _fakeClient('', status: 500),
        currentVersion: '0.9.2',
      );

      expect(checker.check(), throwsException);
    });

    test('tag 无法解析时不视为更新', () async {
      final badJson = _releaseJson.replaceFirst('v0.10.0', 'not-a-version');
      final checker = UpdateChecker(
        client: _fakeClient(badJson),
        currentVersion: '0.9.2',
      );

      final result = await checker.check();

      expect(result.hasUpdate, isFalse);
    });
  });
}
```

- [ ] **步骤 2：运行测试验证失败**

运行：`flutter test test/features/profile/update_service_test.dart`
预期：编译失败，报错 `Error: Method not found: 'GitHubRelease.fromJson'` 或类似 "not defined"。

- [ ] **步骤 3：编写实现**

创建 `lib/features/profile/services/update_service.dart`：

```dart
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:pub_semver/pub_semver.dart';

/// GitHub release 资产（APK）。
class GitHubReleaseAsset {
  const GitHubReleaseAsset({
    required this.name,
    required this.size,
    required this.downloadUrl,
  });

  factory GitHubReleaseAsset.fromJson(Map<String, dynamic> json) {
    return GitHubReleaseAsset(
      name: json['name'] as String? ?? '',
      size: (json['size'] as num?)?.toInt() ?? 0,
      downloadUrl: json['browser_download_url'] as String? ?? '',
    );
  }

  final String name;
  final int size;
  final String downloadUrl;
}

/// GitHub latest release 解析结果。
class GitHubRelease {
  const GitHubRelease({
    required this.tagName,
    required this.body,
    required this.assets,
  });

  factory GitHubRelease.fromJson(Map<String, dynamic> json) {
    return GitHubRelease(
      tagName: json['tag_name'] as String? ?? '',
      body: json['body'] as String? ?? '',
      assets: [
        for (final asset in json['assets'] as List<dynamic>? ?? const [])
          if (asset is Map<String, dynamic>)
            GitHubReleaseAsset.fromJson(asset),
      ],
    );
  }

  final String tagName;
  final String body;
  final List<GitHubReleaseAsset> assets;
}

/// 版本检查结果。
class UpdateCheckResult {
  const UpdateCheckResult({
    required this.release,
    required this.hasUpdate,
    required this.latestVersion,
  });

  final GitHubRelease release;
  final bool hasUpdate;
  final String latestVersion;
}

/// 查询 GitHub latest release 并与本地版本比较。
class UpdateChecker {
  UpdateChecker({
    required this.currentVersion,
    http.Client? client,
    this.repo = 'Luxcis/Jdb_Flutter',
  }) : _client = client ?? http.Client();

  final String currentVersion;
  final String repo;
  final http.Client _client;

  static const _apiUrl =
      'https://api.github.com/repos/Luxcis/Jdb_Flutter/releases/latest';

  /// 请求 latest release 并判断是否有新版本。
  Future<UpdateCheckResult> check() async {
    final response = await _client.get(Uri.parse(_apiUrl));
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

  /// 语义化版本比较：latest > current 返回 true；解析失败返回 false。
  bool _isNewer(String latest, String current) {
    try {
      return Version.parse(latest) > Version.parse(current);
    } on FormatException {
      return false;
    }
  }
}
```

> 说明：`repo` 字段预留用于测试/未来仓库变更，但 `_apiUrl` 当前硬编码 `Luxcis/Jdb_Flutter`（设计文档指定）；若测试需要不同仓库可后续调整。`_apiUrl` 与 `repo` 冗余——按 YAGNI 去掉 `repo` 字段，保持 `_apiUrl` 常量即可（见步骤 5 修正）。

- [ ] **步骤 4：运行测试验证通过**

运行：`flutter test test/features/profile/update_service_test.dart`
预期：4 个测试全部 PASS。

- [ ] **步骤 5：移除冗余 repo 字段（YAGNI）**

修改 `update_service.dart`：删除 `repo` 构造参数与 `final String repo;` 字段，保留 `_apiUrl` 常量。再运行一次测试确认仍通过。

- [ ] **步骤 6：Commit**

```bash
git add lib/features/profile/services/update_service.dart test/features/profile/update_service_test.dart
git commit -m "feat(profile): add GitHub update checker with version compare"
```

---

### 任务 3：UpdateInstaller（ABI 匹配 + 下载）

**文件：**
- 修改：`lib/features/profile/services/update_service.dart`
- 测试：`test/features/profile/update_service_test.dart`

- [ ] **步骤 1：编写失败的测试**

在 `test/features/profile/update_service_test.dart` 追加：

```dart
  group('UpdateInstaller.pickAsset', () {
    const abis = ['arm64-v8a', 'armeabi-v7a', 'x86_64'];

    GitHubRelease releaseWith(List<String> names) => GitHubRelease(
          tagName: 'v0.10.0',
          body: '',
          assets: [
            for (final name in names)
              GitHubReleaseAsset(
                name: name,
                size: 100,
                downloadUrl: 'https://example.com/$name',
              ),
          ],
        );

    test('按 supportedAbis 顺序匹配资产', () {
      final release = releaseWith([
        'app-armeabi-v7a-release.apk',
        'app-x86_64-release.apk',
        'app-arm64-v8a-release.apk',
      ]);
      final installer = UpdateInstaller();

      final asset = installer.pickAsset(release, abis);

      expect(asset.name, contains('arm64-v8a'));
    });

    test('无匹配时回退第一个资产', () {
      final release = releaseWith(['app-unknown-abi-release.apk']);
      final installer = UpdateInstaller();

      final asset = installer.pickAsset(release, abis);

      expect(asset.name, 'app-unknown-abi-release.apk');
    });
  });

  group('UpdateInstaller.download', () {
    test('下载文件并报告进度', () async {
      final installer = UpdateInstaller(
        client: MockClient((request) async {
          return http.Response.bytes(
            List<int>.filled(1024, 7),
            200,
            headers: {'content-length': '1024'},
          );
        }),
        downloadDir: Directory.systemTemp.createTempSync('update_test'),
      );
      final progress = <int>[];
      final asset = const GitHubReleaseAsset(
        name: 'app-arm64-v8a-release.apk',
        size: 1024,
        downloadUrl: 'https://example.com/app.apk',
      );

      final path = await installer.download(
        asset,
        onProgress: (received, total) => progress.add(received),
      );

      expect(await File(path).length(), 1024);
      expect(progress.last, 1024);
    });
  });
```

并在文件头部补充 imports：

```dart
import 'dart:io';

import 'package:http/testing.dart';
```

- [ ] **步骤 2：运行测试验证失败**

运行：`flutter test test/features/profile/update_service_test.dart`
预期：编译失败，`UpdateInstaller` 未定义。

- [ ] **步骤 3：编写实现**

在 `update_service.dart` 追加：

```dart
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// 下载 APK 并调起系统安装器。
class UpdateInstaller {
  UpdateInstaller({http.Client? client, Directory? downloadDir})
      : _client = client ?? http.Client(),
        _downloadDir = downloadDir;

  final http.Client _client;
  final Directory? _downloadDir;

  /// 按 ABI 优先级从 release 资产中挑选 APK。
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

  /// 流式下载 APK 到应用文档目录，返回本地文件路径。
  Future<String> download(
    GitHubReleaseAsset asset, {
    void Function(int received, int total)? onProgress,
  }) async {
    final dir = _downloadDir ?? await getApplicationDocumentsDirectory();
    final targetDir = Directory('${dir.path}/update');
    await targetDir.create(recursive: true);

    final request = http.Request('GET', Uri.parse(asset.downloadUrl));
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
预期：全部测试 PASS（含任务 2 的 4 个）。

- [ ] **步骤 5：Commit**

```bash
git add lib/features/profile/services/update_service.dart test/features/profile/update_service_test.dart
git commit -m "feat(profile): add APK download with ABI matching"
```

---

### 任务 4：Android 安装权限

**文件：**
- 修改：`android/app/src/main/AndroidManifest.xml:50`

- [ ] **步骤 1：添加权限声明**

在 `AndroidManifest.xml` 末尾（`</manifest>` 前）追加：

```xml
    <!--安装未知来源 APK（Android 8+ 调起系统安装器需要）-->
    <uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES" />
```

- [ ] **步骤 2：验证清单合法**

运行：`flutter build apk --debug`（或 `./gradlew :app:processDebugMainManifest`）
预期：构建成功，无 manifest 合并错误。

- [ ] **步骤 3：Commit**

```bash
git add android/app/src/main/AndroidManifest.xml
git commit -m "feat(android): request install packages permission for APK update"
```

---

### 任务 5：设置页 UI（检查按钮 + 更新弹窗）

**文件：**
- 修改：`lib/features/profile/screens/profile_sub_pages.dart`

- [ ] **步骤 1：接入 UpdateChecker 状态与检查逻辑**

在 `_ProfileSettingsPageState` 中新增：

```dart
// 在类字段区追加
late final UpdateChecker _updateChecker;
var _checkingUpdate = false;

// initState 中追加
_updateChecker = UpdateChecker(currentVersion: _appVersion);
```

注意：`_appVersion` 初始为 `'…'`，`_loadAppVersion()` 完成后才有效——所以 `_updateChecker` 不能在 initState 立即创建。改为：

```dart
UpdateChecker? _updateChecker;

UpdateChecker get _checker => _updateChecker ??=
    UpdateChecker(currentVersion: _appVersion == '…' ? '0.0.0' : _appVersion);
```

并在 `_loadAppVersion()` 的 `setState` 后重置 `_updateChecker = null;`，确保用最新版本号重建。

- [ ] **步骤 2：实现检查与弹窗逻辑**

新增方法：

```dart
Future<void> _checkForUpdate() async {
  if (_checkingUpdate) return;
  setState(() => _checkingUpdate = true);
  try {
    final result = await _checker.check();
    if (!mounted) return;
    if (!result.hasUpdate) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已是最新版本')),
      );
      return;
    }
    await _showUpdateDialog(result);
  } catch (_) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('检查更新失败，请稍后重试')),
    );
  } finally {
    if (mounted) setState(() => _checkingUpdate = false);
  }
}
```

- [ ] **步骤 3：实现更新弹窗（版本号 + 日志 + 进度 + 下载安装）**

新增方法：

```dart
Future<void> _showUpdateDialog(UpdateCheckResult result) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _UpdateDialog(
      result: result,
      install: _downloadAndInstall,
    ),
  );
}

/// 下载选中 ABI 的 APK 并调起系统安装器；进度通过 onProgress 上报。
Future<void> _downloadAndInstall(
  UpdateCheckResult result,
  void Function(int received, int total) onProgress,
) async {
  final deviceInfo = await DeviceInfoPlugin().androidInfo;
  final installer = UpdateInstaller();
  final asset = installer.pickAsset(
    result.release,
    deviceInfo.supportedAbis,
  );
  final path = await installer.download(asset, onProgress: onProgress);
  if (!mounted) return;
  final opened = await OpenFilex.open(path);
  if (opened.type != ResultType.done) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('安装包已下载，请在通知栏/文件管理器中安装')),
    );
  }
}
```

- [ ] **步骤 4：新建 _UpdateDialog 弹窗组件**

在文件末尾新增私有组件（进度回调驱动进度条；下载完成/失败通过返回值区分）：

```dart
class _UpdateDialog extends StatefulWidget {
  const _UpdateDialog({required this.result, required this.install});

  final UpdateCheckResult result;
  final Future<void> Function(
    UpdateCheckResult result,
    void Function(int received, int total) onProgress,
  ) install;

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  bool _downloading = false;
  double _progress = 0;
  bool _finished = false;
  String? _error;

  Future<void> _startDownload() async {
    setState(() {
      _downloading = true;
      _error = null;
    });
    try {
      await widget.install(widget.result, (received, total) {
        if (total > 0 && mounted) {
          setState(() => _progress = received / total);
        }
      });
      if (!mounted) return;
      setState(() => _finished = true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _downloading = false;
          _error = '下载失败，请重试';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    return AlertDialog(
      title: Text('发现新版本 ${result.latestVersion}'),
      content: SizedBox(
        width: double.maxFinite,
        child: _downloading
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LinearProgressIndicator(value: _progress),
                  const SizedBox(height: 12),
                  Text('正在下载更新… ${(_progress * 100).toStringAsFixed(0)}%'),
                ],
              )
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '当前版本：',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      result.release.body.isEmpty ? '暂无更新日志' : result.release.body,
                    ),
                  ],
                ),
              ),
      ),
      actions: [
        if (!_downloading && !_finished)
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('稍后再说'),
          ),
        if (_error != null)
          Text(
            '$_error',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        if (_downloading)
          const TextButton(
            onPressed: null,
            child: Text('下载中…'),
          )
        else
          TextButton(
            onPressed: _finished
                ? () => Navigator.pop(context)
                : _startDownload,
            child: Text(_finished ? '完成' : '立即更新'),
          ),
      ],
    );
  }
}
```

- [ ] **步骤 5：修改「当前版本」ListTile 添加按钮**

将第 493-498 行的 ListTile 改为：

```dart
      ListTile(
        leading: const Icon(Icons.info_outline),
        title: const Text('当前版本'),
        subtitle: Text(_appVersion),
        trailing: TextButton(
          onPressed: _checkingUpdate ? null : _checkForUpdate,
          child: _checkingUpdate
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('检查更新'),
        ),
        onTap: _onVersionTap,
      ),
```

- [ ] **步骤 6：补充 imports 并运行静态分析**

文件头部新增：

```dart
import 'package:device_info_plus/device_info_plus.dart';
import 'package:jade/features/profile/services/update_service.dart';
import 'package:open_filex/open_filex.dart';
```

运行：`flutter analyze`
预期：无 error；若有 lint（如 unused import、line length）按提示修复。

- [ ] **步骤 7：运行全部测试**

运行：`flutter test`
预期：全部 PASS（含新增 update_service 测试）。

- [ ] **步骤 8：Commit**

```bash
git add lib/features/profile/screens/profile_sub_pages.dart
git commit -m "feat(settings): add check-update button and update dialog"
```

---

### 任务 6：手动验证（构建 + 真机/模拟器冒烟）

**文件：** 无（仅验证）

- [ ] **步骤 1：构建 debug APK**

运行：`flutter build apk --debug`
预期：构建成功，产物在 `build/app/outputs/flutter-apk/app-debug.apk`。

- [ ] **步骤 2：安装并冒烟（如有设备）**

运行：`flutter run`（或 `adb install`）
预期：
1. 设置页「当前版本」右侧出现「检查更新」按钮。
2. 点击后（当前 0.9.2 与最新 v0.9.2 相同）SnackBar「已是最新版本」。
3. 若 GitHub 有新 release，弹窗展示版本号与更新日志，点「立即更新」下载并调起系统安装器。

> 若当前无新版本可测，可用 `UpdateChecker(currentVersion: '0.9.0')` 临时验证弹窗与下载链路，验证完还原。

- [ ] **步骤 3：Commit（如步骤 2 有代码还原）**

```bash
git add -A
git commit -m "chore: revert temporary manual verification changes"
```

---

## 自检

**规格覆盖度：**
- ✅ 检查按钮在「当前版本」右侧（任务 5 步骤 5）
- ✅ 查询 GitHub latest release（任务 2）
- ✅ 版本比较（任务 2 `_isNewer` + pub_semver）
- ✅ 更新弹窗 + 更新日志（任务 5 `_UpdateDialog`）
- ✅ 自动下载 + 系统安装器（任务 3 download + 任务 5 OpenFilex.open）
- ✅ 可稍后再说（任务 5 `_UpdateDialog`「稍后再说」按钮）
- ✅ Android 权限（任务 4）
- ✅ 错误处理：网络失败/下载失败/tag 解析失败（任务 2/3/5）
- ✅ 单元测试（任务 2/3）

**占位符扫描：** 无 TODO/待定；每个代码步骤含完整代码。

**类型一致性：** `UpdateCheckResult`（release/hasUpdate/latestVersion）、`GitHubReleaseAsset`（name/size/downloadUrl）、`UpdateInstaller.pickAsset/download`、`UpdateChecker.check` 在任务 2/3/5 中签名一致；`_UpdateDialog` 构造参数 `result`/`onInstall` 在任务 5 步骤 3/4 一致。
