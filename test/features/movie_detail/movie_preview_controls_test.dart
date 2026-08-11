import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/features/movie_detail/services/movie_preview_playback.dart';
import 'package:jade/features/movie_detail/widgets/movie_preview_controls.dart';

void main() {
  testWidgets('单击只切换控制层，双击只切换播放状态', (tester) async {
    var togglePlaybackCalls = 0;
    final widget = _buildControls(
      onTogglePlayback: () async {
        togglePlaybackCalls++;
      },
    );

    await tester.pumpWidget(widget);
    expect(
      find.byKey(const Key('movie-preview-controls-overlay')),
      findsOneWidget,
    );
    await tester.pump(kDoubleTapTimeout);

    await tester.tapAt(_backgroundPoint(tester));
    await tester.pump(kDoubleTapTimeout);
    expect(
      find.byKey(const Key('movie-preview-controls-overlay')),
      findsNothing,
    );
    expect(togglePlaybackCalls, 0);

    final backgroundPoint = _backgroundPoint(tester);
    await tester.tapAt(backgroundPoint);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(backgroundPoint);
    await tester.pump();
    expect(togglePlaybackCalls, 1);
    expect(
      find.byKey(const Key('movie-preview-controls-overlay')),
      findsOneWidget,
    );
    await tester.pump(kDoubleTapTimeout);
  });

  testWidgets('长按期间使用 2 倍速，松手后恢复 1 倍速', (tester) async {
    final speeds = <double>[];
    await tester.pumpWidget(
      _buildControls(
        onSetPlaybackSpeed: (speed) async {
          speeds.add(speed);
        },
      ),
    );

    final gesture = await tester.startGesture(_backgroundPoint(tester));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));

    expect(speeds, [2.0]);
    expect(find.text('2.0×'), findsOneWidget);

    await gesture.up();
    await tester.pump();
    expect(speeds, [2.0, 1.0]);
    expect(find.text('2.0×'), findsNothing);
  });

  testWidgets('长按取消后恢复 1 倍速一次', (tester) async {
    final speeds = <double>[];
    await tester.pumpWidget(
      _buildControls(
        onSetPlaybackSpeed: (speed) async {
          speeds.add(speed);
        },
      ),
    );

    final gesture = await tester.startGesture(_backgroundPoint(tester));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    await gesture.cancel();
    await tester.pump();

    expect(speeds, [2.0, 1.0]);
  });

  testWidgets('播放时三秒后隐藏控制层', (tester) async {
    await tester.pumpWidget(_buildControls());

    await tester.pump(const Duration(seconds: 2, milliseconds: 999));
    expect(
      find.byKey(const Key('movie-preview-controls-overlay')),
      findsOneWidget,
    );

    await tester.pump(const Duration(milliseconds: 1));
    expect(
      find.byKey(const Key('movie-preview-controls-overlay')),
      findsNothing,
    );
  });

  testWidgets('暂停时控制层不会自动隐藏', (tester) async {
    await tester.pumpWidget(
      _buildControls(playbackState: _state(isPlaying: false)),
    );

    await tester.pump(const Duration(seconds: 4));
    expect(
      find.byKey(const Key('movie-preview-controls-overlay')),
      findsOneWidget,
    );
  });

  testWidgets('缓冲时控制层不会自动隐藏', (tester) async {
    await tester.pumpWidget(
      _buildControls(playbackState: _state(isBuffering: true)),
    );

    await tester.pump(const Duration(seconds: 4));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      find.byKey(const Key('movie-preview-controls-overlay')),
      findsOneWidget,
    );
  });

  testWidgets('播放完成时重新显示控制层并停止自动隐藏', (tester) async {
    var playbackState = _state();
    late StateSetter updatePlaybackState;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              updatePlaybackState = setState;
              return MoviePreviewControls(
                title: '测试影片',
                video: const SizedBox.expand(),
                playbackState: playbackState,
                onBack: () {},
                onTogglePlayback: () async {},
                onSeek: (_) async {},
                onSetPlaybackSpeed: (_) async {},
                onRetry: () async {},
              );
            },
          ),
        ),
      ),
    );

    await tester.tapAt(_backgroundPoint(tester));
    await tester.pump(kDoubleTapTimeout);
    expect(
      find.byKey(const Key('movie-preview-controls-overlay')),
      findsNothing,
    );

    updatePlaybackState(() {
      playbackState = _state(isCompleted: true);
    });
    await tester.pump();

    expect(
      find.byKey(const Key('movie-preview-controls-overlay')),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 4));
    expect(
      find.byKey(const Key('movie-preview-controls-overlay')),
      findsOneWidget,
    );
  });

  testWidgets('拖动进度条期间保持显示，结束后重新计时', (tester) async {
    final seekPositions = <Duration>[];
    await tester.pumpWidget(
      _buildControls(
        onSeek: (position) async {
          seekPositions.add(position);
        },
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(Slider)),
    );
    await gesture.moveBy(const Offset(24, 0));
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));
    expect(
      find.byKey(const Key('movie-preview-controls-overlay')),
      findsOneWidget,
    );

    await gesture.up();
    await tester.pump();
    expect(seekPositions, hasLength(1));
    await tester.pump(const Duration(seconds: 3));
    expect(
      find.byKey(const Key('movie-preview-controls-overlay')),
      findsNothing,
    );
  });

  testWidgets('隐藏后暂停、缓冲或错误时重新显示控制层', (tester) async {
    var playbackState = _state();
    late StateSetter updatePlaybackState;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              updatePlaybackState = setState;
              return MoviePreviewControls(
                title: '测试影片',
                video: const SizedBox.expand(),
                playbackState: playbackState,
                onBack: () {},
                onTogglePlayback: () async {},
                onSeek: (_) async {},
                onSetPlaybackSpeed: (_) async {},
                onRetry: () async {},
              );
            },
          ),
        ),
      ),
    );

    Future<void> hideControls() async {
      await tester.tapAt(_backgroundPoint(tester));
      await tester.pump(kDoubleTapTimeout);
      expect(
        find.byKey(const Key('movie-preview-controls-overlay')),
        findsNothing,
      );
    }

    await hideControls();
    updatePlaybackState(() {
      playbackState = _state(isPlaying: false);
    });
    await tester.pump();
    expect(
      find.byKey(const Key('movie-preview-controls-overlay')),
      findsOneWidget,
    );

    updatePlaybackState(() {
      playbackState = _state();
    });
    await tester.pump();
    await hideControls();
    updatePlaybackState(() {
      playbackState = _state(isBuffering: true);
    });
    await tester.pump();
    expect(
      find.byKey(const Key('movie-preview-controls-overlay')),
      findsOneWidget,
    );

    updatePlaybackState(() {
      playbackState = _state();
    });
    await tester.pump();
    await hideControls();
    updatePlaybackState(() {
      playbackState = _state(errorDescription: 'media error');
    });
    await tester.pump();
    expect(find.text('预告片播放失败'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
  });

  testWidgets('点击中央播放暂停按钮只切换播放状态', (tester) async {
    var togglePlaybackCalls = 0;
    await tester.pumpWidget(
      _buildControls(
        onTogglePlayback: () async {
          togglePlaybackCalls++;
        },
      ),
    );

    await tester.tap(find.byTooltip('暂停'));
    await tester.pump();

    expect(togglePlaybackCalls, 1);
    expect(
      find.byKey(const Key('movie-preview-controls-overlay')),
      findsOneWidget,
    );
  });

  testWidgets('播放命令失败不会冒泡且控制层保持可见', (tester) async {
    await tester.pumpWidget(
      _buildControls(
        onTogglePlayback: () async {
          throw StateError('playback failed');
        },
      ),
    );

    await tester.tap(find.byTooltip('暂停'));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(
      find.byKey(const Key('movie-preview-controls-overlay')),
      findsOneWidget,
    );
  });

  testWidgets('未知时长显示占位并禁用进度条', (tester) async {
    await tester.pumpWidget(
      _buildControls(playbackState: _state(duration: Duration.zero)),
    );

    final slider = tester.widget<Slider>(find.byType(Slider));
    expect(slider.onChanged, isNull);
    expect(find.text('--:--'), findsOneWidget);
  });

  testWidgets('错误状态显示重试且不会自动隐藏', (tester) async {
    var retryCalls = 0;
    await tester.pumpWidget(
      _buildControls(
        playbackState: _state(errorDescription: 'media error'),
        onRetry: () async {
          retryCalls++;
        },
      ),
    );

    expect(find.text('预告片播放失败'), findsOneWidget);
    await tester.tap(find.text('重试'));
    await tester.pump();
    expect(retryCalls, 1);
    await tester.pump(const Duration(seconds: 4));
    expect(
      find.byKey(const Key('movie-preview-controls-overlay')),
      findsOneWidget,
    );
  });

  testWidgets('卸载后自动隐藏计时器不会触发 setState 异常', (tester) async {
    await tester.pumpWidget(_buildControls());
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 4));

    expect(tester.takeException(), isNull);
  });
}

