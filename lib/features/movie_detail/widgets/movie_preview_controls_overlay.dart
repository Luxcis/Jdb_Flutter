import 'dart:async';

import 'package:flutter/material.dart';
import 'package:jade/features/movie_detail/services/movie_preview_brightness.dart';
import 'package:jade/features/movie_detail/services/movie_preview_playback.dart';
import 'package:jade/features/movie_detail/services/movie_preview_volume.dart';
import 'package:jade/features/movie_detail/widgets/movie_preview_header.dart';

/// 预告片播放页自管理操作层。
///
/// 负责顶部标题栏与底部操作栏的同步显隐、播放控制手势
///（单击显隐、双击播放/暂停、长按 2 倍速、左半区垂直滑亮度、
/// 右半区垂直滑音量、水平滑快进快退）及实时指示器。
class MoviePreviewControlsOverlay extends StatefulWidget {
  const MoviePreviewControlsOverlay({
    super.key,
    required this.title,
    required this.onBack,
    required this.playback,
    required this.brightnessController,
    required this.volumeController,
    this.hideDelay = const Duration(seconds: 3),
    this.horizontalSeekWindow = const Duration(seconds: 90),
    this.edgeInset = 16.0,
    this.initiallyVisible = true,
  });

  static const headerOpacityKey = Key('movie-preview-controls-header-opacity');
  static const bottomOpacityKey = Key('movie-preview-controls-bottom-opacity');
  static const indicatorKey = Key('movie-preview-controls-indicator');

  /// 标题文本。
  final String title;

  /// 返回按钮回调。
  final VoidCallback onBack;

  /// 播放适配器，用于 seek、倍速、播放/暂停查询。
  final MoviePreviewPlayback playback;

  /// 屏幕亮度控制器（调节与恢复）。
  final MoviePreviewBrightnessController brightnessController;

  /// 系统媒体音量控制器。
  final MoviePreviewVolumeController volumeController;

  /// 可隐藏状态下自动隐藏的延迟。
  final Duration hideDelay;

  /// 满宽水平拖动映射的 seek 时间窗口。
  final Duration horizontalSeekWindow;

  /// 手势热区与屏幕边缘的安全距离。
  final double edgeInset;

  /// 进入播放态后操作层是否默认可见。
  final bool initiallyVisible;

  @override
  State<MoviePreviewControlsOverlay> createState() =>
      _MoviePreviewControlsOverlayState();
}

