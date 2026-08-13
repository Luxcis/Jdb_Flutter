import 'package:flutter/material.dart';

/// 可注入的时钟函数，返回当前 [DateTime]，用于测试控制双击判定时间。
typedef MoviePreviewClock = DateTime Function();

/// 页面级原始事件双击检测。
///
/// [Listener] 不参与手势竞技场，因此不会影响子树内的手势识别（如
/// media_kit 内置控制层的单击、长按与拖动）；只在指针按下事件序列满足
/// 双击条件时触发 [onDoubleTap]。
class MoviePreviewDoubleTapDetector extends StatefulWidget {
  const MoviePreviewDoubleTapDetector({
    super.key,
    required this.child,
    required this.onDoubleTap,
    this.doubleTapWindow = const Duration(milliseconds: 300),
    this.doubleTapSlop = 100.0,
    this.clock = DateTime.now,
  });

  /// 被包裹的子组件，双击检测不改变其手势语义。
  final Widget child;

  /// 双击命中时触发的回调。
  final VoidCallback onDoubleTap;

  /// 判定双击的两次按下时间窗上限。
  final Duration doubleTapWindow;

  /// 判定双击的两次按下位置最大容差（逻辑像素）。
  final double doubleTapSlop;

  /// 可注入时钟；默认取系统当前时间。
  final MoviePreviewClock clock;

  @override
  State<MoviePreviewDoubleTapDetector> createState() =>
      _MoviePreviewDoubleTapDetectorState();
}

class _MoviePreviewDoubleTapDetectorState
    extends State<MoviePreviewDoubleTapDetector> {
  final _activePointers = <int>{};
  DateTime? _lastTapDownAt;
  Offset? _lastTapDownPosition;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _handlePointerDown,
      onPointerUp: _handlePointerUp,
      onPointerCancel: _handlePointerCancel,
      child: widget.child,
    );
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (_activePointers.isNotEmpty) {
      _lastTapDownAt = null;
      _lastTapDownPosition = null;
      _activePointers.add(event.pointer);
      return;
    }
    _activePointers.add(event.pointer);

    final now = widget.clock();
    final lastAt = _lastTapDownAt;
    final lastPosition = _lastTapDownPosition;
    if (lastAt != null &&
        lastPosition != null &&
        now.difference(lastAt) <= widget.doubleTapWindow &&
        (event.position - lastPosition).distance <= widget.doubleTapSlop) {
      _lastTapDownAt = null;
      _lastTapDownPosition = null;
      widget.onDoubleTap();
    } else {
      _lastTapDownAt = now;
      _lastTapDownPosition = event.position;
    }
  }

  void _handlePointerUp(PointerUpEvent event) {
    _activePointers.remove(event.pointer);
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    _activePointers.remove(event.pointer);
  }
}
