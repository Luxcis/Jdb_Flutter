# 影片预告片 Chewie 重构实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 使用 Chewie `1.13.1` 原生控制层替换预告片播放器的自定义控制层，同时保留自动横屏、双击播放/暂停、长按临时 `2.0×`、错误重试和竞态安全清理。

**Architecture:** `MoviePreviewPage` 继续持有横屏 lease、播放 session、重试与页面错误状态；`ChewieMoviePreviewPlayback` 同时管理 `VideoPlayerController` 和 `ChewieController`；新的 `MoviePreviewGestureLayer` 仅包装 Chewie 视图并串行处理双击、长按及倍速恢复。Chewie 负责播放按钮、进度、缓冲、音量和 3 秒自动隐藏，应用只保留页面返回按钮、标题、倍速提示和错误页。

**Tech Stack:** Flutter 3.44.8、Dart 3.12.2（项目声明下限 Dart 3.8）、Material 3、Chewie 1.13.1、video_player 2.10.1、flutter_test、Android ADB。

## Global Constraints

- 实现必须符合 `docs/superpowers/specs/2026-08-11-movie-preview-chewie-refactor-design.md`；该文档只覆盖原预告片设计的播放器视图和控制层。
- 新增 `chewie: 1.13.1`，继续直接固定 `video_player: 2.10.1`；不得升级项目 Dart 或 Flutter 下限。
- 使用 Chewie Material 原生控制层，不提供 `customControls`，不重建自定义播放按钮、Slider、时间文本或控制层动画。
- Chewie 必须设置 `autoInitialize: false`、`autoPlay: false`、`looping: false`、`showControls: true`、`showControlsOnInitialize: true`、`draggableProgressBar: true`、`hideControlsTimer: Duration(seconds: 3)`、`allowFullScreen: false`、`allowPlaybackSpeedChanging: false`、`showOptions: false`、`allowMuting: true`、`allowedScreenSleep: false`。
- 外层手势只注册双击和长按系列回调；不得注册单击，Chewie 子树必须继续接收原生控制交互。
- 双击读取当前播放状态：播放中调用 `pause()`，否则调用 `play()`；完成态先 `seekTo(Duration.zero)` 再播放。
- 长按识别成功后请求 `2.0×`；松手或取消后串行恢复 `1.0×`；恢复失败必须暂停播放并进入可重试错误页。
- 进入播放页自动锁定 `landscapeLeft`、`landscapeRight`，离开后恢复系统默认；不得启用 Chewie 第二层全屏路由。
- 保留现有 orientation lease、session generation、重试不可重入、异步命令失效检查、有界清理和 `video_player 2.10.1` 创建失败处置。
- 详情接口、预告封面入口、typed route extra、图库图片集合和图库索引均不得改变。
- 用户文案继续直接硬编码中文；不增加本地化、触觉反馈、正片播放、字幕、投屏、下载、后台播放或画中画。
- 严格执行 RED → GREEN → REFACTOR；每项生产行为先运行对应失败测试，再写最小实现。

---

## 文件结构

### 新建文件

- `lib/features/movie_detail/widgets/movie_preview_gesture_layer.dart`：双击、长按、串行倍速切换与 `2.0×` 临时提示。
- `test/features/movie_detail/movie_preview_playback_test.dart`：Chewie 配置、初始化、视图与双控制器清理测试。
- `test/features/movie_detail/movie_preview_gesture_layer_test.dart`：外层手势、倍速竞态与销毁安全 widget 测试。

### 修改文件

- `pubspec.yaml`、`pubspec.lock`：加入并锁定 Chewie `1.13.1`，保留 video_player `2.10.1`。
- `lib/features/movie_detail/services/movie_preview_playback.dart`：将 `VideoPlayerMoviePreviewPlayback` 重构为 `ChewieMoviePreviewPlayback`。
- `lib/features/movie_detail/screens/movie_preview_screen.dart`：使用 Chewie 视图与新手势层，保留横屏和页面生命周期。
- `test/features/movie_detail/movie_preview_screen_test.dart`：适配新实现名称，覆盖媒体错误和倍速恢复失败的页面行为。

### 删除文件

- `lib/features/movie_detail/widgets/movie_preview_controls.dart`：删除自定义播放按钮、进度、时间和控制层显隐实现。
- `test/features/movie_detail/movie_preview_controls_test.dart`：删除只属于旧自定义控制层的测试；仍有效的双击和长按契约迁移到新手势层及页面测试。

---

### Task 1: 引入 Chewie 并建立播放器适配器

**Files:**

- Modify: `pubspec.yaml`
- Modify: `pubspec.lock`
- Modify: `lib/features/movie_detail/services/movie_preview_playback.dart`
- Create: `test/features/movie_detail/movie_preview_playback_test.dart`
- Modify: `test/features/movie_detail/movie_preview_screen_test.dart`

**Interfaces:**

- Consumes:
  - `Uri`：已经由 `MoviePreviewArgs.videoUri` 验证过的 HTTP(S) M3U8 地址。
  - `VideoPlayerController`：底层媒体控制器。
- Produces:
  - `MoviePreviewPlaybackState moviePreviewPlaybackStateFromVideoPlayerValue(VideoPlayerValue value)`，保持现有映射。
  - `typedef MoviePreviewPlaybackFactory = MoviePreviewPlayback Function(Uri uri)`，签名保持不变。
  - `typedef MoviePreviewChewieControllerFactory = ChewieController Function(VideoPlayerController controller)`。
  - `ChewieController createMoviePreviewChewieController(VideoPlayerController controller)`。
  - `ChewieMoviePreviewPlayback(Uri uri)`。
  - `ChewieMoviePreviewPlayback.withController(VideoPlayerController controller, {MoviePreviewChewieControllerFactory chewieControllerFactory = createMoviePreviewChewieController})`，仅用于测试注入。
  - `MoviePreviewPlayback.buildView()` 在初始化成功后返回 `Chewie`。

