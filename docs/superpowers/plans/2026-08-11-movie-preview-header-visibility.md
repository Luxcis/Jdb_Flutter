# 预告片顶部栏与 Chewie 控制层同步显隐实施计划

> **For Codex:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` to implement this plan task-by-task, with a fresh implementation subagent and a fresh review subagent for every production-code task.

**Goal:** 正常播放预告片时，让返回按钮和影片标题与 Chewie Material 原生控制层使用同一个显隐状态；加载和错误状态的顶部栏继续始终显示。

**Architecture:** 通过 Chewie 的 `customControls` 组合原生 `MaterialControls` 与应用顶部栏，从导出的 `ChewieState.notifier.hideStuff` 读取原生控制层状态。页面只负责把组合控件交给默认 playback；双击、长按、横屏、wakelock、错误恢复和 session 生命周期不改变。

**Tech Stack:** Flutter、Dart、Chewie `1.13.1`、video_player `2.10.1`、flutter_test、Android Debug APK、ADB。

---

## 实施边界

- 隐藏范围是整条顶部栏：返回按钮和单行影片标题。
- 正常播放时，顶部栏只存在于 Chewie `customControls` 子树。
- 加载、非法 URL、初始化失败和媒体错误状态仍由页面直接渲染始终可见的顶部栏。
- 继续使用 Chewie 原生 `MaterialControls`；不得复制播放按钮、进度条、时间、音量、缓冲或自动隐藏逻辑。
- 不创建标题独立计时器，不给外层 `MoviePreviewGestureLayer` 添加 `onTap`。
- 不直接导入 `package:chewie/src/...`。
- `MoviePreviewPlaybackFactory` 保持 `MoviePreviewPlayback Function(Uri)`，不破坏现有页面生命周期测试 fake。
- 不升级 Chewie、video_player、wakelock_plus 或 SDK 下限。
- 每个实现任务必须遵循 RED → GREEN → 聚焦回归 → 提交；不得先改生产代码。

## Task 1：让 Chewie playback 透传可选原生组合控件

**Files:**

- Modify: `lib/features/movie_detail/services/movie_preview_playback.dart`
- Modify: `test/features/movie_detail/movie_preview_playback_test.dart`

### Step 1：先写 customControls 透传失败测试

在 `movie_preview_playback_test.dart` 的第一条固定配置测试之后增加：

```dart
testWidgets('把页面提供的组合控件传给 ChewieController', (tester) async {
  const customControls = KeyedSubtree(
    key: Key('movie-preview-custom-controls'),
    child: SizedBox(),
  );
  final playback = ChewieMoviePreviewPlayback.withController(
    _FakeVideoPlayerController(),
    customControls: customControls,
  );

  await playback.initialize();

  final view = playback.buildView() as Chewie;
  expect(view.controller.customControls, same(customControls));

  await playback.dispose();
});
```

同时在现有“初始化后 buildView 返回固定配置的 Chewie 原生控制层”测试中补充默认契约：

```dart
expect(chewieController.customControls, isNull);
```

因为 controller factory 将新增具名参数，把三个自定义 factory 改成新的闭包形状，但暂不改生产 typedef：

```dart
chewieControllerFactory: (
  controller, {
  customControls,
}) => _RecordingChewieController(controller, events),
```

```dart
chewieControllerFactory: (
  controller, {
  customControls,
}) {
  chewieCreateCalls++;
  return ChewieController(
    videoPlayerController: controller,
    customControls: customControls,
  );
},
```

```dart
chewieControllerFactory: (
  controller, {
  customControls,
}) {
  throw StateError('Chewie create failed');
},
```

### Step 2：运行测试，确认 RED 原因准确

Run:

```bash
flutter test test/features/movie_detail/movie_preview_playback_test.dart
```

Expected:

- 编译失败；
- 错误指向 `ChewieMoviePreviewPlayback.withController` 不存在
  `customControls` 参数，或 factory typedef 不接受具名参数；
- 不接受其他无关失败作为 RED。

### Step 3：实现最小透传

在 `movie_preview_playback.dart` 中把 factory 改为：

```dart
typedef MoviePreviewChewieControllerFactory =
    ChewieController Function(
      VideoPlayerController controller, {
      Widget? customControls,
    });
