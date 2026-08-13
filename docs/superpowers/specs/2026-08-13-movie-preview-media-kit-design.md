# 影片预告片播放器 Media Kit 替换设计

## 目标

将影片预告片播放器从 `chewie + video_player` 替换为 `media_kit + media_kit_video + media_kit_libs_android_video`，并使用 media_kit 自带控制层重构控制层。

替换后的行为基线只有三个自定义点：

1. 长按画面临时 `2.0×` 倍速（media_kit 内置能力，仅开启主题开关）；
2. 双击画面切换播放/暂停（页面级原始事件双击检测，见下文）；
3. 页面标题随播放状态自动显隐（3 秒规则，见下文）。

除此之外，控制层全部保持 media_kit 默认，不额外实现任何自定义控件。

本设计只替换 `docs/superpowers/specs/2026-08-10-movie-preview-player-design.md` 中的播放内核与控制层部分。详情接口解析、详情页预告入口、类型化路由参数、剧照图库索引、横屏锁定、唤醒锁、错误重试等页面级契约继续沿用原设计。

## 现状盘点

当前实现：

- 依赖：`chewie ^1.13.1`、`video_player ^2.14.0`；dev 依赖 `video_player_platform_interface 6.9.0`（仅测试替身使用）。
- `lib/features/movie_detail/services/movie_preview_playback.dart`：`MoviePreviewPlayback` 接口、`MoviePreviewPlaybackState`、`ChewieMoviePreviewPlayback`（`VideoPlayerController + ChewieController`）。
- `lib/features/movie_detail/widgets/movie_preview_chewie_controls.dart`：自定义控制层，依赖 `ChewieState.notifier.hideStuff` 同步头部显隐。
- `lib/features/movie_detail/widgets/movie_preview_gesture_layer.dart`：外层双击/长按手势层。
- `lib/features/movie_detail/screens/movie_preview_screen.dart`：横屏 lease、初始化、自动播放、错误重试、唤醒锁与生命周期防竞态。
- 仓库仅有 `android/` 平台目录，本次只处理 Android。

## 最终行为基线

### 保留的页面级契约（不修改）

- 进入播放页自动锁定 `landscapeLeft` 与 `landscapeRight`，退出恢复应用默认方向。
- 横屏锁定成功后才创建并初始化播放器，成功后自动播放。
- URL 非法、初始化失败、媒体错误时显示“预告片播放失败”和“重试”；重试不可重入，替换旧播放器。
- 唤醒锁在播放成功后获取、退出时释放，由页面级 `MoviePreviewWakelockCoordinator` 单一管理。
- 退出、重试与迟到的异步回调通过 lifecycle generation 与 session 同一性防护。
- 播放到结尾后再次播放从头开始。
- 路由、`MoviePreviewArgs`、详情页预告入口、剧照图库索引不变。

### 三个自定义行为

1. **长按 2.0× 倍速**：`MaterialVideoControlsThemeData(speedUpOnLongPress: true)`，`speedUpFactor` 默认即 `2.0`，指示器使用内置实现。松手恢复之前倍速。
2. **双击切换播放/暂停**：见“双击检测”一节。页面级 `Listener` 不参与手势竞技场，不影响内置控件的单击、长按与按钮操作。
3. **标题自动显隐**：见“头部自动显隐”一节。

### 其余全部保持 media_kit 默认

- 控件初始隐藏（`visibleOnMount` 默认 `false`），单击唤出/收起。
- 底部栏保留默认的进度时间与全屏按钮；中央保留默认播放/暂停与上一个/下一个按钮。
- 进度条默认配色；无静音按钮；无水平滑动快进；内置双击 seek 保持默认关闭（双击由页面级检测接管播放/暂停）。
- 音量/亮度垂直滑动保持默认关闭，不引入 `volume_controller`、`screen_brightness`。

### 行为差异清单

| 交互 | 现状 | 替换后 |
| --- | --- | --- |
| 双击 | 播放/暂停 | 播放/暂停（页面级检测实现） |
| 长按 | 2.0×，恢复失败进错误页 | 2.0× 内置实现，松手恢复 |
| 单击 | 显隐控制层 | 显隐控制层（内置，不变） |
| 控件初始状态 | 显示 | 隐藏（media_kit 默认，单击唤出） |
| 静音按钮 | 有 | 无（media_kit 默认） |
| 全屏按钮 | 无 | 有（media_kit 默认，推入内置全屏路由；该路由内无双击播放/暂停与标题自动显隐，属已知边界） |
| 上一个/下一个按钮 | 无 | 有（media_kit 默认，单视频时无效果） |
| 播放中进入后台 | 可能继续播放 | 自动暂停（`pauseUponEnteringBackgroundMode` 默认 `true`，符合“排除后台播放”边界） |
| 头部 | 跟随控件显隐 | 规则近似，残余不同步见下文 |

## 依赖与初始化

pubspec.yaml：

- 移除：`chewie`、`video_player`、`video_player_platform_interface`（dev）。
- 新增：`media_kit ^1.2.6`、`media_kit_video ^2.0.1`、`media_kit_libs_android_video ^1.3.8`。

