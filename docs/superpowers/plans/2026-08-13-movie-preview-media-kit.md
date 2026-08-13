# 影片预告片播放器 Media Kit 替换实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 用 media_kit 替换预告片播放器的 chewie + video_player，保留长按 2×、双击播放/暂停、标题自动显隐三个自定义行为，其余保持 media_kit 默认。

**Architecture:** 三层边界不变：页面层（横屏 lease、生命周期、错误重试）→ `MediaKitMoviePreviewPlayback`（`Player` + `VideoController`，状态流映射为 `MoviePreviewPlaybackState`）→ 内置 `MaterialVideoControls`。双击由页面级 `Listener` 原始事件检测实现，头部显隐由页面级 overlay 组件实现。

**Tech Stack:** Flutter + Dart，media_kit 1.2.6 / media_kit_video 2.0.1 / media_kit_libs_android_video 1.3.8，wakelock_plus（保留）。

## Global Constraints

- 项目声明 Dart SDK 下限 `sdk: ^3.8.0`，依赖必须兼容该下限（media_kit 1.2.6 要求 `>=3.1.0`，兼容）。
- 依赖版本精确值：`media_kit: ^1.2.6`、`media_kit_video: ^2.0.1`、`media_kit_libs_android_video: ^1.3.8`；最终移除 `chewie`、`video_player`、`video_player_platform_interface`（dev）。
- 行为基线：只实现三个自定义行为（长按 2×、双击播放/暂停、标题自动显隐）；控制层其余全部 media_kit 默认（初始隐藏、保留全屏/上一个/下一个按钮、默认配色、无静音、无滑动手势、音量/亮度关闭）。
- 文案：中文硬编码，不使用 `.arb`/`flutter_localizations`，不新增本地化。
- 目录：所有改动在 `lib/features/movie_detail/` 内；不新增 feature 目录；不改 `lib/core/`。
- `MediaKit.ensureInitialized()` 只加在 `main()`，禁止加在 `mainForTest()`（测试运行在 VM）。
- 保留未跟踪的 `.zcode/` 目录与其它无关改动，只 stage 任务文件；不推送远端。
- 测试命令顺序：聚焦测试 → `flutter analyze` → 全量 `flutter test`；`/opt/homebrew/share/flutter` 下缓存写入失败属于环境问题，不算代码失败。
- 提交信息按仓库惯例：`chore:` / `feat:` / `refactor:` / `docs:` 前缀，中文描述可省略。

---

## 文件结构

- 修改 `pubspec.yaml`：先新增 media_kit 三件套（Task 1），最后移除 chewie/video_player（Task 4）。
- 修改 `lib/main.dart`：`main()` 加 `MediaKit.ensureInitialized()`（Task 1）。
- 新增 `lib/features/movie_detail/widgets/movie_preview_double_tap_detector.dart`：双击检测（Task 2）。
- 新增 `lib/features/movie_detail/widgets/movie_preview_header_overlay.dart`：头部自动显隐（Task 3）。
- 重写 `lib/features/movie_detail/services/movie_preview_playback.dart`：media_kit 适配器（Task 4）。
- 修改 `lib/features/movie_detail/screens/movie_preview_screen.dart`：接线双击检测与头部显隐，删除手势层与倍速命令（Task 4）。
- 删除 `lib/features/movie_detail/widgets/movie_preview_chewie_controls.dart`、`lib/features/movie_detail/widgets/movie_preview_gesture_layer.dart`（Task 4）。
- 测试：新增 `movie_preview_double_tap_detector_test.dart`（Task 2）、`movie_preview_header_overlay_test.dart`（Task 3）；重写 `movie_preview_playback_test.dart`（Task 4）；改造 `movie_preview_screen_test.dart`（Task 4）；删除 `movie_preview_chewie_controls_test.dart`、`movie_preview_gesture_layer_test.dart`（Task 4）。

---

### Task 1: 依赖与初始化

**Files:**
- Modify: `pubspec.yaml`
- Modify: `lib/main.dart`

**Interfaces:**
- Produces: 依赖 `package:media_kit/media_kit.dart`（`Player`、`Media`、`PlatformPlayer`、`PlayerConfiguration`、`Playable`）与 `package:media_kit_video/media_kit_video.dart`（`Video`、`VideoController`、`MaterialVideoControlsTheme`、`MaterialVideoControlsThemeData`、`MaterialVideoControls`）可供后续任务使用。

- [ ] **Step 1: pubspec.yaml 新增 media_kit 依赖（保留 chewie/video_player 不动）**

在 `dependencies:` 段中，把以下三行加到 `wakelock_plus: ^1.3.3` 之后：

```yaml
  media_kit: ^1.2.6
  media_kit_video: ^2.0.1
  media_kit_libs_android_video: ^1.3.8
```

本任务**不**删除 `chewie: ^1.13.1` 与 `video_player: ^2.14.0`（旧代码仍引用它们，删除放到 Task 4）。

- [ ] **Step 2: 拉取依赖并确认解析**

Run: `flutter pub get`

Expected: 成功，`pubspec.lock` 中出现 `media_kit 1.2.6`、`media_kit_video 2.0.1`、`media_kit_libs_android_video 1.3.8`，且 `chewie`、`video_player` 仍在。

- [ ] **Step 3: main() 初始化 media_kit**

修改 `lib/main.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';
```

并把 `main()` 改为：

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  runApp(await _buildEntry());
}
```

`mainForTest()` 保持原样，不添加任何 media_kit 调用。

- [ ] **Step 4: 验证**

Run: `flutter analyze`

Expected: 0 issues（旧代码未受影响，media_kit 仅被 `main.dart` 引用）。

Run: `flutter test test/features/movie_detail/movie_preview_args_test.dart`

Expected: 全部通过。

- [ ] **Step 5: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/main.dart
git commit -m "chore: add media kit dependencies and initialization"
```

