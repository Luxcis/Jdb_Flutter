import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/features/movie_detail/models/movie_preview_args.dart';
import 'package:jade/features/movie_detail/screens/movie_preview_screen.dart';
import 'package:jade/features/movie_detail/services/movie_preview_playback.dart';
import 'package:video_player/video_player.dart';

void main() {
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

  testWidgets('进入页面先锁定横屏，初始化成功后自动播放，退出时清理并恢复方向', (tester) async {
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
    expect(tester.takeException(), isNull);
  });

  testWidgets('非法 URL 显示失败提示且不创建播放驱动', (tester) async {
    var factoryCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: MoviePreviewPage(
          args: const MoviePreviewArgs(
            movieId: 'm1',
            title: '测试影片',
            videoUrl: 'file:///tmp/preview.m3u8',
          ),
          playbackFactory: (_) {
            factoryCalls++;
            return _FakePlayback();
          },
          orientationSetter: (_) async {},
        ),
      ),
    );
    await tester.pump();

    expect(find.text('预告片播放失败'), findsOneWidget);
    expect(factoryCalls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('初始化失败后重试会替换驱动并自动播放', (tester) async {
    final failedPlayback = _FakePlayback(initializeError: Exception('network'));
    final successfulPlayback = _FakePlayback();
    final playbacks = [failedPlayback, successfulPlayback];

    await tester.pumpWidget(
      MaterialApp(
        home: MoviePreviewPage(
          args: const MoviePreviewArgs(
            movieId: 'm1',
            title: '测试影片',
            videoUrl: 'https://media.example.com/preview.m3u8',
          ),
          playbackFactory: (_) => playbacks.removeAt(0),
          orientationSetter: (_) async {},
        ),
      ),
    );
    await tester.pump();

    expect(find.text('预告片播放失败'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
    expect(failedPlayback.initializeCalls, 1);

    await tester.tap(find.text('重试'));
    await tester.pump();

    expect(failedPlayback.disposeCalls, 1);
    expect(successfulPlayback.initializeCalls, 1);
    expect(successfulPlayback.playCalls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('重试清理进行中时只启动一次新播放驱动', (tester) async {
    final disposeCompleter = Completer<void>();
    final failedPlayback = _FakePlayback(
      initializeError: Exception('network'),
      disposeCompleter: disposeCompleter,
    );
    final successfulPlayback = _FakePlayback();
    final playbacks = [failedPlayback, successfulPlayback];
    var factoryCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: MoviePreviewPage(
          args: const MoviePreviewArgs(
            movieId: 'm1',
            title: '测试影片',
            videoUrl: 'https://media.example.com/preview.m3u8',
          ),
          playbackFactory: (_) {
            factoryCalls++;
            return playbacks.removeAt(0);
          },
          orientationSetter: (_) async {},
        ),
      ),
    );
    await tester.pump();

    final retry = tester
        .widget<ElevatedButton>(find.byType(ElevatedButton))
        .onPressed;
    expect(retry, isNotNull);
    retry!();
    retry();
    await tester.pump();

    expect(failedPlayback.disposeCalls, 1);
    expect(factoryCalls, 1);
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNull,
    );

    disposeCompleter.complete();
    await tester.pump();

    expect(factoryCalls, 2);
    expect(successfulPlayback.initializeCalls, 1);
    expect(successfulPlayback.playCalls, 1);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(successfulPlayback.disposeCalls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('同步 factory 异常显示失败提示且不会冒泡', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MoviePreviewPage(
          args: const MoviePreviewArgs(
            movieId: 'm1',
            title: '测试影片',
            videoUrl: 'https://media.example.com/preview.m3u8',
          ),
          playbackFactory: (_) => throw StateError('factory'),
          orientationSetter: (_) async {},
        ),
      ),
    );
    await tester.pump();

    expect(find.text('预告片播放失败'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('完成状态从零开始重新播放', (tester) async {
    final playback = _FakePlayback(
      initialState: const MoviePreviewPlaybackState(
        isInitialized: true,
        isCompleted: true,
      ),
    );
    await _pumpPreviewPage(tester, playback);

    await tester.tap(find.byKey(const Key('movie-preview-gesture-surface')));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byKey(const Key('movie-preview-gesture-surface')));
    await tester.pump();

    expect(playback.commands, ['initialize', 'play', 'seek:0', 'play']);
    await tester.pump(kDoubleTapTimeout);
  });

  testWidgets('暂停状态双击只恢复播放', (tester) async {
    final playback = _FakePlayback(
      initialState: const MoviePreviewPlaybackState(isInitialized: true),
    );
    await _pumpPreviewPage(tester, playback);

    await tester.tap(find.byKey(const Key('movie-preview-gesture-surface')));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byKey(const Key('movie-preview-gesture-surface')));
    await tester.pump();

    expect(playback.commands, ['initialize', 'play', 'play']);
    await tester.pump(kDoubleTapTimeout);
  });

  testWidgets('播放状态双击只暂停', (tester) async {
    final playback = _FakePlayback(
      initialState: const MoviePreviewPlaybackState(
        isInitialized: true,
        isPlaying: true,
      ),
    );
    await _pumpPreviewPage(tester, playback);

    await tester.tap(find.byKey(const Key('movie-preview-gesture-surface')));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byKey(const Key('movie-preview-gesture-surface')));
    await tester.pump();

    expect(playback.commands, ['initialize', 'play', 'pause']);
    await tester.pump(kDoubleTapTimeout);
  });

  test('映射 VideoPlayerValue 的完成和错误状态', () {
    final state = moviePreviewPlaybackStateFromVideoPlayerValue(
      const VideoPlayerValue(
        duration: Duration(minutes: 2),
        position: Duration(seconds: 20),
        size: Size(1920, 1080),
        isInitialized: true,
        isPlaying: true,
        isBuffering: true,
        isCompleted: true,
        errorDescription: 'media error',
      ),
    );

    expect(state.isInitialized, isTrue);
    expect(state.isPlaying, isTrue);
    expect(state.isBuffering, isTrue);
    expect(state.isCompleted, isTrue);
    expect(state.position, const Duration(seconds: 20));
    expect(state.duration, const Duration(minutes: 2));
    expect(state.aspectRatio, 16 / 9);
    expect(state.errorDescription, 'media error');
  });

  test('controller 释放抛错时仍释放 playback state', () async {
    final playback = VideoPlayerMoviePreviewPlayback.withController(
      _ThrowingDisposeVideoPlayerController(),
    );
    final state = playback.state;

    await expectLater(playback.dispose(), throwsA(isA<StateError>()));

    expect(() => state.addListener(() {}), throwsFlutterError);
  });
}

Future<void> _pumpPreviewPage(
  WidgetTester tester,
  _FakePlayback playback,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: MoviePreviewPage(
        args: const MoviePreviewArgs(
          movieId: 'm1',
          title: '测试影片',
          videoUrl: 'https://media.example.com/preview.m3u8',
        ),
        playbackFactory: (_) => playback,
        orientationSetter: (_) async {},
      ),
    ),
  );
  await tester.pump();
}

class _FakePlayback implements MoviePreviewPlayback {
  _FakePlayback({
    this.initializeError,
    this.disposeCompleter,
    this.initialState = const MoviePreviewPlaybackState(),
  });

  final Object? initializeError;
  final Completer<void>? disposeCompleter;
  final MoviePreviewPlaybackState initialState;
  late final _state = ValueNotifier(initialState);
  final commands = <String>[];
  final speedCalls = <double>[];
  int initializeCalls = 0;
  int playCalls = 0;
  int pauseCalls = 0;
  int disposeCalls = 0;

  @override
  ValueListenable<MoviePreviewPlaybackState> get state => _state;

  @override
  Widget buildView() => const SizedBox();

  @override
  Future<void> initialize() async {
    initializeCalls++;
    commands.add('initialize');
    if (initializeError != null) {
      throw initializeError!;
    }
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
  }

  @override
  Future<void> seekTo(Duration position) async {
    commands.add('seek:${position.inMilliseconds}');
  }

  @override
  Future<void> setPlaybackSpeed(double speed) async {
    speedCalls.add(speed);
  }

  @override
  Future<void> dispose() async {
    disposeCalls++;
    await disposeCompleter?.future;
  }
}

class _ThrowingDisposeVideoPlayerController extends VideoPlayerController {
  _ThrowingDisposeVideoPlayerController()
    : super.networkUrl(
        Uri.parse('https://media.example.com/preview.m3u8'),
        formatHint: VideoFormat.hls,
      );

  @override
  Future<void> dispose() async {
    await super.dispose();
    throw StateError('controller dispose');
  }
}
