# 影片详情预告片播放器实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在影片详情的剧照列表首位加入预告片入口，并用只允许横屏的 `video_player` 页面播放详情接口返回的 M3U8 预告片。

**Architecture:** 详情数据继续在共享 `MovieDetail` 与 `normalizeMovieDetailJson` 中归一化。`movie_detail` feature 新增类型化路由参数、可替换的播放驱动、播放器页面和独立手势控制层；播放器页面管理 `video_player` 与横屏生命周期，控制层只处理显示、手势、进度和 3 秒隐藏计时。

**Tech Stack:** Flutter 3.44.8、Dart 3.12.2（项目声明下限 Dart 3.8）、Material 3、go_router、json_serializable、video_player 2.10.1、flutter_test。

## Global Constraints

- 以 `docs/main/api/jdb_api_openapi.json` 中的 `preview_video_url` 为唯一预告片数据契约。
- 只新增官方 `video_player`，固定 `2.10.1`；该版本支持项目声明的 Dart 3.8 下限，不引入 Chewie 或其他播放控制插件。
- 预告封面只作为剧照列表首项入口，不得进入 `ImageGalleryViewer` 的图片与索引集合。
- 进入播放页后只允许 `landscapeLeft` 和 `landscapeRight`；销毁页面时以空方向列表恢复系统默认策略。
- 初始化成功后自动播放；单击切换控制层，双击切换播放/暂停，长按期间 `2.0×`、松手或取消后恢复 `1.0×`。
- 播放中 3 秒无操作自动隐藏控制层；暂停、初始化、拖动、长按与错误状态保持显示。
- 用户文案直接硬编码中文，不引入 ARB、本地化、触觉反馈、后台播放、画中画、字幕、清晰度选择或投屏。
- 不新增 Android 明文流量安全例外；现有 `INTERNET` 权限保持不变。
- 严格遵循 RED → GREEN → REFACTOR；每个生产行为必须先看到对应测试因缺少该行为而失败。

---

## 文件结构

### 新建文件

- `lib/features/movie_detail/models/movie_preview_args.dart`：预告片路由参数与 URL 校验。
- `lib/features/movie_detail/services/movie_preview_playback.dart`：播放器状态、可替换播放驱动接口及 `video_player` 适配器。
- `lib/features/movie_detail/widgets/movie_preview_controls.dart`：播放器画面、手势、控制层和自动隐藏计时。
- `lib/features/movie_detail/screens/movie_preview_screen.dart`：横屏、初始化、自动播放、重试和释放生命周期。
- `test/features/movie_detail/movie_preview_controls_test.dart`：手势、进度和自动隐藏 widget 测试。
- `test/features/movie_detail/movie_preview_screen_test.dart`：播放生命周期、错误、重试和横屏测试。

### 修改文件

- `pubspec.yaml`、`pubspec.lock`：加入 `video_player: 2.10.1`。
- `lib/core/models/movie.dart`、`lib/core/models/movie.g.dart`：加入 `previewVideoUrl`。
- `lib/core/network/api_data.dart`：归一化 `preview_video_url`。
- `test/core/network/api_data_test.dart`：覆盖字段解析与空值清理。
- `lib/core/router/routes.dart`、`lib/core/router/app_router.dart`：注册 `/movie/:id/preview`。
- `lib/features/movie_detail/index.dart`：仅导出路由需要的参数与页面。
- `lib/features/movie_detail/screens/movie_detail_screen.dart`：渲染预告封面首项并发起导航。
- `test/features/movie_detail/movie_detail_screen_test.dart`：覆盖入口顺序、语义、无剧照场景、图库索引和路由参数。
- `test/app_router_test.dart`：覆盖预告片路由缺参兜底。

---

### Task 1: 解析影片预告片数据契约

**Files:**

- Modify: `lib/core/models/movie.dart`
- Modify: `lib/core/models/movie.g.dart`
- Modify: `lib/core/network/api_data.dart`
- Test: `test/core/network/api_data_test.dart`

**Interfaces:**

- Consumes: OpenAPI 字段 `movie.preview_video_url`。
- Produces: `MovieDetail.previewVideoUrl`，类型为 `String?`；下游只会收到已去除首尾空白的非空字符串或 `null`，HTTP(S) 合法性由 Task 2 的路由参数层校验。