- [ ] **Step 1: 添加精确依赖并解析 lockfile**

在 `pubspec.yaml` 的播放器依赖旁加入：

```yaml
  chewie: 1.13.1
  video_player: 2.10.1
```

Run:

```bash
flutter pub get
```

Expected:

- `pubspec.lock` 中 `chewie` 为 `1.13.1`；
- `video_player` 仍为 `2.10.1`；
- 依赖解析成功，未修改 `environment.sdk: ^3.8.0`。

- [ ] **Step 2: 写 Chewie 配置、视图与清理顺序失败测试**

新建 `test/features/movie_detail/movie_preview_playback_test.dart`，加入以下核心测试和测试控制器：

```dart
import 'dart:async';

import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/features/movie_detail/services/movie_preview_playback.dart';
import 'package:video_player/video_player.dart';

void main() {
  testWidgets('初始化后 buildView 返回固定配置的 Chewie 原生控制层', (
    tester,
  ) async {
    final videoController = _FakeVideoPlayerController();
    final playback = ChewieMoviePreviewPlayback.withController(videoController);

    await playback.initialize();

    final view = playback.buildView();
    expect(view, isA<Chewie>());
    final chewieController = (view as Chewie).controller;
    expect(chewieController.videoPlayerController, same(videoController));
    expect(chewieController.autoInitialize, isFalse);
    expect(chewieController.autoPlay, isFalse);
    expect(chewieController.looping, isFalse);
    expect(chewieController.showControls, isTrue);
    expect(chewieController.showControlsOnInitialize, isTrue);
    expect(chewieController.draggableProgressBar, isTrue);
    expect(chewieController.hideControlsTimer, const Duration(seconds: 3));
    expect(chewieController.allowFullScreen, isFalse);
    expect(chewieController.allowPlaybackSpeedChanging, isFalse);
    expect(chewieController.showOptions, isFalse);
    expect(chewieController.allowMuting, isTrue);
    expect(chewieController.allowedScreenSleep, isFalse);

    await playback.dispose();
  });

  test('初始化前 buildView 明确失败', () {
    final playback = ChewieMoviePreviewPlayback.withController(
      _FakeVideoPlayerController(),
    );

    expect(playback.buildView, throwsStateError);
  });

  test('释放顺序为 Chewie 后 video_player 且 dispose 幂等', () async {
    final events = <String>[];
    final videoController = _FakeVideoPlayerController(
      onDispose: () => events.add('video'),
    );
    final playback = ChewieMoviePreviewPlayback.withController(
      videoController,
      chewieControllerFactory: (controller) =>
          _RecordingChewieController(controller, events),
    );
    await playback.initialize();

    await playback.dispose();
    await playback.dispose();

    expect(events, ['chewie', 'video']);
  });

  test('底层初始化失败时不创建 Chewie 且清理有界完成', () async {
    var chewieCreateCalls = 0;
    final playback = ChewieMoviePreviewPlayback.withController(
      _FakeVideoPlayerController(
        initializeError: StateError('platform create failed'),
        neverCompleteDispose: true,
      ),
      chewieControllerFactory: (controller) {
        chewieCreateCalls++;
        return ChewieController(videoPlayerController: controller);
      },
    );

    await expectLater(playback.initialize(), throwsStateError);
    await expectLater(
      playback.dispose().timeout(const Duration(seconds: 2)),
      completes,
    );
    expect(chewieCreateCalls, 0);
  });

  test('Chewie 控制器构造失败时仍正常释放已初始化的视频控制器', () async {
    var videoDisposeCalls = 0;
    final playback = ChewieMoviePreviewPlayback.withController(
      _FakeVideoPlayerController(
        onDispose: () => videoDisposeCalls++,
      ),
      chewieControllerFactory: (_) {
        throw StateError('Chewie create failed');
      },
    );

    await expectLater(playback.initialize(), throwsStateError);
    await playback.dispose();

    expect(videoDisposeCalls, 1);
  });
}

class _FakeVideoPlayerController extends VideoPlayerController {
  _FakeVideoPlayerController({
    this.initializeError,
    this.neverCompleteDispose = false,
    this.onDispose,
  }) : super.networkUrl(
         Uri.parse('https://media.example.com/preview.m3u8'),
         formatHint: VideoFormat.hls,
       );

  final Object? initializeError;
  final bool neverCompleteDispose;
  final VoidCallback? onDispose;

  @override
  Future<void> initialize() async {
    if (initializeError case final error?) {
      throw error;
    }
    value = const VideoPlayerValue(
      duration: Duration(minutes: 1),
      size: Size(1920, 1080),
      isInitialized: true,
    );
  }

  @override
  Future<void> dispose() async {
    onDispose?.call();
    if (neverCompleteDispose) {
      await Completer<void>().future;
    }
  }
}

class _RecordingChewieController extends ChewieController {
  _RecordingChewieController(
    VideoPlayerController controller,
    this.events,
  ) : super(videoPlayerController: controller);

  final List<String> events;

  @override
  void dispose() {
    events.add('chewie');
    super.dispose();
  }
}
```

同时把 `test/features/movie_detail/movie_preview_screen_test.dart` 中直接构造旧实现的测试改为期望新名称：

```dart
final playback = ChewieMoviePreviewPlayback.withController(controller);
```

- [ ] **Step 3: 运行测试并确认 RED**

