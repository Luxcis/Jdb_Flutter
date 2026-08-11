import 'dart:async';

import 'package:flutter/material.dart';
import 'package:jade/features/movie_detail/services/movie_preview_playback.dart';

class MoviePreviewControls extends StatefulWidget {
  const MoviePreviewControls({
    super.key,
    required this.title,
    required this.video,
    required this.playbackState,
    required this.onBack,
    required this.onTogglePlayback,
    required this.onSeek,
    required this.onSetPlaybackSpeed,
    required this.onRetry,
    this.autoHideDelay = const Duration(seconds: 3),
  });

  final String title;
  final Widget video;
  final MoviePreviewPlaybackState playbackState;
  final VoidCallback onBack;
  final Future<void> Function() onTogglePlayback;
  final Future<void> Function(Duration position) onSeek;
  final Future<void> Function(double speed) onSetPlaybackSpeed;
  final Future<void> Function() onRetry;
  final Duration autoHideDelay;

  @override
  State<MoviePreviewControls> createState() => _MoviePreviewControlsState();
}

class _MoviePreviewControlsState extends State<MoviePreviewControls> {
  bool _controlsVisible = true;
  bool _isDragging = false;
  bool _isLongPressing = false;
  double? _dragPositionMilliseconds;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _scheduleAutoHide();
  }

  @override
  void didUpdateWidget(covariant MoviePreviewControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldState = oldWidget.playbackState;
    final newState = widget.playbackState;
    if (oldState.isInitialized != newState.isInitialized ||
        oldState.isPlaying != newState.isPlaying ||
        oldState.isBuffering != newState.isBuffering ||
        oldState.isCompleted != newState.isCompleted ||
        oldState.errorDescription != newState.errorDescription) {
      _cancelAutoHide();
      if (!newState.isInitialized ||
          !newState.isPlaying ||
          newState.isBuffering ||
          newState.isCompleted ||
          (newState.errorDescription?.isNotEmpty ?? false)) {
        _controlsVisible = true;
        return;
      }
      if (_controlsVisible) {
        _scheduleAutoHide();
      }
    }
  }

  @override
  void dispose() {
    _cancelAutoHide();
    if (_isLongPressing) {
      unawaited(
        _runCommand(
          () => widget.onSetPlaybackSpeed(1.0),
          keepControlsVisibleOnFailure: false,
        ),
      );
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.playbackState;
    final hasError = state.errorDescription?.isNotEmpty ?? false;
    return ColoredBox(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            key: const Key('movie-preview-gesture-surface'),
            behavior: HitTestBehavior.opaque,
            onTap: hasError ? null : _toggleControlsVisibility,
            onDoubleTap: hasError ? null : _togglePlayback,
            onLongPressStart: hasError ? null : _startLongPress,
            onLongPressEnd: hasError ? null : (_) => _finishLongPress(),
            onLongPressCancel: hasError ? null : _finishLongPress,
            child: Center(
              child: AspectRatio(
                aspectRatio: state.aspectRatio,
                child: widget.video,
              ),
            ),
          ),
          if (state.isBuffering)
            const Center(child: CircularProgressIndicator(color: Colors.white)),
          if (_isLongPressing) const Center(child: _SpeedIndicator()),
          if (_controlsVisible)
            _PreviewOverlay(
              title: widget.title,
              playbackState: state,
              dragPositionMilliseconds: _dragPositionMilliseconds,
              onBack: widget.onBack,
              onTogglePlayback: _togglePlayback,
              onRetry: _retry,
              onChanged: _changePosition,
              onChangeStart: _startDragging,
              onChangeEnd: _endDragging,
            ),
        ],
      ),
    );
  }

  bool get _canAutoHide {
    final state = widget.playbackState;
    return state.isInitialized &&
        state.isPlaying &&
        !state.isBuffering &&
        !state.isCompleted &&
        !_isDragging &&
        !_isLongPressing &&
        !(state.errorDescription?.isNotEmpty ?? false);
  }

  void _toggleControlsVisibility() {
    _cancelAutoHide();
    setState(() {
      _controlsVisible = !_controlsVisible;
    });
    if (_controlsVisible) {
      _scheduleAutoHide();
    }
  }

  void _togglePlayback() {
    _cancelAutoHide();
    if (!_controlsVisible) {
      setState(() {
        _controlsVisible = true;
      });
    }
    unawaited(_runTogglePlayback());
  }

  Future<void> _runTogglePlayback() async {
    if (await _runCommand(widget.onTogglePlayback) && mounted) {
      _scheduleAutoHide();
    }
  }

  void _startLongPress(LongPressStartDetails _) {
    _cancelAutoHide();
    if (_isLongPressing) return;
    setState(() {
      _controlsVisible = true;
      _isLongPressing = true;
    });
    unawaited(_setPlaybackSpeed(2.0));
  }

  void _finishLongPress() {
    if (!_isLongPressing) return;
    setState(() {
      _isLongPressing = false;
    });
    unawaited(_setPlaybackSpeed(1.0, scheduleAfterSuccess: true));
  }

  Future<void> _setPlaybackSpeed(
    double speed, {
    bool scheduleAfterSuccess = false,
  }) async {
    if (await _runCommand(() => widget.onSetPlaybackSpeed(speed)) &&
        scheduleAfterSuccess &&
        mounted) {
      _scheduleAutoHide();
    }
  }

  void _startDragging(double _) {
    _cancelAutoHide();
    setState(() {
      _isDragging = true;
    });
  }

  void _changePosition(double value) {
    _cancelAutoHide();
    setState(() {
      _dragPositionMilliseconds = value;
    });
  }

  void _endDragging(double value) {
    unawaited(_seek(value));
  }

  Future<void> _seek(double value) async {
    final succeeded = await _runCommand(
      () => widget.onSeek(Duration(milliseconds: value.round())),
    );
    if (!succeeded || !mounted) return;
    setState(() {
      _isDragging = false;
      _dragPositionMilliseconds = null;
    });
    _scheduleAutoHide();
  }

  void _retry() {
    unawaited(_runRetry());
  }

  Future<void> _runRetry() async {
    if (await _runCommand(widget.onRetry) && mounted) {
      _scheduleAutoHide();
    }
  }

  Future<bool> _runCommand(
    Future<void> Function() command, {
    bool keepControlsVisibleOnFailure = true,
  }) async {
    try {
      await command();
      return true;
    } catch (_) {
      if (keepControlsVisibleOnFailure && mounted) {
        _cancelAutoHide();
        setState(() {
          _controlsVisible = true;
        });
      }
      return false;
    }
  }

  void _scheduleAutoHide() {
    _cancelAutoHide();
    if (!_controlsVisible || !_canAutoHide) return;
    _hideTimer = Timer(widget.autoHideDelay, () {
      if (!mounted || !_canAutoHide) return;
      setState(() {
        _controlsVisible = false;
      });
      _hideTimer = null;
    });
  }

  void _cancelAutoHide() {
    _hideTimer?.cancel();
    _hideTimer = null;
  }
}