- [ ] **Step 1: 写字段解析和空值归一化失败测试**

在 `test/core/network/api_data_test.dart` 增加两个测试。第一个使用手写 OpenAPI 形状 fixture，第二个逐项验证缺失、空字符串和空白字符串：

```dart
test('normalizeMovieDetailJson 解析并清理预告片地址', () {
  final movie = MovieDetail.fromJson(
    normalizeMovieDetailJson({
      'movie': {
        'id': 'm1',
        'number': 'ABC-001',
        'title': 'Title',
        'cover_url': 'cover.jpg',
        'preview_video_url': '  https://media.example.com/preview.m3u8?token=a  ',
      },
    }),
  );

  expect(
    movie.previewVideoUrl,
    'https://media.example.com/preview.m3u8?token=a',
  );
});

test('normalizeMovieDetailJson 将缺失或空白预告片地址归一化为 null', () {
  for (final raw in <Object?>[null, '', '   ']) {
    final movie = MovieDetail.fromJson(
      normalizeMovieDetailJson({
        'movie': {
          'id': 'm1',
          'number': 'ABC-001',
          'title': 'Title',
          'cover_url': 'cover.jpg',
          if (raw != null) 'preview_video_url': raw,
        },
      }),
    );

    expect(movie.previewVideoUrl, isNull, reason: 'raw=$raw');
  }
});
```

- [ ] **Step 2: 运行测试并确认 RED**

Run:

```bash
flutter test test/core/network/api_data_test.dart --plain-name 'normalizeMovieDetailJson 解析并清理预告片地址'
flutter test test/core/network/api_data_test.dart --plain-name 'normalizeMovieDetailJson 将缺失或空白预告片地址归一化为 null'
```

Expected: 编译失败，指出 `MovieDetail` 尚无 `previewVideoUrl`。

- [ ] **Step 3: 最小实现模型与归一化**

在 `MovieDetail` 构造函数与字段区加入：

```dart
this.previewVideoUrl,
```

```dart
final String? previewVideoUrl;
```

在 `normalizeMovieDetailJson` 返回值中加入：

```dart
'preview_video_url': _nonEmptyApiString(movie['preview_video_url']),
```

重新生成 JSON 代码：

```bash
dart run build_runner build --delete-conflicting-outputs
```

确认 `movie.g.dart` 的 `_$MovieDetailFromJson` 与 `_$MovieDetailToJson` 分别包含：

```dart
previewVideoUrl: json['preview_video_url'] as String?,
```

```dart
'preview_video_url': instance.previewVideoUrl,
```

- [ ] **Step 4: 运行聚焦测试并确认 GREEN**

Run:

```bash
flutter test test/core/network/api_data_test.dart
```

Expected: `test/core/network/api_data_test.dart` 全部通过。

- [ ] **Step 5: 格式化并提交**

```bash
dart format lib/core/models/movie.dart lib/core/models/movie.g.dart lib/core/network/api_data.dart test/core/network/api_data_test.dart
git add lib/core/models/movie.dart lib/core/models/movie.g.dart lib/core/network/api_data.dart test/core/network/api_data_test.dart
git commit -m "feat: parse movie preview video URL"
```

---

### Task 2: 建立播放器驱动和横屏生命周期页面

**Files:**

- Modify: `pubspec.yaml`
- Modify: `pubspec.lock`
- Create: `lib/features/movie_detail/models/movie_preview_args.dart`
- Create: `lib/features/movie_detail/services/movie_preview_playback.dart`
- Create: `lib/features/movie_detail/screens/movie_preview_screen.dart`
- Test: `test/features/movie_detail/movie_preview_screen_test.dart`

**Interfaces:**

- Consumes: `MoviePreviewArgs(movieId, title, videoUrl)`。
- Produces:
  - `MoviePreviewArgs.videoUri: Uri?`
  - `MoviePreviewPlaybackState`
  - `MoviePreviewPlayback`
  - `MoviePreviewPlaybackFactory`
  - `MoviePreviewPage`
- `MoviePreviewPage` 允许测试注入 `playbackFactory` 与 `orientationSetter`，生产环境默认使用 `video_player` 和 `SystemChrome.setPreferredOrientations`。

- [ ] **Step 1: 添加已核验的播放器依赖**

