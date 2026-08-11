import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/features/movie_detail/models/movie_preview_args.dart';
import 'package:jade/features/movie_detail/screens/movie_preview_screen.dart';
import 'package:jade/features/movie_detail/services/movie_preview_playback.dart';
import 'package:jade/features/movie_detail/services/movie_preview_wakelock.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

void main() {
  test('system coordinator 实际调用 WakelockPlus enable 和 disable', () async {
    final originalPlatform = wakelockPlusPlatformInstance;
    final platform = _RecordingWakelockPlusPlatform();
    wakelockPlusPlatformInstance = platform;
    addTearDown(() => wakelockPlusPlatformInstance = originalPlatform);

    final lease = MoviePreviewWakelockCoordinator.system.acquire();
    await lease.enabled;
    await lease.release();

    expect(platform.toggleCalls, [true, false]);
  });

  testWidgets('旧预告片页面迟到释放不会关闭新页面 owner 的 wakelock', (tester) async {
    final enabledCalls = <bool>[];
    final coordinator = MoviePreviewWakelockCoordinator(
      setWakelockEnabled: (enabled) async => enabledCalls.add(enabled),
    );
    final playbackA = _FakePlayback();
    final playbackB = _FakePlayback();

    await tester.pumpWidget(
      _buildOverlappingPages(coordinator: coordinator, playbackA: playbackA),
    );
    await tester.pump();
    expect(enabledCalls, [true]);

    await tester.pumpWidget(
      _buildOverlappingPages(
        coordinator: coordinator,
        playbackA: playbackA,
        playbackB: playbackB,
      ),
    );
    await tester.pump();
    expect(playbackB.playCalls, 1);
    expect(enabledCalls.where((enabled) => !enabled), isEmpty);

    await tester.pumpWidget(
      _buildOverlappingPages(coordinator: coordinator, playbackB: playbackB),
    );
    await tester.pump();
    expect(enabledCalls.where((enabled) => !enabled), isEmpty);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(enabledCalls.last, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('页面退出释放 wakelock 不等待视频控制器清理完成', (tester) async {
    final enabledCalls = <bool>[];
    final coordinator = MoviePreviewWakelockCoordinator(
      setWakelockEnabled: (enabled) async => enabledCalls.add(enabled),
    );
    final disposeCompleter = Completer<void>();
    final playback = _FakePlayback(disposeCompleter: disposeCompleter);
    await tester.pumpWidget(
      MaterialApp(
        home: MoviePreviewPage(
          args: _argsA,
          playbackFactory: (_) => playback,
          orientationSetter: (_) async {},
          wakelockCoordinator: coordinator,
        ),
      ),
    );
    await tester.pump();
    expect(enabledCalls, [true]);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();

    expect(playback.disposeCalls, 1);
    expect(enabledCalls, [true, false]);

    disposeCompleter.complete();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}

Widget _buildOverlappingPages({
  required MoviePreviewWakelockCoordinator coordinator,
  _FakePlayback? playbackA,
  _FakePlayback? playbackB,
}) {
  return MaterialApp(
    home: Stack(
      children: [
        if (playbackA != null)
          MoviePreviewPage(
            key: const ValueKey('preview-a'),
            args: _argsA,
            playbackFactory: (_) => playbackA,
            orientationSetter: (_) async {},
            wakelockCoordinator: coordinator,
          ),
        if (playbackB != null)
          MoviePreviewPage(
            key: const ValueKey('preview-b'),
            args: _argsB,
            playbackFactory: (_) => playbackB,
            orientationSetter: (_) async {},
            wakelockCoordinator: coordinator,
          ),
      ],
    ),
  );
}

const _argsA = MoviePreviewArgs(
  movieId: 'a',
  title: '预告片 A',
  videoUrl: 'https://media.example.com/a.m3u8',
);

const _argsB = MoviePreviewArgs(
  movieId: 'b',
  title: '预告片 B',
  videoUrl: 'https://media.example.com/b.m3u8',
);

class _FakePlayback implements MoviePreviewPlayback {
  _FakePlayback({this.disposeCompleter});

  final Completer<void>? disposeCompleter;
  final _state = ValueNotifier(const MoviePreviewPlaybackState());
  int playCalls = 0;
  int disposeCalls = 0;

  @override
  ValueListenable<MoviePreviewPlaybackState> get state => _state;

  @override
  Widget buildView() => const SizedBox.expand();

  @override
  Future<void> initialize() async {
    _state.value = const MoviePreviewPlaybackState(isInitialized: true);
  }

  @override
  Future<void> play() async {
    playCalls++;
  }

  @override
  Future<void> pause() async {}

  @override
  Future<void> seekTo(Duration position) async {}

  @override
  Future<void> setPlaybackSpeed(double speed) async {}

  @override
  Future<void> dispose() async {
    disposeCalls++;
    await disposeCompleter?.future;
  }
}

class _RecordingWakelockPlusPlatform extends WakelockPlusMacOSPlugin {
  final toggleCalls = <bool>[];

  @override
  Future<void> toggle({required bool enable}) async {
    toggleCalls.add(enable);
  }

  @override
  Future<bool> get enabled async => toggleCalls.isNotEmpty && toggleCalls.last;
}