Run:

```bash
flutter test test/features/movie_detail/movie_preview_playback_test.dart
```

Expected: 编译失败，指出 `ChewieMoviePreviewPlayback`、`MoviePreviewChewieControllerFactory` 或 Chewie 配置工厂尚不存在。

- [ ] **Step 4: 实现 Chewie 配置工厂**

在 `movie_preview_playback.dart` 中加入 Chewie import、工厂类型和固定配置：

```dart
import 'package:chewie/chewie.dart';

typedef MoviePreviewChewieControllerFactory =
    ChewieController Function(VideoPlayerController controller);

ChewieController createMoviePreviewChewieController(
  VideoPlayerController controller,
) {
  return ChewieController(
    videoPlayerController: controller,
    autoInitialize: false,
    autoPlay: false,
    looping: false,
    showControls: true,
    showControlsOnInitialize: true,
    draggableProgressBar: true,
    hideControlsTimer: const Duration(seconds: 3),
    allowFullScreen: false,
    allowPlaybackSpeedChanging: false,
    showOptions: false,
    allowMuting: true,
    allowedScreenSleep: false,
  );
}
```

- [ ] **Step 5: 用 Chewie 重构播放适配器**

将旧实现替换为下面的结构；`MoviePreviewPlayback` 接口和状态映射函数保持不变：

```dart
class ChewieMoviePreviewPlayback implements MoviePreviewPlayback {
  ChewieMoviePreviewPlayback(Uri uri)
    : this._(
        VideoPlayerController.networkUrl(uri, formatHint: VideoFormat.hls),
        createMoviePreviewChewieController,
      );

  @visibleForTesting
  ChewieMoviePreviewPlayback.withController(
    VideoPlayerController controller, {
    MoviePreviewChewieControllerFactory chewieControllerFactory =
        createMoviePreviewChewieController,
  }) : this._(controller, chewieControllerFactory);

  ChewieMoviePreviewPlayback._(
    this._videoController,
    this._chewieControllerFactory,
  ) {
    _videoController.addListener(_syncState);
    _syncState();
  }

  final VideoPlayerController _videoController;
  final MoviePreviewChewieControllerFactory _chewieControllerFactory;
  final _state = ValueNotifier(const MoviePreviewPlaybackState());
  ChewieController? _chewieController;
  bool _initializationFailedWithoutMediaError = false;
  Future<void>? _disposeOperation;

  @override
  ValueListenable<MoviePreviewPlaybackState> get state => _state;

  @override
  Widget buildView() {
    final controller = _chewieController;
    if (controller == null) {
      throw StateError('Movie preview playback is not initialized.');
    }
    return Chewie(controller: controller);
  }

  @override
  Future<void> initialize() async {
    try {
      await _videoController.initialize();
    } catch (_) {
      _initializationFailedWithoutMediaError =
          !_videoController.value.hasError;
      rethrow;
    }
    _chewieController ??= _chewieControllerFactory(_videoController);
  }

  @override
  Future<void> play() => _videoController.play();

  @override
  Future<void> pause() => _videoController.pause();

  @override
  Future<void> seekTo(Duration position) =>
      _videoController.seekTo(position);

  @override
  Future<void> setPlaybackSpeed(double speed) =>
      _videoController.setPlaybackSpeed(speed);

  @override
  Future<void> dispose() => _disposeOperation ??= _dispose();
}
```

实现 `_dispose()` 时必须使用 `try/finally` 保证以下顺序：

```dart
Future<void> _dispose() async {
  _videoController.removeListener(_syncState);
  Object? firstError;
  StackTrace? firstStackTrace;
  try {
    try {
      _chewieController?.dispose();
    } catch (error, stackTrace) {
      firstError = error;
      firstStackTrace = stackTrace;
    } finally {
      _chewieController = null;
    }

    try {
      if (_initializationFailedWithoutMediaError) {
        await _videoController.dispose().timeout(
          const Duration(seconds: 1),
        );
      } else {
        await _videoController.dispose();
      }
    } on TimeoutException {
      if (!_initializationFailedWithoutMediaError) {
        rethrow;
      }
    } catch (error, stackTrace) {
      firstError ??= error;
      firstStackTrace ??= stackTrace;
    }
  } finally {
    _state.dispose();
  }
  if (firstError case final error?) {
    Error.throwWithStackTrace(error, firstStackTrace!);
  }
}
```

`_syncState()` 继续从 `_videoController.value` 更新 `MoviePreviewPlaybackState`。

- [ ] **Step 6: 运行适配器和既有生命周期测试并确认 GREEN**

Run:

```bash
flutter test test/features/movie_detail/movie_preview_playback_test.dart
flutter test test/features/movie_detail/movie_preview_screen_test.dart
```

Expected: 新适配器测试全部通过；既有页面生命周期测试仅可能因默认工厂仍引用旧类名而失败，该引用在本任务内改为 `ChewieMoviePreviewPlayback.new` 后必须全部通过。

- [ ] **Step 7: 格式化并提交**

```bash
dart format lib/features/movie_detail/services/movie_preview_playback.dart test/features/movie_detail/movie_preview_playback_test.dart test/features/movie_detail/movie_preview_screen_test.dart
git add pubspec.yaml pubspec.lock lib/features/movie_detail/services/movie_preview_playback.dart test/features/movie_detail/movie_preview_playback_test.dart test/features/movie_detail/movie_preview_screen_test.dart
git commit -m "feat: add Chewie preview playback adapter"
```

---

### Task 2: 建立只处理双击和长按的手势层

**Files:**

- Create: `lib/features/movie_detail/widgets/movie_preview_gesture_layer.dart`
- Create: `test/features/movie_detail/movie_preview_gesture_layer_test.dart`

