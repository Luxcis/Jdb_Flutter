import 'dart:async';

import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/features/movie_detail/services/movie_preview_playback.dart';
import 'package:video_player/video_player.dart';

void main() {
  testWidgets('初始化后 buildView 返回固定配置的 Chewie 原生控制层', (tester) async {
    final videoController = _FakeVideoPlayerController();
    final playback = ChewieMoviePreviewPlayback.withController(videoController);

    await playback.initialize();

    final view = playback.buildView();
    expect(view, isA<Chewie>());
    final chewieController = (view as Chewie).controller;
    expect(chewieController.videoPlayerController, same(videoController));
    expect(chewieController.autoInitialize, isFalse);
    expect(chewieController.autoPlay, isFalse);
    expect(chewieController.looping, isFalse);
    expect(chewieController.showControls, isTrue);
    expect(chewieController.showControlsOnInitialize, isTrue);
    expect(chewieController.draggableProgressBar, isTrue);
    expect(chewieController.hideControlsTimer, const Duration(seconds: 3));
    expect(chewieController.allowFullScreen, isFalse);
    expect(chewieController.allowPlaybackSpeedChanging, isFalse);
    expect(chewieController.showOptions, isFalse);
    expect(chewieController.allowMuting, isTrue);
    expect(chewieController.allowedScreenSleep, isFalse);
    expect(chewieController.customControls, isNull);

    await playback.dispose();
  });

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

  test('初始化前 buildView 明确失败', () {
    final playback = ChewieMoviePreviewPlayback.withController(
      _FakeVideoPlayerController(),
    );

    expect(playback.buildView, throwsStateError);
  });

  test('释放顺序为 Chewie 后 video_player 且 dispose 幂等', () async {
    final events = <String>[];
    final videoController = _FakeVideoPlayerController(
      onDispose: () => events.add('video'),
    );
    final playback = ChewieMoviePreviewPlayback.withController(
      videoController,
      chewieControllerFactory: (controller, {customControls}) =>
          _RecordingChewieController(controller, events),
    );
    await playback.initialize();

    await playback.dispose();
    await playback.dispose();

    expect(events, ['chewie', 'video']);
  });

  test('底层初始化失败时不创建 Chewie 且清理有界完成', () async {
    var chewieCreateCalls = 0;
    final playback = ChewieMoviePreviewPlayback.withController(
      _FakeVideoPlayerController(
        initializeError: StateError('platform create failed'),
        neverCompleteDispose: true,
      ),
      chewieControllerFactory: (controller, {customControls}) {
        chewieCreateCalls++;
        return ChewieController(videoPlayerController: controller);
      },
    );

    await expectLater(playback.initialize(), throwsStateError);
    await expectLater(
      playback.dispose().timeout(const Duration(seconds: 2)),
      completes,
    );
    expect(chewieCreateCalls, 0);
  });

  test('Chewie 控制器构造失败时仍正常释放已初始化的视频控制器', () async {
    var videoDisposeCalls = 0;
    final playback = ChewieMoviePreviewPlayback.withController(
      _FakeVideoPlayerController(onDispose: () => videoDisposeCalls++),
      chewieControllerFactory: (_, {customControls}) {
        throw StateError('Chewie create failed');
      },
    );

    await expectLater(playback.initialize(), throwsStateError);
    await playback.dispose();

    expect(videoDisposeCalls, 1);
  });
}

class _FakeVideoPlayerController extends VideoPlayerController {
  _FakeVideoPlayerController({
    this.initializeError,
    this.neverCompleteDispose = false,
    this.onDispose,
  }) : super.networkUrl(
         Uri.parse('https://media.example.com/preview.m3u8'),
         formatHint: VideoFormat.hls,
       );

  final Object? initializeError;
  final bool neverCompleteDispose;
  final VoidCallback? onDispose;

  @override
  Future<void> initialize() async {
    if (initializeError case final error?) {
      throw error;
    }
    value = const VideoPlayerValue(
      duration: Duration(minutes: 1),
      size: Size(1920, 1080),
      isInitialized: true,
    );
  }

  @override
  Future<void> setLooping(bool looping) async {
    value = value.copyWith(isLooping: looping);
  }

  @override
  Future<void> dispose() async {
    onDispose?.call();
    await super.dispose();
    if (neverCompleteDispose) {
      await Completer<void>().future;
    }
  }
}

class _RecordingChewieController extends ChewieController {
  _RecordingChewieController(VideoPlayerController controller, this.events)
    : super(videoPlayerController: controller);

  final List<String> events;

  @override
  void dispose() {
    events.add('chewie');
    super.dispose();
  }
}
