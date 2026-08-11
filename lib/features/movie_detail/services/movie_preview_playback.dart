import 'dart:async';

import 'package:chewie/chewie.dart';
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

typedef MoviePreviewChewieControllerFactory =
    ChewieController Function(VideoPlayerController controller);

ChewieController createMoviePreviewChewieController(
  VideoPlayerController controller,
) {
  return ChewieController(
    videoPlayerController: controller,
    autoInitialize: false,
    autoPlay: false,
    looping: false,
    showControls: true,
    showControlsOnInitialize: true,
    draggableProgressBar: true,
    hideControlsTimer: const Duration(seconds: 3),
    allowFullScreen: false,
    allowPlaybackSpeedChanging: false,
    showOptions: false,
    allowMuting: true,
    allowedScreenSleep: false,
  );
}

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

class ChewieMoviePreviewPlayback implements MoviePreviewPlayback {
  ChewieMoviePreviewPlayback(Uri uri)
    : this._(
        VideoPlayerController.networkUrl(uri, formatHint: VideoFormat.hls),
        createMoviePreviewChewieController,
      );

  @visibleForTesting
  ChewieMoviePreviewPlayback.withController(
    VideoPlayerController controller, {
    MoviePreviewChewieControllerFactory chewieControllerFactory =
        createMoviePreviewChewieController,
  }) : this._(controller, chewieControllerFactory);

  ChewieMoviePreviewPlayback._(
    this._videoController,
    this._chewieControllerFactory,
  ) {
    _videoController.addListener(_syncState);
    _syncState();
  }

  final VideoPlayerController _videoController;
  final MoviePreviewChewieControllerFactory _chewieControllerFactory;
  final _state = ValueNotifier(const MoviePreviewPlaybackState());
  ChewieController? _chewieController;
  bool _initializationFailedWithoutMediaError = false;
  Future<void>? _disposeOperation;

  @override
  ValueListenable<MoviePreviewPlaybackState> get state => _state;

  @override
  Widget buildView() {
    final controller = _chewieController;
    if (controller == null) {
      throw StateError('Movie preview playback is not initialized.');
    }
    return Chewie(controller: controller);
  }

  @override
  Future<void> initialize() async {
    try {
      await _videoController.initialize();
    } catch (_) {
      _initializationFailedWithoutMediaError = !_videoController.value.hasError;
      rethrow;
    }
    _chewieController ??= _chewieControllerFactory(_videoController);
  }

  @override
  Future<void> play() => _videoController.play();

  @override
  Future<void> pause() => _videoController.pause();

  @override
  Future<void> seekTo(Duration position) => _videoController.seekTo(position);

  @override
  Future<void> setPlaybackSpeed(double speed) =>
      _videoController.setPlaybackSpeed(speed);

  @override
  Future<void> dispose() => _disposeOperation ??= _dispose();

  Future<void> _dispose() async {
    _videoController.removeListener(_syncState);
    Object? firstError;
    StackTrace? firstStackTrace;
    try {
      try {
        _chewieController?.dispose();
      } catch (error, stackTrace) {
        firstError = error;
        firstStackTrace = stackTrace;
      } finally {
        _chewieController = null;
      }

      try {
        if (_initializationFailedWithoutMediaError) {
          await _videoController.dispose().timeout(const Duration(seconds: 1));
        } else {
          await _videoController.dispose();
        }
      } on TimeoutException {
        if (!_initializationFailedWithoutMediaError) {
          rethrow;
        }
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

  void _syncState() {
    _state.value = moviePreviewPlaybackStateFromVideoPlayerValue(
      _videoController.value,
    );
  }
}
