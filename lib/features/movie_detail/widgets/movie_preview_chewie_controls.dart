import 'package:chewie/chewie.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:jade/features/movie_detail/widgets/movie_preview_header.dart';

@visibleForTesting
bool moviePreviewHeaderIsHidden(ChewieState? chewieState) {
  return chewieState?.notifier.hideStuff ?? false;
}

class MoviePreviewChewieControls extends StatelessWidget {
  const MoviePreviewChewieControls({
    super.key,
    required this.title,
    required this.onBack,
  });

  static const headerOpacityKey = Key('movie-preview-header-opacity');
  static const _opacityDuration = Duration(milliseconds: 250);

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final chewieState = context.findAncestorStateOfType<ChewieState>();
    final notifier = chewieState?.notifier;
    return Stack(
      fit: StackFit.expand,
      children: [
        const MaterialControls(),
        if (notifier == null)
          _buildHeader(hidden: false)
        else
          AnimatedBuilder(
            animation: notifier,
            builder: (context, child) {
              return _buildHeader(
                hidden: moviePreviewHeaderIsHidden(chewieState),
              );
            },
          ),
      ],
    );
  }

  Widget _buildHeader({required bool hidden}) {
    return ExcludeSemantics(
      excluding: hidden,
      child: IgnorePointer(
        ignoring: hidden,
        child: AnimatedOpacity(
          key: headerOpacityKey,
          opacity: hidden ? 0.0 : 1.0,
          duration: _opacityDuration,
          child: SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: MoviePreviewHeader(title: title, onBack: onBack),
            ),
          ),
        ),
      ),
    );
  }
}
