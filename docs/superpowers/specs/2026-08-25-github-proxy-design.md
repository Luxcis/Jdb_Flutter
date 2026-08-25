# 设置页「GitHub 代理」功能设计

日期：2026-08-25
状态：已批准（用户逐节确认）

## 1. 背景与目标

`ProfileSettingsPage`（lib/features/profile/screens/profile_sub_pages.dart）的「当前版本」ListTile 下方存在「检查更新」流程，依赖 GitHub 直连（`https://api.github.com/.../releases/latest` 与 `https://github.com/.../releases/download/...`）。国内访问 GitHub 时常受阻，本次在「当前版本」**上方**新增 GitHub 代理设置：

1. 下拉框选择代理：`https://hub.luxcis.top/`、`https://gh-proxy.com/`、自定义地址。
2. 使用方式：把代理地址拼接到 GitHub 完整地址之前。
   - 检查更新：`<proxy>https://api.github.com/repos/Luxcis/Jdb_Flutter/releases/latest`
   - 下载 APK：`<proxy>https://github.com/Luxcis/Jdb_Flutter/releases/download/v0.11.0/app-arm64-v8a-release.apk`
3. 默认「不使用代理」（直连），向后兼容。

## 2. 需求决策（已确认）

| 决策点 | 结论 |
|--------|------|
| 默认态 | **不使用代理**（空串）。用户手动切换，保留现有直连行为 |
| 下拉交互形式 | **底部弹窗（BottomSheet）**，与「线路选择」`_openLinePicker` 风格一致 |
| 可选项 | 不使用代理 / `https://hub.luxcis.top/` / `https://gh-proxy.com/` / 自定义… |
| 自定义输入 | 选「自定义…」时弹 `AlertDialog` 输入完整代理前缀；仅做非空校验 |
| 状态管理 | **方案 A**：代理值放 `SettingsProvider`（ChangeNotifier + SharedPreferences），更新流程注入 |
| 代理作用范围 | 整个更新流程（检查更新 API + APK 下载）。项目内仅 `update_service.dart` 引用 GitHub URL，无其他处需代理 |
| URL 拼接规则 | `proxy + fullUrl`；代理为空则原样返回 |

## 3. 数据层（状态 + 持久化）

### 3.1 `lib/core/storage/storage_keys.dart`

新增常量：

```dart
static const String githubProxy = 'key_github_proxy';
```

### 3.2 `lib/core/providers/settings_provider.dart`

沿用现有 ChangeNotifier + SharedPreferences 模式，新增：

- 字段：`String _githubProxy`，默认 `''`（空串 = 不使用代理）。
- getter：`String get githubProxy => _githubProxy;`
- `create()` 读取：`p._githubProxy = prefs.getString(StorageKeys.githubProxy) ?? '';`
- `Future<void> setGithubProxy(String value)`：`normalizeGithubProxy` 规范化（见 §4）→ 赋值 → `_prefs.setString(StorageKeys.githubProxy, normalized)` → `notifyListeners()`。

取值约定：空串 = 不使用代理；非空 = 完整代理前缀（以 `/` 结尾，如 `https://hub.luxcis.top/`）。

> 规范化在 `setGithubProxy` 数据边界统一执行（见 §7 决策「自定义代理未以 `/` 结尾时保存自动补齐」），UI 调用点无需再各自 normalize。

## 4. URL 拼接（核心工具）

在 `lib/core/utils/github_proxy.dart`（核心层，`SettingsProvider` 与服务层均可复用）定义纯函数：

```dart
/// 代理前缀非空时拼接到完整 URL 前，否则原样返回。
String buildGitHubUrl(String proxy, String fullUrl) =>
    proxy.isEmpty ? fullUrl : '$proxy$fullUrl';

/// 规范化代理前缀：空串保留；非空且不以 / 结尾时自动补齐 /。
/// 保证 buildGitHubUrl 始终可按 proxy + fullUrl 直接拼接。
String normalizeGithubProxy(String proxy) =>
    proxy.isEmpty || proxy.endsWith('/') ? proxy : '$proxy/';
```

> 两个函数放在核心层（而非 feature 层），因为 `SettingsProvider`（core 层）需要在 `setGithubProxy` 数据边界统一调用 `normalizeGithubProxy`（见 §7），同时 `UpdateChecker`/`UpdateInstaller`（feature 层）也复用同一套拼接规则。`update_service.dart` 不再直接定义这两个函数，改为 import 本文件。

> `normalizeGithubProxy` 在 `setGithubProxy` 内统一调用（§7 决策），内置选项本身已以 `/` 结尾，仅自定义地址需要补齐。UI 层的调用点不再各自 normalize。

