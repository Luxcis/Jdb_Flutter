# 影片预告片 Chewie 重构设计

## 目标

将现有预告片播放器的自定义播放控制层替换为 Chewie 原生控制层，同时保留以下页面级契约：

- 进入播放页后自动锁定 `landscapeLeft` 和 `landscapeRight`；
- 双击画面切换播放或暂停；
- 长按画面切换为 `2.0×`，松手或取消后恢复 `1.0×`；
- 退出页面后恢复应用默认方向；
- 初始化、播放和清理失败时保持可退出、可重试且不泄漏播放器资源。

本设计只替换 `docs/superpowers/specs/2026-08-10-movie-preview-player-design.md` 中的播放器视图和控制层部分。详情接口解析、详情页预告入口、类型化路由参数、剧照图库索引及范围边界继续沿用原设计。

## 依赖约束

新增：

```yaml
chewie: 1.13.1
```

保留：

```yaml
video_player: 2.10.1
```

Chewie 是 `video_player` 的 UI 和控制层封装，仍要求业务代码创建并管理 `VideoPlayerController`，因此不能移除 `video_player` 直接依赖。

选择 Chewie `1.13.1` 的原因：

- 支持项目声明的 Dart `>=3.8.0` 下限；
- 依赖 `video_player ^2.10.0`，与当前固定的 `video_player 2.10.1` 兼容；
- Chewie `1.14.x` 要求更高 Dart/Flutter 与 `video_player ^2.11.1`，会改变当前项目的 SDK 兼容边界。

## 架构

重构后仍保留三层边界：

1. `MoviePreviewPage`：负责横屏 lease、初始化、自动播放、错误重试、页面返回和资源清理。
2. `ChewieMoviePreviewPlayback`：同时持有 `VideoPlayerController` 与 `ChewieController`，向页面暴露播放状态、播放命令和 Chewie 视图。
3. `MoviePreviewGestureLayer`：包装 Chewie 视图，只负责双击和长按手势，不实现按钮、进度条或控制层隐藏。

现有 `MoviePreviewOrientationCoordinator`、`MoviePreviewOrientationLease`、`MoviePreviewArgs` 与正式路由保持不变。

## Chewie 播放适配器

`VideoPlayerMoviePreviewPlayback` 重命名并重构为 `ChewieMoviePreviewPlayback`。

初始化顺序：

1. 创建 `VideoPlayerController.networkUrl(uri, formatHint: VideoFormat.hls)`。
2. 页面成功获取横屏 lease 后调用 `initialize()`。
3. 初始化底层 `VideoPlayerController`。
4. 创建 `ChewieController`。
5. 页面调用底层播放命令开始自动播放。

Chewie 配置固定为：

- `autoInitialize: false`：初始化仍由页面显式控制；
- `autoPlay: false`：只有横屏锁定和底层初始化都成功后才播放；
- `looping: false`；
- `showControls: true`；
- `showControlsOnInitialize: true`；
- `draggableProgressBar: true`；
- `hideControlsTimer: Duration(seconds: 3)`；
- `allowFullScreen: false`：播放页本身已经是自动横屏的全页播放器，不再打开第二层全屏路由；
- `allowPlaybackSpeedChanging: false`：避免原生倍速菜单与“松手恢复 `1.0×`”冲突；
- `showOptions: false`：不显示没有有效选项的菜单；
- `allowMuting: true`；
- `allowedScreenSleep: false`；
- 使用 Material 原生控制层；
- 缓冲显示 Chewie 原生加载状态。

`buildView()` 返回：

```dart
Chewie(controller: chewieController)
```

底层 `VideoPlayerValue` 仍映射为 `MoviePreviewPlaybackState`，供页面判断媒体错误、重试和生命周期状态。

## 双击与长按手势

Chewie 视图外层使用以下用户可见语义：

```dart
GestureDetector(
  onDoubleTap: togglePlayPause,
  onLongPress: startDoubleSpeed,
  onLongPressEnd: (_) => restoreNormalSpeed(),
  onLongPressCancel: restoreNormalSpeed,
  child: Chewie(controller: chewieController),
)
```

行为定义：

- 双击：
  - 当前正在播放时调用 `pause()`；
  - 当前未播放时调用 `play()`；
  - 不替换 Chewie 原生单击显示/隐藏控制层行为。
- 长按被识别后：
  - 串行请求 `setPlaybackSpeed(2.0)`；
  - 成功且手势仍有效时显示“2.0×”提示；
  - 失败时不显示错误的倍速提示。
- 松手或取消：
  - 将 `setPlaybackSpeed(1.0)` 排在任何尚未完成的 `2.0×` 请求之后；
  - 恢复成功后隐藏“2.0×”提示；
  - 恢复失败时暂停播放并进入可重试错误状态，不能静默保持 2 倍速。
