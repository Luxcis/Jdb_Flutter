import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/features/movie_detail/services/movie_preview_playback.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

// 测试通过注入 fake 驱动 Player 内部受保护的平台控制器，需要访问
// PlatformPlayer 的 @protected 成员。
// ignore_for_file: invalid_use_of_protected_member

class _FakePlatformPlayer extends PlatformPlayer {
  _FakePlatformPlayer({this.openError, this.disposeError})
    : super(configuration: const PlayerConfiguration());

  final Object? openError;
  final Object? disposeError;
  final events = <String>[];
  final opened = <({String uri, bool play})>[];

  @override
  Future<void> open(Playable playable, {bool play = true}) async {
    if (openError != null) {
      throw openError!;
    }
    opened.add((uri: (playable as Media).uri, play: play));
  }

  @override
  Future<void> play() async => events.add('play');

  @override
  Future<void> pause() async => events.add('pause');

  @override
  Future<void> seek(Duration position) async =>
      events.add('seek:${position.inMilliseconds}');

  @override
  Future<void> dispose() async {
    events.add('dispose');
    if (disposeError != null) {
      throw disposeError!;
    }
    await super.dispose();
  }
}

MediaKitMoviePreviewPlayback _build(_FakePlatformPlayer platform) {
  return MediaKitMoviePreviewPlayback(
    Uri.parse('https://media.example.com/preview.m3u8'),
    player: Player(platformPlayer: platform),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('initialize 以 play:false 打开给定 URL 并标记已初始化', () async {
    final platform = _FakePlatformPlayer();
    final playback = _build(platform);

    await playback.initialize();

    expect(platform.opened, [
      (uri: 'https://media.example.com/preview.m3u8', play: false),
    ]);
    expect(playback.state.value.isInitialized, isTrue);
    await playback.dispose();
  });

  test('open 失败时 initialize 重抛且不标记初始化', () async {
    final platform = _FakePlatformPlayer(openError: StateError('open failed'));
    final playback = _build(platform);

    await expectLater(playback.initialize(), throwsStateError);
    expect(playback.state.value.isInitialized, isFalse);
    expect(playback.buildView, throwsStateError);
    await playback.dispose();
  });

  test('未初始化 buildView 抛 StateError，初始化后返回主题包裹的 Video', () async {
    final platform = _FakePlatformPlayer();
    final playback = _build(platform);

    expect(playback.buildView, throwsStateError);

    await playback.initialize();
    final theme = playback.buildView() as MaterialVideoControlsTheme;
    expect(theme.normal.speedUpOnLongPress, isTrue);

    final video = theme.child as Video;
    expect(video.controller.player, isA<Player>());
    expect(video.wakelock, isFalse);
    expect(video.fit, BoxFit.contain);
    expect(video.controls, same(MaterialVideoControls));
    await playback.dispose();
  });

  test('状态流映射为 MoviePreviewPlaybackState', () async {
    final platform = _FakePlatformPlayer();
    final playback = _build(platform);
    await playback.initialize();

    platform.playingController.add(true);
    platform.bufferingController.add(true);
    platform.completedController.add(true);
    platform.errorController.add('media error');
    platform.positionController.add(const Duration(seconds: 20));
    platform.durationController.add(const Duration(minutes: 2));
    platform.widthController.add(1920);
    platform.heightController.add(1080);

    await pumpEventQueue();

    final state = playback.state.value;
    expect(state.isPlaying, isTrue);
    expect(state.isBuffering, isTrue);
    expect(state.isCompleted, isTrue);
    expect(state.errorDescription, 'media error');
    expect(state.position, const Duration(seconds: 20));
    expect(state.duration, const Duration(minutes: 2));
    expect(state.aspectRatio, 16 / 9);
    await playback.dispose();
  });

  test('宽高缺失时宽高比回退 16/9', () async {
    final platform = _FakePlatformPlayer();
    final playback = _build(platform);
    await playback.initialize();

    platform.widthController.add(null);
    platform.heightController.add(null);

    expect(playback.state.value.aspectRatio, 16 / 9);
    await playback.dispose();
  });

  test('completed 时自动 seek 到 0', () async {
    final platform = _FakePlatformPlayer();
    final playback = _build(platform);
    await playback.initialize();

    platform.completedController.add(true);

    await pumpEventQueue();

    expect(platform.events, ['seek:0']);
    await playback.dispose();
  });

  test('play pause seekTo 委托给 Player', () async {
    final platform = _FakePlatformPlayer();
    final playback = _build(platform);
    await playback.initialize();

    await playback.play();
    await playback.pause();
    await playback.seekTo(const Duration(seconds: 30));

    expect(platform.events, ['play', 'pause', 'seek:30000']);
    await playback.dispose();
  });

  test('dispose 幂等：只释放一次 Player 与状态', () async {
    final platform = _FakePlatformPlayer();
    final playback = _build(platform);
    final state = playback.state;
    await playback.initialize();

    await playback.dispose();
    await playback.dispose();

    expect(platform.events.where((event) => event == 'dispose').length, 1);
    expect(() => state.addListener(() {}), throwsFlutterError);
  });

  test('dispose 释放抛错时仍释放状态并重抛第一个错误', () async {
    final platform = _FakePlatformPlayer(
      disposeError: StateError('dispose failed'),
    );
    final playback = _build(platform);
    final state = playback.state;
    await playback.initialize();

    await expectLater(playback.dispose(), throwsA(isA<StateError>()));
    expect(() => state.addListener(() {}), throwsFlutterError);
  });
}
