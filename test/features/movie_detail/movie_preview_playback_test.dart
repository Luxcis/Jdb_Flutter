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
  Object? seekError;
  final events = <String>[];
  final opened = <({String uri, bool play, Map<String, String>? headers})>[];

  @override
  Future<void> open(Playable playable, {bool play = true}) async {
    if (openError != null) {
      throw openError!;
    }
    final media = playable as Media;
    opened.add((uri: media.uri, play: play, headers: media.httpHeaders));
  }

  @override
  Future<void> play() async => events.add('play');

  @override
  Future<void> pause() async => events.add('pause');

  @override
  Future<void> seek(Duration position) async {
    if (seekError != null) {
      throw seekError!;
    }
    events.add('seek:${position.inMilliseconds}');
  }

  @override
  Future<void> dispose() async {
    events.add('dispose');
    if (disposeError != null) {
      throw disposeError!;
    }
    await super.dispose();
  }
}

MediaKitMoviePreviewPlayback _build(
  _FakePlatformPlayer platform, {
  Duration viewBindingSettle = Duration.zero,
}) {
  return MediaKitMoviePreviewPlayback(
    Uri.parse('https://media.example.com/preview.m3u8'),
    player: Player(platformPlayer: platform),
    viewBindingSettle: viewBindingSettle,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('initialize 以 play:false 打开给定 URL 并标记已初始化', () async {
    final platform = _FakePlatformPlayer();
    final playback = _build(platform);

    await playback.initialize();

    expect(platform.opened, [
      (
        uri: 'https://media.example.com/preview.m3u8',
        play: false,
        headers: null,
      ),
    ]);
    expect(playback.state.value.isInitialized, isTrue);
    await playback.dispose();
  });

  test('httpHeaders 注入到打开的 Media（在线正片 Referer）', () async {
    final platform = _FakePlatformPlayer();
    final playback = MediaKitMoviePreviewPlayback(
      Uri.parse(
        'https://surrit.com/a5e4d7c9-2206-4f41-901c-1dd66a6ead27/playlist.m3u8',
      ),
      player: Player(platformPlayer: platform),
      httpHeaders: const {
        'Referer': 'https://missav.live/ja/',
        'User-Agent': 'ua',
      },
    );

    await playback.initialize();

    expect(platform.opened.single.headers, {
      'Referer': 'https://missav.live/ja/',
      'User-Agent': 'ua',
    });
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

  test('未初始化 buildView 抛 StateError，初始化后返回无内置控件的 Video', () async {
    final platform = _FakePlatformPlayer();
    final playback = _build(platform);

    expect(playback.buildView, throwsStateError);

    await playback.initialize();
    final video = playback.buildView() as Video;
    expect(video.controller.player, isA<Player>());
    expect(video.wakelock, isFalse);
    expect(video.fit, BoxFit.contain);
    expect(video.controls, same(NoVideoControls));
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

  test('completed 且 seek 抛错时进入可重试错误态', () async {
    final platform = _FakePlatformPlayer()
      ..seekError = StateError('seek failed');
    final playback = _build(platform);
    await playback.initialize();

    platform.completedController.add(true);

    await pumpEventQueue();

    expect(playback.state.value.errorDescription, isNotNull);
    expect(playback.state.value.errorDescription, isNotEmpty);
    await playback.dispose();
  });

  test('completed=false 不触发 seek', () async {
    final platform = _FakePlatformPlayer();
    final playback = _build(platform);
    await playback.initialize();

    platform.completedController.add(false);

    await pumpEventQueue();

    expect(platform.events.where((event) => event == 'seek:0'), isEmpty);
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

  test('Android 渲染配置走 MediaCodec 直渲染，其他平台保持默认', () {
    final android = moviePreviewVideoControllerConfiguration(isAndroid: true);
    expect(android.vo, 'mediacodec_embed');
    expect(android.hwdec, 'mediacodec');

    final desktop = moviePreviewVideoControllerConfiguration(isAndroid: false);
    expect(desktop.vo, isNull);
    expect(desktop.hwdec, isNull);
  });

  test('播放器日志格式化为含 prefix 与级别的诊断文本', () {
    expect(
      formatMoviePreviewPlayerLog(
        const PlayerLog(
          prefix: 'vo/gpu/opengl',
          level: 'fatal',
          text: 'Could not create EGL context for GLES 2.x +!',
        ),
      ),
      'movie_preview mpv[vo/gpu/opengl/fatal] '
      'Could not create EGL context for GLES 2.x +!',
    );
  });

  test('播放器日志转发到 logSink', () async {
    final platform = _FakePlatformPlayer();
    final messages = <String>[];
    final playback = MediaKitMoviePreviewPlayback(
      Uri.parse('https://media.example.com/preview.m3u8'),
      player: Player(platformPlayer: platform),
      logSink: messages.add,
    );
    await playback.initialize();

    platform.logController.add(
      const PlayerLog(prefix: 'vd', level: 'error', text: 'Could not open codec'),
    );
    await pumpEventQueue();

    expect(messages, [
      'movie_preview mpv[vd/error] Could not open codec',
    ]);
    await playback.dispose();
  });

  test('waitUntilViewReady 在画面输出就绪后完成', () async {
    final platform = _FakePlatformPlayer();
    final playback = _build(platform);
    await playback.initialize();

    final video = playback.buildView() as Video;
    var ready = false;
    final future = playback.waitUntilViewReady().then((_) => ready = true);
    await pumpEventQueue();
    expect(ready, isFalse);

    video.controller.id.value = 1;
    await future;
    expect(ready, isTrue);
    await playback.dispose();
  });

  test('画面输出就绪后仍需等稳定窗口（视频输出绑定）结束', () async {
    final platform = _FakePlatformPlayer();
    final playback = _build(
      platform,
      viewBindingSettle: const Duration(milliseconds: 200),
    );
    await playback.initialize();

    final video = playback.buildView() as Video;
    var ready = false;
    final future = playback.waitUntilViewReady().then((_) => ready = true);
    video.controller.id.value = 1;
    await pumpEventQueue();
    expect(ready, isFalse);

    await future;
    expect(ready, isTrue);
    await playback.dispose();
  });

  test('画面输出已就绪时 waitUntilViewReady 只等稳定窗口', () async {
    final platform = _FakePlatformPlayer();
    final playback = _build(platform);
    await playback.initialize();

    final video = playback.buildView() as Video;
    video.controller.id.value = 1;
    await pumpEventQueue();

    await playback.waitUntilViewReady();

    expect(playback.state.value.isInitialized, isTrue);
    await playback.dispose();
  });
}
