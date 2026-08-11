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

class VideoPlayerMoviePreviewPlayback implements MoviePreviewPlayback {
  VideoPlayerMoviePreviewPlayback(Uri uri)
    : _controller = VideoPlayerController.networkUrl(
        uri,
        formatHint: VideoFormat.hls,
      ) {
    _controller.addListener(_syncState);
    _syncState();
  }

  final VideoPlayerController _controller;
  final _state = ValueNotifier(const MoviePreviewPlaybackState());

  @override
  ValueListenable<MoviePreviewPlaybackState> get state => _state;

  @override
  Widget buildView() => VideoPlayer(_controller);

  @override
  Future<void> initialize() => _controller.initialize();

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
  Future<void> dispose() async {
    _controller.removeListener(_syncState);
    await _controller.dispose();
    _state.dispose();
  }

  void _syncState() {
    final value = _controller.value;
    _state.value = MoviePreviewPlaybackState(
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
}
