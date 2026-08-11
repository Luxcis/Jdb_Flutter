import 'dart:async';

import 'package:flutter/material.dart';
import 'package:jade/features/movie_detail/models/movie_preview_args.dart';
import 'package:jade/features/movie_detail/services/movie_preview_orientation.dart';
import 'package:jade/features/movie_detail/services/movie_preview_playback.dart';
import 'package:jade/features/movie_detail/services/movie_preview_wakelock.dart';
import 'package:jade/features/movie_detail/widgets/movie_preview_gesture_layer.dart';
import 'package:jade/features/movie_detail/widgets/movie_preview_header.dart';

typedef PreferredOrientationsSetter = MoviePreviewPreferredOrientationsSetter;

class MoviePreviewPage extends StatefulWidget {
  const MoviePreviewPage({
    super.key,
    required this.args,
    this.playbackFactory,
    this.orientationSetter,
    this.orientationCoordinator,
    this.wakelockCoordinator,
  }) : assert(
         orientationSetter == null || orientationCoordinator == null,
         'Only one orientation dependency can be provided.',
       );

  final MoviePreviewArgs? args;
  final MoviePreviewPlaybackFactory? playbackFactory;
  final PreferredOrientationsSetter? orientationSetter;
  final MoviePreviewOrientationCoordinator? orientationCoordinator;
  final MoviePreviewWakelockCoordinator? wakelockCoordinator;

  @override
  State<MoviePreviewPage> createState() => _MoviePreviewPageState();
}

class _MoviePreviewPageState extends State<MoviePreviewPage> {
  static const _cleanupStepTimeout = Duration(milliseconds: 1500);

  late final MoviePreviewOrientationCoordinator _orientationCoordinator;
  late final MoviePreviewWakelockCoordinator _wakelockCoordinator;

  _PlaybackSession? _session;
  MoviePreviewOrientationLease? _orientationLease;
  MoviePreviewWakelockLease? _wakelockLease;
  var _isLoading = true;
  var _hasError = false;
  var _isRetrying = false;
  var _orientationReady = false;
  var _lifecycleGeneration = 0;

  MoviePreviewPlaybackFactory get _playbackFactory =>
      widget.playbackFactory ?? ChewieMoviePreviewPlayback.new;

  String get _title => widget.args?.title ?? '预告片';

  @override
  void initState() {
    super.initState();
    _orientationCoordinator =
        widget.orientationCoordinator ??
        (widget.orientationSetter == null
            ? MoviePreviewOrientationCoordinator.system
            : MoviePreviewOrientationCoordinator(
                setPreferredOrientations: widget.orientationSetter!,
              ));
    _wakelockCoordinator =
        widget.wakelockCoordinator ?? MoviePreviewWakelockCoordinator.system;
    final generation = ++_lifecycleGeneration;
    unawaited(_acquireOrientationAndInitialize(generation));
  }

