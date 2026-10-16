import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// Android 播放渲染配置：MediaCodec 直接渲染输出到播放画面，不经 GL/EGL 上下文。
///
/// 等价于 mpv-android 默认的 `vo=mediacodec_embed` + `hwdec=mediacodec`：
/// 在 GL 上下文不可用的运行环境（如模拟器的 gfxstream/SwiftShader 翻译层）
/// 同样能出画；非 Android 保持 media_kit 默认配置。
VideoControllerConfiguration moviePreviewVideoControllerConfiguration({
  bool? isAndroid,
}) {
  final android = isAndroid ?? (!kIsWeb && Platform.isAndroid);
  if (!android) {
    return const VideoControllerConfiguration();
  }
  return const VideoControllerConfiguration(
    vo: 'mediacodec_embed',
    hwdec: 'mediacodec',
  );
}

/// 把播放器（mpv）日志格式化为诊断输出；播放失败原因据此在设备日志中可见。
String formatMoviePreviewPlayerLog(PlayerLog log) =>
    'movie_preview mpv[${log.prefix}/${log.level}] ${log.text}';

@immutable
class MoviePreviewPlaybackState {
  const MoviePreviewPlaybackState({
    this.isInitialized = false,
    this.isPlaying = false,
    this.isBuffering = false,
    this.isCompleted = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.aspectRatio = 16 / 9,
    this.errorDescription,
  });

  final bool isInitialized;
  final bool isPlaying;
  final bool isBuffering;
  final bool isCompleted;
  final Duration position;
  final Duration duration;
  final double aspectRatio;
  final String? errorDescription;
}

abstract interface class MoviePreviewPlayback {
  ValueListenable<MoviePreviewPlaybackState> get state;

  Widget buildView();
  Future<void> initialize();

  /// 等待播放画面输出（surface）就绪并与视频输出绑定。
  ///
  /// 调用方需先挂载 [buildView] 返回的画面，再等待本方法完成后才 [play]；
  /// 画面未就绪时开始播放会让视频输出中途切换，导致黑屏或播放管线卡死。
  /// 超时则继续（尽力而为），不抛出异常。
  Future<void> waitUntilViewReady();

  Future<void> play();
  Future<void> pause();
  Future<void> seekTo(Duration position);
  Future<void> setRate(double rate);
  Future<void> dispose();
}

typedef MoviePreviewPlaybackFactory = MoviePreviewPlayback Function(Uri uri);

/// 基于 media_kit 的预告片 / 在线正片播放适配器。
///
/// 测试通过 [Player.platformPlayer] 注入 fake（见
/// `movie_preview_playback_test.dart`），生产环境默认创建真实 [Player]。
class MediaKitMoviePreviewPlayback implements MoviePreviewPlayback {
  /// 构造播放适配器。
  ///
  /// [uri] 为播放地址；[player] 可注入自定义 [Player]（测试用 fake），
  /// 省略时创建真实 [Player]；[httpHeaders] 为播放请求头（在线正片需要注入
  /// Referer 白名单，预告片为 null）；[videoConfiguration] 为视频输出配置，
  /// 省略时按平台选择（Android 使用 MediaCodec 直渲染）；
  /// [viewBindingSettle] 为画面输出就绪后的稳定窗口（测试可传
  /// [Duration.zero]）；[logSink] 接收播放器日志的诊断文本，
  /// 省略时写入 [debugPrint]。
  MediaKitMoviePreviewPlayback(
    Uri uri, {
    Player? player,
    Map<String, String>? httpHeaders,
    VideoControllerConfiguration? videoConfiguration,
    Duration viewBindingSettle = _defaultViewBindingSettle,
    void Function(String message)? logSink,
  }) : _uri = uri,
       _httpHeaders = httpHeaders,
       _viewBindingSettle = viewBindingSettle,
       _logSink = logSink ?? debugPrint,
       _player = player ?? Player() {
    _videoController = VideoController(
      _player,
      configuration: videoConfiguration ??
          moviePreviewVideoControllerConfiguration(),
    );
    _subscriptions.addAll([
      _player.stream.playing.listen(_onPlaying),
      _player.stream.buffering.listen(_onBuffering),
      _player.stream.completed.listen(_onCompleted),
      _player.stream.error.listen(_onError),
      _player.stream.position.listen(_onPosition),
      _player.stream.duration.listen(_onDuration),
      _player.stream.width.listen(_onWidth),
      _player.stream.height.listen(_onHeight),
      // 播放链路失败原因（视频输出初始化失败、网络失败、解码失败等）据此可见。
      _player.stream.log.listen(_onLog),
    ]);
  }

  /// 画面输出就绪的等待上限；超时继续起播（尽力而为）。
  static const _viewReadyTimeout = Duration(seconds: 5);