---

### Task 2: 双击检测组件

**Files:**
- Create: `lib/features/movie_detail/widgets/movie_preview_double_tap_detector.dart`
- Test: `test/features/movie_detail/movie_preview_double_tap_detector_test.dart`

**Interfaces:**
- Produces: `MoviePreviewDoubleTapDetector({required Widget child, required VoidCallback onDoubleTap, Duration doubleTapWindow = const Duration(milliseconds: 300), double doubleTapSlop = 100.0, MoviePreviewClock clock = DateTime.now})`；`typedef MoviePreviewClock = DateTime Function();`
- Consumes: 无（只依赖 Flutter）。

- [ ] **Step 1: 写失败测试**

新建 `test/features/movie_detail/movie_preview_double_tap_detector_test.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/features/movie_detail/widgets/movie_preview_double_tap_detector.dart';

class _FakeClock {
  DateTime current = DateTime(2026, 8, 13, 12, 0, 0);
  DateTime call() => current;
}

Widget _wrap({
  required _FakeClock clock,
  required VoidCallback onDoubleTap,
  required Widget child,
}) {
  return MaterialApp(
    home: MoviePreviewDoubleTapDetector(
      clock: clock.call,
      onDoubleTap: onDoubleTap,
      child: child,
    ),
  );
}

void main() {
  testWidgets('间隔不超过 300ms 且位置接近的两次按下触发一次回调', (tester) async {
    final clock = _FakeClock();
    var calls = 0;
    await tester.pumpWidget(
      _wrap(
        clock: clock,
        onDoubleTap: () => calls++,
        child: const SizedBox.expand(),
      ),
    );

    await tester.tapAt(const Offset(100, 100));
    clock.current = clock.current.add(const Duration(milliseconds: 200));
    await tester.tapAt(const Offset(105, 102));

    expect(calls, 1);
  });

  testWidgets('两次按下超过 300ms 不触发', (tester) async {
    final clock = _FakeClock();
    var calls = 0;
    await tester.pumpWidget(
      _wrap(
        clock: clock,
        onDoubleTap: () => calls++,
        child: const SizedBox.expand(),
      ),
    );

    await tester.tapAt(const Offset(100, 100));
    clock.current = clock.current.add(const Duration(milliseconds: 301));
    await tester.tapAt(const Offset(100, 100));

    expect(calls, 0);
  });

  testWidgets('两次按下位置差超过 100 不触发', (tester) async {
    final clock = _FakeClock();
    var calls = 0;
    await tester.pumpWidget(
      _wrap(
        clock: clock,
        onDoubleTap: () => calls++,
        child: const SizedBox.expand(),
      ),
    );

    await tester.tapAt(const Offset(100, 100));
    clock.current = clock.current.add(const Duration(milliseconds: 100));
    await tester.tapAt(const Offset(250, 100));

    expect(calls, 0);
  });

  testWidgets('第二指针按下时清除历史，之后单击不再误判', (tester) async {
    final clock = _FakeClock();
    var calls = 0;
    await tester.pumpWidget(
      _wrap(
        clock: clock,
        onDoubleTap: () => calls++,
        child: const SizedBox.expand(),
      ),
    );

    await tester.tapAt(const Offset(100, 100));
    clock.current = clock.current.add(const Duration(milliseconds: 301));

    final first = await tester.startGesture(const Offset(100, 100));
    final second = await tester.startGesture(const Offset(300, 300));
    await first.up();
    await second.up();
    await tester.pump();

    await tester.tapAt(const Offset(100, 100));

    expect(calls, 0);
  });

  testWidgets('触发后历史复位，随后的双击再次触发', (tester) async {
    final clock = _FakeClock();
    var calls = 0;
    await tester.pumpWidget(
      _wrap(
        clock: clock,
        onDoubleTap: () => calls++,
        child: const SizedBox.expand(),
      ),
    );

    await tester.tapAt(const Offset(100, 100));
    clock.current = clock.current.add(const Duration(milliseconds: 100));
    await tester.tapAt(const Offset(100, 100));
    expect(calls, 1);

    clock.current = clock.current.add(const Duration(milliseconds: 500));
    await tester.tapAt(const Offset(100, 100));
    clock.current = clock.current.add(const Duration(milliseconds: 100));
    await tester.tapAt(const Offset(100, 100));

    expect(calls, 2);
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/features/movie_detail/movie_preview_double_tap_detector_test.dart`

Expected: FAIL，报 `movie_preview_double_tap_detector.dart` 找不到（组件还不存在）。

- [ ] **Step 3: 实现组件**

新建 `lib/features/movie_detail/widgets/movie_preview_double_tap_detector.dart`：