**Interfaces:**

- Consumes:
  - `Widget child`：Task 1 的 `Chewie` 视图。
  - `Future<void> Function() onTogglePlayback`：由页面根据底层当前状态切换播放或暂停。
  - `Future<void> Function(double speed) onSetPlaybackSpeed`：页面级 session 安全倍速命令。
  - `Future<void> Function() onSpeedRecoveryFailure`：恢复 `1.0×` 失败后的页面处置。
- Produces:
  - `MoviePreviewGestureLayer`。
  - 固定手势面 key：`Key('movie-preview-gesture-surface')`。
  - 倍速成功期间的 `Text('2.0×')`。
- 不注册 `onTap`，不依赖 `MoviePreviewPlaybackState`，不实现播放按钮、进度、时间、缓冲或自动隐藏。

- [ ] **Step 1: 写外层手势契约失败测试**

创建 `test/features/movie_detail/movie_preview_gesture_layer_test.dart`，先加入单击透传、双击和基础长按测试：

```dart
import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/features/movie_detail/widgets/movie_preview_gesture_layer.dart';

void main() {
  testWidgets('单击透传给子树且外层不切换播放', (tester) async {
    var childTapCalls = 0;
    var toggleCalls = 0;
    await tester.pumpWidget(
      _buildLayer(
        child: GestureDetector(
          onTap: () => childTapCalls++,
          child: const ColoredBox(color: Colors.black),
        ),
        onTogglePlayback: () async => toggleCalls++,
      ),
    );

    await tester.tapAt(_surfacePoint(tester));
    await tester.pump(kDoubleTapTimeout);

    expect(childTapCalls, 1);
    expect(toggleCalls, 0);
  });

  testWidgets('双击只调用一次播放切换', (tester) async {
    var toggleCalls = 0;
    await tester.pumpWidget(
      _buildLayer(onTogglePlayback: () async => toggleCalls++),
    );

    final point = _surfacePoint(tester);
    await tester.tapAt(point);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(point);
    await tester.pump();

    expect(toggleCalls, 1);
    await tester.pump(kDoubleTapTimeout);
  });

  testWidgets('长按成功显示 2.0× 且松手恢复 1.0×', (tester) async {
    final speeds = <double>[];
    await tester.pumpWidget(
      _buildLayer(onSetPlaybackSpeed: (speed) async => speeds.add(speed)),
    );

    final gesture = await tester.startGesture(_surfacePoint(tester));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    expect(speeds, [2.0]);
    expect(find.text('2.0×'), findsOneWidget);

    await gesture.up();
    await tester.pump();
    expect(speeds, [2.0, 1.0]);
    expect(find.text('2.0×'), findsNothing);
  });
}
```

测试辅助方法固定为：

```dart
Widget _buildLayer({
  Widget child = const ColoredBox(color: Colors.black),
  Future<void> Function()? onTogglePlayback,
  Future<void> Function(double speed)? onSetPlaybackSpeed,
  Future<void> Function()? onSpeedRecoveryFailure,
}) {
  return MaterialApp(
    home: Scaffold(
      body: MoviePreviewGestureLayer(
        onTogglePlayback: onTogglePlayback ?? () async {},
        onSetPlaybackSpeed: onSetPlaybackSpeed ?? (_) async {},
        onSpeedRecoveryFailure: onSpeedRecoveryFailure ?? () async {},
        child: child,
      ),
    ),
  );
}

Offset _surfacePoint(WidgetTester tester) {
  return tester.getCenter(
    find.byKey(const Key('movie-preview-gesture-surface')),
  );
}
```

- [ ] **Step 2: 运行基础手势测试并确认 RED**

Run:

```bash
flutter test test/features/movie_detail/movie_preview_gesture_layer_test.dart
```

Expected: 编译失败，指出 `movie_preview_gesture_layer.dart` 和 `MoviePreviewGestureLayer` 尚不存在。

- [ ] **Step 3: 写最小手势层并确认基础测试 GREEN**

创建 `movie_preview_gesture_layer.dart`，先实现公开边界与基础交互：

```dart
import 'dart:async';

import 'package:flutter/material.dart';

class MoviePreviewGestureLayer extends StatefulWidget {
  const MoviePreviewGestureLayer({
    super.key,
    required this.child,
    required this.onTogglePlayback,
    required this.onSetPlaybackSpeed,
    required this.onSpeedRecoveryFailure,
  });

  final Widget child;
  final Future<void> Function() onTogglePlayback;
  final Future<void> Function(double speed) onSetPlaybackSpeed;
  final Future<void> Function() onSpeedRecoveryFailure;

  @override
  State<MoviePreviewGestureLayer> createState() =>
      _MoviePreviewGestureLayerState();
}
```

`build()` 只包含手势面、Chewie 子树和倍速提示：

```dart
@override
Widget build(BuildContext context) {
  return Stack(
    fit: StackFit.expand,
    children: [
      GestureDetector(
        key: const Key('movie-preview-gesture-surface'),
        behavior: HitTestBehavior.opaque,
        onDoubleTap: () => unawaited(_togglePlayback()),
        onLongPress: _startLongPress,
        onLongPressEnd: (_) => _finishLongPress(),
        onLongPressCancel: _finishLongPress,
        child: widget.child,
      ),
      if (_isDoubleSpeedConfirmed)
        const Center(child: _MoviePreviewSpeedIndicator()),
    ],
  );
}
```

`_togglePlayback()` 捕获命令错误，确保 GestureDetector 回调不产生未处理 Future：