  /// 视频输出与画面输出完成绑定所需的稳定窗口（默认 1s）。
  ///
  /// media_kit 在画面输出（surface）就绪后才异步改写 mpv 的视频输出
  /// （`vo` / `wid`）并重建解码器；mpv 没有暴露绑定完成的回调，
  /// 而在这之前起播会让 MediaCodec 直渲染管线停住（进度不动、画面全黑），
  /// 因此等一个有界稳定窗口后再起播。
  static const _defaultViewBindingSettle = Duration(seconds: 1);

  final Uri _uri;
  final Map<String, String>? _httpHeaders;
  final Duration _viewBindingSettle;
  final void Function(String message) _logSink;
  final Player _player;
  late final VideoController _videoController;
  final _state = ValueNotifier(const MoviePreviewPlaybackState());
  final _subscriptions = <StreamSubscription<dynamic>>[];
  Future<void>? _disposeOperation;

  var _isInitialized = false;
  var _isPlaying = false;
  var _isBuffering = false;
  var _isCompleted = false;
  String? _errorDescription;
  var _position = Duration.zero;
  var _duration = Duration.zero;
  int _width = 0;
  int _height = 0;

  @override
  ValueListenable<MoviePreviewPlaybackState> get state => _state;

  @override
  Widget buildView() {
    if (!_isInitialized) {
      throw StateError('Movie preview playback is not initialized.');
    }
    return Video(
      controller: _videoController,
      fit: BoxFit.contain,
      fill: Colors.black,
      wakelock: false,
      controls: NoVideoControls,
    );
  }

  @override
  Future<void> initialize() async {
    await _player.open(
      Media(_uri.toString(), httpHeaders: _httpHeaders),
      play: false,
    );
    _isInitialized = true;
    _syncState();
  }

  @override
  Future<void> waitUntilViewReady() async {
    if (_videoController.id.value == null) {
      final completer = Completer<void>();
      void listener() {
        if (_videoController.id.value != null && !completer.isCompleted) {
          completer.complete();
        }
      }

      _videoController.id.addListener(listener);
      try {
        await completer.future.timeout(_viewReadyTimeout);
      } on TimeoutException {
        _logSink(
          'movie_preview view-ready timeout: 播放画面输出未在 '
          '${_viewReadyTimeout.inSeconds}s 内就绪，继续起播',
        );
        return;
      } finally {
        _videoController.id.removeListener(listener);
      }
    }
    await Future<void>.delayed(_viewBindingSettle);
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seekTo(Duration position) => _player.seek(position);

  @override
  Future<void> setRate(double rate) => _player.setRate(rate);

  @override
  Future<void> dispose() => _disposeOperation ??= _dispose();

  Future<void> _dispose() async {
    Object? firstError;
    StackTrace? firstStackTrace;
    try {
      for (final subscription in _subscriptions) {
        try {
          await subscription.cancel();
        } catch (error, stackTrace) {
          firstError ??= error;
          firstStackTrace ??= stackTrace;
        }
      }
      _subscriptions.clear();
      try {
        await _player.dispose();
      } catch (error, stackTrace) {
        firstError ??= error;
        firstStackTrace ??= stackTrace;
      }
    } finally {
      _state.dispose();
    }
    if (firstError case final error?) {
      Error.throwWithStackTrace(error, firstStackTrace!);
    }
  }

  void _onPlaying(bool value) {
    _isPlaying = value;
    _syncState();
  }

  void _onBuffering(bool value) {
    _isBuffering = value;
    _syncState();
  }

  void _onCompleted(bool value) {
    _isCompleted = value;
    if (value) {
      unawaited(_seekToStartOnCompleted());
    }
    _syncState();
  }

  Future<void> _seekToStartOnCompleted() async {
    try {
      await _player.seek(Duration.zero);
    } catch (error) {
      _errorDescription = error.toString();
      _syncState();
    }
  }

  void _onError(String value) {
    _errorDescription = value;
    _syncState();
  }

  void _onLog(PlayerLog log) {
    // 只做诊断输出，不改变播放状态与用户可见文案。
    _logSink(formatMoviePreviewPlayerLog(log));
  }

  void _onPosition(Duration value) {
    _position = value;
    _syncState();
  }

  void _onDuration(Duration value) {
    _duration = value;
    _syncState();
  }

  void _onWidth(int? value) {
    _width = value ?? 0;
    _syncState();
  }

  void _onHeight(int? value) {
    _height = value ?? 0;
    _syncState();
  }

  void _syncState() {
    _state.value = MoviePreviewPlaybackState(
      isInitialized: _isInitialized,
      isPlaying: _isPlaying,
      isBuffering: _isBuffering,
      isCompleted: _isCompleted,
      position: _position,
      duration: _duration,
      aspectRatio: (_width > 0 && _height > 0) ? _width / _height : 16 / 9,
      errorDescription: _errorDescription,
    );
  }
}