```dart
import 'package:flutter/material.dart';

typedef MoviePreviewClock = DateTime Function();

/// 页面级原始事件双击检测。
///
/// [Listener] 不参与手势竞技场，因此不会影响子树内的手势识别（如
/// media_kit 内置控制层的单击、长按与拖动）；只在指针按下事件序列满足
/// 双击条件时触发 [onDoubleTap]。
class MoviePreviewDoubleTapDetector extends StatefulWidget {
  const MoviePreviewDoubleTapDetector({
    super.key,
    required this.child,
    required this.onDoubleTap,
    this.doubleTapWindow = const Duration(milliseconds: 300),
    this.doubleTapSlop = 100.0,
    this.clock = DateTime.now,
  });

  final Widget child;
  final VoidCallback onDoubleTap;
  final Duration doubleTapWindow;
  final double doubleTapSlop;
  final MoviePreviewClock clock;

  @override
  State<MoviePreviewDoubleTapDetector> createState() =>
      _MoviePreviewDoubleTapDetectorState();
}

class _MoviePreviewDoubleTapDetectorState
    extends State<MoviePreviewDoubleTapDetector> {
  final _activePointers = <int>{};
  DateTime? _lastTapDownAt;
  Offset? _lastTapDownPosition;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _handlePointerDown,
      onPointerUp: _handlePointerUp,
      onPointerCancel: _handlePointerCancel,
      child: widget.child,
    );
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (_activePointers.isNotEmpty) {
      _lastTapDownAt = null;
      _lastTapDownPosition = null;
      _activePointers.add(event.pointer);
      return;
    }
    _activePointers.add(event.pointer);

    final now = widget.clock();
    final lastAt = _lastTapDownAt;
    final lastPosition = _lastTapDownPosition;
    if (lastAt != null &&
        lastPosition != null &&
        now.difference(lastAt) <= widget.doubleTapWindow &&
        (event.position - lastPosition).distance <= widget.doubleTapSlop) {
      _lastTapDownAt = null;
      _lastTapDownPosition = null;
      widget.onDoubleTap();
    } else {
      _lastTapDownAt = now;
      _lastTapDownPosition = event.position;
    }
  }

  void _handlePointerUp(PointerUpEvent event) {
    _activePointers.remove(event.pointer);
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    _activePointers.remove(event.pointer);
  }
}
```

- [ ] **Step 4: 运行测试确认通过**

Run: `flutter test test/features/movie_detail/movie_preview_double_tap_detector_test.dart`

Expected: PASS（5 个用例）。

- [ ] **Step 5: Commit**

```bash
git add lib/features/movie_detail/widgets/movie_preview_double_tap_detector.dart test/features/movie_detail/movie_preview_double_tap_detector_test.dart
git commit -m "feat: add double tap detector for movie preview"
```

---

### Task 3: 头部自动显隐组件

**Files:**
- Create: `lib/features/movie_detail/widgets/movie_preview_header_overlay.dart`
- Test: `test/features/movie_detail/movie_preview_header_overlay_test.dart`

**Interfaces:**
- Consumes: `MoviePreviewPlaybackState`（来自 `lib/features/movie_detail/services/movie_preview_playback.dart`，本任务不修改该文件）、`MoviePreviewHeader`（来自 `lib/features/movie_detail/widgets/movie_preview_header.dart`）。
- Produces: `MoviePreviewHeaderOverlay({required String title, required VoidCallback onBack, required ValueListenable<MoviePreviewPlaybackState> state, Duration hideDelay = const Duration(seconds: 3)})`，含 `static const headerOpacityKey = Key('movie-preview-header-opacity')`。

- [ ] **Step 1: 写失败测试**

新建 `test/features/movie_detail/movie_preview_header_overlay_test.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/features/movie_detail/services/movie_preview_playback.dart';
import 'package:jade/features/movie_detail/widgets/movie_preview_header_overlay.dart';

MoviePreviewPlaybackState _state({
  bool playing = true,
  bool buffering = false,
  bool completed = false,
  String? error,
}) {
  return MoviePreviewPlaybackState(
    isInitialized: true,
    isPlaying: playing,
    isBuffering: buffering,
    isCompleted: completed,
    errorDescription: error,
  );
}

Widget _wrap(ValueNotifier<MoviePreviewPlaybackState> notifier) {
  return MaterialApp(
    home: MoviePreviewHeaderOverlay(
      title: '测试影片',
      onBack: () {},
      state: notifier,
    ),
  );
}

double _opacity(WidgetTester tester) {
  return tester
      .widget<AnimatedOpacity>(
        find.byKey(MoviePreviewHeaderOverlay.headerOpacityKey),
      )
      .opacity;
}

bool _ignoring(WidgetTester tester) {
  return tester
      .widget<IgnorePointer>(
        find.ancestor(
          of: find.byKey(MoviePreviewHeaderOverlay.headerOpacityKey),
          matching: find.byType(IgnorePointer),
        ),
      )
      .ignoring;
}

void main() {
  testWidgets('渲染标题与返回按钮', (tester) async {
    final notifier = ValueNotifier(_state(playing: false));
    await tester.pumpWidget(_wrap(notifier));

    expect(find.text('测试影片'), findsOneWidget);
    expect(find.byTooltip('返回'), findsOneWidget);
    expect(_opacity(tester), 1.0);

    await tester.pumpWidget(const SizedBox());
    notifier.dispose();
  });

  testWidgets('播放中 3 秒后隐藏', (tester) async {
    final notifier = ValueNotifier(_state());
    await tester.pumpWidget(_wrap(notifier));

    await tester.pump(const Duration(seconds: 2));
    expect(_opacity(tester), 1.0);

    await tester.pump(const Duration(seconds: 1));
    expect(_opacity(tester), 0.0);
    expect(_ignoring(tester), isTrue);

    await tester.pumpWidget(const SizedBox());
    notifier.dispose();
  });

  testWidgets('暂停立即显示', (tester) async {
    final notifier = ValueNotifier(_state());
    await tester.pumpWidget(_wrap(notifier));
    await tester.pump(const Duration(seconds: 3));
    expect(_opacity(tester), 0.0);

    notifier.value = _state(playing: false);
    await tester.pump();

    expect(_opacity(tester), 1.0);
    expect(_ignoring(tester), isFalse);

    await tester.pumpWidget(const SizedBox());
    notifier.dispose();
  });

  testWidgets('缓冲中不隐藏', (tester) async {
    final notifier = ValueNotifier(_state(buffering: true));
    await tester.pumpWidget(_wrap(notifier));
    await tester.pump(const Duration(seconds: 4));

    expect(_opacity(tester), 1.0);

    await tester.pumpWidget(const SizedBox());
    notifier.dispose();
  });

  testWidgets('完成态与错误态保持显示', (tester) async {
    for (final state in [
      _state(playing: false, completed: true),
      _state(playing: false, error: 'media error'),
    ]) {
      final notifier = ValueNotifier(state);
      await tester.pumpWidget(_wrap(notifier));
      await tester.pump(const Duration(seconds: 4));

      expect(_opacity(tester), 1.0);

      await tester.pumpWidget(const SizedBox());
      notifier.dispose();
    }
  });

  testWidgets('重新进入播放状态重新计时', (tester) async {
    final notifier = ValueNotifier(_state(playing: false));
    await tester.pumpWidget(_wrap(notifier));

    notifier.value = _state();
    await tester.pump(const Duration(seconds: 2));
    expect(_opacity(tester), 1.0);

    notifier.value = _state(playing: false);
    await tester.pump();
    notifier.value = _state();
    await tester.pump(const Duration(seconds: 2));
    expect(_opacity(tester), 1.0);

    await tester.pump(const Duration(seconds: 1));
    expect(_opacity(tester), 0.0);

    await tester.pumpWidget(const SizedBox());
    notifier.dispose();
  });

  testWidgets('销毁时取消定时器不抛异常', (tester) async {
    final notifier = ValueNotifier(_state());
    await tester.pumpWidget(_wrap(notifier));
    await tester.pump(const Duration(seconds: 1));

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 4));

    expect(tester.takeException(), isNull);
    notifier.dispose();
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/features/movie_detail/movie_preview_header_overlay_test.dart`

