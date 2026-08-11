import 'dart:async';

import 'package:flutter/material.dart';

class MoviePreviewGestureLayer extends StatefulWidget {
  const MoviePreviewGestureLayer({
    super.key,
    required this.child,
    required this.onTogglePlayback,
    required this.onSetPlaybackSpeed,
    required this.onSpeedRecoveryFailure,
  });

  final Widget child;
  final Future<void> Function() onTogglePlayback;
  final Future<void> Function(double speed) onSetPlaybackSpeed;
  final Future<void> Function() onSpeedRecoveryFailure;

  @override
  State<MoviePreviewGestureLayer> createState() =>
      _MoviePreviewGestureLayerState();
}

class _MoviePreviewGestureLayerState extends State<MoviePreviewGestureLayer> {
  bool _isLongPressing = false;
  bool _isDoubleSpeedConfirmed = false;
  Future<void> _speedTransitions = Future<void>.value();
  int _speedGestureGeneration = 0;
  final _queuedSpeedRestores = <int>{};

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          key: const Key('movie-preview-gesture-surface'),
          behavior: HitTestBehavior.opaque,
          onDoubleTap: () => unawaited(_togglePlayback()),
          onLongPress: _startLongPress,
          onLongPressEnd: (_) => _finishLongPress(),
          onLongPressCancel: _finishLongPress,
          child: widget.child,
        ),
        if (_isDoubleSpeedConfirmed)
          const Center(child: _MoviePreviewSpeedIndicator()),
      ],
    );
  }

  Future<void> _togglePlayback() async {
    try {
      await widget.onTogglePlayback();
    } catch (_) {}
  }

  void _startLongPress() {
    if (_isLongPressing) return;
    final generation = ++_speedGestureGeneration;
    setState(() {
      _isLongPressing = true;
      _isDoubleSpeedConfirmed = false;
    });
    _enqueueSpeedTransition(() async {
      try {
        await widget.onSetPlaybackSpeed(2.0);
      } catch (_) {
        return;
      }
      if (!mounted ||
          generation != _speedGestureGeneration ||
          !_isLongPressing) {
        return;
      }
      setState(() {
        _isDoubleSpeedConfirmed = true;
      });
    });
  }

  void _finishLongPress() {
    if (!_isLongPressing) return;
    final generation = _speedGestureGeneration;
    setState(() {
      _isLongPressing = false;
    });
    _queueDefaultSpeedRestore(generation);
  }

  void _queueDefaultSpeedRestore(int generation) {
    if (!_queuedSpeedRestores.add(generation)) return;
    _enqueueSpeedTransition(() async {
      try {
        await widget.onSetPlaybackSpeed(1.0);
        if (!mounted || generation != _speedGestureGeneration) return;
        setState(() {
          _isDoubleSpeedConfirmed = false;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _speedGestureGeneration++;
          _isLongPressing = false;
          _isDoubleSpeedConfirmed = false;
        });
        try {
          await widget.onSpeedRecoveryFailure();
        } catch (_) {}
      } finally {
        _queuedSpeedRestores.remove(generation);
      }
    });
  }

  void _enqueueSpeedTransition(Future<void> Function() transition) {
    final result = _speedTransitions.then((_) => transition());
    _speedTransitions = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    unawaited(_speedTransitions);
  }

  @override
  void dispose() {
    if (_isLongPressing || _isDoubleSpeedConfirmed) {
      _isLongPressing = false;
      _queueDefaultSpeedRestore(_speedGestureGeneration);
    }
    super.dispose();
  }
}

class _MoviePreviewSpeedIndicator extends StatelessWidget {
  const _MoviePreviewSpeedIndicator();

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
