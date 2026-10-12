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

  testWidgets('点击底部进度条 seek 到对应位置', (tester) async {
    final playback = _FakePlayback(
      initialState: const MoviePreviewPlaybackState(
        isInitialized: true,
        isPlaying: true,
        position: Duration.zero,
        duration: Duration(minutes: 2),
      ),
    );
    await _pumpOverlay(tester, playback);

    final barBox =
        tester.renderObject(find.byType(LayoutBuilder).at(1)) as RenderBox;
    final barTopLeft = barBox.localToGlobal(Offset.zero);
    await tester.tapAt(
      barTopLeft + Offset(barBox.size.width * 0.25, barBox.size.height / 2),
    );
    await tester.pump();

    expect(playback.seekPositions, isNotEmpty);
    await tester.pump(kDoubleTapTimeout);
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