版本兼容性（已核实）：

- `media_kit 1.2.6` 要求 `sdk >=3.1.0`，满足项目 `sdk: ^3.8.0`。
- `media_kit_video 2.0.1` 依赖 `media_kit ^1.2.3` 与 `wakelock_plus ^1.1.6`（项目已有 `wakelock_plus ^1.3.3`，保留）。

初始化：

- `lib/main.dart` 的 `main()` 中在 `WidgetsFlutterBinding.ensureInitialized()` 之后调用 `MediaKit.ensureInitialized()`；`mainForTest()` 不调用（测试运行在 VM，不初始化原生事件循环）。
- Android Manifest 无改动；HTTPS M3U8 直接经 `Media(uri)` 打开，默认 `protocolWhitelist` 已含 `https` 与 `crypto`（AES-128 HLS 无需额外配置，仍需真机验证）。

构建影响：

- `media_kit_libs_android_video` 的 libmpv 由 Gradle 首次构建时从 GitHub 下载（4 个 ABI，MD5 校验），首次构建需联网。
- universal APK 体积显著增大（各 ABI 均打入 libmpv）；发布时建议 `--split-per-abi` 或 app bundle，本次不修改构建配置。

## 架构设计

### 1. 播放适配器：`MediaKitMoviePreviewPlayback`

文件：`lib/features/movie_detail/services/movie_preview_playback.dart`

- 保留 `MoviePreviewPlayback`、`MoviePreviewPlaybackState`、`MoviePreviewPlaybackFactory`；从接口移除 `setPlaybackSpeed`（页面不再发起倍速命令）。
- 测试接缝使用 media_kit 官方注入点 `Player(platformPlayer: ...)`：测试注入继承 `PlatformPlayer` 的 fake（其公开的 `*Controller` 可直接驱动状态流），生产代码与测试共用同一 `Player` API，与现有 `withController` 注入模式一致。
- 构造时创建 `Player()` 与 `VideoController(player)`。
- `initialize()` = `await player.open(Media(uri), play: false)`，成功后 `isInitialized = true`。
- 订阅 `stream.playing / buffering / completed / error / position / duration / width / height` 映射为 `MoviePreviewPlaybackState`：

| media_kit 信号 | 状态字段 |
| --- | --- |
| `stream.playing` | `isPlaying` |
| `stream.buffering` | `isBuffering` |
| `stream.completed` | `isCompleted` |
| `stream.error` | `errorDescription` |
| `stream.position` / `stream.duration` | `position` / `duration` |
| `stream.width` / `stream.height` | `aspectRatio`（无效时回退 `16/9`） |

- 监听 `stream.completed` 后自动 `seek(Duration.zero)`，保证“结尾后再播放从头开始”。
- `buildView()` 只返回 `Video`（含控制层），未初始化时抛 `StateError`（沿用现有契约）：

```dart
MaterialVideoControlsTheme(
  normal: MaterialVideoControlsThemeData(speedUpOnLongPress: true),
  child: Video(
    controller: _videoController,
    fit: BoxFit.contain,
    fill: Colors.black,
    wakelock: false, // 唤醒锁由页面级协调器单一管理
    controls: MaterialVideoControls.new,
  ),
)
```

- `dispose()`：取消全部订阅 → `player.dispose()` → 释放状态通知器；幂等，沿用收集首个错误的 try/finally 模式；删除 video_player 特有的“初始化失败有界 dispose”hack。

### 2. 双击检测：`MoviePreviewDoubleTapDetector`

文件：`lib/features/movie_detail/widgets/movie_preview_double_tap_detector.dart`

背景：`MaterialVideoControls` 内置手势层始终注册 `onDoubleTap`（内置 seek 关闭时无动作），外层普通 `GestureDetector` 在手势竞技场中无法稳定获胜。`Listener` 不参与竞技场，命中路径上的所有 `Listener` 都会收到原始指针事件，因此页面级 `Listener` 可以可靠地实现双击检测，同时不影响内置控件的单击、长按与拖动。

行为：

- 300ms 内两次 pointer-down、位置差不超过 100 逻辑像素、期间无其它指针 → 判定双击，调用 `onDoubleTap` 后清空历史。
- 多指针同时按下时忽略并重置历史；可注入时钟便于测试。
- 只包裹视频区域（`buildView()`），不包裹头部，避免双击返回按钮触发两次返回。
- 已知边界（记录）：双击若发生在进度条或按钮区域，同样会切换播放/暂停；内置控件的单击回调会在双击判定超时后触发一次控制层显隐切换，与旧契约“双击播放/暂停并短暂显示控制层”语义一致。

页面接入：命中后调用 `_togglePlayback`（沿用现有逻辑：已播完先 `seek(0)` 再播、播放中暂停、否则播放），保留 `_PlaybackCommand` 的 generation/session 失效防护。

### 3. 头部自动显隐：`MoviePreviewHeaderOverlay`

文件：`lib/features/movie_detail/widgets/movie_preview_header_overlay.dart`