```

让固定 controller 工厂只新增可选控件，其他 Chewie 配置逐项保持不变：

```dart
ChewieController createMoviePreviewChewieController(
  VideoPlayerController controller, {
  Widget? customControls,
}) {
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
    customControls: customControls,
  );
}
```

两个构造入口都接收控件，并保存到 playback 实例：

```dart
class ChewieMoviePreviewPlayback implements MoviePreviewPlayback {
  ChewieMoviePreviewPlayback(
    Uri uri, {
    Widget? customControls,
  }) : this._(
         VideoPlayerController.networkUrl(uri, formatHint: VideoFormat.hls),
         createMoviePreviewChewieController,
         customControls,
       );

  @visibleForTesting
  ChewieMoviePreviewPlayback.withController(
    VideoPlayerController controller, {
    MoviePreviewChewieControllerFactory chewieControllerFactory =
        createMoviePreviewChewieController,
    Widget? customControls,
  }) : this._(controller, chewieControllerFactory, customControls);

  ChewieMoviePreviewPlayback._(
    this._videoController,
    this._chewieControllerFactory,
    this._customControls,
  ) {
    _videoController.addListener(_syncState);
    _syncState();
  }

  final Widget? _customControls;
```

初始化完成后创建 Chewie controller 时透传：

```dart
_chewieController ??= _chewieControllerFactory(
  _videoController,
  customControls: _customControls,
);
```

不要修改初始化、状态映射、命令代理或 dispose 顺序。

### Step 4：运行聚焦测试并格式化

Run:

```bash
dart format lib/features/movie_detail/services/movie_preview_playback.dart test/features/movie_detail/movie_preview_playback_test.dart
flutter test test/features/movie_detail/movie_preview_playback_test.dart
git diff --check
```

Expected:

- playback 测试全部通过；
- 默认 `customControls == null`；
- 显式传入的 widget 与 `ChewieController.customControls` 为同一实例；
- `git diff --check` 无输出。

### Step 5：提交 Task 1

```bash
git add lib/features/movie_detail/services/movie_preview_playback.dart test/features/movie_detail/movie_preview_playback_test.dart
git commit -m "feat: allow preview Chewie custom controls"
```

## Task 2：新增与 Chewie notifier 同步的顶部栏组合控件

**Files:**

- Create: `lib/features/movie_detail/widgets/movie_preview_header.dart`
- Create: `lib/features/movie_detail/widgets/movie_preview_chewie_controls.dart`
- Modify: `lib/features/movie_detail/screens/movie_preview_screen.dart`
- Create: `test/features/movie_detail/movie_preview_chewie_controls_test.dart`

### Step 1：先为同步显隐写真实 Chewie widget 测试

创建 `movie_preview_chewie_controls_test.dart`，导入公开入口：

```dart
import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/features/movie_detail/widgets/movie_preview_chewie_controls.dart';
import 'package:video_player/video_player.dart';
```

增加测试用 video controller；它只模拟初始化、播放、暂停和 looping，不复制
Chewie 的可见状态：

```dart
class _ControlsVideoPlayerController extends VideoPlayerController {
  _ControlsVideoPlayerController()
    : super.networkUrl(
        Uri.parse('https://media.example.com/preview.m3u8'),
        formatHint: VideoFormat.hls,
      );

  @override
  Future<void> initialize() async {
    value = const VideoPlayerValue(
      duration: Duration(minutes: 1),
      size: Size(1920, 1080),
      isInitialized: true,
    );
  }

  @override
  Future<void> play() async {
    value = value.copyWith(isPlaying: true);
  }

  @override
  Future<void> pause() async {
    value = value.copyWith(isPlaying: false);
  }