`video_player` 当前最新版 `2.13.0` 要求 Dart 3.12；为保留项目 `sdk: ^3.8.0` 的声明下限，固定使用仍支持该下限的 `2.10.1`：

```yaml
dependencies:
  video_player: 2.10.1
```

Run:

```bash
flutter pub get
```

Expected: `pubspec.lock` 锁定 `video_player 2.10.1` 及其官方平台实现。

- [ ] **Step 2: 写参数校验与生命周期失败测试**

在 `test/features/movie_detail/movie_preview_screen_test.dart` 创建 `_FakePlayback`，完整实现下面 Step 4 的 `MoviePreviewPlayback` 接口，以 `ValueNotifier<MoviePreviewPlaybackState>` 提供状态，并记录 `initialize`、`play`、`pause`、`setPlaybackSpeed`、`dispose` 调用次数。

加入以下行为测试：

```dart
test('MoviePreviewArgs 只接受带 host 的 HTTP(S) 地址', () {
  expect(
    const MoviePreviewArgs(
      movieId: 'm1',
      title: '测试影片',
      videoUrl: 'https://media.example.com/preview.m3u8',
    ).videoUri,
    Uri.parse('https://media.example.com/preview.m3u8'),
  );
  expect(
    const MoviePreviewArgs(
      movieId: 'm1',
      title: '测试影片',
      videoUrl: 'file:///tmp/preview.m3u8',
    ).videoUri,
    isNull,
  );
  expect(
    const MoviePreviewArgs(
      movieId: 'm1',
      title: '测试影片',
      videoUrl: 'not a URL',
    ).videoUri,
    isNull,
  );
});

testWidgets('进入页面先锁定横屏，初始化成功后自动播放，退出时清理并恢复方向', (
  tester,
) async {
  final playback = _FakePlayback();
  final orientationCalls = <List<DeviceOrientation>>[];

  await tester.pumpWidget(
    MaterialApp(
      home: MoviePreviewPage(
        args: const MoviePreviewArgs(
          movieId: 'm1',
          title: '测试影片',
          videoUrl: 'https://media.example.com/preview.m3u8',
        ),
        playbackFactory: (_) => playback,
        orientationSetter: (orientations) async {
          orientationCalls.add(List.of(orientations));
        },
      ),
    ),
  );
  await tester.pump();

  expect(orientationCalls.first, [
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  expect(playback.initializeCalls, 1);
  expect(playback.playCalls, 1);

  await tester.pumpWidget(const SizedBox());
  await tester.pump();

  expect(playback.pauseCalls, 1);
  expect(playback.speedCalls.last, 1.0);
  expect(playback.disposeCalls, 1);
  expect(orientationCalls.last, isEmpty);
});
```

另写两个独立测试：

- 非法 URL 显示“预告片播放失败”，且 factory 调用次数为 0。
- 第一个 fake 的 `initialize` 抛出异常后显示“重试”；点击后释放第一个 fake，创建第二个 fake，并在第二次初始化成功后自动播放。

- [ ] **Step 3: 运行测试并确认 RED**

Run:

```bash
flutter test test/features/movie_detail/movie_preview_screen_test.dart
```

Expected: 编译失败，指出参数、播放接口和页面尚不存在。

- [ ] **Step 4: 实现类型化参数与播放驱动边界**

在 `movie_preview_args.dart` 实现：

```dart
class MoviePreviewArgs {
  const MoviePreviewArgs({
    required this.movieId,
    required this.title,
    required this.videoUrl,
  });

  final String movieId;
  final String title;
  final String videoUrl;

  Uri? get videoUri {
    final uri = Uri.tryParse(videoUrl);
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty) {
      return null;
    }
    return uri;
  }
}
```

在 `movie_preview_playback.dart` 定义稳定边界：

```dart
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
  Future<void> setPlaybackSpeed(double speed);
  Future<void> dispose();
}

typedef MoviePreviewPlaybackFactory = MoviePreviewPlayback Function(Uri uri);
```

实现 `VideoPlayerMoviePreviewPlayback`：

- 用 `VideoPlayerController.networkUrl(uri, formatHint: VideoFormat.hls)` 创建控制器。
- 注册一个 listener，将 `VideoPlayerValue` 的初始化、播放、缓冲、结束、位置、时长、宽高比和错误映射到 `ValueNotifier<MoviePreviewPlaybackState>`。
- `buildView()` 返回 `VideoPlayer(_controller)`。
- 其余方法只转发给 `VideoPlayerController`。
- `dispose()` 先移除 listener，再释放 controller 和 notifier。

