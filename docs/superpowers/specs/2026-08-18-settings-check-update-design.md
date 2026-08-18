# 设置页「检查更新」功能设计

日期：2026-08-18
状态：已批准（用户逐节确认）

## 1. 背景与目标

`ProfileSettingsPage`（lib/features/profile/screens/profile_sub_pages.dart）的「当前版本」ListTile 目前仅展示版本号（5 连击隐藏入口）。本次新增：

1. 在「当前版本」行**右侧添加「检查更新」按钮**。
2. 点击后查询 GitHub `Luxcis/Jdb_Flutter` 仓库的 latest release，与本地版本比较。
3. 有新版 → 弹窗展示更新日志 + 版本号，用户点「立即更新」后**自动下载最新 APK 并调起系统安装器**；无新版 → SnackBar 提示「已是最新版本」。

## 2. 需求决策（已确认）

| 决策点 | 结论 |
|--------|------|
| 更新弹窗行为 | **可稍后再说**：弹窗提供「立即更新」与「稍后再说」两个按钮，不强制更新 |
| 下载安装方式 | **open_filex + 系统安装器**：应用内下载 APK 到私有目录，调起系统安装器由用户确认安装（非 ROOT） |
| 版本比较基准 | **应用内版本号 vs GitHub tag**：`package_info_plus.version`（如 `0.9.2`）对比 release `tag_name`（`v0.9.2`，去 `v` 前缀） |
| ABI 匹配 | 按 `supportedAbis` 顺序匹配资产名：`arm64-v8a` → `armeabi-v7a` → `x86_64`，均不匹配则回退第一个资产 |
| 弹窗内容 | 新版本号 + 更新日志（release body）+ 下载进度条；不展示 APK 大小（YAGNI） |
| 检查按钮形态 | ListTile `trailing` 放「检查更新」TextButton；点击版本号区域仍保留原有 5 连击入口 |

## 3. 依赖变更

`pubspec.yaml` dependencies 新增：

```yaml
http: ^1.2.0        # 请求 GitHub API + 下载 APK（流式进度）
open_filex: ^4.7.0  # 调起系统安装器
version: ^3.0.2     # 语义化版本比较
```

> 下载不用 dio：现有 `ApiClient.dio` 带签名/域名切换拦截器，不适合直连 GitHub。

## 4. 新增文件

### 4.1 `lib/features/profile/services/update_service.dart`

对齐现有 `AppVersionService` 模式（可注入、纯逻辑可单测）：

```dart
/// GitHub release 资产（APK）
class GitHubReleaseAsset {
  final String name;
  final String downloadUrl;
  final int size;
}

/// GitHub latest release 解析结果
class GitHubRelease {
  final String tagName;   // 如 v0.9.2
  final String body;      // 更新日志
  final List<GitHubReleaseAsset> assets;
}

/// 版本检查结果
class UpdateCheckResult {
  final GitHubRelease release;
  final bool hasUpdate;
  final String latestVersion; // 去 v 前缀
}
```

- `UpdateChecker`：`Future<UpdateCheckResult> check()` — GET `https://api.github.com/repos/Luxcis/Jdb_Flutter/releases/latest`，`package:version` 比较，`http.Client` 可注入以便测试。
- `UpdateInstaller`：
  - `Future<GitHubReleaseAsset> pickAsset(GitHubRelease release, List<String> supportedAbis)` — ABI 匹配。
  - `Future<String> download(GitHubReleaseAsset asset, {void Function(int received, int total)? onProgress})` — 流式下载到 `getApplicationDocumentsDirectory()/update/app-jade-<version>.apk`，返回本地路径。
  - `Future<bool> install(String path)` — `OpenFilex.open(path, type: 'application/vnd.android.package-archive')`。

### 4.2 设置页改动（profile_sub_pages.dart）

- 「当前版本」ListTile 增加 `trailing: TextButton('检查更新' | loading)`。
- `_checkForUpdate()`：检查中按钮转圈并禁用；完成/失败恢复。
- 有新版本 → `showDialog` 更新弹窗（版本号 + 日志 + 进度）；无 → SnackBar「已是最新版本」。
- 弹窗「立即更新」→ 下载（进度条更新）→ 调起安装器；失败 → 弹窗内提示可重试；关闭弹窗 → 取消下载。
- 下载完成后 SnackBar「已下载，请确认安装」。

## 5. Android 配置

`android/app/src/main/AndroidManifest.xml` 新增权限：

```xml
<!-- 安装未知来源 APK（Android 8+） -->
<uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES" />
```

> 不新增存储权限：APK 下载到应用私有目录（`getApplicationDocumentsDirectory`），无需 `WRITE_EXTERNAL_STORAGE`。

## 6. 错误处理与边界

| 场景 | 处理 |
|------|------|
| 网络失败 / JSON 解析失败 | SnackBar「检查更新失败，请稍后重试」 |
| tag 格式异常无法解析 | 视为无新版本，记录日志 |
| 下载失败 | 弹窗内提示失败 + 「重试」按钮 |
| 下载中关闭弹窗 | 取消下载（关闭 `http.Client`） |
| 调起安装器失败 | SnackBar 提示失败（YAGNI：不提供打开目录回退） |

## 7. 测试

`test/features/profile/update_service_test.dart`（纯 Dart，注入 fake `http.Client`）：

1. 版本比较：`0.9.2 vs v0.9.2`（相等 → 无更新）；`0.9.2 vs v0.10.0`（有更新）；`0.9.2 vs v1.0.0`。
2. ABI 匹配：`arm64-v8a` 优先；无匹配回退第一个资产。
3. JSON 解析：完整 release 响应 → `GitHubRelease` 字段正确。
4. 下载：流式写文件 + 进度回调触发（用临时目录）。