class _MoviePreviewControlsOverlayState
    extends State<MoviePreviewControlsOverlay> {
  static const _opacityDuration = Duration(milliseconds: 250);
  static const _indicatorDismissDelay = Duration(milliseconds: 800);

  late final ValueNotifier<bool> _visible;
  Timer? _hideTimer;
  Timer? _indicatorTimer;

  MoviePreviewPlaybackState _state = const MoviePreviewPlaybackState();
  double _currentBrightness = 0.5;
  double _currentVolume = 0.5;

  // Gesture state.
  _GestureKind _activeGesture = _GestureKind.none;
  Offset? _gestureStart;
  double _gestureStartValue = 0.0;
  Duration _gestureStartPosition = Duration.zero;
  Size _gestureSize = Size.zero;

  // Indicator state.
  _Indicator _indicator = const _Indicator.none();

  bool get _canAutoHide {
    return _state.isPlaying &&
        !_state.isBuffering &&
        !_state.isCompleted &&
        (_state.errorDescription?.isEmpty ?? true);
  }

  @override
  void initState() {
    super.initState();
    _visible = ValueNotifier(widget.initiallyVisible);
    widget.playback.state.addListener(_onStateChanged);
    _state = widget.playback.state.value;
    if (_visible.value) _resetHideTimer();
    unawaited(_readInitialValues());
  }

  Future<void> _readInitialValues() async {
    final brightness = await _withResult(
      () => widget.brightnessController.current,
      'brightness-current',
    );
    final volume = await _withResult(
      () => widget.volumeController.current,
      'volume-current',
    );
    if (mounted) {
      setState(() {
        _currentBrightness = (brightness ?? _currentBrightness).clamp(0.0, 1.0);
        _currentVolume = (volume ?? _currentVolume).clamp(0.0, 1.0);
      });
    }
  }

  @override
  void didUpdateWidget(covariant MoviePreviewControlsOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.playback, oldWidget.playback)) {
      oldWidget.playback.state.removeListener(_onStateChanged);
      widget.playback.state.addListener(_onStateChanged);
      _onStateChanged();
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _indicatorTimer?.cancel();
    widget.playback.state.removeListener(_onStateChanged);
    _visible.dispose();
    super.dispose();
  }

  void _onStateChanged() {
    final value = widget.playback.state.value;
    if (mounted) {
      setState(() {
        _state = value;
      });
    }
    if (!_canAutoHide) {
      _setVisible(true);
    }
  }

  void _setVisible(bool visible) {
    if (_visible.value == visible) return;
    _visible.value = visible;
    if (visible) {
      _resetHideTimer();
    } else {
      _hideTimer?.cancel();
      _hideTimer = null;
    }
  }

  void _resetHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = null;
    if (!_canAutoHide || !_visible.value) return;
    _hideTimer = Timer(widget.hideDelay, () {
      if (mounted && _canAutoHide) {
        _setVisible(false);
      }
    });
  }

  void _keepVisibleOnInteraction() {
    _setVisible(true);
  }

  // ---- Tap / double-tap ---------------------------------------------------

  void _onTap() {
    _setVisible(!_visible.value);
  }

  void _onDoubleTap() {
    _keepVisibleOnInteraction();
    _togglePlayPause();
  }

  Future<void> _togglePlayPause() async {
    final playback = widget.playback;
    final value = _state;
    try {
      if (value.isCompleted) {
        await playback.seekTo(Duration.zero);
        if (!mounted || !identical(playback, widget.playback)) return;
        await playback.play();
      } else if (value.isPlaying) {
        await playback.pause();
      } else {
        await playback.play();
      }
    } catch (error, stackTrace) {
      _logIgnored('toggle-playback', error, stackTrace);
    }
  }

  // ---- Long press (speed up) ----------------------------------------------

  void _onLongPressStart(LongPressStartDetails details) {
    if (_activeGesture != _GestureKind.none) return;
    _activeGesture = _GestureKind.speedUp;
    _keepVisibleOnInteraction();
    _showIndicator(const _Indicator.speedUp());
    unawaited(
      _ignoreErrors(() async => widget.playback.setRate(2.0), 'set-rate'),
    );
  }

  void _onLongPressEnd(LongPressEndDetails details) {
    if (_activeGesture != _GestureKind.speedUp) return;
    _activeGesture = _GestureKind.none;
    _keepVisibleOnInteraction();
    _dismissIndicator();
    unawaited(
      _ignoreErrors(() async => widget.playback.setRate(1.0), 'reset-rate'),
    );
  }

  // ---- Vertical drag (brightness / volume) --------------------------------

  void _onVerticalDragStart(DragStartDetails details) {
    if (_activeGesture != _GestureKind.none) return;
    final position = details.localPosition;
    if (_isInEdgeArea(position)) return;

    final kind = position.dx <= _gestureSize.width / 2
        ? _GestureKind.brightness
        : _GestureKind.volume;
    _activeGesture = kind;
    _gestureStart = position;
    _gestureStartValue = kind == _GestureKind.brightness
        ? _currentBrightness
        : _currentVolume;
    _keepVisibleOnInteraction();
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    if (_activeGesture != _GestureKind.brightness &&
        _activeGesture != _GestureKind.volume) {
      return;
    }
    final dy = details.localPosition.dy - (_gestureStart?.dy ?? 0.0);
    final ratio = -dy / (_gestureSize.height.nonZero);
    final value = (_gestureStartValue + ratio).clamp(0.0, 1.0);
    final rounded = (value * 100).roundToDouble() / 100;

    if (_activeGesture == _GestureKind.brightness) {
      _currentBrightness = rounded;
      _showIndicator(_Indicator.brightness(rounded));
      unawaited(
        _ignoreErrors(
          () async => widget.brightnessController.setBrightness(rounded),
          'set-brightness',
        ),
      );
    } else {
      _currentVolume = rounded;
      _showIndicator(_Indicator.volume(rounded));
      unawaited(
        _ignoreErrors(
          () async => widget.volumeController.setVolume(rounded),
          'set-volume',
        ),
      );
    }
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    if (_activeGesture == _GestureKind.brightness ||
        _activeGesture == _GestureKind.volume) {
      _activeGesture = _GestureKind.none;
      _keepVisibleOnInteraction();
      _scheduleIndicatorDismiss();
    }
  }

  // ---- Horizontal drag (seek) ---------------------------------------------

  void _onHorizontalDragStart(DragStartDetails details) {
    if (_activeGesture != _GestureKind.none) return;
    final position = details.localPosition;
    if (_isInEdgeArea(position)) return;
    if (_state.duration <= Duration.zero) return;

    _activeGesture = _GestureKind.seek;
    _gestureStart = position;
    _gestureStartPosition = _state.position;
    _keepVisibleOnInteraction();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (_activeGesture != _GestureKind.seek) return;
    final dx = details.localPosition.dx - (_gestureStart?.dx ?? 0.0);
    final ratio = dx / (_gestureSize.width.nonZero);
    final offsetMs = ratio * widget.horizontalSeekWindow.inMilliseconds;
    final target =
        _gestureStartPosition + Duration(milliseconds: offsetMs.round());
    final clamped = _clampDuration(target, Duration.zero, _state.duration);

    _showIndicator(_Indicator.seek(clamped, clamped - _gestureStartPosition));
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (_activeGesture != _GestureKind.seek) return;
    _activeGesture = _GestureKind.none;
    _keepVisibleOnInteraction();
    final target = _indicator.whenSeekTarget ?? _state.position;
    _dismissIndicator();
    unawaited(
      _ignoreErrors(() async => widget.playback.seekTo(target), 'seek-to'),
    );
  }

  // ---- Helpers ------------------------------------------------------------

  bool _isInEdgeArea(Offset position) {
    final size = _gestureSize;
    return position.dx < widget.edgeInset ||
        position.dx > size.width - widget.edgeInset ||
        position.dy < widget.edgeInset ||
        position.dy > size.height - widget.edgeInset;
  }

  void _showIndicator(_Indicator indicator) {
    _indicatorTimer?.cancel();
    _indicatorTimer = null;
    if (mounted) {
      setState(() {
        _indicator = indicator;
      });
    }
  }

  void _dismissIndicator() {
    _indicatorTimer?.cancel();
    _indicatorTimer = null;
    if (mounted) {
      setState(() {
        _indicator = const _Indicator.none();
      });
    }
  }

  void _scheduleIndicatorDismiss() {
    _indicatorTimer?.cancel();
    _indicatorTimer = Timer(_indicatorDismissDelay, _dismissIndicator);
  }

  // ---- Build --------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _gestureSize = Size(constraints.maxWidth, constraints.maxHeight);
        return Stack(
          fit: StackFit.expand,
          children: [
            _indicatorOverlay(),
            _gestureLayer(),
            _header(),
            _bottomBar(),
          ],
        );
      },
    );
  }

  Widget _gestureLayer() {
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _onTap,
        onDoubleTap: _onDoubleTap,
        onLongPressStart: _onLongPressStart,
        onLongPressEnd: _onLongPressEnd,
        onHorizontalDragStart: _onHorizontalDragStart,
        onHorizontalDragUpdate: _onHorizontalDragUpdate,
        onHorizontalDragEnd: _onHorizontalDragEnd,
        onVerticalDragStart: _onVerticalDragStart,
        onVerticalDragUpdate: _onVerticalDragUpdate,
        onVerticalDragEnd: _onVerticalDragEnd,
        child: const SizedBox.expand(),
      ),
    );
  }

  Widget _header() {
    return ValueListenableBuilder<bool>(
      valueListenable: _visible,
      builder: (context, visible, child) {
        return ExcludeSemantics(
          excluding: !visible,
          child: IgnorePointer(
            ignoring: !visible,
            child: AnimatedOpacity(
              key: MoviePreviewControlsOverlay.headerOpacityKey,
              opacity: visible ? 1.0 : 0.0,
              duration: _opacityDuration,
              child: SafeArea(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: MoviePreviewHeader(
                    title: widget.title,
                    onBack: widget.onBack,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _bottomBar() {
    return ValueListenableBuilder<bool>(
      valueListenable: _visible,
      builder: (context, visible, child) {
        return ExcludeSemantics(
          excluding: !visible,
          child: IgnorePointer(
            ignoring: !visible,
            child: AnimatedOpacity(
              key: MoviePreviewControlsOverlay.bottomOpacityKey,
              opacity: visible ? 1.0 : 0.0,
              duration: _opacityDuration,
              child: SafeArea(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Row(
                      children: [
                        _playPauseButton(),
                        Expanded(child: _progressBar()),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: Text(
                            '${_formatDuration(_state.position)} / ${_formatDuration(_state.duration)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12.0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _progressBar() {
    final canSeek = _state.duration > Duration.zero;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapDown: canSeek
          ? (details) => _seekToProgress(details.localPosition.dx)
          : null,
      onHorizontalDragStart: canSeek
          ? (_) => _keepVisibleOnInteraction()
          : null,
      onHorizontalDragUpdate: canSeek
          ? (details) => _seekToProgress(details.localPosition.dx)
          : null,
      child: SizedBox(
        height: 36.0,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final progress = _sliderValue;
            return Stack(
              alignment: Alignment.centerLeft,
              children: [
                Container(
                  height: 2.4,
                  width: constraints.maxWidth,
                  color: Colors.white38,
                ),
                FractionallySizedBox(
                  widthFactor: progress,
                  alignment: Alignment.centerLeft,
                  child: Container(height: 2.4, color: Colors.red),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _seekToProgress(double dx) {
    _keepVisibleOnInteraction();
    if (_state.duration <= Duration.zero) return;
    final width = _gestureSize.width;
    if (width <= 0) return;
    final ratio = (dx / width).clamp(0.0, 1.0);
    final target = Duration(
      milliseconds: (ratio * _state.duration.inMilliseconds).round(),
    );
    unawaited(
      _ignoreErrors(
        () async => widget.playback.seekTo(target),
        'seek-progress',
      ),
    );
  }

  double get _sliderValue {
    final duration = _state.duration.inMilliseconds;
    if (duration <= 0) return 0.0;
    return (_state.position.inMilliseconds / duration).clamp(0.0, 1.0);
  }

  Widget _playPauseButton() {
    final isCompleted = _state.isCompleted;
    final isPlaying = _state.isPlaying && !isCompleted;
    return IconButton(
      onPressed: _togglePlayPause,
      tooltip: isCompleted ? '重新播放' : (isPlaying ? '暂停' : '播放'),
      color: Colors.white,
      icon: Icon(
        isCompleted
            ? Icons.replay
            : (isPlaying ? Icons.pause : Icons.play_arrow),
      ),
    );
  }

  Widget _indicatorOverlay() {
    return IgnorePointer(
      child: Center(
        child: AnimatedOpacity(
          key: MoviePreviewControlsOverlay.indicatorKey,
          opacity: _indicator.isVisible ? 1.0 : 0.0,
          duration: _opacityDuration,
          onEnd: () {
            if (!_indicator.isVisible && mounted) {
              setState(() {
                _indicator = const _Indicator.none();
              });
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 12.0,
            ),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: _indicator.buildWidget(),
          ),
        ),
      ),
    );
  }
}

// ---- Indicator model ------------------------------------------------------

enum _IndicatorKind { none, speedUp, brightness, volume, seek }

@immutable
class _Indicator {
  const _Indicator.none()
    : kind = _IndicatorKind.none,
      value = 0.0,
      target = null,
      offset = null;

  const _Indicator.speedUp()
    : kind = _IndicatorKind.speedUp,
      value = 0.0,
      target = null,
      offset = null;

  const _Indicator.brightness(this.value)
    : kind = _IndicatorKind.brightness,
      target = null,
      offset = null;

  const _Indicator.volume(this.value)
    : kind = _IndicatorKind.volume,
      target = null,
      offset = null;

  const _Indicator.seek(this.target, this.offset)
    : kind = _IndicatorKind.seek,
      value = 0.0;

  final _IndicatorKind kind;
  final double value;
  final Duration? target;
  final Duration? offset;

  bool get isVisible => kind != _IndicatorKind.none;

  Duration? get whenSeekTarget => target;

  Widget buildWidget() {
    switch (kind) {
      case _IndicatorKind.none:
        return const SizedBox.shrink();
      case _IndicatorKind.speedUp:
        return _indicatorRow(Icons.fast_forward, '2x 倍速');
      case _IndicatorKind.brightness:
        return _indicatorRow(
          Icons.brightness_medium,
          '${(value * 100).round()}%',
        );
      case _IndicatorKind.volume:
        return _indicatorRow(Icons.volume_up, '${(value * 100).round()}%');
      case _IndicatorKind.seek:
        final off = offset ?? Duration.zero;
        final sign = off.isNegative ? '' : '+';
        return _indicatorRow(
          off.isNegative ? Icons.replay : Icons.forward,
          '${_formatDuration(target ?? Duration.zero)}\n$sign${_formatDuration(off.abs())}',
        );
    }
  }
}

Widget _indicatorRow(IconData icon, String text) {
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, color: Colors.white, size: 32.0),
      const SizedBox(height: 8.0),
      Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white, fontSize: 14.0),
      ),
    ],
  );
}

// ---- Gesture kind ---------------------------------------------------------

enum _GestureKind { none, speedUp, brightness, volume, seek }

// ---- Utilities ------------------------------------------------------------

String _formatDuration(Duration duration) {
  final totalSeconds = duration.inSeconds.abs();
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  final formatted =
      '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  return duration.isNegative ? '-$formatted' : formatted;
}

Duration _clampDuration(Duration value, Duration min, Duration max) {
  if (value < min) return min;
  if (value > max) return max;
  return value;
}

Future<void> _ignoreErrors(Future<void> Function() action, String stage) async {
  try {
    await action();
  } catch (error, stackTrace) {
    _logIgnored(stage, error, stackTrace);
  }
}

Future<T?> _withResult<T>(Future<T> Function() action, String stage) async {
  try {
    return await action();
  } catch (error, stackTrace) {
    _logIgnored(stage, error, stackTrace);
    return null;
  }
}

void _logIgnored(String stage, Object error, StackTrace stackTrace) {
  debugPrint('movie_preview_controls $stage failed: $error\n$stackTrace');
}

extension on double {
  double get nonZero => this == 0.0 ? 1.0 : this;
}
