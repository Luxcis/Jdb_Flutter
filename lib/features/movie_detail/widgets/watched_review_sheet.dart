import 'package:flutter/material.dart';

import '../../../core/widgets/star_rating.dart';

/// Submits a watched review with its selected score and trimmed content.
typedef WatchedReviewSubmit =
    Future<void> Function({required int score, required String content});

/// Collects a five-star score and an optional-length, non-blank review.
class WatchedReviewSheet extends StatefulWidget {
  /// Creates a watched-review form.
  const WatchedReviewSheet({super.key, required this.onSubmit});

  /// Called after the form has a valid score and non-blank content.
  final WatchedReviewSubmit onSubmit;

  @override
  State<WatchedReviewSheet> createState() => _WatchedReviewSheetState();
}

class _WatchedReviewSheetState extends State<WatchedReviewSheet> {
  final _contentController = TextEditingController();
  int _score = 0;
  bool _submitting = false;
  String? _error;

  bool get _canSubmit {
    return !_submitting &&
        _score >= 1 &&
        _score <= 5 &&
        _contentController.text.trim().isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 12,
          children: [
            Text('标记为看过', style: Theme.of(context).textTheme.titleLarge),
            const Text('评分'),
            StarRating(
              key: const Key('watched-review-rating'),
              score: _score.toDouble(),
              size: 32,
              enabled: !_submitting,
              onChanged: (value) => setState(() {
                _score = value;
                _error = null;
              }),
            ),
            TextField(
              key: const Key('watched-review-content-field'),
              controller: _contentController,
              enabled: !_submitting,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(labelText: '评论内容'),
              onChanged: (_) => setState(() => _error = null),
            ),
            if (_error != null)
              Text(
                _error!,
                key: const Key('watched-review-error'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              spacing: 8,
              children: [
                TextButton(
                  key: const Key('watched-review-cancel-button'),
                  onPressed: _submitting ? null : () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
                FilledButton(
                  key: const Key('watched-review-submit-button'),
                  onPressed: _canSubmit ? _submit : null,
                  child: Text(_submitting ? '提交中' : '提交'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.onSubmit(
        score: _score,
        content: _contentController.text.trim(),
      );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = '操作失败，请重试';
      });
    }
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }
}