Offset _backgroundPoint(WidgetTester tester) {
  return tester.getTopLeft(
        find.byKey(const Key('movie-preview-gesture-surface')),
      ) +
      const Offset(64, 240);
}

MoviePreviewPlaybackState _state({
  bool isPlaying = true,
  bool isBuffering = false,
  bool isCompleted = false,
  Duration duration = const Duration(minutes: 2),
  String? errorDescription,
}) {
  return MoviePreviewPlaybackState(
    isInitialized: true,
    isPlaying: isPlaying,
    isBuffering: isBuffering,
    isCompleted: isCompleted,
    duration: duration,
    position: const Duration(seconds: 10),
    errorDescription: errorDescription,
  );
}

Widget _buildControls({
  MoviePreviewPlaybackState? playbackState,
  Future<void> Function()? onTogglePlayback,
  Future<void> Function(Duration position)? onSeek,
  Future<void> Function(double speed)? onSetPlaybackSpeed,
  Future<void> Function()? onRetry,
}) {
  return MaterialApp(
    home: Scaffold(
      body: MoviePreviewControls(
        title: '测试影片',
        video: const SizedBox.expand(),
        playbackState: playbackState ?? _state(),
        onBack: () {},
        onTogglePlayback: onTogglePlayback ?? () async {},
        onSeek: onSeek ?? (_) async {},
        onSetPlaybackSpeed: onSetPlaybackSpeed ?? (_) async {},
        onRetry: onRetry ?? () async {},
      ),
    ),
  );
}