class _PreviewOverlay extends StatelessWidget {
  const _PreviewOverlay({
    required this.title,
    required this.playbackState,
    required this.dragPositionMilliseconds,
    required this.onBack,
    required this.onTogglePlayback,
    required this.onRetry,
    required this.onChanged,
    required this.onChangeStart,
    required this.onChangeEnd,
  });

  final String title;
  final MoviePreviewPlaybackState playbackState;
  final double? dragPositionMilliseconds;
  final VoidCallback onBack;
  final VoidCallback onTogglePlayback;
  final VoidCallback onRetry;
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeStart;
  final ValueChanged<double>? onChangeEnd;

  @override
  Widget build(BuildContext context) {
    final durationMilliseconds = playbackState.duration.inMilliseconds;
    final positionMilliseconds =
        (dragPositionMilliseconds ??
                playbackState.position.inMilliseconds.toDouble())
            .clamp(0, durationMilliseconds)
            .toDouble();
    final hasError = playbackState.errorDescription?.isNotEmpty ?? false;
    final canSeek = durationMilliseconds > 0;

    return Positioned.fill(
      child: Stack(
        key: const Key('movie-preview-controls-overlay'),
        children: [
          const Positioned.fill(
            child: IgnorePointer(child: ColoredBox(color: Colors.black54)),
          ),
          SafeArea(
            child: Stack(
              children: [
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: onBack,
                        tooltip: '返回',
                        color: Colors.white,
                        icon: const Icon(Icons.arrow_back),
                      ),
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
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
                              onPressed: onRetry,
                              child: const Text('重试'),
                            ),
                          ],
                        )
                      : IconButton(
                          onPressed: onTogglePlayback,
                          tooltip: playbackState.isPlaying ? '暂停' : '播放',
                          color: Colors.white,
                          iconSize: 52,
                          icon: Icon(
                            playbackState.isPlaying
                                ? Icons.pause_circle_outline
                                : Icons.play_circle_outline,
                          ),
                        ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 0,
                  child: Row(
                    children: [
                      Text(
                        _formatDuration(
                          Duration(milliseconds: positionMilliseconds.round()),
                        ),
                        style: const TextStyle(color: Colors.white),
                      ),
                      Expanded(
                        child: Slider(
                          value: positionMilliseconds,
                          max: durationMilliseconds.toDouble(),
                          onChanged: canSeek ? onChanged : null,
                          onChangeStart: canSeek ? onChangeStart : null,
                          onChangeEnd: canSeek ? onChangeEnd : null,
                        ),
                      ),
                      Text(
                        canSeek
                            ? _formatDuration(playbackState.duration)
                            : '--:--',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SpeedIndicator extends StatelessWidget {
  const _SpeedIndicator();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text('2.0×', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}

String _formatDuration(Duration value) {
  final hours = value.inHours;
  final minutes = value.inMinutes.remainder(60);
  final seconds = value.inSeconds.remainder(60);
  String twoDigits(int number) => number.toString().padLeft(2, '0');
  if (hours > 0) {
    return '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}';
  }
  return '${twoDigits(minutes)}:${twoDigits(seconds)}';
}