- [ ] **Step 5: 实现页面初始化、重试和销毁**

`MoviePreviewPage` 构造函数使用以下 API：

```dart
typedef PreferredOrientationsSetter =
    Future<void> Function(List<DeviceOrientation> orientations);

class MoviePreviewPage extends StatefulWidget {
  const MoviePreviewPage({
    super.key,
    required this.args,
    this.playbackFactory,
    this.orientationSetter,
  });

  final MoviePreviewArgs? args;
  final MoviePreviewPlaybackFactory? playbackFactory;
  final PreferredOrientationsSetter? orientationSetter;
}
```

页面状态按固定顺序执行：

1. `initState` 中异步请求左右横屏。
2. 校验 `args?.videoUri`；失败时设置错误“预告片播放失败”，不创建驱动。
3. 通过 factory 创建驱动并 `await initialize()`。
4. `mounted` 且本次初始化仍为最新代次时调用 `play()`。
5. 捕获初始化异常并显示“预告片播放失败”和“重试”按钮。
6. 重试先释放旧驱动，再为同一 URI 创建新驱动。
7. `dispose` 中启动一个有序异步清理：`setPlaybackSpeed(1.0)`、`pause()`、`dispose()`，最后调用 `orientationSetter([])`；每一步独立捕获异常，保证方向一定恢复。

本任务先用黑色 `Scaffold`、加载指示、错误文案、重试按钮和 `AspectRatio(child: playback.buildView())` 完成基础页面；Task 3 再替换为完整控制层。

- [ ] **Step 6: 运行生命周期测试并确认 GREEN**

Run:

```bash
flutter test test/features/movie_detail/movie_preview_screen_test.dart
```

Expected: 参数校验、自动播放、错误重试、销毁和横屏恢复全部通过，且 `tester.takeException()` 为 `null`。

- [ ] **Step 7: 格式化并提交**

```bash
dart format lib/features/movie_detail/models/movie_preview_args.dart lib/features/movie_detail/services/movie_preview_playback.dart lib/features/movie_detail/screens/movie_preview_screen.dart test/features/movie_detail/movie_preview_screen_test.dart
git add pubspec.yaml pubspec.lock lib/features/movie_detail/models/movie_preview_args.dart lib/features/movie_detail/services/movie_preview_playback.dart lib/features/movie_detail/screens/movie_preview_screen.dart test/features/movie_detail/movie_preview_screen_test.dart
git commit -m "feat: add landscape movie preview playback"
```

---

### Task 3: 实现播放器手势、进度与自动隐藏控制层

**Files:**

- Create: `lib/features/movie_detail/widgets/movie_preview_controls.dart`
- Modify: `lib/features/movie_detail/screens/movie_preview_screen.dart`
- Test: `test/features/movie_detail/movie_preview_controls_test.dart`
- Test: `test/features/movie_detail/movie_preview_screen_test.dart`

**Interfaces:**

- Consumes: Task 2 的 `MoviePreviewPlaybackState` 及页面提供的播放命令。
- Produces: `MoviePreviewControls`，控制层不直接依赖 `VideoPlayerController`。

- [ ] **Step 1: 写单击与双击失败测试**

使用初始化且正在播放的固定状态、`SizedBox.expand()` 视频占位和回调计数器挂载 `MoviePreviewControls`。

测试契约：

```dart
testWidgets('单击只切换控制层，双击只切换播放状态', (tester) async {
  var togglePlaybackCalls = 0;
  final widget = _buildControls(
    onTogglePlayback: () async {
      togglePlaybackCalls += 1;
    },
  );

  await tester.pumpWidget(widget);
  expect(
    find.byKey(const Key('movie-preview-controls-overlay')),
    findsOneWidget,
  );

  await tester.tap(find.byKey(const Key('movie-preview-gesture-surface')));
  await tester.pump(kDoubleTapTimeout);
  expect(find.byKey(const Key('movie-preview-controls-overlay')), findsNothing);
  expect(togglePlaybackCalls, 0);

  final center = tester.getCenter(
    find.byKey(const Key('movie-preview-gesture-surface')),
  );
  await tester.tapAt(center);
  await tester.pump(const Duration(milliseconds: 50));
  await tester.tapAt(center);
  await tester.pump();
  expect(togglePlaybackCalls, 1);
  expect(
    find.byKey(const Key('movie-preview-controls-overlay')),
    findsOneWidget,
  );
});
```

