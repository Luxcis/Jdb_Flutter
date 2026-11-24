import 'package:flutter/material.dart';
import 'package:jade/core/widgets/selectable_copy_search_text.dart';

/// 评论内容：超过 5 行自动截断，提供展开/收起控制；正文支持长按选择、复制与搜索。
class ExpandableReviewContent extends StatefulWidget {
  const ExpandableReviewContent({
    super.key,
    required this.text,
    required this.style,
  });

  static const maxLines = 5;

  final String text;
  final TextStyle? style;

  @override
  State<ExpandableReviewContent> createState() =>
      _ExpandableReviewContentState();
}

class _ExpandableReviewContentState extends State<ExpandableReviewContent> {
  bool _expanded = false;

  String? _visiblePrefixCache;
  String? _visiblePrefixText;
  double? _visiblePrefixWidth;

  /// 折叠态下省略号之前的可见文本前缀（按文本与宽度缓存）。
  String _visiblePrefix(
    double maxWidth,
    TextDirection textDirection,
    TextScaler textScaler,
  ) {
    if (_visiblePrefixCache != null &&
        _visiblePrefixText == widget.text &&
        _visiblePrefixWidth == maxWidth) {
      return _visiblePrefixCache!;
    }
    final prefix = visiblePrefixOf(
      text: widget.text,
      style: widget.style,
      maxLines: ExpandableReviewContent.maxLines,
      maxWidth: maxWidth,
      textDirection: textDirection,
      textScaler: textScaler,
    );
    _visiblePrefixCache = prefix;
    _visiblePrefixText = widget.text;
    _visiblePrefixWidth = maxWidth;
    return prefix;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final textScaler = MediaQuery.textScalerOf(context);
        final textPainter = TextPainter(
          text: TextSpan(text: widget.text, style: widget.style),
          maxLines: ExpandableReviewContent.maxLines,
          textDirection: Directionality.of(context),
          textScaler: textScaler,
        )..layout(maxWidth: constraints.maxWidth);
        final textExceedsMaxLines = textPainter.didExceedMaxLines;
        textPainter.dispose();
        if (!textExceedsMaxLines) {
          return SelectableCopySearchText(
            text: widget.text,
            style: widget.style,
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableCopySearchText(
              text: widget.text,
              style: widget.style,
              maxLines: _expanded ? null : ExpandableReviewContent.maxLines,
              visiblePrefix: _expanded
                  ? null
                  : _visiblePrefix(
                      constraints.maxWidth,
                      Directionality.of(context),
                      textScaler,
                    ),
              onTap: () => setState(() => _expanded = !_expanded),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                key: Key(_expanded ? 'review-collapse' : 'review-expand'),
                onPressed: () => setState(() => _expanded = !_expanded),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 32),
                  visualDensity: VisualDensity.compact,
                  textStyle: Theme.of(context).textTheme.bodySmall,
                ),
                child: Text(_expanded ? '收起' : '展开'),
              ),
            ),
          ],
        );
      },
    );
  }
}
