import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:jade/features/movie_detail/services/movie_preview_playback.dart';
import 'package:jade/features/movie_detail/widgets/movie_preview_header.dart';

/// 播放态页面头部：进入“播放中且非缓冲”状态 3 秒后隐藏，
/// 暂停/缓冲/完成/错误时立即显示。
class MoviePreviewHeaderOverlay extends StatefulWidget {
  const MoviePreviewHeaderOverlay({
    super.key,
    required this.title,
    required this.onBack,
    required this.state,
    this.hideDelay = const Duration(seconds: 3),
  });

  static const headerOpacityKey = Key('movie-preview-header-opacity');
  static const _opacityDuration = Duration(milliseconds: 250);

  final String title;
  final VoidCallback onBack;
  final ValueListenable<MoviePreviewPlaybackState> state;
  final Duration hideDelay;

  @override
  State<MoviePreviewHeaderOverlay> createState() =>
      _MoviePreviewHeaderOverlayState();
}

class _MoviePreviewHeaderOverlayState extends State<MoviePreviewHeaderOverlay> {
  final _hidden = ValueNotifier<bool>(false);
  Timer? _hideTimer;
  bool _wasHideEligible = false;

  @override
  void initState() {
    super.initState();
    widget.state.addListener(_onStateChanged);
    _onStateChanged();
  }

  @override
  void dispose() {
    widget.state.removeListener(_onStateChanged);
    _hideTimer?.cancel();
    _hidden.dispose();
    super.dispose();
  }

  void _onStateChanged() {
    final value = widget.state.value;
    final hasError = value.errorDescription != null && value.errorDescription!.isNotEmpty;
    final hideEligible =
        value.isPlaying && !value.isBuffering && !value.isCompleted && !hasError;
    if (hideEligible && !_wasHideEligible) {
      if (_hidden.value) {
        _hidden.value = false;
      }
      _hideTimer?.cancel();
      _hideTimer = Timer(widget.hideDelay, () {
        _hideTimer = null;
        if (mounted) {
          _hidden.value = true;
        }
      });
    } else if (!hideEligible && _wasHideEligible) {
      _hideTimer?.cancel();
      _hideTimer = null;
      if (_hidden.value) {
        _hidden.value = false;
      }
    }
    _wasHideEligible = hideEligible;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _hidden,
      builder: (context, hidden, child) {
        return ExcludeSemantics(
          excluding: hidden,
          child: IgnorePointer(
            ignoring: hidden,
            child: AnimatedOpacity(
              key: MoviePreviewHeaderOverlay.headerOpacityKey,
              opacity: hidden ? 0.0 : 1.0,
              duration: MoviePreviewHeaderOverlay._opacityDuration,
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
}