- [ ] **Step 2: 写长按倍速失败测试**

```dart
testWidgets('长按期间使用 2 倍速，松手后恢复 1 倍速', (tester) async {
  final speeds = <double>[];
  await tester.pumpWidget(
    _buildControls(
      onSetPlaybackSpeed: (speed) async {
        speeds.add(speed);
      },
    ),
  );

  final center = tester.getCenter(
    find.byKey(const Key('movie-preview-gesture-surface')),
  );
  final gesture = await tester.startGesture(center);
  await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));

  expect(speeds, [2.0]);
  expect(find.text('2.0×'), findsOneWidget);

  await gesture.up();
  await tester.pump();
  expect(speeds, [2.0, 1.0]);
  expect(find.text('2.0×'), findsNothing);
});
```

再增加取消路径测试：触发长按后调用 `gesture.cancel()`，也必须得到 `[2.0, 1.0]`。

- [ ] **Step 3: 写自动隐藏与保持显示失败测试**

分开验证以下状态，避免一个测试混合多个故障：

- 正在播放时 `2 秒 999 毫秒` 仍显示，累计到 `3 秒` 后隐藏。
- 暂停时泵入超过 3 秒仍显示。
- `isBuffering: true` 时泵入超过 3 秒仍显示。
- 拖动进度条期间泵入超过 3 秒仍显示，拖动结束后重新计时。
- `errorDescription` 非空时显示“预告片播放失败”和“重试”，泵入超过 3 秒仍显示。
- 卸载 widget 后泵入超过 3 秒不抛出 timer 驱动的 `setState after dispose`。

- [ ] **Step 4: 运行控制层测试并确认 RED**

Run:

```bash
flutter test test/features/movie_detail/movie_preview_controls_test.dart
```

Expected: 编译失败，指出 `MoviePreviewControls` 尚不存在。

- [ ] **Step 5: 实现控制层公开 API**

使用以下构造函数，所有播放器副作用均通过回调传入：

```dart
class MoviePreviewControls extends StatefulWidget {
  const MoviePreviewControls({
    super.key,
    required this.title,
    required this.video,
    required this.playbackState,
    required this.onBack,
    required this.onTogglePlayback,
    required this.onSeek,
    required this.onSetPlaybackSpeed,
    required this.onRetry,
    this.autoHideDelay = const Duration(seconds: 3),
  });

  final String title;
  final Widget video;
  final MoviePreviewPlaybackState playbackState;
  final VoidCallback onBack;
  final Future<void> Function() onTogglePlayback;
  final Future<void> Function(Duration position) onSeek;
  final Future<void> Function(double speed) onSetPlaybackSpeed;
  final Future<void> Function() onRetry;
  final Duration autoHideDelay;
}
```

内部状态固定为：

```dart
bool _controlsVisible = true;
bool _isDragging = false;
bool _isLongPressing = false;
double? _dragPositionMilliseconds;
Timer? _hideTimer;
```

实现规则：

- 外层 `GestureDetector` 使用 key `movie-preview-gesture-surface`。
- `onTap` 切换 `_controlsVisible`；显示时调用 `_scheduleAutoHide()`。
- `onDoubleTap` 强制显示控制层、调用 `onTogglePlayback()`，并重新计时。
- `onLongPressStart` 取消隐藏 timer、显示“2.0×”、调用 `onSetPlaybackSpeed(2.0)`。
- `onLongPressEnd` 与 `onLongPressCancel` 共用 `_finishLongPress()`，只执行一次 `onSetPlaybackSpeed(1.0)` 并重新计时。
- `_scheduleAutoHide()` 只在正在播放、已初始化、非缓冲、非拖动、非长按且无错误时创建 timer。
- `didUpdateWidget` 在播放状态、缓冲状态、完成状态或错误变化时取消或重建 timer；完成状态保持控制层显示。
- `dispose` 取消 timer；若仍在长按，异步请求恢复 `1.0×`。
- 视频用 `Center > AspectRatio(playbackState.aspectRatio) > video`，背景保持黑色。
- 控制 overlay 使用 key `movie-preview-controls-overlay`，并将左上返回/标题、中央播放暂停、底部时间和 `Slider` 放在 `SafeArea` 内。
- Slider 使用毫秒数；拖动开始设置 `_isDragging` 并取消 timer，拖动结束调用 `onSeek` 后清空临时进度并重新计时。
- 当 `duration == Duration.zero` 时，总时长显示 `--:--` 且 Slider 的 `onChanged` 为 `null`；已知时长使用 `mm:ss`，超过一小时使用 `hh:mm:ss`。
- 缓冲时在画面中央显示 `CircularProgressIndicator`；错误时显示“预告片播放失败”和“重试”。

