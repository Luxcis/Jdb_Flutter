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
      if (newState.isCompleted) {
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
      unawaited(widget.onSetPlaybackSpeed(1.0));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.playbackState;
    final hasError = state.errorDescription?.isNotEmpty ?? false;
    return ColoredBox(
      color: Colors.black,
      child: GestureDetector(
        key: const Key('movie-preview-gesture-surface'),
        behavior: HitTestBehavior.opaque,
        onTap: hasError ? null : _toggleControlsVisibility,
        onDoubleTap: hasError ? null : _togglePlayback,
        onLongPressStart: hasError ? null : _startLongPress,
        onLongPressEnd: hasError ? null : (_) => _finishLongPress(),
        onLongPressCancel: hasError ? null : _finishLongPress,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: AspectRatio(
                aspectRatio: state.aspectRatio,
                child: widget.video,
              ),
            ),
            if (state.isBuffering)
              const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            if (_isLongPressing) const Center(child: _SpeedIndicator()),
            if (_controlsVisible)
              _PreviewOverlay(
                title: widget.title,
                playbackState: state,
                dragPositionMilliseconds: _dragPositionMilliseconds,
                onBack: widget.onBack,
                onRetry: widget.onRetry,
                onChanged: _changePosition,
                onChangeStart: _startDragging,
                onChangeEnd: _endDragging,
              ),
          ],
        ),
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
    unawaited(widget.onTogglePlayback());
    _scheduleAutoHide();
  }

  void _startLongPress(LongPressStartDetails _) {
    _cancelAutoHide();
    if (_isLongPressing) return;
    setState(() {
      _controlsVisible = true;
      _isLongPressing = true;
    });
    unawaited(widget.onSetPlaybackSpeed(2.0));
  }

  void _finishLongPress() {
    if (!_isLongPressing) return;
    setState(() {
      _isLongPressing = false;
    });
    unawaited(widget.onSetPlaybackSpeed(1.0));
    _scheduleAutoHide();
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
    setState(() {
      _isDragging = false;
      _dragPositionMilliseconds = null;
    });
    unawaited(widget.onSeek(Duration(milliseconds: value.round())));
    _scheduleAutoHide();
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
    required this.onRetry,
    required this.onChanged,
    required this.onChangeStart,
    required this.onChangeEnd,
  });

  final String title;
  final MoviePreviewPlaybackState playbackState;
  final double? dragPositionMilliseconds;
  final VoidCallback onBack;
  final Future<void> Function() onRetry;
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
      child: Container(
        key: const Key('movie-preview-controls-overlay'),
        color: Colors.black54,
        child: SafeArea(
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
                            onPressed: () => unawaited(onRetry()),
                            child: const Text('重试'),
                          ),
                        ],
                      )
                    : Icon(
                        playbackState.isPlaying
                            ? Icons.pause_circle_outline
                            : Icons.play_circle_outline,
                        color: Colors.white,
                        size: 52,
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
