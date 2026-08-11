import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jade/features/movie_detail/models/movie_preview_args.dart';
import 'package:jade/features/movie_detail/services/movie_preview_playback.dart';
import 'package:jade/features/movie_detail/widgets/movie_preview_controls.dart';

typedef PreferredOrientationsSetter =
    Future<void> Function(List<DeviceOrientation> orientations);

class MoviePreviewPage extends StatefulWidget {
  const MoviePreviewPage({
    super.key,
    required this.args,
    this.playbackFactory,
    this.orientationSetter,
  });

  final MoviePreviewArgs? args;
  final MoviePreviewPlaybackFactory? playbackFactory;
  final PreferredOrientationsSetter? orientationSetter;

  @override
  State<MoviePreviewPage> createState() => _MoviePreviewPageState();
}

class _MoviePreviewPageState extends State<MoviePreviewPage> {
  MoviePreviewPlayback? _playback;
  var _isLoading = true;
  var _hasError = false;
  var _isRetrying = false;
  var _initializationGeneration = 0;
  final _disposedPlaybacks = Set<MoviePreviewPlayback>.identity();

  PreferredOrientationsSetter get _orientationSetter =>
      widget.orientationSetter ?? SystemChrome.setPreferredOrientations;

  MoviePreviewPlaybackFactory get _playbackFactory =>
      widget.playbackFactory ?? VideoPlayerMoviePreviewPlayback.new;

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  @override
  void dispose() {
    _initializationGeneration++;
    final playback = _playback;
    _playback = null;
    unawaited(_disposeAndRestoreOrientation(playback));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_hasError) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('预告片播放失败', style: TextStyle(color: Colors.white)),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _isRetrying ? null : _retry,
            child: const Text('重试'),
          ),
        ],
      );
    }

    final playback = _playback;
    if (_isLoading || playback == null) {
      return const CircularProgressIndicator(color: Colors.white);
    }

    return ValueListenableBuilder<MoviePreviewPlaybackState>(
      valueListenable: playback.state,
      builder: (context, state, child) {
        return MoviePreviewControls(
          title: widget.args?.title ?? '',
          video: playback.buildView(),
          playbackState: state,
          onBack: () => Navigator.of(context).pop(),
          onTogglePlayback: _togglePlayback,
          onSeek: playback.seekTo,
          onSetPlaybackSpeed: playback.setPlaybackSpeed,
          onRetry: _retry,
        );
      },
    );
  }

  Future<void> _togglePlayback() async {
    final playback = _playback;
    if (playback == null) return;
    final value = playback.state.value;
    if (value.isCompleted) {
      await playback.seekTo(Duration.zero);
      await playback.play();
    } else if (value.isPlaying) {
      await playback.pause();
    } else {
      await playback.play();
    }
  }

  Future<void> _start() async {
    await _setLandscapeOrientations();
    if (!mounted) return;
    await _initializePlayback();
  }

  Future<void> _setLandscapeOrientations() async {
    try {
      await _orientationSetter([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } catch (_) {}
  }

  Future<void> _initializePlayback() async {
    final uri = widget.args?.videoUri;
    if (uri == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
      return;
    }

    final generation = ++_initializationGeneration;
    MoviePreviewPlayback? playback;

    try {
      playback = _playbackFactory(uri);
      _playback = playback;
      await playback.initialize();
      if (!mounted || generation != _initializationGeneration) {
        await _disposeStalePlayback(playback);
        return;
      }
      await playback.play();
      if (!mounted || generation != _initializationGeneration) {
        await _disposeStalePlayback(playback);
        return;
      }
      setState(() {
        _isLoading = false;
        _hasError = false;
      });
    } catch (_) {
      if (!mounted || generation != _initializationGeneration) {
        await _disposeStalePlayback(playback);
        return;
      }
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  Future<void> _retry() async {
    if (_isRetrying) return;
    setState(() {
      _isRetrying = true;
    });
    try {
      final playback = _playback;
      _playback = null;
      _initializationGeneration++;
      await _disposePlayback(playback);
      if (!mounted) return;
      setState(() {
        _isLoading = true;
        _hasError = false;
      });
      await _initializePlayback();
    } finally {
      if (mounted) {
        setState(() {
          _isRetrying = false;
        });
      }
    }
  }

  Future<void> _disposeAndRestoreOrientation(
    MoviePreviewPlayback? playback,
  ) async {
    await _disposePlayback(playback);
    try {
      await _orientationSetter([]);
    } catch (_) {}
  }

  Future<void> _disposePlayback(MoviePreviewPlayback? playback) async {
    if (playback == null || !_disposedPlaybacks.add(playback)) return;
    try {
      await playback.setPlaybackSpeed(1.0);
    } catch (_) {}
    try {
      await playback.pause();
    } catch (_) {}
    try {
      await playback.dispose();
    } catch (_) {}
  }

  Future<void> _disposeStalePlayback(MoviePreviewPlayback? playback) async {
    if (identical(_playback, playback)) {
      _playback = null;
    }
    await _disposePlayback(playback);
  }
}