```dart
Future<void> _togglePlayback() async {
  try {
    await widget.onTogglePlayback();
  } catch (_) {}
}
```

Run:

```bash
flutter test test/features/movie_detail/movie_preview_gesture_layer_test.dart
```

Expected: 单击透传、双击和基础长按测试通过。

- [ ] **Step 4: 写倍速竞态、错误和销毁失败测试**

在同一测试文件继续加入：

```dart
testWidgets('长按取消只恢复一次 1.0×', (tester) async {
  final speeds = <double>[];
  await tester.pumpWidget(
    _buildLayer(onSetPlaybackSpeed: (speed) async => speeds.add(speed)),
  );

  final gesture = await tester.startGesture(_surfacePoint(tester));
  await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
  await gesture.cancel();
  await tester.pump();

  expect(speeds, [2.0, 1.0]);
});

testWidgets('2.0× 延迟时提前松手最终串行恢复 1.0×', (tester) async {
  final allowDoubleSpeed = Completer<void>();
  final speeds = <double>[];
  var appliedSpeed = 1.0;
  await tester.pumpWidget(
    _buildLayer(
      onSetPlaybackSpeed: (speed) async {
        speeds.add(speed);
        if (speed == 2.0) {
          await allowDoubleSpeed.future;
        }
        appliedSpeed = speed;
      },
    ),
  );

  final gesture = await tester.startGesture(_surfacePoint(tester));
  await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
  await gesture.up();
  allowDoubleSpeed.complete();
  await tester.pump();
  await tester.pump();

  expect(speeds, [2.0, 1.0]);
  expect(appliedSpeed, 1.0);
  expect(find.text('2.0×'), findsNothing);
});

testWidgets('设置 2.0× 失败不显示提示且不进入恢复错误', (tester) async {
  var recoveryFailureCalls = 0;
  await tester.pumpWidget(
    _buildLayer(
      onSetPlaybackSpeed: (speed) async {
        if (speed == 2.0) throw StateError('set 2x failed');
      },
      onSpeedRecoveryFailure: () async => recoveryFailureCalls++,
    ),
  );

  final gesture = await tester.startGesture(_surfacePoint(tester));
  await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
  expect(find.text('2.0×'), findsNothing);
  await gesture.up();
  await tester.pump();

  expect(recoveryFailureCalls, 0);
  expect(tester.takeException(), isNull);
});

testWidgets('恢复 1.0× 失败通知页面一次并隐藏错误倍速提示', (tester) async {
  var recoveryFailureCalls = 0;
  await tester.pumpWidget(
    _buildLayer(
      onSetPlaybackSpeed: (speed) async {
        if (speed == 1.0) throw StateError('restore failed');
      },
      onSpeedRecoveryFailure: () async => recoveryFailureCalls++,
    ),
  );

  final gesture = await tester.startGesture(_surfacePoint(tester));
  await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
  await gesture.up();
  await tester.pump();
  await tester.pump();

  expect(recoveryFailureCalls, 1);
  expect(find.text('2.0×'), findsNothing);
  expect(tester.takeException(), isNull);
});

testWidgets('长按中销毁且恢复失败不产生异步异常', (tester) async {
  final speeds = <double>[];
  await tester.pumpWidget(
    _buildLayer(
      onSetPlaybackSpeed: (speed) async {
        speeds.add(speed);
        if (speed == 1.0) throw StateError('dispose restore failed');
      },
    ),
  );

  await tester.startGesture(_surfacePoint(tester));
  await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
  await tester.pumpWidget(const SizedBox());
  await tester.pump();

  expect(speeds, [2.0, 1.0]);
  expect(tester.takeException(), isNull);
});
```

- [ ] **Step 5: 实现串行倍速状态机**

在 `_MoviePreviewGestureLayerState` 中加入：

```dart
bool _isLongPressing = false;
bool _isDoubleSpeedConfirmed = false;
Future<void> _speedTransitions = Future<void>.value();
int _speedGestureGeneration = 0;
final _queuedSpeedRestores = <int>{};
```

长按开始必须排入 `2.0×` 命令，并在命令返回后重新检查 widget 是否仍存在、generation 是否一致及手势是否仍有效：

```dart
void _startLongPress() {
  if (_isLongPressing) return;
  final generation = ++_speedGestureGeneration;
  setState(() {
    _isLongPressing = true;
    _isDoubleSpeedConfirmed = false;
  });
  _enqueueSpeedTransition(() async {
    try {
      await widget.onSetPlaybackSpeed(2.0);
    } catch (_) {
      return;
    }
    if (!mounted ||
        generation != _speedGestureGeneration ||
        !_isLongPressing) {
      return;
    }
    setState(() {
      _isDoubleSpeedConfirmed = true;
    });
  });
}
```

松手、取消和销毁必须共享同一恢复入口：

```dart
void _finishLongPress() {
  if (!_isLongPressing) return;
  final generation = _speedGestureGeneration;
  setState(() {
    _isLongPressing = false;
  });
  _queueDefaultSpeedRestore(generation);
}

void _queueDefaultSpeedRestore(int generation) {
  if (!_queuedSpeedRestores.add(generation)) return;
  _enqueueSpeedTransition(() async {
    try {
      await widget.onSetPlaybackSpeed(1.0);
      if (!mounted || generation != _speedGestureGeneration) return;
      setState(() {
        _isDoubleSpeedConfirmed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _speedGestureGeneration++;
        _isLongPressing = false;
        _isDoubleSpeedConfirmed = false;
      });
      try {
        await widget.onSpeedRecoveryFailure();
      } catch (_) {}
    } finally {
      _queuedSpeedRestores.remove(generation);
    }
  });
}

void _enqueueSpeedTransition(Future<void> Function() transition) {
  final result = _speedTransitions.then((_) => transition());
  _speedTransitions = result.then<void>(
    (_) {},
    onError: (Object _, StackTrace _) {},
  );
  unawaited(_speedTransitions);
}
```

