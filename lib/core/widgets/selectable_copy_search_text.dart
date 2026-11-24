import 'package:flutter/gestures.dart' show computeHitSlop, kPrimaryButton;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:go_router/go_router.dart';
import 'package:jade/router/routes.dart';

const String _ellipsis = '…';

/// 可选择文本：长按进入选择态并展示中文操作菜单（复制、搜索、全选），
/// 未选中时点击触发 [onTap]。
///
/// 评论正文与影片详情页标题共用本组件，保证菜单项、关键词规范化与
/// 可见前缀截断规则一致。
class SelectableCopySearchText extends StatefulWidget {
  const SelectableCopySearchText({
    super.key,
    required this.text,
    this.style,
    this.maxLines,
    this.visiblePrefix,
    this.onTap,
  });

  final String text;
  final TextStyle? style;

  /// 折叠行数；null 表示文本完整可见。
  final int? maxLines;

  /// 折叠态下省略号之前的可见文本前缀；文本完整可见时为 null。
  final String? visiblePrefix;

  /// 未选中文字时点击文本的回调；null 表示点击无附加行为。
  final VoidCallback? onTap;

  @override
  State<SelectableCopySearchText> createState() =>
      _SelectableCopySearchTextState();
}

class _SelectableCopySearchTextState extends State<SelectableCopySearchText> {
  bool _hasSelection = false;
  String _selectedText = '';
  Offset _pointerDownPosition = Offset.zero;
  int _pointerDownButtons = 0;

  @override
  void didUpdateWidget(SelectableCopySearchText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _hasSelection = false;
      _selectedText = '';
    }
  }

  /// 当前选区对应的可见文本。
  ///
  /// 折叠态下选区可能覆盖省略号之后的隐藏文本，而 [SelectedContent] 只提供纯文本、
  /// 不含选区位置：若选区不是可见前缀的子串，说明它越过了省略号，退化为可见前缀。
  String _visibleSelectionText() {
    final selected = _selectedText;
    final visiblePrefix = widget.visiblePrefix;
    if (visiblePrefix == null || visiblePrefix.contains(selected)) {
      return selected;
    }
    return visiblePrefix;
  }

  /// 复制当前所选可见文本。
  void _copySelection() {
    final text = _visibleSelectionText();
    if (text.isEmpty) return;
    Clipboard.setData(ClipboardData(text: text));
  }

  /// 搜索当前所选文本：去除首尾空白并把内部换行/连续空白折叠为单个空格。
  void _searchSelection(BuildContext context) {
    final keyword = _visibleSelectionText()
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (keyword.isEmpty) return;
    context.push(
      Uri(
        path: AppRoutes.searchResults,
        queryParameters: {'q': keyword},
      ).toString(),
    );
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
                label: '搜索',
                onPressed: () {
                  selectableRegionState.hideToolbar(false);
                  _searchSelection(context);
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

/// 计算折叠态下省略号之前的可见文本前缀。
///
/// 与渲染截断点保持一致：可见文本是“追加省略号后仍能在 [maxLines] 行内完成排版的
/// 最长前缀”。按字素二分探测，避免把代理对等字素截断到一半；测量与渲染使用同一
/// [textScaler]，保证系统字体缩放下截断点一致。
String visiblePrefixOf({
  required String text,
  required TextStyle? style,
  required int maxLines,
  required double maxWidth,
  required TextDirection textDirection,
  required TextScaler textScaler,
}) {
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