  @override
  Future<void> setLooping(bool looping) async {
    value = value.copyWith(isLooping: looping);
  }
}
```

增加真实 Chewie harness：

```dart
Future<({ChewieController chewie, VideoPlayerController video})>
_pumpControls(
  WidgetTester tester, {
  required VoidCallback onBack,
}) async {
  final video = _ControlsVideoPlayerController();
  await video.initialize();
  await video.play();
  final chewie = ChewieController(
    videoPlayerController: video,
    autoInitialize: false,
    autoPlay: false,
    showControls: true,
    showControlsOnInitialize: true,
    hideControlsTimer: const Duration(seconds: 3),
    allowFullScreen: false,
    customControls: MoviePreviewChewieControls(
      title: '测试影片',
      onBack: onBack,
    ),
  );
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox.expand(child: Chewie(controller: chewie)),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
  return (chewie: chewie, video: video);
}

double _headerOpacity(WidgetTester tester) {
  return tester
      .widget<AnimatedOpacity>(
        find.byKey(MoviePreviewChewieControls.headerOpacityKey),
      )
      .opacity;
}
```

先写三个失败测试：

```dart
testWidgets('顶部栏跟随真实 Chewie 控制层自动隐藏并由单击恢复', (tester) async {
  final harness = await _pumpControls(tester, onBack: () {});

  expect(_headerOpacity(tester), 1.0);

  await tester.pump(const Duration(seconds: 3));
  expect(_headerOpacity(tester), 0.0);

  await tester.tapAt(tester.getCenter(find.byType(Chewie)));
  await tester.pump();
  expect(_headerOpacity(tester), 1.0);

  await tester.pumpWidget(const SizedBox());
  harness.chewie.dispose();
  await harness.video.dispose();
});

testWidgets('顶部栏隐藏时返回不可点击且不暴露语义', (tester) async {
  var backCalls = 0;
  final semantics = tester.ensureSemantics();
  final harness = await _pumpControls(
    tester,
    onBack: () => backCalls++,
  );

  await tester.pump(const Duration(seconds: 3));
  expect(_headerOpacity(tester), 0.0);
  expect(find.bySemanticsLabel('返回'), findsNothing);

  await tester.tap(find.byTooltip('返回'), warnIfMissed: false);
  expect(backCalls, 0);

  semantics.dispose();
  await tester.pumpWidget(const SizedBox());
  harness.chewie.dispose();
  await harness.video.dispose();
});

test('ChewieState 缺失时顶部栏采用可见兜底', () {
  expect(moviePreviewHeaderIsHidden(null), isFalse);
});
```

这些测试必须驱动真实 `Chewie` 和 `MaterialControls` 的 3 秒 timer；不得在测试中
直接调用应用自定义的“隐藏/显示”回调。

### Step 2：运行测试，确认 RED

Run:

```bash
flutter test test/features/movie_detail/movie_preview_chewie_controls_test.dart
```

Expected:

- 编译失败，因为组合控件和可见兜底函数尚不存在；
- 不接受测试超时或 video platform channel 错误作为 RED。

### Step 3：提取 MoviePreviewHeader，保持页面现有行为

新建 `movie_preview_header.dart`，原样移动页面底部的 header：

```dart
import 'package:flutter/material.dart';

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

在 `movie_preview_screen.dart` 导入该文件并删除页面文件底部的同名 class。此时
页面仍保留原来的两处 `SafeArea`，只完成无行为变化的提取。

### Step 4：实现原生控制层组合 widget

创建 `movie_preview_chewie_controls.dart`：

```dart
import 'package:chewie/chewie.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:jade/features/movie_detail/widgets/movie_preview_header.dart';

@visibleForTesting
bool moviePreviewHeaderIsHidden(ChewieState? chewieState) {
  return chewieState?.notifier.hideStuff ?? false;
}

class MoviePreviewChewieControls extends StatelessWidget {
  const MoviePreviewChewieControls({
    super.key,
    required this.title,
    required this.onBack,
  });

  static const headerOpacityKey = Key('movie-preview-header-opacity');
  static const _opacityDuration = Duration(milliseconds: 250);

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final chewieState = context.findAncestorStateOfType<ChewieState>();
    final notifier = chewieState?.notifier;
    return Stack(
      fit: StackFit.expand,
      children: [
        const MaterialControls(),
        if (notifier == null)
          _buildHeader(hidden: false)
        else
          AnimatedBuilder(
            animation: notifier,
            builder: (context, child) {
              return _buildHeader(
                hidden: moviePreviewHeaderIsHidden(chewieState),
              );
            },
          ),
      ],
    );
  }

  Widget _buildHeader({required bool hidden}) {
    return ExcludeSemantics(
      excluding: hidden,
      child: IgnorePointer(
        ignoring: hidden,
        child: AnimatedOpacity(
          key: headerOpacityKey,
          opacity: hidden ? 0.0 : 1.0,
          duration: _opacityDuration,
          child: SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: MoviePreviewHeader(title: title, onBack: onBack),
            ),
          ),
        ),
      ),
    );
  }
}
```

约束：

- `MaterialControls` 必须保持 `const` 且不包一层新的点击手势；
- `AnimatedBuilder` 的 animation 必须是当前 `ChewieState.notifier`；
- 不创建 `Timer`；
- 不调用 play、pause、seek 或 setPlaybackSpeed；
- 隐藏时同时启用 `IgnorePointer` 与 `ExcludeSemantics`；
- 不使用 Chewie `src` 路径。

### Step 5：运行新控件测试和提取回归

Run:

```bash
dart format lib/features/movie_detail/widgets/movie_preview_header.dart lib/features/movie_detail/widgets/movie_preview_chewie_controls.dart lib/features/movie_detail/screens/movie_preview_screen.dart test/features/movie_detail/movie_preview_chewie_controls_test.dart
flutter test test/features/movie_detail/movie_preview_chewie_controls_test.dart
flutter test test/features/movie_detail/movie_preview_screen_test.dart
git diff --check
```

Expected:

- 新控件测试全部通过；
- 3 秒隐藏来自 Chewie 自身 timer；
- 单击 Chewie 画面后 header 恢复；
- 隐藏时点击与语义均关闭；
- 页面现有回归全部通过；
- diff check 干净。

若真实 Chewie 测试的 3 秒边界因 250ms 初始化动画产生时间偏差，只允许使用
`pump` 精确推进 Chewie 已配置的时间；不得把断言改成应用自行触发 notifier。

### Step 6：提交 Task 2

```bash
git add lib/features/movie_detail/widgets/movie_preview_header.dart lib/features/movie_detail/widgets/movie_preview_chewie_controls.dart lib/features/movie_detail/screens/movie_preview_screen.dart test/features/movie_detail/movie_preview_chewie_controls_test.dart
git commit -m "refactor: add synchronized preview Chewie controls"
```

## Task 3：页面默认播放接入组合控件并删除外部常驻顶部栏

**Files:**

- Modify: `lib/features/movie_detail/screens/movie_preview_screen.dart`
- Modify: `test/features/movie_detail/movie_preview_screen_test.dart`

### Step 1：让页面 fake 模拟 playback 内部顶部栏，先写“只有一份”失败测试

在 `movie_preview_screen_test.dart` 导入：

```dart
import 'package:jade/features/movie_detail/widgets/movie_preview_header.dart';
```

把 `_FakePlayback.buildView()` 从空 `SizedBox` 改为模拟生产 playback 内部的
顶部栏：

```dart
@override
Widget buildView() {
  return Builder(
    builder: (context) {
      return Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(
            key: Key('fake-preview-video'),
            color: Colors.black,
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: MoviePreviewHeader(
                title: '测试影片',
                onBack: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        ],
      );
    },
  );
}
```

在正常初始化测试附近增加：

```dart
testWidgets('正常播放只保留 playback controls 内的一份顶部栏', (tester) async {
  final playback = _FakePlayback();

  await _pumpPreviewPage(tester, playback: playback);
  await tester.pump();

  expect(find.byType(MoviePreviewHeader), findsOneWidget);
  expect(find.byTooltip('返回'), findsOneWidget);
});
```

保留已有加载、错误和返回测试；fake 内的返回按钮继续让正常播放测试通过路由退出。

### Step 2：运行页面测试，确认 RED

Run:

```bash
flutter test test/features/movie_detail/movie_preview_screen_test.dart
```

Expected:

- 新测试失败，找到两份 `MoviePreviewHeader`：
  1. fake playback 内部一份；
  2. 页面外部常驻一份。

### Step 3：默认 playback 创建时注入组合控件

在 `movie_preview_screen.dart` 增加：

```dart
import 'package:jade/features/movie_detail/widgets/movie_preview_chewie_controls.dart';
import 'package:jade/features/movie_detail/widgets/movie_preview_header.dart';
```

删除：

```dart
MoviePreviewPlaybackFactory get _playbackFactory =>
    widget.playbackFactory ?? ChewieMoviePreviewPlayback.new;
```

新增页面统一返回方法和 playback 创建方法：

```dart
void _pop() => Navigator.of(context).pop();

MoviePreviewPlayback _createPlayback(Uri uri) {
  final injectedFactory = widget.playbackFactory;
  if (injectedFactory != null) {
    return injectedFactory(uri);
  }
  return ChewieMoviePreviewPlayback(
    uri,
    customControls: MoviePreviewChewieControls(
      title: _title,
      onBack: _pop,
    ),
  );
}
```

在 `_acquireOrientationAndInitialize` 的既有 session 创建位置，把：

```dart
final playback = _playbackFactory(uri);
```

改为：

```dart
final playback = _createPlayback(uri);
```

不要改变 URI 校验、generation、orientation、wakelock 或 retry 顺序。

### Step 4：移除正常播放状态的页面外部顶部栏

把 `_buildPlaybackBody` 的静态 child 从外部 `Stack` 缩减为手势层：

```dart
child: MoviePreviewGestureLayer(
  onTogglePlayback: () => _togglePlayback(command),
  onSetPlaybackSpeed: (speed) => _setPlaybackSpeed(command, speed),
  onSpeedRecoveryFailure: () => _handleSpeedRecoveryFailure(command),
  child: playback.buildView(),
),
```

不要给 `MoviePreviewGestureLayer` 增加 `onTap`。Chewie 内部组合控件负责正常播放的
顶部栏。

把 `_buildStatusBody` 的返回 callback 改为 `_pop`，但保留页面级
`SafeArea + MoviePreviewHeader`：

```dart
MoviePreviewHeader(
  title: _title,
  onBack: _pop,
),
```

这确保加载和错误状态仍始终有一份可操作顶部栏。

### Step 5：运行页面及全部预告片聚焦回归

Run:

```bash
dart format lib/features/movie_detail/screens/movie_preview_screen.dart test/features/movie_detail/movie_preview_screen_test.dart
flutter test test/features/movie_detail/movie_preview_screen_test.dart
flutter test test/features/movie_detail/movie_preview_playback_test.dart test/features/movie_detail/movie_preview_chewie_controls_test.dart test/features/movie_detail/movie_preview_gesture_layer_test.dart test/features/movie_detail/movie_preview_orientation_test.dart test/features/movie_detail/movie_preview_wakelock_test.dart
git diff --check
```

Expected:

- 正常播放仅一份 playback 内顶部栏；
- loading/error header 仍为一份且可返回；
- 双击、长按、session race、媒体错误、重试、横屏和 wakelock 回归全部通过；
- `MoviePreviewGestureLayer` 继续没有 `onTap`；
- diff check 干净。

### Step 6：提交 Task 3

```bash
git add lib/features/movie_detail/screens/movie_preview_screen.dart test/features/movie_detail/movie_preview_screen_test.dart
git commit -m "feat: sync preview header with Chewie controls"
```

## Task 4：最终验证、Flutter 构建与 ADB 覆盖安装

**Files:**

- Verify only; no source edits expected.

### Step 1：静态边界检查

Run:

```bash
rg -n "package:chewie/src/|Timer\\(|onTap:" lib/features/movie_detail/widgets/movie_preview_chewie_controls.dart lib/features/movie_detail/widgets/movie_preview_gesture_layer.dart
rg -n "MaterialControls|ChewieState|hideStuff|IgnorePointer|ExcludeSemantics" lib/features/movie_detail/widgets/movie_preview_chewie_controls.dart
git diff --check
git status --short
```

Expected:

- 第一条命令无 `src`、新 timer 或外层单击命中；
- 第二条能看到公开 Chewie 控件、同一 notifier 状态以及点击/语义保护；
- diff check 无输出；
- 工作树干净。

### Step 2：运行详情与路由回归

Run:

```bash
flutter test test/features/movie_detail/movie_detail_screen_test.dart test/app_router_test.dart
```

Expected: 全部通过，详情页预告片入口和播放路由不变。

### Step 3：运行分析与完整测试

Run:

```bash
flutter analyze
flutter test
```

Expected:

- `flutter analyze` 输出 `No issues found!`；
- 完整测试全部通过；
- 若 Flutter SDK cache 写入 `/opt/homebrew/share/flutter` 被沙箱拒绝，应在同一
  HEAD 上申请受控重跑，明确区分环境失败和代码失败。

### Step 4：确认唯一在线 Android 目标

Run:

```bash
adb devices -l
```

Expected:

- 仅选择状态为 `device` 的 Android 模拟器；
- 如果有多个在线目标，后续每条 ADB 命令都显式使用 `-s <serial>`，不得猜测。

### Step 5：使用 Flutter 构建新的 Debug APK

Run:

```bash
flutter build apk --debug
shasum -a 256 build/app/outputs/flutter-apk/app-debug.apk
```

Expected:

- Flutter 构建退出码为 0；
- APK 位于 `build/app/outputs/flutter-apk/app-debug.apk`；
- 记录本次新产物 SHA-256，禁止安装构建失败前遗留的旧 APK。

### Step 6：使用 ADB 覆盖安装并启动

以 `emulator-5554` 为例；实际执行必须替换为 Step 4 确认的唯一 serial：

```bash
adb -s emulator-5554 install -r build/app/outputs/flutter-apk/app-debug.apk
adb -s emulator-5554 shell am force-stop com.jade.jade
adb -s emulator-5554 shell monkey -p com.jade.jade -c android.intent.category.LAUNCHER 1
adb -s emulator-5554 shell dumpsys package com.jade.jade
adb -s emulator-5554 shell dumpsys activity activities
```

Expected:

- install 输出 `Success`；
- package version 与本项目当前 `versionName/versionCode` 一致；
- app 进程启动；
- `topResumedActivity` 属于 `com.jade.jade`。

如果实际 applicationId 不是 `com.jade.jade`，必须先从 Android 配置或已安装包
只读确认，再替换命令，不能凭记忆安装或启动。

### Step 7：模拟器交互验收

在模拟器中执行：

1. 打开一部带 `preview_video_url` 的影片详情；
2. 确认剧照列表首项封面仍带播放图标；
3. 点击进入预告片并确认自动横屏；
4. 初始状态确认返回按钮、标题和 Chewie MaterialControls 同时可见；
5. 播放约 3 秒后确认底部原生控制层与整条顶部栏同时隐藏；
6. 单击画面确认两者同时恢复；
7. 双击确认播放/暂停；
8. 长按确认临时 `2.0×`，松手恢复 `1.0×`；
9. 返回详情页并确认恢复竖屏。

真实 M3U8 不可达时：

- 只记录已经观察到的入口、横屏、错误页、重试和返回方向；
- 不宣称控制层显隐、双击或长按已人工通过；
- 自动化测试通过不能冒充真实媒体播放验收。

## 完成条件

- 三个实现任务分别通过独立代码审查，没有 Critical/Important 问题；
- 正常播放顶部栏与 Chewie 原生控制层使用同一 notifier；
- 页面不再外部常驻第二份顶部栏；
- loading/error 顶部栏始终可见；
- 所有聚焦测试、详情/路由测试、`flutter analyze` 和完整 `flutter test` 通过；
- 新 APK 由当前 HEAD 使用 Flutter 命令成功构建，并由 ADB 成功安装到已确认的
  模拟器；
- 工作树干净，最终报告记录 HEAD、测试计数、APK SHA-256、设备 serial 和未验证
  的真实媒体交互项。
