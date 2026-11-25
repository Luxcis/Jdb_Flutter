import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/features/movie_detail/services/movie_preview_brightness.dart';
import 'package:jade/features/movie_detail/services/movie_preview_playback.dart';
import 'package:jade/features/movie_detail/services/movie_preview_volume.dart';
import 'package:jade/features/movie_detail/widgets/movie_preview_controls_overlay.dart';

void main() {
  testWidgets('双击播放画面切换播放/暂停', (tester) async {
    final playback = _FakePlayback(
      initialState: const MoviePreviewPlaybackState(isInitialized: true),
    );
    await _pumpOverlay(tester, playback);

    await _doubleTapAt(tester, _centerPoint());
    await tester.pump(kDoubleTapTimeout);

    expect(playback.commands, ['play']);
  });

  testWidgets('双击完成态重新播放', (tester) async {
    final playback = _FakePlayback(
      initialState: const MoviePreviewPlaybackState(
        isInitialized: true,
        isCompleted: true,
      ),
    );
    await _pumpOverlay(tester, playback);

    await _doubleTapAt(tester, _centerPoint());
    await tester.pump(kDoubleTapTimeout);

    expect(playback.commands, ['seek:0', 'play']);
  });

  testWidgets('单击切换顶部标题栏与底部操作栏同步显隐', (tester) async {
    final playback = _FakePlayback(
      initialState: const MoviePreviewPlaybackState(
        isInitialized: true,
        isPlaying: true,
      ),
    );
    await _pumpOverlay(tester, playback);

    expect(_headerOpacity(tester), 1.0);
    expect(_bottomOpacity(tester), 1.0);

    await tester.tapAt(_centerPoint());
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(_headerOpacity(tester), 0.0);
    expect(_bottomOpacity(tester), 0.0);

    await tester.tapAt(_centerPoint());
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(_headerOpacity(tester), 1.0);
    expect(_bottomOpacity(tester), 1.0);
  });

  testWidgets('播放中 3 秒无操作自动隐藏操作层', (tester) async {
    final playback = _FakePlayback(
      initialState: const MoviePreviewPlaybackState(
        isInitialized: true,
        isPlaying: true,
      ),
    );
    await _pumpOverlay(tester, playback);

    expect(_headerOpacity(tester), 1.0);
    await tester.pump(const Duration(seconds: 3));
    expect(_headerOpacity(tester), 0.0);
    expect(_bottomOpacity(tester), 0.0);
  });

  testWidgets('暂停时操作层保持显示', (tester) async {
    final playback = _FakePlayback(
      initialState: const MoviePreviewPlaybackState(isInitialized: true),
    );
    await _pumpOverlay(tester, playback);

    await tester.pump(const Duration(seconds: 4));
    expect(_headerOpacity(tester), 1.0);
    expect(_bottomOpacity(tester), 1.0);
  });

  testWidgets('长按 2 倍速，松开恢复', (tester) async {
    final playback = _FakePlayback(
      initialState: const MoviePreviewPlaybackState(
        isInitialized: true,
        isPlaying: true,
      ),
    );
    await _pumpOverlay(tester, playback);

    final gesture = await tester.startGesture(_centerPoint());
    await tester.pump(const Duration(milliseconds: 600));
    expect(playback.rates, [2.0]);
    expect(
      find.byKey(MoviePreviewControlsOverlay.indicatorKey),
      findsOneWidget,
    );

    await gesture.up();
    await tester.pump();
    expect(playback.rates, [2.0, 1.0]);
    await tester.pump(kDoubleTapTimeout);
  });

  testWidgets('屏幕左半区垂直滑动调节亮度并显示指示器', (tester) async {
    final brightness = FakeMoviePreviewBrightnessController(initial: 0.5);
    await _pumpOverlay(
      tester,
      _FakePlayback(
        initialState: const MoviePreviewPlaybackState(
          isInitialized: true,
          isPlaying: true,
        ),
      ),
      brightnessController: brightness,
    );

    await tester.dragFrom(const Offset(80.0, 300.0), const Offset(0.0, -100.0));
    await tester.pump();

    expect(brightness.setValues.last, greaterThan(0.5));
    expect(brightness.setValues.last, lessThanOrEqualTo(1.0));
    expect(
      find.byKey(MoviePreviewControlsOverlay.indicatorKey),
      findsOneWidget,
    );
    await tester.pump(kDoubleTapTimeout);
  });

  testWidgets('屏幕右半区垂直滑动调节音量并显示指示器', (tester) async {
    final volume = FakeMoviePreviewVolumeController(initial: 0.5);
    await _pumpOverlay(
      tester,
      _FakePlayback(
        initialState: const MoviePreviewPlaybackState(
          isInitialized: true,
          isPlaying: true,
        ),
      ),
      volumeController: volume,
    );

    await tester.dragFrom(const Offset(720.0, 300.0), const Offset(0.0, 100.0));
    await tester.pump();

    expect(volume.setValues.last, lessThan(0.5));
    expect(volume.setValues.last, greaterThanOrEqualTo(0.0));
    expect(
      find.byKey(MoviePreviewControlsOverlay.indicatorKey),
      findsOneWidget,
    );
    await tester.pump(kDoubleTapTimeout);
  });

  testWidgets('水平滑动快进快退并显示目标位置指示器', (tester) async {
    final playback = _FakePlayback(
      initialState: const MoviePreviewPlaybackState(
        isInitialized: true,
        isPlaying: true,
        position: Duration(seconds: 30),
        duration: Duration(minutes: 2),
      ),
    );
    await _pumpOverlay(tester, playback);

    await tester.dragFrom(const Offset(400.0, 300.0), const Offset(100.0, 0.0));
    await tester.pump();

    expect(playback.seekPositions, isNotEmpty);
    expect(
      find.byKey(MoviePreviewControlsOverlay.indicatorKey),
      findsOneWidget,
    );
    await tester.pump(kDoubleTapTimeout);
  });

  testWidgets('点击进度条 50% 位置按进度条宽度 seek 到一半时长', (tester) async {
    final playback = _FakePlayback(
      initialState: const MoviePreviewPlaybackState(
        isInitialized: true,
        isPlaying: true,
        position: Duration.zero,
        duration: Duration(minutes: 2),
      ),
    );
    await _pumpOverlay(tester, playback);

    await _tapProgressBar(tester, 0.5);

    expect(playback.seekPositions, hasLength(1));
    expect(
      playback.seekPositions.single.inMilliseconds,
      closeTo(const Duration(minutes: 1).inMilliseconds, 1000),
    );
    await tester.pump(kDoubleTapTimeout);
  });

  testWidgets('点击进度条最右端 seek 到接近视频结尾', (tester) async {
    final playback = _FakePlayback(
      initialState: const MoviePreviewPlaybackState(
        isInitialized: true,
        isPlaying: true,
        position: Duration.zero,
        duration: Duration(minutes: 2),
      ),
    );
    await _pumpOverlay(tester, playback);

    await _tapProgressBar(tester, 1.0, insetPixels: 1.0);

    final target = playback.seekPositions.single.inMilliseconds;
    final total = const Duration(minutes: 2).inMilliseconds;
    expect(target, greaterThan((total * 0.95).round()));
    expect(target, lessThanOrEqualTo(total));
    await tester.pump(kDoubleTapTimeout);
  });

  testWidgets('拖动进度条时填充跟随手指且按进度条宽度 seek', (tester) async {
    final playback = _FakePlayback(
      initialState: const MoviePreviewPlaybackState(
        isInitialized: true,
        isPlaying: true,
        position: Duration.zero,
        duration: Duration(minutes: 2),
      ),
    );
    await _pumpOverlay(tester, playback);

    final box = _progressBarBox(tester);
    final topLeft = box.localToGlobal(Offset.zero);
    final gesture = await tester.startGesture(
      topLeft + Offset(box.size.width * 0.25, box.size.height / 2),
    );
    await tester.pump();
    // 第一次移动越过拖动阈值，让进度条的手势识别器赢得手势竞技场。
    await gesture.moveBy(Offset(box.size.width * 0.1, 0));
    await tester.pump();
    await gesture.moveBy(Offset(box.size.width * 0.4, 0));
    await tester.pump();

    final fill = tester.widget<FractionallySizedBox>(
      find.descendant(
        of: find.byKey(MoviePreviewControlsOverlay.progressBarKey),
        matching: find.byType(FractionallySizedBox),
      ),
    );
    expect(fill.widthFactor, closeTo(0.75, 0.02));

    await gesture.up();
    await tester.pump();
    expect(
      playback.seekPositions.last.inMilliseconds,
      closeTo(const Duration(seconds: 90).inMilliseconds, 1500),
    );
    await tester.pump(kDoubleTapTimeout);
  });

  testWidgets('初始缓冲结束后恢复播放会重新计时并自动隐藏', (tester) async {
    final playback = _FakePlayback(
      initialState: const MoviePreviewPlaybackState(
        isInitialized: true,
        isPlaying: true,
        isBuffering: true,
      ),
    );
    await _pumpOverlay(tester, playback);

    expect(_headerOpacity(tester), 1.0);
    await tester.pump(const Duration(seconds: 4));
    expect(_headerOpacity(tester), 1.0, reason: '缓冲期间不应自动隐藏');

    playback.emit(
      const MoviePreviewPlaybackState(isInitialized: true, isPlaying: true),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));

    expect(_headerOpacity(tester), 0.0);
    expect(_bottomOpacity(tester), 0.0);
  });

  testWidgets('暂停恢复播放后重新计时并自动隐藏', (tester) async {
    final playback = _FakePlayback(
      initialState: const MoviePreviewPlaybackState(
        isInitialized: true,
        isPlaying: true,
      ),
    );
    await _pumpOverlay(tester, playback);

    playback.emit(const MoviePreviewPlaybackState(isInitialized: true));
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));
    expect(_headerOpacity(tester), 1.0, reason: '暂停期间应保持显示');

    playback.emit(
      const MoviePreviewPlaybackState(isInitialized: true, isPlaying: true),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));

    expect(_headerOpacity(tester), 0.0);
    expect(_bottomOpacity(tester), 0.0);
  });

  testWidgets('手动唤起操作层后按规则再次自动隐藏', (tester) async {
    final playback = _FakePlayback(
      initialState: const MoviePreviewPlaybackState(
        isInitialized: true,
        isPlaying: true,
      ),
    );
    await _pumpOverlay(tester, playback);

    await tester.pump(const Duration(seconds: 3));
    expect(_headerOpacity(tester), 0.0);

    await tester.tapAt(_centerPoint());
    await tester.pump(const Duration(milliseconds: 500));
    expect(_headerOpacity(tester), 1.0);

    await tester.pump(const Duration(seconds: 3));
    expect(_headerOpacity(tester), 0.0);
  });

  testWidgets('亮度/音量调节失败不中断播放与操作层', (tester) async {
    final brightness = FakeMoviePreviewBrightnessController()
      ..error = Exception('brightness failed');
    final volume = FakeMoviePreviewVolumeController()
      ..error = Exception('volume failed');
    await _pumpOverlay(
      tester,
      _FakePlayback(
        initialState: const MoviePreviewPlaybackState(
          isInitialized: true,
          isPlaying: true,
        ),
      ),
      brightnessController: brightness,
      volumeController: volume,
    );

    await tester.dragFrom(const Offset(80.0, 300.0), const Offset(0.0, -50.0));
    await tester.dragFrom(const Offset(720.0, 300.0), const Offset(0.0, 50.0));
    await tester.pump();

    expect(tester.takeException(), isNull);
    await tester.pump(kDoubleTapTimeout);
  });
}

