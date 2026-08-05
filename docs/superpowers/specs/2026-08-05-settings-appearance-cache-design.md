# 设置页清理与外观/缓存功能设计

## 目标

完善设置页（`/profile/settings`）的三项内容：

1. 删除无交互的「默认筛选标签」占位项及其全部代码。
2. 将静态的「外观模式」占位项变为可交互：支持跟随系统 / 浅色 / 深色三态切换，
   立即生效并持久化。
3. 将静态的「清除缓存」占位项变为可交互：显示当前图片缓存占用大小，支持一键
   清除磁盘与内存图片缓存。

## 范围

- 设置页 `ProfileSettingsPage`（`lib/features/profile/screens/profile_sub_pages.dart`）。
- `SettingsProvider` 与 `StorageKeys` 中「默认筛选标签」相关代码清理。
- 新增 core 层缓存服务 `CacheService`，供设置页计算大小与清除缓存。
- `pubspec.yaml` 直接声明 `path_provider`（当前仅为传递依赖）。
- 同步更新相关测试。

不做的事：不实现其他缓存（无数据库/无其他目录）；不清除登录态等安全数据；
不改动 `ThemeProvider` 内部实现（仅连接 UI）；不删除 `lib/features/settings/`
死代码目录（属于独立重构，另行处理）。

## 现状

- 活跃设置页为 `ProfileSettingsPage`，其中「外观模式」「默认筛选标签」「清除缓存」
  三项均为无 onTap 的静态占位。
- `ThemeProvider`（`ChangeNotifier`）已具备三态切换、持久化
  （key `theme-mode-index`）、`MaterialApp.themeMode` 接线，仅缺 UI 入口。
- 图片缓存走 `JdbImageCacheManager.instance`（`flutter_cache_manager`），磁盘目录
  `getTemporaryDirectory()/jdbImageCache`。公开 API 有 `emptyCache()`；无公开
  `getCacheSize()`，大小需遍历目录文件求和。
- 「默认筛选标签」的 `SettingsProvider.defaultFilterTags` 全链路无任何 UI 消费者，
  删除安全。

## 方案

### 1. 删除「默认筛选标签」

- `profile_sub_pages.dart`：删除静态 cell。
- `settings_provider.dart`：删除 `_defaultFilterTags` 字段、getter、
  `setDefaultFilterTags()`、`create()` 中的加载逻辑，及不再使用的 `dart:convert`
  import。
- `storage_keys.dart`：删除 `defaultFilterTags` 常量。
- `profile_sub_pages_test.dart`：删除对应断言。

### 2. 外观模式切换

- 「外观模式」cell 改为可交互 `ListTile`，subtitle 实时显示当前模式中文名
  （跟随系统 / 浅色模式 / 深色模式），通过 `context.watch<ThemeProvider>()` 刷新。
- onTap 弹出 `showModalBottomSheet`：标题「外观模式」，三个单选行
  （跟随系统 / 浅色模式 / 深色模式），当前项尾部 `check` 高亮，样式与
  `_LinePickerSheet` 一致。
- 选中后调用 `context.read<ThemeProvider>().setThemeMode(mode)`：`app.dart`
  已监听 `themeMode` 立即生效，Provider 内部自动持久化。

### 3. 清除缓存

采用「core 层抽象服务 + 页面注入」方案（可测试性优先，widget 测试环境无法
真实访问文件系统）：

- 新建 `lib/core/network/cache_service.dart`：
  - 抽象类 `CacheService`：`Future<int> getCacheSizeBytes()`、
    `Future<void> clearAll()`。
  - `JdbImageCacheService` 实现，构造时注入依赖（默认参数便于生产直用）：
    - `cacheManager`（默认 `JdbImageCacheManager.instance`）。
    - `cacheDirectory`（默认 `() => getTemporaryDirectory()`）。
    大小 = 遍历 `cacheDirectory()/jdbImageCache` 目录所有文件 `length` 求和
    （目录不存在返回 0）；清除 = `cacheManager.emptyCache()` +
    `PaintingBinding.instance.imageCache.clear()`。
  - 纯函数 `String formatCacheSize(int bytes)`：B/KB/MB 分级、保留一位小数
    （0 显示 `0 B`），供页面与单测共用。
- 设置页「清除缓存」cell：subtitle 显示格式化大小（`0 B` / `23.4 MB`，B/KB/MB
  分级，保留一位小数）；点击弹出确认对话框（「清除图片缓存？将删除已下载的
  图片封面与剧照」），确认后调用 `clearAll()`，subtitle 归零并 SnackBar
  提示「缓存已清除」。
- `ProfileSettingsPage` 由 `StatelessWidget` 转为 `StatefulWidget`，持有缓存大小
  状态（`initState` 异步加载），构造函数可选注入 `CacheService`（默认
  `JdbImageCacheService()`），便于测试。

### 装配与依赖

- `pubspec.yaml` 直接依赖增加 `path_provider`（对齐 lock 中既有版本）。

## 错误处理

- 缓存大小计算失败（目录不存在/IO 异常）按 `0` 处理，不阻塞页面。
- 清除失败：捕获异常，SnackBar 提示「清除失败，请稍后重试」，subtitle 保持
  原值。
- 外观模式持久化失败（`SharedPreferences` 写失败）不影响内存态与 UI，
  下次启动以内存为准重新持久化（沿用 `ThemeProvider` 现有行为）。

## 测试与验收

按 TDD 顺序增加回归覆盖：

1. 缓存服务单测（`JdbImageCacheService`）：以临时目录注入 `cacheDirectory` 与
   mock `CacheManager`（子类重写 `emptyCache()` 计数）隔离文件系统，验证大小
   统计（含目录不存在返回 0）、清除调用顺序、`formatCacheSize` 分级格式。
2. 设置页 Widget 测试（注入 fake `CacheService`）：
   - 「默认筛选标签」不再渲染。
   - 点击「外观模式」弹出弹窗，三选项齐全；选中「深色模式」后
     `ThemeProvider.themeMode == ThemeMode.dark` 且 prefs 持久化；
     subtitle 更新为「深色模式」。
   - 「清除缓存」subtitle 显示 fake 服务返回的大小；点击 → 确认对话框 →
     确认后 `clearAll()` 被调用、subtitle 归零、出现「缓存已清除」SnackBar。

验证顺序为目标单元测试、目标 Widget 测试、静态分析，最后运行完整测试套件并
如实记录既有无关失败。
