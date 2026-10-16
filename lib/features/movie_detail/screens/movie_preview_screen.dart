import 'dart:async';

import 'package:flutter/material.dart';
import 'package:jade/features/movie_detail/models/movie_preview_args.dart';
import 'package:jade/features/movie_detail/services/missav_stream_resolver.dart';
import 'package:jade/features/movie_detail/services/movie_preview_brightness.dart';
import 'package:jade/features/movie_detail/services/movie_preview_operation_manager.dart';
import 'package:jade/features/movie_detail/services/movie_preview_orientation.dart';
import 'package:jade/features/movie_detail/services/movie_preview_playback.dart';
import 'package:jade/features/movie_detail/services/movie_preview_system_ui.dart';
import 'package:jade/features/movie_detail/services/movie_preview_volume.dart';
import 'package:jade/features/movie_detail/services/movie_preview_wakelock.dart';
import 'package:jade/features/movie_detail/widgets/movie_preview_controls_overlay.dart';
import 'package:jade/features/movie_detail/widgets/movie_preview_header.dart';

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
    this.brightnessController,
    this.volumeController,
    this.onlineResolver,
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
  final MoviePreviewBrightnessController? brightnessController;
  final MoviePreviewVolumeController? volumeController;

  /// 在线正片来源的取流解析器；省略时在首次解析时创建生产实现。
  final MissavStreamResolver? onlineResolver;

  @override
  State<MoviePreviewScreen> createState() => _MoviePreviewScreenState();
}

class _MoviePreviewScreenState extends State<MoviePreviewScreen> {
  static const _cleanupStepTimeout = Duration(milliseconds: 1500);

  late final MoviePreviewOperationManager _operationManager;
  late final MoviePreviewBrightnessController _brightnessController;
  late final MoviePreviewVolumeController _volumeController;

  _PlaybackSession? _session;
  MoviePreviewOperationLease? _operationLease;
  MissavStreamResolver? _onlineResolver;
  MissavHttpStreamResolver? _ownedResolver;
  var _isLoading = true;
  var _hasError = false;
  var _isRetrying = false;
  var _orientationReady = false;
  var _lifecycleGeneration = 0;

  String get _title => widget.args?.title ?? '预告片';

  bool get _isOnline => widget.args?.isOnline ?? false;

  void _pop() => Navigator.of(context).pop();

  MoviePreviewPlayback _createPlayback(
    Uri uri, {
    Map<String, String>? httpHeaders,
  }) {
    final injectedFactory = widget.playbackFactory;
    if (injectedFactory != null) {
      return injectedFactory(uri);
    }
    return MediaKitMoviePreviewPlayback(uri, httpHeaders: httpHeaders);
  }

  @override
  void initState() {
    super.initState();
    _operationManager =
        widget.operationManager ?? _createOperationManagerFromInjected();
    _brightnessController =
        widget.brightnessController ?? SystemMoviePreviewBrightnessController();
    _volumeController =
        widget.volumeController ?? SystemMoviePreviewVolumeController();
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
    _closeOwnedResolver();
    unawaited(_operationManager.release());
    unawaited(_cleanupSession(session));
    unawaited(_resetBrightness());
    super.dispose();
  }

  void _closeOwnedResolver() {
    final owned = _ownedResolver;
    _ownedResolver = null;
    _onlineResolver = null;
    if (owned == null) return;
    try {
      owned.close();
    } catch (error, stackTrace) {
      _logIgnored('close-resolver', error, stackTrace);
    }
  }

  Future<void> _resetBrightness() async {
    try {
      await _brightnessController.reset();
    } catch (error, stackTrace) {
      _logIgnored('reset-brightness', error, stackTrace);
    }
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
    return ValueListenableBuilder<MoviePreviewPlaybackState>(
      valueListenable: playback.state,
      builder: (context, state, child) {
        if (state.errorDescription?.isNotEmpty ?? false) {
          return _buildStatusBody(hasError: true);
        }
        return Stack(
          fit: StackFit.expand,
          children: [
            playback.buildView(),
            MoviePreviewControlsOverlay(
              title: _title,
              onBack: _pop,
              playback: playback,
              brightnessController: _brightnessController,
              volumeController: _volumeController,
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
                    Text(
                      _isOnline ? '在线播放失败' : '预告片播放失败',
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _isRetrying ? null : _retry,
                      child: const Text('重试'),
                    ),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Colors.white),
                    if (_isOnline)
                      const Padding(
                        padding: EdgeInsets.only(top: 16),
                        child: Text(
                          '正在解析播放地址…',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                  ],
                ),
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
    final args = widget.args;
    var uri = args?.videoUri;
    Map<String, String>? httpHeaders;

    if (uri == null && (args?.isOnline ?? false)) {
      final resolved = await _resolveOnlineStream(
        args!.onlineNumber!,
        generation,
      );
      if (resolved == null) return;
      uri = resolved.playlistUrl;
      httpHeaders = resolved.httpHeaders;
    }

    if (uri == null) {
      if (_isCurrentGeneration(generation)) {
        _showPageError();
      }
      return;
    }

    _PlaybackSession? session;
    try {
      session = _PlaybackSession(
        _createPlayback(uri, httpHeaders: httpHeaders),
      );
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

  /// 解析在线正片播放地址；返回 `null` 表示不再继续（代际过期或已进入失败态）。
  Future<MissavResolvedStream?> _resolveOnlineStream(
    String number,
    int generation,
  ) async {
    try {
      final resolver = _onlineResolver ??= _createOnlineResolver();
      final resolved = await resolver.resolve(number);
      if (!_isCurrentGeneration(generation)) return null;
      return resolved;
    } catch (error, stackTrace) {
      _logFailure('online-resolve', error, stackTrace);
      if (_isCurrentGeneration(generation)) {
        _showPageError();
      }
      return null;
    }
  }

  MissavStreamResolver _createOnlineResolver() {
    final injected = widget.onlineResolver;
    if (injected != null) return injected;
    final owned = MissavHttpStreamResolver();
    _ownedResolver = owned;
    return owned;
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

void _logIgnored(String stage, Object error, StackTrace stackTrace) {
  // 清理/副作用路径故意忽略失败，但保留日志痕迹便于排查。
  debugPrint('movie_preview $stage failed: $error\n$stackTrace');
}

void _logFailure(String stage, Object error, StackTrace stackTrace) {
  // 失败路径已转换为页面错误态，日志用于排查具体原因。
  debugPrint('movie_preview $stage failed: $error\n$stackTrace');
}
