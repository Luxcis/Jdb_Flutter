import 'package:flutter/material.dart';
import 'package:jade/core/models/review.dart';

/// Renders the review-state actions shown on a movie detail page.
class MovieReviewActions extends StatelessWidget {
  /// Creates the action group for [review].
  const MovieReviewActions({
    super.key,
    required this.review,
    required this.loading,
    required this.onWantWatch,
    required this.onWatched,
    required this.onDelete,
    required this.onSaveToList,
  });

  /// The current review state, or null when the movie is unmarked.
  final Review? review;

  /// Whether a review-state request is currently in progress.
  final bool loading;

  /// Called when the movie is marked as wanted.
  final VoidCallback onWantWatch;

  /// Called when the movie is marked as watched.
  final VoidCallback onWatched;

  /// Called when the current review state is removed.
  final VoidCallback onDelete;

  /// Called when the movie is saved to a list.
  final VoidCallback onSaveToList;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final actionStyle = FilledButton.styleFrom(
      minimumSize: const Size(0, 32),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      visualDensity: VisualDensity.compact,
      textStyle: Theme.of(context).textTheme.labelMedium,
    );
    final deleteStyle = FilledButton.styleFrom(
      minimumSize: const Size(0, 32),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      visualDensity: VisualDensity.compact,
      textStyle: Theme.of(context).textTheme.labelMedium,
      backgroundColor: colorScheme.error,
      foregroundColor: colorScheme.onError,
    );
    final status = review?.status;
    final buttons = <Widget>[];

    if (status == 'want_watch') {
      buttons.add(
        _ReviewActionButton(
          buttonKey: const Key('movie-delete-want-watch-button'),
          label: '删除想看',
          onPressed: loading ? null : onDelete,
          style: deleteStyle,
        ),
      );
      buttons.add(
        _ReviewActionButton(
          buttonKey: const Key('movie-watched-button'),
          label: '看过',
          onPressed: loading ? null : onWatched,
          style: actionStyle,
        ),
      );
    } else if (status == 'watched') {
      buttons.add(
        _ReviewActionButton(
          buttonKey: const Key('movie-delete-watched-button'),
          label: '删除看过',
          onPressed: loading ? null : onDelete,
          style: deleteStyle,
        ),
      );
    } else {
      buttons.add(
        _ReviewActionButton(
          buttonKey: const Key('movie-want-watch-button'),
          label: '想看',
          onPressed: loading ? null : onWantWatch,
          style: actionStyle,
        ),
      );
      buttons.add(
        _ReviewActionButton(
          buttonKey: const Key('movie-watched-button'),
          label: '看过',
          onPressed: loading ? null : onWatched,
          style: actionStyle,
        ),
      );
    }

    buttons.add(
      _ReviewActionButton(
        buttonKey: const Key('movie-save-to-list-button'),
        label: '存入清单',
        onPressed: onSaveToList,
        style: actionStyle,
      ),
    );

    return Wrap(spacing: 8, runSpacing: 6, children: buttons);
  }
}

class _ReviewActionButton extends StatelessWidget {
  const _ReviewActionButton({
    required Key buttonKey,
    required String label,
    required VoidCallback? onPressed,
    required ButtonStyle style,
  }) : _buttonKey = buttonKey,
       _label = label,
       _onPressed = onPressed,
       _style = style;

  final Key _buttonKey;
  final String _label;
  final VoidCallback? _onPressed;
  final ButtonStyle _style;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      key: _buttonKey,
      style: _style,
      onPressed: _onPressed,
      child: Text(_label),
    );
  }
}
