import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/features/movie_detail/models/movie_preview_args.dart';
import 'package:jade/features/movie_detail/screens/movie_preview_screen.dart';
import 'package:jade/features/movie_detail/services/movie_preview_playback.dart';
import 'package:jade/features/movie_detail/services/movie_preview_system_ui.dart';
import 'package:jade/features/movie_detail/widgets/movie_preview_header.dart';
import 'package:jade/features/movie_detail/widgets/movie_preview_header_overlay.dart';

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
          systemUiCoordinator: _testSystemUiCoordinator,
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
    expect(playback.disposeCalls, 1);
    expect(orientationCalls.last, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('正常播放页面只显示一份顶部栏', (tester) async {
    final playback = _FakePlayback();

    await _pumpPreviewPage(tester, playback);
    await tester.pump();

    expect(find.byType(MoviePreviewHeader), findsOneWidget);
    expect(find.byTooltip('返回'), findsOneWidget);
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
          systemUiCoordinator: _testSystemUiCoordinator,
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
          systemUiCoordinator: _testSystemUiCoordinator,
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
          systemUiCoordinator: _testSystemUiCoordinator,
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

  testWidgets('重试时旧 playback 清理永不完成也会有界地创建新驱动', (tester) async {
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
          args: _validArgs,
          playbackFactory: (_) {
            factoryCalls++;
            return playbacks.removeAt(0);
          },
          orientationSetter: (_) async {},
          systemUiCoordinator: _testSystemUiCoordinator,
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('重试'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();

    expect(factoryCalls, 2);
    expect(successfulPlayback.initializeCalls, 1);
    expect(successfulPlayback.playCalls, 1);
    expect(find.text('重试'), findsNothing);

    disposeCompleter.complete();
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('退出页面不等待 playback 清理完成即可恢复方向', (tester) async {
    final disposeCompleter = Completer<void>();
    final playback = _FakePlayback(disposeCompleter: disposeCompleter);
    final orientationCalls = <List<DeviceOrientation>>[];

    await _pumpPreviewRoute(
      tester,
      MoviePreviewPage(
        args: _validArgs,
        playbackFactory: (_) => playback,
        orientationSetter: (orientations) async {
          orientationCalls.add(List.of(orientations));
        },
        systemUiCoordinator: _testSystemUiCoordinator,
      ),
    );

    await tester.tap(find.byTooltip('返回'));
    await tester.pump();

    expect(find.byKey(const Key('preview-launcher')), findsOneWidget);
    expect(orientationCalls.last, isEmpty);
    expect(playback.disposeCalls, 1);

    disposeCompleter.complete();
    await tester.pump();
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
          systemUiCoordinator: _testSystemUiCoordinator,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('预告片播放失败'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('完成态 seek 尚未完成时退出不会继续调用 play', (tester) async {
    final seekCompleter = Completer<void>();
    final playback = _FakePlayback(
      seekCompleter: seekCompleter,
      initialState: const MoviePreviewPlaybackState(
        isInitialized: true,
        isCompleted: true,
      ),
    );
    await _pumpPreviewPage(tester, playback);

    await tester.tapAt(_backgroundPoint(tester));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(_backgroundPoint(tester));
    await tester.pump();
    expect(playback.commands, ['initialize', 'play', 'seek:0']);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    seekCompleter.complete();
    await tester.pump();

    expect(playback.playCalls, 1);
    expect(tester.takeException(), isNull);
    await tester.pump(kDoubleTapTimeout);
  });

  testWidgets('横屏锁定失败不创建 playback 且显示可退出错误页并尝试恢复', (tester) async {
    final orientationCalls = <List<DeviceOrientation>>[];
    var factoryCalls = 0;

    await _pumpPreviewRoute(
      tester,
      MoviePreviewPage(
        args: _validArgs,
        playbackFactory: (_) {
          factoryCalls++;
          return _FakePlayback();
        },
        orientationSetter: (orientations) async {
          orientationCalls.add(List.of(orientations));
          if (orientations.isNotEmpty) {
            throw StateError('orientation lock failed');
          }
        },
        systemUiCoordinator: _testSystemUiCoordinator,
      ),
    );
    await tester.pump();

    expect(factoryCalls, 0);
    expect(find.text('预告片播放失败'), findsOneWidget);
    expect(find.text('测试影片'), findsOneWidget);
    expect(find.byTooltip('返回'), findsOneWidget);
    expect(orientationCalls, [
      [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight],
      <DeviceOrientation>[],
    ]);

    await tester.tap(find.byTooltip('返回'));
    await tester.pump();
    expect(find.byKey(const Key('preview-launcher')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('加载状态显示安全区返回按钮和标题且可以退出', (tester) async {
    final initializeCompleter = Completer<void>();

    await _pumpPreviewRoute(
      tester,
      MoviePreviewPage(
        args: _validArgs,
        playbackFactory: (_) =>
            _FakePlayback(initializeCompleter: initializeCompleter),
        orientationSetter: (_) async {},
        systemUiCoordinator: _testSystemUiCoordinator,
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await _expectHeaderAndExit(tester);

    initializeCompleter.complete();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('非法参数错误状态显示安全区返回按钮和标题且可以退出', (tester) async {
    await _pumpPreviewRoute(
      tester,
      MoviePreviewPage(
        args: const MoviePreviewArgs(
          movieId: 'm1',
          title: '测试影片',
          videoUrl: 'file:///tmp/preview.m3u8',
        ),
        playbackFactory: (_) => _FakePlayback(),
        orientationSetter: (_) async {},
        systemUiCoordinator: _testSystemUiCoordinator,
      ),
    );
    await tester.pump();

    expect(find.text('预告片播放失败'), findsOneWidget);
    await _expectHeaderAndExit(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('初始化错误状态显示安全区返回按钮和标题且可以退出', (tester) async {
    await _pumpPreviewRoute(
      tester,
      MoviePreviewPage(
        args: _validArgs,
        playbackFactory: (_) =>
            _FakePlayback(initializeError: StateError('init failed')),
        orientationSetter: (_) async {},
        systemUiCoordinator: _testSystemUiCoordinator,
      ),
    );
    await tester.pump();

    expect(find.text('预告片播放失败'), findsOneWidget);
    await _expectHeaderAndExit(tester);
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

    await tester.tapAt(_backgroundPoint(tester));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(_backgroundPoint(tester));
    await tester.pump();

    expect(playback.commands, ['initialize', 'play', 'seek:0', 'play']);
    await tester.pump(kDoubleTapTimeout);
  });

  testWidgets('暂停状态双击只恢复播放', (tester) async {
    final playback = _FakePlayback(
      initialState: const MoviePreviewPlaybackState(isInitialized: true),
    );
    await _pumpPreviewPage(tester, playback);

    await tester.tapAt(_backgroundPoint(tester));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(_backgroundPoint(tester));
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

    await tester.tapAt(_backgroundPoint(tester));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(_backgroundPoint(tester));
    await tester.pump();

    expect(playback.commands, ['initialize', 'play', 'pause']);
    await tester.pump(kDoubleTapTimeout);
  });

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
      find.byKey(MoviePreviewHeaderOverlay.headerOpacityKey),
      findsNothing,
    );
  });

  testWidgets('进入页面设置沉浸模式，退出恢复默认双栏', (tester) async {
    final calls = <({SystemUiMode mode, List<SystemUiOverlay>? overlays})>[];
    final coordinator = MoviePreviewSystemUiCoordinator(
      setSystemUiMode: (mode, {overlays}) async {
        calls.add((mode: mode, overlays: overlays));
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MoviePreviewPage(
          args: _validArgs,
          playbackFactory: (_) => _FakePlayback(),
          orientationSetter: (_) async {},
          systemUiCoordinator: coordinator,
        ),
      ),
    );
    await tester.pump();

    expect(
      calls.first,
      (mode: SystemUiMode.immersiveSticky, overlays: null),
    );

    await tester.pumpWidget(const SizedBox());
    await tester.pump();

    expect(calls.last.mode, SystemUiMode.manual);
    expect(
      calls.last.overlays,
      [SystemUiOverlay.top, SystemUiOverlay.bottom],
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('横屏锁定失败时仍保持沉浸，退出时恢复', (tester) async {
    final calls = <SystemUiMode>[];
    final coordinator = MoviePreviewSystemUiCoordinator(
      setSystemUiMode: (mode, {overlays}) async {
        calls.add(mode);
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MoviePreviewPage(
          args: _validArgs,
          playbackFactory: (_) => _FakePlayback(),
          orientationSetter: (_) async {
            throw StateError('orientation lock failed');
          },
          systemUiCoordinator: coordinator,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('预告片播放失败'), findsOneWidget);
    expect(calls, [SystemUiMode.immersiveSticky]);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();

    expect(calls.last, SystemUiMode.manual);
    expect(tester.takeException(), isNull);
  });

  testWidgets('旧页面迟到恢复不会破坏新页面的沉浸模式', (tester) async {
    final releaseGate = Completer<void>();
    final calls = <SystemUiMode>[];
    final coordinator = MoviePreviewSystemUiCoordinator(
      setSystemUiMode: (mode, {overlays}) async {
        calls.add(mode);
        if (mode == SystemUiMode.manual && calls.where((m) => m == SystemUiMode.manual).length == 1) {
          await releaseGate.future;
        }
      },
    );

    Widget buildPage() {
      return MaterialApp(
        home: MoviePreviewPage(
          args: _validArgs,
          playbackFactory: (_) => _FakePlayback(),
          orientationSetter: (_) async {},
          systemUiCoordinator: coordinator,
        ),
      );
    }

    await tester.pumpWidget(buildPage());
    await tester.pump();

    await tester.pumpWidget(const SizedBox());
    await tester.pump();

    await tester.pumpWidget(buildPage());
    await tester.pump();

    releaseGate.complete();
    await tester.pump();

    expect(calls.last, SystemUiMode.immersiveSticky);
    expect(tester.takeException(), isNull);
  });
}

const _validArgs = MoviePreviewArgs(
  movieId: 'm1',
  title: '测试影片',
  videoUrl: 'https://media.example.com/preview.m3u8',
);

final _testSystemUiCoordinator = MoviePreviewSystemUiCoordinator(
  setSystemUiMode: (mode, {overlays}) async {},
);

Future<void> _pumpPreviewRoute(WidgetTester tester, Widget previewPage) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) {
          return Scaffold(
            body: Center(
              child: ElevatedButton(
                key: const Key('preview-launcher'),
                onPressed: () {
                  Navigator.of(context).push(
                    PageRouteBuilder<void>(
                      pageBuilder: (_, _, _) => previewPage,
                      transitionDuration: Duration.zero,
                      reverseTransitionDuration: Duration.zero,
                    ),
                  );
                },
                child: const Text('打开预告片'),
              ),
            ),
          );
        },
      ),
    ),
  );
  await tester.tap(find.byKey(const Key('preview-launcher')));
  await tester.pump();
}

Future<void> _expectHeaderAndExit(WidgetTester tester) async {
  expect(find.text('测试影片'), findsOneWidget);
  expect(find.byTooltip('返回'), findsOneWidget);

  await tester.tap(find.byTooltip('返回'));
  await tester.pump();

  expect(find.byKey(const Key('preview-launcher')), findsOneWidget);
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
        systemUiCoordinator: _testSystemUiCoordinator,
      ),
    ),
  );
  await tester.pump();
}

Offset _backgroundPoint(WidgetTester tester) {
  return tester.getTopLeft(find.byKey(const Key('fake-preview-video'))) +
      const Offset(64, 240);
}

class _FakePlayback implements MoviePreviewPlayback {
  _FakePlayback({
    this.initializeError,
    this.initializeCompleter,
    this.seekCompleter,
    this.disposeCompleter,
    this.initialState = const MoviePreviewPlaybackState(),
  });

  final Object? initializeError;
  final Completer<void>? initializeCompleter;
  final Completer<void>? seekCompleter;
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
