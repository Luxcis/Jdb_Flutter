import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/features/movie_detail/models/movie_preview_args.dart';
import 'package:jade/features/movie_detail/screens/movie_preview_screen.dart';
import 'package:jade/features/movie_detail/services/movie_preview_playback.dart';

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
}

class _FakePlayback implements MoviePreviewPlayback {
  _FakePlayback({this.initializeError});

  final Object? initializeError;
  final _state = ValueNotifier(const MoviePreviewPlaybackState());
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
    if (initializeError != null) {
      throw initializeError!;
    }
    _state.value = const MoviePreviewPlaybackState(isInitialized: true);
  }

  @override
  Future<void> play() async {
    playCalls++;
  }

  @override
  Future<void> pause() async {
    pauseCalls++;
  }

  @override
  Future<void> seekTo(Duration position) async {}

  @override
  Future<void> setPlaybackSpeed(double speed) async {
    speedCalls.add(speed);
  }

  @override
  Future<void> dispose() async {
    disposeCalls++;
  }
}