销毁时不得 `setState`，但必须尝试把已经进入长按或已经确认的倍速恢复到 `1.0×`：

```dart
@override
void dispose() {
  if (_isLongPressing || _isDoubleSpeedConfirmed) {
    _isLongPressing = false;
    _queueDefaultSpeedRestore(_speedGestureGeneration);
  }
  super.dispose();
}
```

倍速提示使用黑色高对比背景：

```dart
class _MoviePreviewSpeedIndicator extends StatelessWidget {
  const _MoviePreviewSpeedIndicator();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text('2.0×', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}
```

- [ ] **Step 6: 运行手势层测试并确认 GREEN**

Run:

```bash
flutter test test/features/movie_detail/movie_preview_gesture_layer_test.dart
```

Expected: 单击透传、双击、松手、取消、延迟命令、切换失败、恢复失败和销毁安全测试全部通过。

- [ ] **Step 7: 格式化并提交**

```bash
dart format lib/features/movie_detail/widgets/movie_preview_gesture_layer.dart test/features/movie_detail/movie_preview_gesture_layer_test.dart
git add lib/features/movie_detail/widgets/movie_preview_gesture_layer.dart test/features/movie_detail/movie_preview_gesture_layer_test.dart
git commit -m "feat: add movie preview gesture layer"
```

---

### Task 3: 页面接入 Chewie 并删除旧自定义控制层

**Files:**

- Modify: `lib/features/movie_detail/screens/movie_preview_screen.dart`
- Modify: `test/features/movie_detail/movie_preview_screen_test.dart`
- Delete: `lib/features/movie_detail/widgets/movie_preview_controls.dart`
- Delete: `test/features/movie_detail/movie_preview_controls_test.dart`

**Interfaces:**

- Consumes:
  - Task 1 的 `ChewieMoviePreviewPlayback.new` 和 `MoviePreviewPlayback.buildView()`。
  - Task 2 的 `MoviePreviewGestureLayer`。
- Produces:
  - `MoviePreviewPage` 对外构造参数保持不变。
  - 正常态：Chewie 原生控制层、外层双击/长按、`MoviePreviewHeader`。
  - 错误态：`预告片播放失败`、`重试`、返回按钮和标题。
  - `Future<void> _handleSpeedRecoveryFailure()`：暂停当前 session，并在仍是当前 session 时进入错误页。
- `MoviePreviewHeader` 从被删除的旧控制层文件迁移到 `movie_preview_screen.dart`，保持 `返回` tooltip、单行标题和 `Semantics(header: true)`。

- [ ] **Step 1: 写页面媒体错误与倍速恢复失败测试**

在 `test/features/movie_detail/movie_preview_screen_test.dart` 的 `_FakePlayback` 增加可注入的倍速命令：

```dart
_FakePlayback({
  this.initializeError,
  this.initializeCompleter,
  this.seekCompleter,
  this.disposeCompleter,
  this.onSetPlaybackSpeed,
  this.initialState = const MoviePreviewPlaybackState(),
});

final Future<void> Function(double speed)? onSetPlaybackSpeed;

@override
Future<void> setPlaybackSpeed(double speed) async {
  speedCalls.add(speed);
  await onSetPlaybackSpeed?.call(speed);
}

void emit(MoviePreviewPlaybackState value) {
  _state.value = value;
}
```

加入媒体错误测试：

```dart
testWidgets('播放中底层媒体错误切换到可退出可重试页面', (tester) async {
  final playback = _FakePlayback();
  await _pumpPreviewPage(tester, playback);

  playback.emit(
    const MoviePreviewPlaybackState(
      isInitialized: true,
      errorDescription: 'media error',
    ),
  );
  await tester.pump();

  expect(find.text('预告片播放失败'), findsOneWidget);
  expect(find.text('重试'), findsOneWidget);
  expect(find.byTooltip('返回'), findsOneWidget);
  expect(
    find.byKey(const Key('movie-preview-gesture-surface')),
    findsNothing,
  );
});
```

加入倍速恢复失败页面处置测试：

```dart
testWidgets('长按恢复 1.0× 失败会暂停并进入可重试错误页', (tester) async {
  final playback = _FakePlayback(
    initialState: const MoviePreviewPlaybackState(
      isInitialized: true,
      isPlaying: true,
    ),
    onSetPlaybackSpeed: (speed) async {
      if (speed == 1.0) throw StateError('restore failed');
    },
  );
  await _pumpPreviewPage(tester, playback);

  final gesture = await tester.startGesture(_backgroundPoint(tester));
  await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
  await gesture.up();
  await tester.pump();
  await tester.pump();

  expect(playback.speedCalls, [2.0, 1.0]);
  expect(playback.pauseCalls, 1);
  expect(find.text('预告片播放失败'), findsOneWidget);
  expect(find.text('重试'), findsOneWidget);
  expect(tester.takeException(), isNull);
});
```

既有以下测试必须保留，不得以 Chewie 已有控制能力为理由删除：

- 横屏成功后才初始化和自动播放；
- 横屏失败不创建 playback；
- 初始化失败重试替换 playback；
- 清理永不完成时重试仍有界继续；
- 页面退出立即释放 orientation lease；
- 完成态双击先 seek 到零再播放；
- 暂停态双击播放、播放态双击暂停；
- 加载和错误页都能返回；
- 页面 A 的延迟方向恢复不覆盖页面 B。