## 5. 更新服务接入代理

### 5.1 `UpdateChecker`

- 构造函数新增 `String proxy`（默认 `''`）。
- `_apiUrl` 保持常量，请求时拼接：
  ```dart
  Uri _releaseUrl() => Uri.parse(buildGitHubUrl(proxy, _apiUrl));
  ```
- 即：代理为空 → 原 `https://api.github.com/.../releases/latest`；非空 → `https://hub.luxcis.top/https://api.github.com/.../releases/latest`。

### 5.2 `UpdateInstaller`

- 构造函数新增 `String proxy`（默认 `''`）。
- `download()` 里构造 `http.Request` 前拼接：
  ```dart
  final request = http.Request(
    'GET',
    Uri.parse(buildGitHubUrl(proxy, asset.downloadUrl)),
  );
  ```
- 即：代理为空 → 原 `https://github.com/.../app-arm64-v8a-release.apk`；非空 → `https://hub.luxcis.top/https://github.com/.../app-arm64-v8a-release.apk`。

## 6. UI（设置页顶部新增单元格）

在 `profile_sub_pages.dart` 的「当前版本」ListTile **上方**插入一个 ListTile：

- leading：`Icons.public`
- title：`GitHub 代理`
- subtitle：显示当前选中项文案
  - 不使用代理 → `不使用代理`
  - `https://hub.luxcis.top/` → `hub.luxcis.top`
  - `https://gh-proxy.com/` → `gh-proxy.com`
  - 自定义 → 显示自定义地址（`_hostOf` 或原文）
- trailing：`Icons.chevron_right`

点击后调用 `_openGithubProxyPicker(context)`，弹出 **BottomSheet**（复用 `_openLinePicker` 结构），单选行：

1. 不使用代理（默认，选中态打勾）
2. `https://hub.luxcis.top/`
3. `https://gh-proxy.com/`
4. 自定义…

选中即 `context.read<SettingsProvider>().setGithubProxy(...)` 持久化。选「自定义…」时弹 `AlertDialog` 输入完整代理前缀，输入非空后保存；取消则不生效。

## 7. 错误处理与边界

| 场景 | 处理 |
|------|------|
| 自定义地址为空 | 不保存（AlertDialog 内提示「请输入代理地址」） |
| 代理不可用 / 请求失败 | 复用现有「检查更新失败，请稍后重试」snackbar，不在代理设置层新增错误处理（YAGNI） |
| 自定义代理未以 `/` 结尾 | **保存时自动补齐 `/`**：`setGithubProxy` 内统一 `normalizeGithubProxy`，若非空且不以 `/` 结尾则追加 `/`。这样 `buildGitHubUrl` 始终可按 `proxy + fullUrl` 直接拼接，无需针对内置/自定义分叉 |

## 8. 测试

### 8.1 `test/core/providers/settings_provider_test.dart`（追加）

1. `githubProxy` 默认空串。
2. 恢复已保存的代理值。
3. `setGithubProxy` 后持久化并通知监听者。

### 8.2 `test/features/profile/update_service_test.dart`（追加）

1. `buildGitHubUrl`：空代理原样返回；非空代理 prepend。
2. `normalizeGithubProxy`：空串/已以 `/` 结尾保持不变；未以 `/` 结尾自动补齐 `/`。
3. `UpdateChecker` 注入 proxy → `MockClient` 断言请求 URL 已拼接代理前缀（代理为空时仍为原 URL）。
4. `UpdateInstaller.download` 注入 proxy → `MockClient` 断言请求 `downloadUrl` 已拼接代理前缀。

## 9. 改动文件清单

- `lib/core/storage/storage_keys.dart`：新增 `githubProxy` 常量。
- `lib/core/providers/settings_provider.dart`：新增 `githubProxy` 字段/getter/读写（`setGithubProxy` 内统一规范化）。
- `lib/core/utils/github_proxy.dart`：新增 `buildGitHubUrl` / `normalizeGithubProxy` 纯函数（核心层）。
- `lib/features/profile/services/update_service.dart`：`UpdateChecker`/`UpdateInstaller` 增加 `proxy` 参数并拼接（改 import 核心层函数）。
- `lib/features/profile/screens/profile_sub_pages.dart`：「当前版本」上方插入 `GitHub 代理` ListTile + `_openGithubProxyPicker`（BottomSheet + 自定义 AlertDialog）；更新流程注入 `SettingsProvider.githubProxy`。
- `test/core/providers/settings_provider_test.dart`：追加代理相关用例（含 `setGithubProxy` 规范化）。
- `test/features/profile/update_service_test.dart`：追加代理拼接相关用例。