- [ ] **Step 6: 将控制层接入播放页面**

在 `MoviePreviewPage` 用 `ValueListenableBuilder<MoviePreviewPlaybackState>` 重建 `MoviePreviewControls`，回调映射为：

```dart
Future<void> _togglePlayback() async {
  final playback = _playback;
  if (playback == null) return;
  final value = playback.state.value;
  if (value.isCompleted) {
    await playback.seekTo(Duration.zero);
    await playback.play();
  } else if (value.isPlaying) {
    await playback.pause();
  } else {
    await playback.play();
  }
}
```

- `onBack`: `Navigator.of(context).pop()`。
- `onSeek`: `playback.seekTo`。
- `onSetPlaybackSpeed`: `playback.setPlaybackSpeed`。
- `onRetry`: Task 2 的重试方法。

补充页面测试，验证完成状态执行 `seekTo(Duration.zero)` 后再 `play()`，暂停状态只执行 `play()`，播放状态只执行 `pause()`。

- [ ] **Step 7: 运行控制层和页面测试并确认 GREEN**

Run:

```bash
flutter test test/features/movie_detail/movie_preview_controls_test.dart
flutter test test/features/movie_detail/movie_preview_screen_test.dart
```

Expected: 手势、3 秒隐藏、错误、进度、完成后重播和生命周期测试全部通过。

- [ ] **Step 8: 格式化并提交**

```bash
dart format lib/features/movie_detail/widgets/movie_preview_controls.dart lib/features/movie_detail/screens/movie_preview_screen.dart test/features/movie_detail/movie_preview_controls_test.dart test/features/movie_detail/movie_preview_screen_test.dart
git add lib/features/movie_detail/widgets/movie_preview_controls.dart lib/features/movie_detail/screens/movie_preview_screen.dart test/features/movie_detail/movie_preview_controls_test.dart test/features/movie_detail/movie_preview_screen_test.dart
git commit -m "feat: add movie preview gestures and controls"
```

---

### Task 4: 在详情剧照列表首位接入预告片路由

**Files:**

- Modify: `lib/core/router/routes.dart`
- Modify: `lib/core/router/app_router.dart`
- Modify: `lib/features/movie_detail/index.dart`
- Modify: `lib/features/movie_detail/screens/movie_detail_screen.dart`
- Test: `test/features/movie_detail/movie_detail_screen_test.dart`
- Test: `test/app_router_test.dart`

**Interfaces:**

- Consumes: Task 1 的 `MovieDetail.previewVideoUrl`、Task 2 的 `MoviePreviewArgs` 与 `MoviePreviewPage`。
- Produces:
  - `AppRoutes.moviePreview = '/movie/:id/preview'`
  - `AppRoutes.moviePreviewLocation(String movieId)`
  - 详情页首位 key `movie-detail-preview`
  - 播放图标 key `movie-detail-preview-play-icon`

- [ ] **Step 1: 扩展详情 fixture 并写入口失败测试**

将 `_enqueueCompleteMovieDetail` 改为可选参数，但默认保持现有测试无预告片：

```dart
void _enqueueCompleteMovieDetail(
  FakeAdapter adapter, {
  String? previewVideoUrl,
  List<Object?> previewImages = const [
    {'url': 'screenshots/test.jpg'},
    {'url': 'screenshots/test-2.jpg'},
  ],
}) {
```

fixture 的 `movie` map 使用：

```dart
if (previewVideoUrl != null) 'preview_video_url': previewVideoUrl,
'preview_images': previewImages,
```