- [ ] **Step 2: 运行页面测试并确认 RED**

Run:

```bash
flutter test test/features/movie_detail/movie_preview_screen_test.dart --plain-name '播放中底层媒体错误切换到可退出可重试页面'
flutter test test/features/movie_detail/movie_preview_screen_test.dart --plain-name '长按恢复 1.0× 失败会暂停并进入可重试错误页'
```

Expected:

- 媒体错误仍由旧 `MoviePreviewControls` 渲染，手势面仍存在，不是页面错误壳；
- 倍速恢复失败尚未通过页面级回调暂停 session；
- 至少一个断言失败，证明新页面集成尚未存在。

- [ ] **Step 3: 将页面默认驱动切换为 Chewie**

替换 import：

```dart
import 'package:jade/features/movie_detail/widgets/movie_preview_gesture_layer.dart';
```

删除对 `movie_preview_controls.dart` 的 import，并将默认工厂改为：

```dart
MoviePreviewPlaybackFactory get _playbackFactory =>
    widget.playbackFactory ?? ChewieMoviePreviewPlayback.new;
```

- [ ] **Step 4: 用 Chewie 视图和手势层替换正常播放布局**

把正常播放分支拆成 `_buildPlaybackBody`，以 `ValueListenableBuilder.child` 保持同一个 Chewie 子树，避免视频 position 更新时反复创建视图：

```dart
Widget _buildBody() {
  final session = _session;
  if (!_isLoading && !_hasError && session != null) {
    return _buildPlaybackBody(session);
  }
  return _buildStatusBody(hasError: _hasError);
}

Widget _buildPlaybackBody(_PlaybackSession session) {
  final playback = session.playback;
  return ValueListenableBuilder<MoviePreviewPlaybackState>(
    valueListenable: playback.state,
    child: Stack(
      fit: StackFit.expand,
      children: [
        MoviePreviewGestureLayer(
          onTogglePlayback: _togglePlayback,
          onSetPlaybackSpeed: _setPlaybackSpeed,
          onSpeedRecoveryFailure: _handleSpeedRecoveryFailure,
          child: playback.buildView(),
        ),
        SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: MoviePreviewHeader(
              title: _title,
              onBack: () => Navigator.of(context).pop(),
            ),
          ),
        ),
      ],
    ),
    builder: (context, state, child) {
      if (state.errorDescription?.isNotEmpty ?? false) {
        return _buildStatusBody(hasError: true);
      }
      return child!;
    },
  );
}
```

将现有加载/错误 Stack 提取为 `_buildStatusBody`，保持中文文案和返回入口：

```dart
Widget _buildStatusBody({required bool hasError}) {
  return Stack(
    fit: StackFit.expand,
    children: [
      Center(
        child: hasError
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '预告片播放失败',
                    style: TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _isRetrying ? null : _retry,
                    child: const Text('重试'),
                  ),
                ],
              )
            : const CircularProgressIndicator(color: Colors.white),
      ),
      SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: MoviePreviewHeader(
            title: _title,
            onBack: () => Navigator.of(context).pop(),
          ),
        ),
      ),
    ],
  );
}
```

- [ ] **Step 5: 实现倍速恢复失败的页面级处置**

新增不抛异常的当前命令判断：

```dart
bool _isCommandCurrent(_PlaybackCommand command) {
  return mounted &&
      command.generation == _lifecycleGeneration &&
      identical(_session, command.session);
}

void _ensureCommandIsCurrent(_PlaybackCommand command) {
  if (!_isCommandCurrent(command)) {
    throw const _PlaybackCommandInvalidated();
  }
}
```

恢复 `1.0×` 失败时尝试暂停；无论暂停成功与否，只要 session 仍然有效就进入页面错误态：

```dart
Future<void> _handleSpeedRecoveryFailure() async {
  final command = _currentCommand();
  if (command == null) return;
  try {
    await command.session.playback.pause();
  } catch (_) {}
  if (_isCommandCurrent(command)) {
    _showPageError();
  }
}
```

页面 `dispose()` 和 `_retry()` 继续先增加 `_lifecycleGeneration`、摘除 `_session`，再分别执行有界 playback 清理与独立 orientation lease 释放；不得等待播放器 dispose 后才恢复方向。

- [ ] **Step 6: 迁移页面导航头并删除旧控制层**

把原 `MoviePreviewHeader` 的完整实现迁移到 `movie_preview_screen.dart`：

```dart
class MoviePreviewHeader extends StatelessWidget {
  const MoviePreviewHeader({
    super.key,
    required this.title,
    required this.onBack,
  });

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onBack,
          tooltip: '返回',
          color: Colors.white,
          icon: const Icon(Icons.arrow_back),
        ),
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}
```

删除：

```text
lib/features/movie_detail/widgets/movie_preview_controls.dart
test/features/movie_detail/movie_preview_controls_test.dart
```

确认不存在旧控制层引用：

```bash
rg -n "MoviePreviewControls|movie_preview_controls|_formatDuration|movie-preview-controls-overlay" lib test
```

Expected: 无输出。

- [ ] **Step 7: 运行页面与手势测试并确认 GREEN**

Run:

```bash
flutter test test/features/movie_detail/movie_preview_playback_test.dart
flutter test test/features/movie_detail/movie_preview_gesture_layer_test.dart
flutter test test/features/movie_detail/movie_preview_screen_test.dart
flutter test test/features/movie_detail/movie_preview_orientation_test.dart
```

Expected: Chewie 适配器、手势、页面生命周期和 orientation lease 测试全部通过，没有未处理 Future 或 `setState() called after dispose()`。

- [ ] **Step 8: 格式化并提交**