Future<void> _pumpOverlay(
  WidgetTester tester,
  _FakePlayback playback, {
  FakeMoviePreviewBrightnessController? brightnessController,
  FakeMoviePreviewVolumeController? volumeController,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: Colors.black),
            MoviePreviewControlsOverlay(
              title: '测试影片',
              onBack: () {},
              playback: playback,
              brightnessController:
                  brightnessController ??
                  FakeMoviePreviewBrightnessController(),
              volumeController:
                  volumeController ?? FakeMoviePreviewVolumeController(),
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pump();
}

Offset _centerPoint() => const Offset(400.0, 300.0);

RenderBox _progressBarBox(WidgetTester tester) =>
    tester.renderObject<RenderBox>(
      find.byKey(MoviePreviewControlsOverlay.progressBarKey),
    );

Future<void> _tapProgressBar(
  WidgetTester tester,
  double fraction, {
  double insetPixels = 0.0,
}) async {
  final box = _progressBarBox(tester);
  final topLeft = box.localToGlobal(Offset.zero);
  final dx = (box.size.width * fraction - insetPixels).clamp(
    0.0,
    box.size.width - 1.0,
  );
  await tester.tapAt(topLeft + Offset(dx, box.size.height / 2));
  await tester.pump();
}

Future<void> _doubleTapAt(WidgetTester tester, Offset point) async {
  await tester.tapAt(point);
  await tester.pump(const Duration(milliseconds: 50));
  await tester.tapAt(point);
  await tester.pump();
}

double _headerOpacity(WidgetTester tester) {
  final opacity = tester.widget<AnimatedOpacity>(
    find.byKey(MoviePreviewControlsOverlay.headerOpacityKey),
  );
  return opacity.opacity;
}

double _bottomOpacity(WidgetTester tester) {
  final opacity = tester.widget<AnimatedOpacity>(
    find.byKey(MoviePreviewControlsOverlay.bottomOpacityKey),
  );
  return opacity.opacity;
}

class _FakePlayback implements MoviePreviewPlayback {
  _FakePlayback({this.initialState = const MoviePreviewPlaybackState()});

  final MoviePreviewPlaybackState initialState;
  late final _state = ValueNotifier(initialState);
  final commands = <String>[];
  final seekPositions = <Duration>[];
  final rates = <double>[];

  @override
  ValueListenable<MoviePreviewPlaybackState> get state => _state;

  void emit(MoviePreviewPlaybackState value) => _state.value = value;

  @override
  Widget buildView() => const SizedBox.expand();

  @override
  Future<void> initialize() async {}

  @override
  Future<void> play() async {
    commands.add('play');
  }

  @override
  Future<void> pause() async {
    commands.add('pause');
  }

  @override
  Future<void> seekTo(Duration position) async {
    commands.add('seek:${position.inMilliseconds}');
    seekPositions.add(position);
  }

  @override
  Future<void> setRate(double rate) async {
    commands.add('rate:$rate');
    rates.add(rate);
  }

  @override
  Future<void> dispose() async {}
}