新增三个 widget 测试：

1. `有预告片时封面入口位于第一项并具有播放语义`
   - 传入 M3U8 URL。
   - 滚动到 section。
   - 找到 `movie-detail-preview`、`movie-detail-preview-play-icon` 和 `movie-detail-screenshot-0`。
   - 断言预告入口的左坐标小于第一张普通剧照。
   - 断言语义标签为“播放《测试影片》预告片”。

2. `只有预告片时仍显示预告片剧照区域`
   - 传入 M3U8 URL 和空 `previewImages`。
   - 断言 section 与预告入口存在，`MovieScreenshotImage` 不存在。

3. `没有预告片时保持普通剧照列表`
   - 使用默认 fixture。
   - 断言预告入口不存在，两个剧照 key 均存在。

- [ ] **Step 2: 写图库索引与导航失败测试**

图库回归测试使用带预告片 fixture，点击 `movie-detail-screenshot-1` 后仍断言：

```dart
expect(find.text('2 / 2'), findsOneWidget);
```

导航测试使用局部 `GoRouter`，目标子路由只渲染“预告播放页”占位并保存 `state.extra`。点击预告入口后断言：

```dart
expect(router.state.uri.path, '/movie/m1/preview');
expect(capturedArgs, isA<MoviePreviewArgs>());
final args = capturedArgs! as MoviePreviewArgs;
expect(args.movieId, 'm1');
expect(args.title, '测试影片');
expect(args.videoUrl, 'https://media.example.com/preview.m3u8');
```

在 `test/app_router_test.dart` 增加直接访问 `/movie/m1/preview` 且没有 `extra` 的测试，断言显示“预告片播放失败”，证明正式路由存在且缺参安全。

- [ ] **Step 3: 运行测试并确认 RED**

Run:

```bash
flutter test test/features/movie_detail/movie_detail_screen_test.dart --plain-name '有预告片时封面入口位于第一项并具有播放语义'
flutter test test/features/movie_detail/movie_detail_screen_test.dart --plain-name '只有预告片时仍显示预告片剧照区域'
flutter test test/features/movie_detail/movie_detail_screen_test.dart --plain-name '点击预告入口传递播放参数'
flutter test test/app_router_test.dart --plain-name '预告片路由缺少参数时显示安全错误页'
```

Expected: 入口 key、路由常量或页面路由尚不存在导致失败。

- [ ] **Step 4: 注册正式路由与导出**

在 `AppRoutes` 增加：

```dart
static const String moviePreview = '/movie/:id/preview';

static String moviePreviewLocation(String movieId) =>
    '/movie/${Uri.encodeComponent(movieId)}/preview';
```

在 `AppRouter._routes` 中将更具体的预告片路由注册在详情路由之前：

```dart
GoRoute(
  path: AppRoutes.moviePreview,
  builder: (context, state) => MoviePreviewPage(
    args: state.extra is MoviePreviewArgs
        ? state.extra! as MoviePreviewArgs
        : null,
  ),
),
```

`lib/features/movie_detail/index.dart` 只增加：

```dart
export 'models/movie_preview_args.dart';
export 'screens/movie_preview_screen.dart';
```

- [ ] **Step 5: 实现详情页预告入口**

从 `MovieDetailPage.build` 创建导航回调，并依次传入 `_MovieDetailTabs`、`_BasicInfoTab` 和 `_ScreenshotSection`：

```dart
onPreviewTap: () => context.push(
  AppRoutes.moviePreviewLocation(detail.id),
  extra: MoviePreviewArgs(
    movieId: detail.id,
    title: detail.title,
    videoUrl: detail.previewVideoUrl!,
  ),
),
```

基本信息页显示条件改为：

```dart
if (detail.previewVideoUrl != null || detail.screenshots.isNotEmpty)
  _ScreenshotSection(
    urls: detail.screenshots,
    previewCoverUrl:
        detail.previewVideoUrl == null ? null : detail.coverUrl,
    previewTitle: detail.title,
    onPreviewTap: onPreviewTap,
  ),
```

`_ScreenshotSection` 的 `itemCount` 为 `urls.length + (hasPreview ? 1 : 0)`。当 `index == 0 && hasPreview` 时渲染：