```bash
dart format lib/features/movie_detail/screens/movie_preview_screen.dart test/features/movie_detail/movie_preview_screen_test.dart
git add lib/features/movie_detail/screens/movie_preview_screen.dart test/features/movie_detail/movie_preview_screen_test.dart
git add -u lib/features/movie_detail/widgets/movie_preview_controls.dart test/features/movie_detail/movie_preview_controls_test.dart
git commit -m "refactor: use Chewie native preview controls"
```

---

### Task 4: 运行功能回归、静态分析与全量测试

**Files:**

- Verify only: `lib/features/movie_detail/**`
- Verify only: `lib/core/router/**`
- Verify only: `test/features/movie_detail/**`
- Verify only: `test/app_router_test.dart`

**Interfaces:**

- Consumes: Task 1–3 的三个提交。
- Produces: 无代码；输出聚焦测试、静态分析和完整测试的可追溯结果。

- [ ] **Step 1: 检查依赖版本和旧控制层残留**

Run:

```bash
rg -n "chewie|video_player" pubspec.lock
rg -n "MoviePreviewControls|movie_preview_controls|movie-preview-controls-overlay" lib test
git diff --check
```

Expected:

- 依赖树包含 Chewie `1.13.1` 与 video_player `2.10.1`；
- 旧控制层搜索无输出；
- `git diff --check` 无输出。

- [ ] **Step 2: 运行预告片聚焦测试**

Run:

```bash
flutter test test/features/movie_detail/movie_preview_playback_test.dart test/features/movie_detail/movie_preview_gesture_layer_test.dart test/features/movie_detail/movie_preview_screen_test.dart test/features/movie_detail/movie_preview_orientation_test.dart
```

Expected: 所有预告片播放器测试通过。

- [ ] **Step 3: 运行详情入口与路由回归**

Run:

```bash
flutter test test/features/movie_detail/movie_detail_screen_test.dart test/app_router_test.dart
```

Expected:

- 有预告地址时封面仍位于剧照列表首位并显示播放图标；
- 无预告地址时不插入封面；
- 点击预告入口仍传递 `MoviePreviewArgs`；
- 预告封面不进入图库，剧照索引保持原值；
- 路由缺少 typed extra 时仍进入可退出错误页。

- [ ] **Step 4: 运行静态分析**

Run:

```bash
flutter analyze
```

Expected: `No issues found!`

- [ ] **Step 5: 运行完整测试**

Run:

```bash
flutter test
```

Expected: 完整测试套件全部通过；记录测试总数与命令输出，不以“未发现测试”作为通过。

- [ ] **Step 6: 确认工作树只包含计划内提交**

Run:

```bash
git status --short
git log --oneline b334aa5..HEAD
```

Expected:

- 工作树干净；
- 新增提交只对应 Chewie 播放适配器、手势层和页面重构。

---

### Task 5: 构建 Debug APK 并安装到 Android 模拟器

**Files:**

- Build artifact: `build/app/outputs/flutter-apk/app-debug.apk`
- No source changes.

**Interfaces:**

- Consumes: 已通过 Task 4 的干净功能分支。
- Produces: 安装到 `emulator-5554` 的 `xxx.porn.jdb` Debug 应用，以及真实设备交互验收记录。

- [ ] **Step 1: 确认目标模拟器在线**

Run:

```bash
adb devices -l
```

Expected: `emulator-5554` 状态为 `device`。若设备序列号变化，先从此命令取得唯一在线 emulator 序列号，再替换后续 `-s` 参数；不得安装到未确认的物理设备。

- [ ] **Step 2: 使用 Flutter 构建 Debug APK**

Run:

```bash
flutter build apk --debug
```

Expected:

- 构建成功；
- 产物为 `build/app/outputs/flutter-apk/app-debug.apk`。

- [ ] **Step 3: 覆盖安装并启动应用**

Run:

```bash
adb -s emulator-5554 install -r build/app/outputs/flutter-apk/app-debug.apk
adb -s emulator-5554 shell am force-stop xxx.porn.jdb
adb -s emulator-5554 shell am start -n xxx.porn.jdb/.MainActivity
```

Expected:

- 安装返回 `Success`；
- Activity 启动返回 `Starting: Intent`；
- 应用前台显示且没有启动崩溃。

- [ ] **Step 4: 核对安装包和运行状态**

Run:

```bash
adb -s emulator-5554 shell dumpsys package xxx.porn.jdb
adb -s emulator-5554 shell pidof xxx.porn.jdb
```

Expected:

- package 信息包含 `versionName=0.8.0` 与 `versionCode=800`；
- `pidof` 返回进程号。

- [ ] **Step 5: 验收真实预告片交互**

在模拟器中打开一部具有 `preview_video_url` 的影片详情，逐项确认：

1. 剧照列表首项为影片封面并带播放图标；
2. 点击后直接进入横屏播放页，不出现竖屏播放阶段；
3. 画面使用 Chewie Material 原生播放按钮、进度条、音量和缓冲状态；
4. 原生控制层播放中约 3 秒自动隐藏，单击仍可显示或隐藏；
5. 双击播放画面可切换播放/暂停；
6. 长按识别后显示 `2.0×` 并以 2 倍速播放，松手后恢复 `1.0×`；
7. Chewie 不显示倍速选项、不打开第二层全屏路由；
8. 返回详情页后恢复应用默认方向；
9. 网络或媒体失败时显示“预告片播放失败”和“重试”，返回按钮仍可用。

若任一项失败，记录具体步骤、画面状态与 `adb logcat` 中的首个相关异常，回到对应任务按 RED → GREEN 修复，再重新执行 Task 4 和 Task 5。