Expected: FAIL，报 `movie_preview_header_overlay.dart` 找不到。

- [ ] **Step 3: 实现组件**

新建 `lib/features/movie_detail/widgets/movie_preview_header_overlay.dart`：

```dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:jade/features/movie_detail/services/movie_preview_playback.dart';
import 'package:jade/features/movie_detail/widgets/movie_preview_header.dart';

/// 播放态页面头部：进入“播放中且非缓冲”状态 3 秒后隐藏，
/// 暂停/缓冲/完成/错误时立即显示。
class MoviePreviewHeaderOverlay extends StatefulWidget {
  const MoviePreviewHeaderOverlay({
    super.key,
    required this.title,
    required this.onBack,
    required this.state,
    this.hideDelay = const Duration(seconds: 3),
  });

  static const headerOpacityKey = Key('movie-preview-header-opacity');
  static const _opacityDuration = Duration(milliseconds: 250);

  final String title;
  final VoidCallback onBack;
  final ValueListenable<MoviePreviewPlaybackState> state;
  final Duration hideDelay;

  @override
  State<MoviePreviewHeaderOverlay> createState() =>
      _MoviePreviewHeaderOverlayState();
}

class _MoviePreviewHeaderOverlayState extends State<MoviePreviewHeaderOverlay> {
  final _hidden = ValueNotifier<bool>(false);
  Timer? _hideTimer;
  bool _wasHideEligible = false;

  @override
  void initState() {
    super.initState();
    widget.state.addListener(_onStateChanged);
    _onStateChanged();
  }

  @override
  void dispose() {
    widget.state.removeListener(_onStateChanged);
    _hideTimer?.cancel();
    _hidden.dispose();
    super.dispose();
  }

  void _onStateChanged() {
    final value = widget.state.value;
    final hideEligible = value.isPlaying && !value.isBuffering;
    if (hideEligible && !_wasHideEligible) {
      if (_hidden.value) {
        _hidden.value = false;
      }
      _hideTimer?.cancel();
      _hideTimer = Timer(widget.hideDelay, () {
        _hideTimer = null;
        if (mounted) {
          _hidden.value = true;
        }
      });
    } else if (!hideEligible && _wasHideEligible) {
      _hideTimer?.cancel();
      _hideTimer = null;
      if (_hidden.value) {
        _hidden.value = false;
      }
    }
    _wasHideEligible = hideEligible;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _hidden,
      builder: (context, hidden, child) {
        return ExcludeSemantics(
          excluding: hidden,
          child: IgnorePointer(
            ignoring: hidden,
            child: AnimatedOpacity(
              key: MoviePreviewHeaderOverlay.headerOpacityKey,
              opacity: hidden ? 0.0 : 1.0,
              duration: MoviePreviewHeaderOverlay._opacityDuration,
              child: SafeArea(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: MoviePreviewHeader(
                    title: widget.title,
                    onBack: widget.onBack,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
```

- [ ] **Step 4: 运行测试确认通过**

Run: `flutter test test/features/movie_detail/movie_preview_header_overlay_test.dart`

Expected: PASS（8 个用例）。

- [ ] **Step 5: Commit**

```bash
git add lib/features/movie_detail/widgets/movie_preview_header_overlay.dart test/features/movie_detail/movie_preview_header_overlay_test.dart
git commit -m "feat: add auto-hiding header overlay for movie preview"
```

---

### Task 4: 播放适配器与页面替换（核心）

**Files:**
- Rewrite: `lib/features/movie_detail/services/movie_preview_playback.dart`
- Rewrite: `test/features/movie_detail/movie_preview_playback_test.dart`
- Modify: `lib/features/movie_detail/screens/movie_preview_screen.dart`
- Modify: `test/features/movie_detail/movie_preview_screen_test.dart`
- Modify: `pubspec.yaml`（移除 chewie/video_player）
- Delete: `lib/features/movie_detail/widgets/movie_preview_chewie_controls.dart`
- Delete: `lib/features/movie_detail/widgets/movie_preview_gesture_layer.dart`
- Delete: `test/features/movie_detail/movie_preview_chewie_controls_test.dart`
- Delete: `test/features/movie_detail/movie_preview_gesture_layer_test.dart`