- 加载/错误态的静态头部与播放态的显隐头部复用同一 `MoviePreviewHeader`（返回按钮 + 单行标题）。
- 播放态显隐规则（监听 `MoviePreviewPlayback.state`）：进入“播放中且非缓冲”状态起 3 秒无状态变化 → 隐藏；暂停/缓冲/完成/错误 → 显示；250ms 淡入淡出，隐藏时 `IgnorePointer + ExcludeSemantics`；定时器在销毁时取消。
- 残余不同步（已接受，写入文档）：① 用户点按屏幕唤出/收起内置控件时头部感知不到，可能暂时不一致；② 暂停时头部保持显示，内置控件在自身 3 秒计时后仍会隐藏。
- 已知边界：用户点按默认全屏按钮进入内置全屏路由后，双击与标题自定义行为不生效；该路由是纯 media_kit 默认视图。

### 4. 页面结构

`MoviePreviewPage` 播放态结构：

```text
Stack
├── MoviePreviewDoubleTapDetector（Listener）
│   └── Video（内置控制层，theme 仅 speedUpOnLongPress）
└── MoviePreviewHeaderOverlay（SafeArea 顶部，随状态显隐）
```

- 删除 `MoviePreviewGestureLayer` 与 `MoviePreviewChewieControls`。
- `_createPlayback` 不再传 `customControls`。
- 清理流程删除 `setPlaybackSpeed(1.0)` 步骤；保留暂停与释放的有界清理（`_cleanupStepTimeout`）。
- 保留 `_PlaybackSession`、`_PlaybackCommand`、generation 防竞态、横屏 lease 与唤醒锁 lease 的释放顺序。

## 错误与生命周期

- `open()` 抛错 → `initialize()` 重抛 → 页面错误态；媒体错误经 `stream.error` 映射进状态 → 页面错误态；两者都可重试。
- 重试新建 `Player` 与 `VideoController`，不遗留旧控制器。
- `dispose()` 幂等；页面退出时先失效 generation，再独立释放横屏 lease、唤醒锁 lease 与播放器，顺序不互相阻塞。

## 测试策略

按 TDD 顺序覆盖：

### 适配器测试（`movie_preview_playback_test.dart` 重写）

- 注入 fake `MediaKitPreviewPlayer`：状态映射（播放/缓冲/完成/错误/位置/时长/宽高比）、initialize 成败、completed 自动归零、dispose 幂等与顺序、未初始化 `buildView()` 抛错。

### 双击检测测试（新增）

- 300ms 内两次按下且位置接近 → 回调一次；超时不算双击；位移超容差不触发；多指针忽略；触发后历史复位；可注入时钟。

### 头部显隐测试（新增，替换 chewie 控件测试）

- 播放中 3 秒后隐藏；暂停/缓冲/完成/错误显示；隐藏时 `IgnorePointer`；销毁取消定时器。

### 页面测试（`movie_preview_screen_test.dart` 改造）

- 注入 fake `MoviePreviewPlayback` 的接缝不变，大部分用例保留；删除 Chewie/双击手势相关用例，改为双击检测回调与头部显隐用例。

### 删除

- `movie_preview_chewie_controls_test.dart`、`movie_preview_gesture_layer_test.dart`。

### 验证顺序

1. 聚焦测试（适配器、双击检测、头部显隐、页面）。
2. `flutter analyze`。
3. 全量 `flutter test`。
4. Android debug 构建并在模拟器人工验证：真实 M3U8 播放、双击播放/暂停、长按 2×、单击显隐、头部显隐、横屏恢复、错误重试。

## 风险

- universal APK 体积显著增大，首次 Gradle 构建联网下载 libmpv。
- AES-128 HLS 依赖 libmpv，需真机实测（默认协议白名单理论上开箱即用）。
- 头部与内置控件显隐存在已接受的残余不同步。
- 控件初始隐藏、全屏按钮、上一个/下一个按钮为 media_kit 默认行为，与本设计的行为差异清单一致。
- media_kit 错误流语义与 video_player 不同，错误页/重试路径必须真机验证。

## 文件变更清单

修改：

- `pubspec.yaml`：替换依赖。
- `lib/main.dart`：`main()` 增加 `MediaKit.ensureInitialized()`。
- `lib/features/movie_detail/services/movie_preview_playback.dart`：`ChewieMoviePreviewPlayback` 替换为 `MediaKitMoviePreviewPlayback`，通过 `Player(platformPlayer: ...)` 注入点支持测试替身。
- `lib/features/movie_detail/screens/movie_preview_screen.dart`：接入双击检测与头部显隐，删除手势层与 `setPlaybackSpeed` 相关命令。

新增：

- `lib/features/movie_detail/widgets/movie_preview_double_tap_detector.dart`
- `lib/features/movie_detail/widgets/movie_preview_header_overlay.dart`

删除：

- `lib/features/movie_detail/widgets/movie_preview_chewie_controls.dart`
- `lib/features/movie_detail/widgets/movie_preview_gesture_layer.dart`

测试：删除 `movie_preview_chewie_controls_test.dart`、`movie_preview_gesture_layer_test.dart`；重写 `movie_preview_playback_test.dart`；改造 `movie_preview_screen_test.dart`；新增双击检测与头部显隐测试。
