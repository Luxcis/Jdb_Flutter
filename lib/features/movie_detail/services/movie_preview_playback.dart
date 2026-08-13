import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

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
  Future<void> play();
  Future<void> pause();
  Future<void> seekTo(Duration position);
  Future<void> dispose();
}

typedef MoviePreviewPlaybackFactory = MoviePreviewPlayback Function(Uri uri);

/// 基于 media_kit 的预告片播放适配器。
///
/// 测试通过 [Player.platformPlayer] 注入 fake（见
/// `movie_preview_playback_test.dart`），生产环境默认创建真实 [Player]。
class MediaKitMoviePreviewPlayback implements MoviePreviewPlayback {
  /// 构造播放适配器。
  ///
  /// [uri] 为预告片地址；[player] 可注入自定义 [Player]（测试用 fake），
  /// 省略时创建真实 [Player]。
  MediaKitMoviePreviewPlayback(Uri uri, {Player? player})
    : _uri = uri,
      _player = player ?? Player() {
    _videoController = VideoController(_player);
    _subscriptions.addAll([
      _player.stream.playing.listen(_onPlaying),
      _player.stream.buffering.listen(_onBuffering),
      _player.stream.completed.listen(_onCompleted),
      _player.stream.error.listen(_onError),
      _player.stream.position.listen(_onPosition),
      _player.stream.duration.listen(_onDuration),
      _player.stream.width.listen(_onWidth),
      _player.stream.height.listen(_onHeight),
    ]);
  }

  final Uri _uri;
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
    return MaterialVideoControlsTheme(
      normal: const MaterialVideoControlsThemeData(speedUpOnLongPress: true),
      fullscreen: const MaterialVideoControlsThemeData(
        speedUpOnLongPress: true,
      ),
      child: Video(
        controller: _videoController,
        fit: BoxFit.contain,
        fill: Colors.black,
        wakelock: false,
        controls: MaterialVideoControls,
      ),
    );
  }

  @override
  Future<void> initialize() async {
    await _player.open(Media(_uri.toString()), play: false);
    _isInitialized = true;
    _syncState();
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seekTo(Duration position) => _player.seek(position);

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