- 页面销毁：
  - 失效所有待执行的手势命令；
  - 有界尝试恢复 `1.0×`；
  - 不允许销毁后的回调更新界面。

外层 `GestureDetector` 不实现单击回调。Chewie 子树继续接收原生按钮、进度条、音量和控制层显隐手势。

## 页面布局

页面保持黑色背景和自动横屏。

正常播放状态使用：

```text
Stack
├── MoviePreviewGestureLayer
│   └── Chewie
├── 2.0× 临时提示
└── SafeArea
    └── 返回按钮 + 单行影片标题
```

返回按钮和影片标题属于页面导航，不属于播放控制层，因此继续由应用提供。Chewie 原生控制层负责其余播放操作。

加载、URL 非法、横屏锁定失败和初始化失败状态继续复用带 `SafeArea` 的页面标题与返回按钮：

- 加载状态显示进度；
- 错误状态显示“预告片播放失败”和“重试”；
- 所有状态都允许直接返回影片详情页。

## 生命周期与清理

现有加固逻辑必须保留：

- 播放器只有在横屏 lease 成功后才创建和初始化；
- 页面 A 的迟到方向恢复不能清除页面 B 的横屏锁；
- 重试不可重入；
- 退出或重试会使当前播放 session 与在途命令失效；
- 每个异步播放命令完成后重新校验 session 和 lifecycle generation；
- `video_player 2.10.1` 创建失败后的非完成 dispose 使用有界清理；
- 方向 lease 的释放不依赖播放器 dispose 完成。

新增 Chewie 清理顺序：

1. 失效页面和手势命令；
2. 尝试恢复 `1.0×`；
3. 暂停底层播放器；
4. 释放 `ChewieController`，停止其监听和定时器；
5. 有界释放 `VideoPlayerController`；
6. 释放应用持有的状态通知器；
7. 独立释放方向 lease。

清理必须幂等；初始化失败且尚未创建 `ChewieController` 时只清理已存在的资源。

## 删除与保留

删除：

- 当前自定义 `MoviePreviewControls` 播放按钮、进度条、时间格式和自动隐藏实现；
- 自定义单击显隐逻辑；
- 自定义 Slider 与对应测试；
- Chewie 已原生提供的缓冲、播放按钮和控制层隐藏逻辑。

保留：

- 页面返回按钮和影片标题；
- 双击播放/暂停；
- 长按临时 `2.0×`；
- 页面级错误和重试；
- 横屏 lease 与所有竞态防护；
- M3U8 地址、详情入口、路由与图库索引逻辑。

## 测试策略

### 依赖与适配器

- `pubspec.lock` 锁定 Chewie `1.13.1` 和 `video_player 2.10.1`。
- 初始化成功后创建一个配置符合本设计的 `ChewieController`。
- `buildView()` 返回 `Chewie`。
- 初始化失败时不会创建或泄漏 `ChewieController`。
- 清理同时释放 Chewie 与底层视频控制器，且保持有界、幂等。

### 手势层 widget 测试

- 双击在播放时调用暂停，在暂停时调用播放。
- 单击仍由 Chewie 子树处理，外层不注册单击行为。
- 长按成功后请求 `2.0×` 并显示提示。
- 松手和取消均恢复 `1.0×`。
- `2.0×` 请求延迟时提前松手，最终速度为 `1.0×`。
- 切换 `2.0×` 失败时不显示提示。
- 恢复 `1.0×` 失败时暂停并显示可重试错误。
- 销毁期间没有未处理 Future 或 `setState after dispose`。

### 页面生命周期测试

- 横屏锁定成功后才初始化 Chewie 播放器并自动播放。
- 横屏锁定失败不创建播放器。
- 加载、非法 URL、初始化失败均显示返回按钮、标题和错误/重试状态。
- 页面 A 延迟清理后页面 B 仍保持横屏。
- 初始化失败与永不完成的底层清理不会阻止返回、重试或方向恢复。
- 重试替换 Chewie 与视频控制器，不遗留旧控制器。

### 回归验证

- 影片详情预告入口和 typed extra 路由测试继续通过。
- 预告封面不进入剧照图库，原图库索引不变。
- 删除旧自定义控制层测试，改为 Chewie 适配器和手势层行为测试。
- 运行相关聚焦测试、`flutter analyze` 和完整 `flutter test`。
- 在 Android 模拟器上重新构建并安装 debug APK，人工确认真实 M3U8、Chewie 原生控制层、双击、长按和横屏恢复。

## 非目标

- 不恢复自定义进度条、时间文本、播放按钮或控制层动画；
- 不使用 `customControls` 复制旧控制层；
- 不启用 Chewie 第二层全屏路由；
- 不增加正片播放、清晰度选择、字幕、投屏、下载、后台播放或画中画；
- 不修改影片详情数据、预告入口、路由参数或剧照图库契约。
