import 'dart:async';

import 'package:flutter/material.dart';
import 'package:jade/features/movie_detail/models/movie_preview_args.dart';
import 'package:jade/features/movie_detail/services/movie_preview_operation_manager.dart';
import 'package:jade/features/movie_detail/services/movie_preview_orientation.dart';
import 'package:jade/features/movie_detail/services/movie_preview_playback.dart';
import 'package:jade/features/movie_detail/services/movie_preview_system_ui.dart';
import 'package:jade/features/movie_detail/services/movie_preview_wakelock.dart';
import 'package:jade/features/movie_detail/widgets/movie_preview_double_tap_detector.dart';
import 'package:jade/features/movie_detail/widgets/movie_preview_header.dart';
import 'package:jade/features/movie_detail/widgets/movie_preview_header_overlay.dart';

typedef PreferredOrientationsSetter = MoviePreviewPreferredOrientationsSetter;

class MoviePreviewScreen extends StatefulWidget {
  const MoviePreviewScreen({
    super.key,
    required this.args,
    this.playbackFactory,
    this.orientationSetter,
    this.orientationCoordinator,
    this.wakelockCoordinator,
    this.systemUiCoordinator,
    this.operationManager,
  }) : assert(
         orientationSetter == null || orientationCoordinator == null,
         'Only one orientation dependency can be provided.',
       );

  final MoviePreviewArgs? args;
  final MoviePreviewPlaybackFactory? playbackFactory;
  final PreferredOrientationsSetter? orientationSetter;
  final MoviePreviewOrientationCoordinator? orientationCoordinator;
  final MoviePreviewWakelockCoordinator? wakelockCoordinator;
  final MoviePreviewSystemUiCoordinator? systemUiCoordinator;
  final MoviePreviewOperationManager? operationManager;

  @override
  State<MoviePreviewScreen> createState() => _MoviePreviewScreenState();
}

class _MoviePreviewScreenState extends State<MoviePreviewScreen> {
  static const _cleanupStepTimeout = Duration(milliseconds: 1500);

  late final MoviePreviewOperationManager _operationManager;

  _PlaybackSession? _session;
  MoviePreviewOperationLease? _operationLease;
  var _isLoading = true;
  var _hasError = false;
  var _isRetrying = false;
  var _orientationReady = false;
  var _lifecycleGeneration = 0;

  String get _title => widget.args?.title ?? '预告片';

  void _pop() => Navigator.of(context).pop();

  MoviePreviewPlayback _createPlayback(Uri uri) {
    final injectedFactory = widget.playbackFactory;
    if (injectedFactory != null) {
      return injectedFactory(uri);
    }
    return MediaKitMoviePreviewPlayback(uri);
  }

  @override
  void initState() {
    super.initState();
    _operationManager =
        widget.operationManager ?? _createOperationManagerFromInjected();
    final lease = _operationManager.acquire();
    _operationLease = lease;
    unawaited(_ignoreSystemUiOperation(lease.systemUiLease.enabled));
    final generation = ++_lifecycleGeneration;
    unawaited(_acquireOrientationAndInitialize(generation));
  }

  MoviePreviewOperationManager _createOperationManagerFromInjected() {
    final orientationCoordinator =
        widget.orientationCoordinator ??
        (widget.orientationSetter == null
            ? MoviePreviewOrientationCoordinator.system
            : MoviePreviewOrientationCoordinator(
                setPreferredOrientations: widget.orientationSetter!,
              ));
    final wakelockCoordinator =
        widget.wakelockCoordinator ?? MoviePreviewWakelockCoordinator.system;
    final systemUiCoordinator =
        widget.systemUiCoordinator ?? MoviePreviewSystemUiCoordinator.system;
    return MoviePreviewOperationManager(
      orientationCoordinator: orientationCoordinator,
      wakelockCoordinator: wakelockCoordinator,
      systemUiCoordinator: systemUiCoordinator,
    );
  }

  @override
  void dispose() {
    _lifecycleGeneration++;
    final session = _session;
    _session = null;
    _operationLease = null;
    _orientationReady = false;
    unawaited(_operationManager.release());
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
      child: MoviePreviewDoubleTapDetector(
        onDoubleTap: () => _onDoubleTap(command),
        child: playback.buildView(),
      ),
      builder: (context, state, child) {
        if (state.errorDescription?.isNotEmpty ?? false) {
          return _buildStatusBody(hasError: true);
        }
        return Stack(
          fit: StackFit.expand,
          children: [
            child!,
            MoviePreviewHeaderOverlay(
              title: _title,
              onBack: _pop,
              state: playback.state,
            ),
          ],
        );
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
            child: MoviePreviewHeader(title: _title, onBack: _pop),
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

  void _onDoubleTap(_PlaybackCommand command) {
    unawaited(() async {
      try {
        await _togglePlayback(command);
      } catch (error, stackTrace) {
        _logIgnored('ignored-operation', error, stackTrace);
      }
    }());
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
    var lease = _operationLease;
    if (lease == null) return;

    try {
      await lease.orientationLocked;
    } catch (error, stackTrace) {
      _logIgnored('orientation-lock', error, stackTrace);
      if (_isCurrentGeneration(generation) &&
          identical(_operationLease, lease)) {
        _orientationReady = false;
        _showPageError();
      }
      unawaited(_releaseOrientationLease(lease));
      return;
    }

    if (!_isCurrentGeneration(generation) ||
        !identical(_operationLease, lease)) {
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
      session = _PlaybackSession(_createPlayback(uri));
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
      final lease = _operationLease;
      if (lease != null) {
        _operationManager.acquireWakelock(lease);
      }
      setState(() {
        _isLoading = false;
        _hasError = false;
      });
    } catch (error, stackTrace) {
      _logIgnored('session-init', error, stackTrace);
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
        final lease = _operationLease;
        if (lease != null) {
          _operationLease = _operationManager.replaceOrientationLease(lease);
        }
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

  Future<void> _releaseOrientationLease(
    MoviePreviewOperationLease lease,
  ) async {
    try {
      await lease.orientationLease.release();
    } catch (error, stackTrace) {
      _logIgnored('ignored-operation', error, stackTrace);
    }
  }

  Future<void> _ignoreSystemUiOperation(Future<void> operation) async {
    try {
      await operation;
    } catch (error, stackTrace) {
      _logIgnored('ignored-operation', error, stackTrace);
    }
  }

  Future<void> _cleanupSession(_PlaybackSession? session) {
    if (session == null) return Future<void>.value();
    return session.cleanupOperation ??= _runCleanup(session.playback);
  }

  Future<void> _runCleanup(MoviePreviewPlayback playback) async {
    await _ignoreBoundedCleanup(playback.pause);
    await _ignoreBoundedCleanup(playback.dispose);
  }

  Future<void> _ignoreBoundedCleanup(Future<void> Function() command) async {
    try {
      await command().timeout(_cleanupStepTimeout);
    } catch (error, stackTrace) {
      _logIgnored('ignored-operation', error, stackTrace);
    }
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

void _logIgnored(String stage, Object error, StackTrace stackTrace) {
  // 清理/副作用路径故意忽略失败，但保留日志痕迹便于排查。
  debugPrint('movie_preview $stage failed: $error\n$stackTrace');
}