```dart
Semantics(
  button: true,
  label: '播放《$previewTitle》预告片',
  child: AspectRatio(
    aspectRatio: 16 / 9,
    child: Material(
      clipBehavior: Clip.antiAlias,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        key: const Key('movie-detail-preview'),
        onTap: onPreviewTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            MovieCoverImage(
              previewCoverUrl!,
              variant: MovieImageVariant.cover,
              fit: BoxFit.cover,
            ),
            const Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Color(0x99000000),
                  shape: BoxShape.circle,
                ),
                child: Padding(
                  padding: EdgeInsets.all(10),
                  child: Icon(
                    Icons.play_arrow_rounded,
                    key: Key('movie-detail-preview-play-icon'),
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  ),
)
```

普通剧照使用 `screenshotIndex = index - (hasPreview ? 1 : 0)` 读取 URL、生成 key、语义标签和图库 `initialIndex`，确保所有索引只基于 `urls`。

- [ ] **Step 6: 运行详情与路由测试并确认 GREEN**

Run:

```bash
flutter test test/features/movie_detail/movie_detail_screen_test.dart
flutter test test/app_router_test.dart
```

Expected: 新增入口、路由、语义和图库回归测试通过，既有详情与根路由测试无回归。

- [ ] **Step 7: 格式化并提交**

```bash
dart format lib/core/router/routes.dart lib/core/router/app_router.dart lib/features/movie_detail/index.dart lib/features/movie_detail/screens/movie_detail_screen.dart test/features/movie_detail/movie_detail_screen_test.dart test/app_router_test.dart
git add lib/core/router/routes.dart lib/core/router/app_router.dart lib/features/movie_detail/index.dart lib/features/movie_detail/screens/movie_detail_screen.dart test/features/movie_detail/movie_detail_screen_test.dart test/app_router_test.dart
git commit -m "feat: open movie previews from detail"
```

---

### Task 5: 全量验证与变更审计

**Files:**

- Verify only: all files changed by Tasks 1–4

**Interfaces:**

- Consumes: 四个已提交的功能单元。
- Produces: 可复核的格式化、聚焦测试、静态分析、全量测试和 Git 范围证据。

- [ ] **Step 1: 格式化所有相关 Dart 文件**

```bash
dart format lib/core/models/movie.dart lib/core/models/movie.g.dart lib/core/network/api_data.dart lib/core/router/routes.dart lib/core/router/app_router.dart lib/features/movie_detail/index.dart lib/features/movie_detail/models/movie_preview_args.dart lib/features/movie_detail/services/movie_preview_playback.dart lib/features/movie_detail/widgets/movie_preview_controls.dart lib/features/movie_detail/screens/movie_preview_screen.dart lib/features/movie_detail/screens/movie_detail_screen.dart test/core/network/api_data_test.dart test/features/movie_detail/movie_preview_controls_test.dart test/features/movie_detail/movie_preview_screen_test.dart test/features/movie_detail/movie_detail_screen_test.dart test/app_router_test.dart
```

Expected: formatter 正常退出；若产生改动，只提交相关格式化文件并使用提交信息 `style: format movie preview player`。

- [ ] **Step 2: 运行聚焦测试**

```bash
flutter test test/core/network/api_data_test.dart
flutter test test/features/movie_detail/movie_preview_controls_test.dart
flutter test test/features/movie_detail/movie_preview_screen_test.dart
flutter test test/features/movie_detail/movie_detail_screen_test.dart
flutter test test/app_router_test.dart
```

Expected: 五个测试文件全部通过，无未捕获异常。

- [ ] **Step 3: 运行静态分析**

```bash
flutter analyze
```

Expected: `No issues found!`

- [ ] **Step 4: 运行完整测试**

```bash
flutter test
```

Expected: 全部测试通过。若命令仅因 `/opt/homebrew/share/flutter` 下 SDK 缓存不可写而失败，先按环境权限问题报告，不得写成测试通过；获得允许后在非沙箱环境重跑同一命令。

- [ ] **Step 5: 审计最终范围**

```bash
git status --short
git diff --check
git log --oneline --decorate -8
```

Expected:

- 没有未提交的功能文件；
- `git diff --check` 无空白错误；
- 提交历史只包含计划中列出的数据、播放生命周期、控制层和详情入口提交；
- 不包含 Android 网络安全放宽、iOS 配置、正片播放或其他无关修改。