**Interfaces:**
- Consumes: `MoviePreviewDoubleTapDetector`（Task 2）、`MoviePreviewHeaderOverlay`（Task 3）、`MoviePreviewHeader`、`MoviePreviewArgs`、`MoviePreviewOrientationCoordinator`、`MoviePreviewWakelockCoordinator`（现有）。
- Produces: `MediaKitMoviePreviewPlayback(Uri uri, {Player? player})`；`MoviePreviewPlayback` 接口移除 `setPlaybackSpeed`；`MoviePreviewPlaybackFactory` 签名不变。

- [ ] **Step 1: 重写适配器测试（红）**

整体替换 `test/features/movie_detail/movie_preview_playback_test.dart` 为：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/features/movie_detail/services/movie_preview_playback.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

class _FakePlatformPlayer extends PlatformPlayer {
  _FakePlatformPlayer({this.openError, this.disposeError})
    : super(configuration: const PlayerConfiguration());

  final Object? openError;
  final Object? disposeError;
  final events = <String>[];
  final opened = <({String uri, bool play})>[];

  @override
  Future<void> open(Playable playable, {bool play = true}) async {
    if (openError != null) {
      throw openError!;
    }
    opened.add((uri: (playable as Media).uri, play: play));
  }

  @override
  Future<void> play() async => events.add('play');

  @override
  Future<void> pause() async => events.add('pause');

  @override
  Future<void> seek(Duration position) async =>
      events.add('seek:${position.inMilliseconds}');

  @override
  Future<void> dispose() async {
    events.add('dispose');
    if (disposeError != null) {
      throw disposeError!;
    }
    await super.dispose();
  }
}

MediaKitMoviePreviewPlayback _build(_FakePlatformPlayer platform) {
  return MediaKitMoviePreviewPlayback(
    Uri.parse('https://media.example.com/preview.m3u8'),
    player: Player(platformPlayer: platform),
  );
}

