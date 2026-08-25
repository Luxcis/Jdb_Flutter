import 'package:flutter/material.dart';
import 'package:jade/core/widgets/error_retry_widget.dart';

/// 影片详情页各内容分区的基础容器：标题（可带尾部文字）+ 固定高度内容区。
class MovieSection extends StatelessWidget {
  const MovieSection({
    super.key,
    required this.title,
    required this.height,
    required this.child,
    this.titleTrailing,
  });

  final String title;
  final double height;
  final Widget child;
  final String? titleTrailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 10,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                if (titleTrailing != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    titleTrailing!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(height: height, child: child),
        ],
      ),
    );
  }
}

/// 详情页各 Tab 列表之间的分隔线。
Widget detailTabDivider(BuildContext context) {
  return Divider(
    height: 1,
    indent: 16,
    endIndent: 16,
    color: Theme.of(context).colorScheme.outlineVariant,
  );
}

/// 可滚动容器内的加载失败提示（包裹 [ErrorRetryWidget]，避免溢出）。
class ScrollableTabError extends StatelessWidget {
  const ScrollableTabError({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: ErrorRetryWidget(message: message, onRetry: onRetry),
        ),
      ),
    );
  }
}