  @override
  void dispose() {
    _lifecycleGeneration++;
    final session = _session;
    _session = null;
    final orientationLease = _orientationLease;
    _orientationLease = null;
    final wakelockLease = _wakelockLease;
    _wakelockLease = null;
    _orientationReady = false;
    unawaited(_releaseOrientation(orientationLease));
    unawaited(_releaseWakelock(wakelockLease));
    unawaited(_cleanupSession(session));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor: Colors.black, body: _buildBody());
  }

  Widget _buildBody() {
    final session = _session;
    if (!_isLoading && !_hasError && session != null) {
      return _buildPlaybackBody(session);
    }
    return _buildStatusBody(hasError: _hasError);
  }

  Widget _buildPlaybackBody(_PlaybackSession session) {
    final playback = session.playback;
    final command = _PlaybackCommand(
      session: session,
      generation: _lifecycleGeneration,
    );
    return ValueListenableBuilder<MoviePreviewPlaybackState>(
      valueListenable: playback.state,
      child: Stack(
        fit: StackFit.expand,
        children: [
          MoviePreviewGestureLayer(
            onTogglePlayback: () => _togglePlayback(command),
            onSetPlaybackSpeed: (speed) => _setPlaybackSpeed(command, speed),
            onSpeedRecoveryFailure: () => _handleSpeedRecoveryFailure(command),
            child: playback.buildView(),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: MoviePreviewHeader(
                title: _title,
                onBack: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        ],
      ),
      builder: (context, state, child) {
        if (state.errorDescription?.isNotEmpty ?? false) {
          return _buildStatusBody(hasError: true);
        }
        return child!;
      },
    );
  }

  Widget _buildStatusBody({required bool hasError}) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Center(
          child: hasError
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '预告片播放失败',
                      style: TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _isRetrying ? null : _retry,
                      child: const Text('重试'),
                    ),
                  ],
                )
              : const CircularProgressIndicator(color: Colors.white),
        ),
        SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: MoviePreviewHeader(
              title: _title,
              onBack: () => Navigator.of(context).pop(),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _togglePlayback(_PlaybackCommand command) async {
    _ensureCommandIsCurrent(command);
    final playback = command.session.playback;
    final value = playback.state.value;
    if (value.isCompleted) {
      await playback.seekTo(Duration.zero);
      _ensureCommandIsCurrent(command);
      await playback.play();
      _ensureCommandIsCurrent(command);
    } else if (value.isPlaying) {
      await playback.pause();
      _ensureCommandIsCurrent(command);
    } else {
      await playback.play();
      _ensureCommandIsCurrent(command);
    }
  }

  Future<void> _setPlaybackSpeed(_PlaybackCommand command, double speed) async {
    _ensureCommandIsCurrent(command);
    await command.session.playback.setPlaybackSpeed(speed);
    _ensureCommandIsCurrent(command);
  }

  Future<void> _handleSpeedRecoveryFailure(_PlaybackCommand command) async {
    _ensureCommandIsCurrent(command);
    _showPageError();
    try {
      await command.session.playback.pause().timeout(_cleanupStepTimeout);
    } catch (_) {}
    _ensureCommandIsCurrent(command);
  }

  bool _isCommandCurrent(_PlaybackCommand command) {
    return mounted &&
        command.generation == _lifecycleGeneration &&
        identical(_session, command.session);
  }

  void _ensureCommandIsCurrent(_PlaybackCommand command) {
    if (!_isCommandCurrent(command)) {
      throw const _PlaybackCommandInvalidated();
    }
  }

  Future<void> _acquireOrientationAndInitialize(int generation) async {
    final lease = _orientationCoordinator.acquire();
    _orientationLease = lease;
    try {
      await lease.locked;
    } catch (_) {
      if (_isCurrentGeneration(generation) &&
          identical(_orientationLease, lease)) {
        _orientationLease = null;
        _orientationReady = false;
        _showPageError();
      }
      unawaited(_releaseOrientation(lease));
      return;
    }

    if (!_isCurrentGeneration(generation) ||
        !identical(_orientationLease, lease)) {
      unawaited(_releaseOrientation(lease));
      return;
    }
    _orientationReady = true;
    await _initializePlayback(generation);
  }

  Future<void> _initializePlayback(int generation) async {
    final uri = widget.args?.videoUri;
    if (uri == null) {
      if (_isCurrentGeneration(generation)) {
        _showPageError();
      }
      return;
    }

    _PlaybackSession? session;
    try {
      session = _PlaybackSession(_playbackFactory(uri));
      _session = session;
      await session.playback.initialize();
      if (!_isCurrentSession(generation, session)) {
        _detachAndCleanup(session);
        return;
      }
      await session.playback.play();
      if (!_isCurrentSession(generation, session)) {
        _detachAndCleanup(session);
        return;
      }
      _acquireWakelock();
      setState(() {
        _isLoading = false;
        _hasError = false;
      });
    } catch (_) {
      if (session != null && !_isCurrentSession(generation, session)) {
        _detachAndCleanup(session);
        return;
      }
      if (_isCurrentGeneration(generation)) {
        _showPageError();
      }
    }
  }

  Future<void> _retry() async {
    if (_isRetrying || !mounted) return;
    setState(() {
      _isRetrying = true;
    });
    final generation = ++_lifecycleGeneration;
    final session = _session;
    _session = null;
    try {
      await _cleanupSession(session);
      if (!_isCurrentGeneration(generation)) return;
      setState(() {
        _isLoading = true;
        _hasError = false;
      });
      if (_orientationReady) {
        await _initializePlayback(generation);
      } else {
        await _acquireOrientationAndInitialize(generation);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRetrying = false;
        });
      }
    }
  }

  bool _isCurrentGeneration(int generation) =>
      mounted && generation == _lifecycleGeneration;

  bool _isCurrentSession(int generation, _PlaybackSession session) =>
      _isCurrentGeneration(generation) && identical(_session, session);

  void _showPageError() {
    setState(() {
      _isLoading = false;
      _hasError = true;
    });
  }

  void _detachAndCleanup(_PlaybackSession session) {
    if (identical(_session, session)) {
      _session = null;
    }
    unawaited(_cleanupSession(session));
  }

  Future<void> _releaseOrientation(MoviePreviewOrientationLease? lease) async {
    if (lease == null) return;
    try {
      await lease.release();
    } catch (_) {}
  }

  void _acquireWakelock() {
    if (_wakelockLease != null) return;
    final lease = _wakelockCoordinator.acquire();
    _wakelockLease = lease;
    unawaited(_ignoreWakelockOperation(lease.enabled));
  }

  Future<void> _releaseWakelock(MoviePreviewWakelockLease? lease) async {
    if (lease == null) return;
    await _ignoreWakelockOperation(lease.release());
  }

  Future<void> _ignoreWakelockOperation(Future<void> operation) async {
    try {
      await operation;
    } catch (_) {}
  }

  Future<void> _cleanupSession(_PlaybackSession? session) {
    if (session == null) return Future<void>.value();
    return session.cleanupOperation ??= _runCleanup(session.playback);
  }

  Future<void> _runCleanup(MoviePreviewPlayback playback) async {
    await _ignoreBoundedCleanup(() => playback.setPlaybackSpeed(1.0));
    await _ignoreBoundedCleanup(playback.pause);
    await _ignoreBoundedCleanup(playback.dispose);
  }

  Future<void> _ignoreBoundedCleanup(Future<void> Function() command) async {
    try {
      await command().timeout(_cleanupStepTimeout);
    } catch (_) {}
  }
}

class _PlaybackSession {
  _PlaybackSession(this.playback);

  final MoviePreviewPlayback playback;
  Future<void>? cleanupOperation;
}

class _PlaybackCommand {
  const _PlaybackCommand({required this.session, required this.generation});

  final _PlaybackSession session;
  final int generation;
}

class _PlaybackCommandInvalidated implements Exception {
  const _PlaybackCommandInvalidated();
}
