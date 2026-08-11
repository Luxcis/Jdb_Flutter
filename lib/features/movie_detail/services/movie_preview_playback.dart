import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:video_player/video_player.dart';

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
  Future<void> setPlaybackSpeed(double speed);
  Future<void> dispose();
}

typedef MoviePreviewPlaybackFactory = MoviePreviewPlayback Function(Uri uri);

MoviePreviewPlaybackState moviePreviewPlaybackStateFromVideoPlayerValue(
  VideoPlayerValue value,
) {
  return MoviePreviewPlaybackState(
    isInitialized: value.isInitialized,
    isPlaying: value.isPlaying,
    isBuffering: value.isBuffering,
    isCompleted: value.isCompleted,
    position: value.position,
    duration: value.duration,
    aspectRatio: value.aspectRatio,
    errorDescription: value.errorDescription,
  );
}

class VideoPlayerMoviePreviewPlayback implements MoviePreviewPlayback {
  VideoPlayerMoviePreviewPlayback(Uri uri)
    : this._(
        VideoPlayerController.networkUrl(uri, formatHint: VideoFormat.hls),
      );

  @visibleForTesting
  VideoPlayerMoviePreviewPlayback.withController(
    VideoPlayerController controller,
  ) : this._(controller);

  VideoPlayerMoviePreviewPlayback._(this._controller) {
    _controller.addListener(_syncState);
    _syncState();
  }

  final VideoPlayerController _controller;
  final _state = ValueNotifier(const MoviePreviewPlaybackState());
  bool _initializationFailedWithoutMediaError = false;
  Future<void>? _disposeOperation;

  @override
  ValueListenable<MoviePreviewPlaybackState> get state => _state;

  @override
  Widget buildView() => VideoPlayer(_controller);

  @override
  Future<void> initialize() async {
    try {
      await _controller.initialize();
    } catch (_) {
      _initializationFailedWithoutMediaError = !_controller.value.hasError;
      rethrow;
    }
  }

  @override
  Future<void> play() => _controller.play();

  @override
  Future<void> pause() => _controller.pause();

  @override
  Future<void> seekTo(Duration position) => _controller.seekTo(position);

  @override
  Future<void> setPlaybackSpeed(double speed) =>
      _controller.setPlaybackSpeed(speed);

  @override
  Future<void> dispose() => _disposeOperation ??= _dispose();

  Future<void> _dispose() async {
    _controller.removeListener(_syncState);
    try {
      if (_initializationFailedWithoutMediaError) {
        try {
          await _controller.dispose().timeout(const Duration(seconds: 1));
        } on TimeoutException {
          // video_player 2.10.1 never completes dispose when platform creation
          // throws before its private creation completer is completed.
        }
      } else {
        await _controller.dispose();
      }
    } finally {
      _state.dispose();
    }
  }

  void _syncState() {
    _state.value = moviePreviewPlaybackStateFromVideoPlayerValue(
      _controller.value,
    );
  }
}
