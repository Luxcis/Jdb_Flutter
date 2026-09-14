import 'package:flutter/gestures.dart' show computeHitSlop, kPrimaryButton;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

/// 评论内容：超过 5 行自动截断，提供展开/收起控制；正文支持长按选择与复制。
class ExpandableReviewContent extends StatefulWidget {
  const ExpandableReviewContent({super.key, required this.text, required this.style});

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
    final prefix = _visiblePrefixOf(
      widget.text,
      widget.style,
      ExpandableReviewContent.maxLines,
      maxWidth,
      textDirection,
      textScaler,
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
          return ReviewSelectableText(text: widget.text, style: widget.style);
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ReviewSelectableText(
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

const String _ellipsis = '…';

/// 计算折叠态下省略号之前的可见文本前缀。
///
/// 与渲染截断点保持一致：可见正文是“追加省略号后仍能在 [maxLines] 行内完成排版的
/// 最长前缀”。按字素二分探测，避免把代理对等字素截断到一半；测量与渲染使用同一
/// [textScaler]，保证系统字体缩放下截断点一致。
String _visiblePrefixOf(
  String text,
  TextStyle? style,
  int maxLines,
  double maxWidth,
  TextDirection textDirection,
  TextScaler textScaler,
) {
  final graphemes = text.characters.toList();
  bool fitsWithEllipsis(int count) {
    final painter = TextPainter(
      text: TextSpan(
        text: graphemes.take(count).join() + _ellipsis,
        style: style,
      ),
      maxLines: maxLines,
      textDirection: textDirection,
      textScaler: textScaler,
    )..layout(maxWidth: maxWidth);
    final fits = !painter.didExceedMaxLines;
    painter.dispose();
    return fits;
  }

  var low = 0;
  var high = graphemes.length;
  while (low < high) {
    final mid = (low + high + 1) ~/ 2;
    if (fitsWithEllipsis(mid)) {
      low = mid;
    } else {
      high = mid - 1;
    }
  }
  return graphemes.take(low).join();
}

/// 可选择正文：长按进入选择态并展示中文操作菜单，未选中时点击触发 [onTap]。
class ReviewSelectableText extends StatefulWidget {
  const ReviewSelectableText({
    super.key,
    required this.text,
    this.style,
    this.maxLines,
    this.visiblePrefix,
    this.onTap,
  });

  final String text;
  final TextStyle? style;

  /// 折叠行数；null 表示正文完整可见。
  final int? maxLines;

  /// 折叠态下省略号之前的可见文本前缀；正文完整可见时为 null。
  final String? visiblePrefix;

  /// 未选中文字时点击正文的回调；null 表示点击无附加行为。
  final VoidCallback? onTap;

  @override
  State<ReviewSelectableText> createState() => _ReviewSelectableTextState();
}

class _ReviewSelectableTextState extends State<ReviewSelectableText> {
  bool _hasSelection = false;
  String _selectedText = '';
  Offset _pointerDownPosition = Offset.zero;
  int _pointerDownButtons = 0;

  @override
  void didUpdateWidget(ReviewSelectableText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _hasSelection = false;
      _selectedText = '';
    }
  }

  /// 复制当前所选文本；折叠态下选区可能覆盖省略号之后的隐藏文本，仅保留可见前缀。
  void _copySelection() {
    var text = _selectedText;
    final visiblePrefix = widget.visiblePrefix;
    if (visiblePrefix != null && text.length > visiblePrefix.length) {
      text = visiblePrefix;
    }
    if (text.isEmpty) return;
    Clipboard.setData(ClipboardData(text: text));
  }

  void _handlePointerUp(PointerUpEvent event) {
    final onTap = widget.onTap;
    if (onTap == null || _hasSelection) return;
    // 主键与位移判定基于按下事件：抬起事件 buttons 恒为 0。
    if (_pointerDownButtons != kPrimaryButton) return;
    if ((event.localPosition - _pointerDownPosition).distance >
        computeHitSlop(event.kind, null)) {
      return;
    }
    onTap();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (event) {
        _pointerDownPosition = event.localPosition;
        _pointerDownButtons = event.buttons;
      },
      onPointerUp: _handlePointerUp,
      child: SelectionArea(
        onSelectionChanged: (content) {
          _hasSelection = content != null && content.plainText.isNotEmpty;
          _selectedText = content?.plainText ?? '';
        },
        contextMenuBuilder: (context, selectableRegionState) {
          return AdaptiveTextSelectionToolbar.buttonItems(
            anchors: selectableRegionState.contextMenuAnchors,
            buttonItems: [
              ContextMenuButtonItem(
                label: '复制',
                onPressed: () {
                  _copySelection();
                  selectableRegionState.hideToolbar(false);
                },
              ),
              ContextMenuButtonItem(
                label: '全选',
                onPressed: () => selectableRegionState.selectAll(
                  SelectionChangedCause.toolbar,
                ),
              ),
            ],
          );
        },
        child: Text(
          widget.text,
          style: widget.style,
          maxLines: widget.maxLines,
          overflow: widget.maxLines == null ? null : TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
