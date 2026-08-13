# 影片预告片播放页沉浸式系统栏设计

## 目标

进入影片预告片播放页时自动隐藏系统顶部状态栏与底部导航栏（全屏沉浸式 `SystemUiMode.immersiveSticky`），退出播放页时恢复应用默认的系统栏显示。

## 现状

- 播放页 `MoviePreviewPage` 已有两个同构的协调器：`MoviePreviewOrientationCoordinator`（横屏 lease）与 `MoviePreviewWakelockCoordinator`（唤醒锁 lease），均采用「acquire 返回 lease、内部串行队列、旧 lease 迟到释放不覆盖新 lease」的模式。
- 全局主题在 `lib/core/theme/app_theme.dart` 通过 `SystemUiOverlayStyle` 定义普通页面的系统栏样式，应用当前使用系统默认的双栏显示。
- 播放页目前没有设置系统 UI 模式，进入后状态栏与导航栏保持可见。

## 方案

复用横屏协调器的 lease 模式，新增系统 UI 协调器（方案 A）。不用页面直接裸调 `SystemChrome`（重叠页面/快速进出时的迟到恢复竞态难以处理且不可测），也不把职责塞进现有横屏协调器（职责混杂）。

## 服务设计

新文件 `lib/features/movie_detail/services/movie_preview_system_ui.dart`：

- `typedef MoviePreviewSystemUiModeSetter = Future<void> Function(SystemUiMode mode, {List<SystemUiOverlay>? overlays});`
- `MoviePreviewSystemUiCoordinator` 镜像横屏协调器：
  - `static final system` 接入 `SystemChrome.setEnabledSystemUIMode`；
  - `acquire()` 返回 `MoviePreviewSystemUiLease`；
  - 内部串行队列执行全部模式切换，保证「先 acquire 后 release」的调用顺序；
  - lease 被新 acquire 取代后，旧 lease 的 `release()` 不再生效，避免旧页面迟到恢复清掉新页面的沉浸模式。
- 进入模式：`SystemUiMode.immersiveSticky`（状态栏与导航栏全隐藏，边缘滑入可临时唤出，数秒后自动再隐藏）。
- 退出模式：`SystemUiMode.manual` + `overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom]`，恢复应用默认双栏显示，与全局 `SystemUiOverlayStyle` 兼容。

## 页面接入

`lib/features/movie_detail/screens/movie_preview_screen.dart`：

- 新增注入参数 `systemUiCoordinator`（测试注入 fake），与 `orientationCoordinator`、`wakelockCoordinator` 并列。
- 在进入流程一开始（与横屏 lease 同时）acquire 系统 UI lease；该操作是装饰性能力，失败吞掉并继续初始化，不阻塞播放。
- 横屏锁定失败时页面照旧进入错误态，但页面仍保持沉浸（与播放态一致），不提前恢复系统栏。
- `dispose()`：与横屏/唤醒锁 lease 一样独立 `unawaited` 释放，不等待播放器清理完成。
- 重试不重新 acquire（页面仍处于沉浸状态）。

## 测试策略

### 协调器单测

镜像现有 `movie_preview_orientation_test.dart` 写法：

- acquire 调用 `SystemUiMode.immersiveSticky`；
- release 调用 `SystemUiMode.manual` 且 overlays 为 top+bottom；
- 串行队列保持 acquire/release 调用顺序；
- lease 被取代后旧 release 不生效。

### 页面 widget 测试

注入 fake setter：

- 进入页面后系统 UI 设为 immersiveSticky；
- 退出页面后恢复默认双栏；
- 横屏锁定失败时页面仍保持沉浸（错误态下系统栏同样隐藏），退出页面时恢复；
- 页面 A 的迟到恢复不会破坏页面 B 的沉浸模式。

### 验证顺序

聚焦测试 → `flutter analyze` → 全量 `flutter test` → 真机/模拟器确认：进入即隐藏、边缘滑入临时唤出、退出恢复。

## 边界说明

- immersiveSticky 唤出后自动再隐藏的时长是系统行为，应用不控制。
- 点击 media_kit 默认全屏按钮进入的内置全屏路由同样处于沉浸状态（系统级设置，无冲突）。
- 装饰性失败不影响播放：系统 UI 设置失败只吞掉并记录，页面照常进入播放流程。

## 文件变更清单

新增：

- `lib/features/movie_detail/services/movie_preview_system_ui.dart`
- `test/features/movie_detail/movie_preview_system_ui_test.dart`

修改：

- `lib/features/movie_detail/screens/movie_preview_screen.dart`：新增注入参数、acquire/release 接线。
- `test/features/movie_detail/movie_preview_screen_test.dart`：注入 fake 并新增对应用例。