void main() {
  test('initialize 以 play:false 打开给定 URL 并标记已初始化', () async {
    final platform = _FakePlatformPlayer();
    final playback = _build(platform);

    await playback.initialize();

    expect(
      platform.opened,
      [(uri: 'https://media.example.com/preview.m3u8', play: false)],
    );
    expect(playback.state.value.isInitialized, isTrue);
    await playback.dispose();
  });

  test('open 失败时 initialize 重抛且不标记初始化', () async {
    final platform = _FakePlatformPlayer(openError: StateError('open failed'));
    final playback = _build(platform);

    await expectLater(playback.initialize(), throwsStateError);
    expect(playback.state.value.isInitialized, isFalse);
    expect(playback.buildView, throwsStateError);
    await playback.dispose();
  });

  test('未初始化 buildView 抛 StateError，初始化后返回主题包裹的 Video', () async {
    final platform = _FakePlatformPlayer();
    final playback = _build(platform);

    expect(playback.buildView, throwsStateError);

    await playback.initialize();
    final theme = playback.buildView() as MaterialVideoControlsTheme;
    expect(theme.normal.speedUpOnLongPress, isTrue);

    final video = theme.child as Video;
    expect(video.controller.player, isA<Player>());
    expect(video.wakelock, isFalse);
    expect(video.fit, BoxFit.contain);
    expect(video.controls, MaterialVideoControls.new);
    await playback.dispose();
  });

  test('状态流映射为 MoviePreviewPlaybackState', () async {
    final platform = _FakePlatformPlayer();
    final playback = _build(platform);
    await playback.initialize();

    platform.playingController.add(true);
    platform.bufferingController.add(true);
    platform.completedController.add(true);
    platform.errorController.add('media error');
    platform.positionController.add(const Duration(seconds: 20));
    platform.durationController.add(const Duration(minutes: 2));
    platform.widthController.add(1920);
    platform.heightController.add(1080);

    final state = playback.state.value;
    expect(state.isPlaying, isTrue);
    expect(state.isBuffering, isTrue);
    expect(state.isCompleted, isTrue);
    expect(state.errorDescription, 'media error');
    expect(state.position, const Duration(seconds: 20));
    expect(state.duration, const Duration(minutes: 2));
    expect(state.aspectRatio, 16 / 9);
    await playback.dispose();
  });

  test('宽高缺失时宽高比回退 16/9', () async {
    final platform = _FakePlatformPlayer();
    final playback = _build(platform);
    await playback.initialize();

    platform.widthController.add(null);
    platform.heightController.add(null);

    expect(playback.state.value.aspectRatio, 16 / 9);
    await playback.dispose();
  });

  test('completed 时自动 seek 到 0', () async {
    final platform = _FakePlatformPlayer();
    final playback = _build(platform);
    await playback.initialize();

    platform.completedController.add(true);

    expect(platform.events, ['seek:0']);
    await playback.dispose();
  });

  test('play pause seekTo 委托给 Player', () async {
    final platform = _FakePlatformPlayer();
    final playback = _build(platform);
    await playback.initialize();

    await playback.play();
    await playback.pause();
    await playback.seekTo(const Duration(seconds: 30));

    expect(platform.events, ['play', 'pause', 'seek:30000']);
    await playback.dispose();
  });

  test('dispose 幂等：只释放一次 Player 与状态', () async {
    final platform = _FakePlatformPlayer();
    final playback = _build(platform);
    final state = playback.state;
    await playback.initialize();

    await playback.dispose();
    await playback.dispose();

    expect(platform.events.where((event) => event == 'dispose').length, 1);
    expect(() => state.addListener(() {}), throwsFlutterError);
  });

  test('dispose 释放抛错时仍释放状态并重抛第一个错误', () async {
    final platform = _FakePlatformPlayer(
      disposeError: StateError('dispose failed'),
    );
    final playback = _build(platform);
    final state = playback.state;
    await playback.initialize();

    await expectLater(playback.dispose(), throwsA(isA<StateError>()));
    expect(() => state.addListener(() {}), throwsFlutterError);
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/features/movie_detail/movie_preview_playback_test.dart`

Expected: FAIL，报 `MediaKitMoviePreviewPlayback` 未定义（旧文件仍是 Chewie 实现，接口还有 `setPlaybackSpeed`）。

- [ ] **Step 3: 重写适配器文件**

整体替换 `lib/features/movie_detail/services/movie_preview_playback.dart` 为：

```dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

@immutable
class MoviePreviewPlaybackState {
  const MoviePreviewPlaybackState({
    this.isInitialized = false,
    this.isPlaying = false,
    this.isBuffering = false,
    this.isCompleted = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.aspectRatio = 16 / 9,
    this.errorDescription,
  });

  final bool isInitialized;
  final bool isPlaying;
  final bool isBuffering;
  final bool isCompleted;
  final Duration position;
  final Duration duration;
  final double aspectRatio;
  final String? errorDescription;
}

abstract interface class MoviePreviewPlayback {
  ValueListenable<MoviePreviewPlaybackState> get state;

  Widget buildView();
  Future<void> initialize();
  Future<void> play();
  Future<void> pause();
  Future<void> seekTo(Duration position);
  Future<void> dispose();
}

typedef MoviePreviewPlaybackFactory = MoviePreviewPlayback Function(Uri uri);

/// 基于 media_kit 的预告片播放适配器。
///
/// 测试通过 [Player.platformPlayer] 注入 fake（见
/// `movie_preview_playback_test.dart`），生产环境默认创建真实 [Player]。
class MediaKitMoviePreviewPlayback implements MoviePreviewPlayback {
  MediaKitMoviePreviewPlayback(Uri uri, {Player? player})
    : _uri = uri,
      _player = player ?? Player() {
    _videoController = VideoController(_player);
    _subscriptions.addAll([
      _player.stream.playing.listen(_onPlaying),
      _player.stream.buffering.listen(_onBuffering),
      _player.stream.completed.listen(_onCompleted),
      _player.stream.error.listen(_onError),
      _player.stream.position.listen(_onPosition),
      _player.stream.duration.listen(_onDuration),
      _player.stream.width.listen(_onWidth),
      _player.stream.height.listen(_onHeight),
    ]);
  }

  final Uri _uri;
  final Player _player;
  late final VideoController _videoController;
  final _state = ValueNotifier(const MoviePreviewPlaybackState());
  final _subscriptions = <StreamSubscription<dynamic>>[];
  Future<void>? _disposeOperation;

  var _isInitialized = false;
  var _isPlaying = false;
  var _isBuffering = false;
  var _isCompleted = false;
  String? _errorDescription;
  var _position = Duration.zero;
  var _duration = Duration.zero;
  int _width = 0;
  int _height = 0;

  @override
  ValueListenable<MoviePreviewPlaybackState> get state => _state;

  @override
  Widget buildView() {
    if (!_isInitialized) {
      throw StateError('Movie preview playback is not initialized.');
    }
    return MaterialVideoControlsTheme(
      normal: const MaterialVideoControlsThemeData(speedUpOnLongPress: true),
      child: Video(
        controller: _videoController,
        fit: BoxFit.contain,
        fill: Colors.black,
        wakelock: false,
        controls: MaterialVideoControls.new,
      ),
    );
  }

  @override
  Future<void> initialize() async {
    await _player.open(Media(_uri.toString()), play: false);
    _isInitialized = true;
    _syncState();
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seekTo(Duration position) => _player.seek(position);

  @override
  Future<void> dispose() => _disposeOperation ??= _dispose();

  Future<void> _dispose() async {
    Object? firstError;
    StackTrace? firstStackTrace;
    try {
      for (final subscription in _subscriptions) {
        try {
          await subscription.cancel();
        } catch (error, stackTrace) {
          firstError ??= error;
          firstStackTrace ??= stackTrace;
        }
      }
      _subscriptions.clear();
      try {
        await _player.dispose();
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

  void _onPlaying(bool value) {
    _isPlaying = value;
    _syncState();
  }

  void _onBuffering(bool value) {
    _isBuffering = value;
    _syncState();
  }

  void _onCompleted(bool value) {
    _isCompleted = value;
    if (value) {
      unawaited(_player.seek(Duration.zero));
    }
    _syncState();
  }

  void _onError(String value) {
    _errorDescription = value;
    _syncState();
  }

  void _onPosition(Duration value) {
    _position = value;
    _syncState();
  }

  void _onDuration(Duration value) {
    _duration = value;
    _syncState();
  }

  void _onWidth(int? value) {
    _width = value ?? 0;
    _syncState();
  }

  void _onHeight(int? value) {
    _height = value ?? 0;
    _syncState();
  }

  void _syncState() {
    _state.value = MoviePreviewPlaybackState(
      isInitialized: _isInitialized,
      isPlaying: _isPlaying,
      isBuffering: _isBuffering,
      isCompleted: _isCompleted,
      position: _position,
      duration: _duration,
      aspectRatio: (_width > 0 && _height > 0) ? _width / _height : 16 / 9,
      errorDescription: _errorDescription,
    );
  }
}
```

- [ ] **Step 4: 运行适配器测试确认通过**

Run: `flutter test test/features/movie_detail/movie_preview_playback_test.dart`

Expected: PASS（9 个用例）。注意此时页面与其余旧文件尚未更新，`flutter analyze` 会报错，属于预期中间状态。

- [ ] **Step 5: 改造页面**

修改 `lib/features/movie_detail/screens/movie_preview_screen.dart`：

5a. 替换 import：

```dart
// 删除：
// import 'package:jade/features/movie_detail/widgets/movie_preview_chewie_controls.dart';
// import 'package:jade/features/movie_detail/widgets/movie_preview_gesture_layer.dart';
// 新增：
import 'package:jade/features/movie_detail/widgets/movie_preview_double_tap_detector.dart';
import 'package:jade/features/movie_detail/widgets/movie_preview_header_overlay.dart';
```

5b. `_createPlayback` 改为：

```dart
MoviePreviewPlayback _createPlayback(Uri uri) {
  final injectedFactory = widget.playbackFactory;
  if (injectedFactory != null) {
    return injectedFactory(uri);
  }
  return MediaKitMoviePreviewPlayback(uri);
}
```

5c. `_buildPlaybackBody` 改为：

```dart
Widget _buildPlaybackBody(_PlaybackSession session) {
  final playback = session.playback;
  final command = _PlaybackCommand(
    session: session,
    generation: _lifecycleGeneration,
  );
  return ValueListenableBuilder<MoviePreviewPlaybackState>(
    valueListenable: playback.state,
    child: MoviePreviewDoubleTapDetector(
      onDoubleTap: () => _onDoubleTap(command),
      child: playback.buildView(),
    ),
    builder: (context, state, child) {
      if (state.errorDescription?.isNotEmpty ?? false) {
        return _buildStatusBody(hasError: true);
      }
      return Stack(
        fit: StackFit.expand,
        children: [
          child!,
          MoviePreviewHeaderOverlay(
            title: _title,
            onBack: _pop,
            state: playback.state,
          ),
        ],
      );
    },
  );
}
```

5d. 新增双击回调（吞掉失效命令异常，避免未处理异步错误）：

```dart
void _onDoubleTap(_PlaybackCommand command) {
  unawaited(() async {
    try {
      await _togglePlayback(command);
    } catch (_) {}
  }());
}
```

5e. 删除 `_setPlaybackSpeed` 与 `_handleSpeedRecoveryFailure` 两个方法（及对它们的全部引用）。

5f. `_runCleanup` 删除倍速恢复步骤：

```dart
Future<void> _runCleanup(MoviePreviewPlayback playback) async {
  await _ignoreBoundedCleanup(playback.pause);
  await _ignoreBoundedCleanup(playback.dispose);
}
```

5g. `_togglePlayback` 保持原逻辑不变（已播完 seek 0 再播、播放中暂停、否则播放，带 generation/session 校验）。

- [ ] **Step 6: 删除旧组件与旧测试**

删除以下 4 个文件（`git rm`）：

- `lib/features/movie_detail/widgets/movie_preview_chewie_controls.dart`
- `lib/features/movie_detail/widgets/movie_preview_gesture_layer.dart`
- `test/features/movie_detail/movie_preview_chewie_controls_test.dart`
- `test/features/movie_detail/movie_preview_gesture_layer_test.dart`

- [ ] **Step 7: 改造页面测试**

修改 `test/features/movie_detail/movie_preview_screen_test.dart`：

7a. 替换 import：

```dart
// 删除：
// import 'package:chewie/chewie.dart';
// import 'package:video_player/video_player.dart';
// import 'package:video_player_platform_interface/video_player_platform_interface.dart';
// import 'package:jade/features/movie_detail/widgets/movie_preview_chewie_controls.dart';
// 新增：
import 'package:jade/features/movie_detail/widgets/movie_preview_header_overlay.dart';
```

7b. `_backgroundPoint` 改用假视频视图的 key：

```dart
Offset _backgroundPoint(WidgetTester tester) {
  return tester.getTopLeft(find.byKey(const Key('fake-preview-video'))) +
      const Offset(64, 240);
}
```

7c. `_FakePlayback` 整类替换为（删除倍速字段与方法，buildView 不再自带头部——头部现在由页面 overlay 提供）：

```dart
class _FakePlayback implements MoviePreviewPlayback {
  _FakePlayback({
    this.initializeError,
    this.initializeCompleter,
    this.seekCompleter,
    this.pauseCompleter,
    this.disposeCompleter,
    this.initialState = const MoviePreviewPlaybackState(),
  });

  final Object? initializeError;
  final Completer<void>? initializeCompleter;
  final Completer<void>? seekCompleter;
  final Completer<void>? pauseCompleter;
  final Completer<void>? disposeCompleter;
  final MoviePreviewPlaybackState initialState;
  late final _state = ValueNotifier(initialState);
  final commands = <String>[];
  int initializeCalls = 0;
  int playCalls = 0;
  int pauseCalls = 0;
  int disposeCalls = 0;

  @override
  ValueListenable<MoviePreviewPlaybackState> get state => _state;

  @override
  Widget buildView() {
    return const ColoredBox(
      key: Key('fake-preview-video'),
      color: Colors.black,
    );
  }

  @override
  Future<void> initialize() async {
    initializeCalls++;
    commands.add('initialize');
    if (initializeError != null) {
      throw initializeError!;
    }
    await initializeCompleter?.future;
    _state.value = MoviePreviewPlaybackState(
      isInitialized: true,
      isPlaying: initialState.isPlaying,
      isCompleted: initialState.isCompleted,
    );
  }

  @override
  Future<void> play() async {
    playCalls++;
    commands.add('play');
  }

  @override
  Future<void> pause() async {
    pauseCalls++;
    commands.add('pause');
    await pauseCompleter?.future;
  }

  @override
  Future<void> seekTo(Duration position) async {
    commands.add('seek:${position.inMilliseconds}');
    await seekCompleter?.future;
  }

  void emit(MoviePreviewPlaybackState value) {
    _state.value = value;
  }

  @override
  Future<void> dispose() async {
    disposeCalls++;
    await disposeCompleter?.future;
  }
}
```

7d. 删除整段 `_FakeVideoPlayerPlatform`、`_ThrowingDisposeVideoPlayerController`、`_CreateFailureVideoPlayerController` 类。

7e. 按以下清单删除用例（连同其代码块）：

- `'默认 playback 把组合控件接入 Chewie 且只显示一份顶部栏'`（默认构造覆盖已移至 Task 4 Step 1 的适配器测试）
- `'旧手势队列在媒体错误重试后不会改变新 session 倍速'`（手势层已删除）
- `'长按恢复 1.0× 失败会暂停并进入可重试错误页'`（手势层已删除）
- `'长按恢复失败时 pause 永不完成仍及时显示错误重试页'`（手势层已删除）
- `'映射 VideoPlayerValue 的完成和错误状态'`（映射覆盖在适配器测试）
- `'controller 释放抛错时仍释放 playback state'`（覆盖在适配器测试）
- `'平台创建失败后 playback dispose 会有界完成并释放 state'`（video_player 特有 hack 已删除）

7f. 保留用例做三处修改：

- `'进入页面先锁定横屏，初始化成功后自动播放，退出时清理并恢复方向'`：删除断言行 `expect(playback.speedCalls.last, 1.0);`。
- `'播放中底层媒体错误切换到可退出可重试页面'`：把最后一段替换为：

```dart
    expect(
      find.byKey(MoviePreviewHeaderOverlay.headerOpacityKey),
      findsNothing,
    );
```

- `'正常播放只保留 playback controls 内的一份顶部栏'`：保持用例，只改用例名为 `'正常播放页面只显示一份顶部栏'`，断言不变（`find.byType(MoviePreviewHeader)` 与 `find.byTooltip('返回')` 均 `findsOneWidget`）。

其余保留用例（非法 URL、重试替换驱动、重试去重、有界清理、方向恢复、同步 factory 异常、横屏锁定失败、加载/错误态头部、完成态重播、暂停/播放态双击、完成态 seek 未完成退出）无需改动；双击用例继续用 `tester.tapAt(_backgroundPoint(tester))` 两次的既有写法（真实时钟下两次按下间隔远小于 300ms）。

- [ ] **Step 8: 移除旧依赖**

`pubspec.yaml` 删除 `chewie: ^1.13.1` 与 `video_player: ^2.14.0`；dev_dependencies 删除 `video_player_platform_interface: 6.9.0`。保留 `wakelock_plus: ^1.3.3`。

Run: `flutter pub get`

Expected: 成功，lock 中不再有 chewie/video_player 及其平台包。

- [ ] **Step 9: 静态分析与聚焦测试**

Run: `flutter analyze`

Expected: 0 issues。

Run:

```bash
flutter test test/features/movie_detail/movie_preview_playback_test.dart test/features/movie_detail/movie_preview_double_tap_detector_test.dart test/features/movie_detail/movie_preview_header_overlay_test.dart test/features/movie_detail/movie_preview_screen_test.dart
```

Expected: 全部 PASS。

- [ ] **Step 10: 全量测试**

Run: `flutter test`

Expected: 全部 PASS。若出现与本次改动无关的既有失败，记录并在报告中说明。

- [ ] **Step 11: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/features/movie_detail test/features/movie_detail
git commit -m "refactor: replace chewie video player with media kit in movie preview"
```

注意：`git add` 只包含上述路径，不包含 `.zcode/` 或其它无关改动。

---

### Task 5: Android 构建与真机验证

**Files:**
- 无代码变更（除非验证发现问题）。

**Interfaces:**
- Consumes: Task 4 的完整实现。

- [ ] **Step 1: 构建 debug APK**

Run: `flutter build apk --debug`

Expected: 成功。首次构建时 Gradle 会从 GitHub 下载 4 个 ABI 的 libmpv（MD5 校验），耗时较长且需要联网。

- [ ] **Step 2: 记录 APK 体积**

Run: `ls -lh build/app/outputs/flutter-apk/app-debug.apk`

Expected: 明显大于替换前（libmpv 全部 ABI 打入），把体积数字记入验证报告。

- [ ] **Step 3: 安装到设备**

Run: `adb devices`

若无可用设备：请用户连接设备或启动模拟器，再继续。

Run: `flutter install`（或 `adb install -r build/app/outputs/flutter-apk/app-debug.apk`）

- [ ] **Step 4: 人工验证清单（逐项确认并记录）**

1. 影片详情页有 `preview_video_url` 的影片显示预告入口，点击进入横屏预告片页。
2. 真实 M3U8 能正常出画与出声（AES-128 HLS 经 libmpv 播放）。
3. 进入后自动播放；控件初始隐藏，单击唤出/收起。
4. 双击画面切换播放/暂停。
5. 长按画面进入 2.0× 并显示内置指示器，松手恢复原速。
6. 播放中 3 秒后标题自动隐藏；暂停时标题显示。
7. 返回按钮在头部隐藏时不可点（IgnorePointer），显示时可点；退出后应用方向恢复正常。
8. 断网/非法 URL 时显示“预告片播放失败”与“重试”，重试可恢复。
9. 进入后台自动暂停，回到前台保持暂停状态。

- [ ] **Step 5: 报告**

把逐项结果、APK 体积、任何异常与截图证据写入报告。若发现 bug：先写复现测试（红）→ 修复（绿）→ 重新跑 Task 4 Step 9/10 → 单独提交修复（`fix:` 前缀）。
