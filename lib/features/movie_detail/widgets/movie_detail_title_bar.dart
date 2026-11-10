import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 影片详情页顶部可折叠标题栏。
///
/// 作为详情页 [NestedScrollView] 滚动头部的第一个 sliver：
/// - 页面处于顶部时按标题实际行数展开，多行展示完整标题；
/// - 用户向下滚动后立即收拢为单行并以省略号隐藏超出部分，高度随滚动连续收缩；
/// - 收起后固定在页面顶部（pinned），TabBar 固定在其下方。
class MovieDetailTitleBar extends StatelessWidget {
  const MovieDetailTitleBar({super.key, required this.title});

  final String title;

  /// 标题左侧内边距：返回按钮宽 56，加上与原 AppBar 标题间距一致的 16。
  static const double _leadingPadding = 72;
  static const double _trailingPadding = 16;

  /// 标题底部留白，使单行标题在 toolbar 内垂直居中。
  static const double _bottomPadding = 14;

  /// 多行标题相对状态栏的顶部留白。
  static const double _topGap = 8;

  /// 展开态高度占屏幕可用高度的最大比例，避免极端超长标题占满屏幕。
  static const double _maxHeightFactor = 0.4;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = (theme.textTheme.titleLarge ?? const TextStyle(fontSize: 22))
        .copyWith(
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.onSurface,
        );
    final layout = _TitleLayout.measure(
      context: context,
      title: title,
      style: style,
    );
    return SliverAppBar(
      key: const Key('movie-detail-title-bar'),
      pinned: true,
      backgroundColor: theme.colorScheme.surface,
      toolbarHeight: layout.collapsedHeight,
      expandedHeight: layout.expandedHeight,
      flexibleSpace: _CollapsingTitle(
        title: title,
        style: style,
        expandedMaxLines: layout.expandedMaxLines,
      ),
    );
  }
}

/// 标题在展开/收起两种形态下的布局结果。
class _TitleLayout {
  const _TitleLayout({
    required this.collapsedHeight,
    required this.expandedHeight,
    required this.expandedMaxLines,
  });

  /// 收起态高度，不含状态栏内边距；大字号下自动加高，避免单行标题被裁剪。
  final double collapsedHeight;

  /// 展开态高度，不含状态栏内边距。
  final double expandedHeight;

  /// 展开态允许显示的最大行数；常规标题等于实际行数，极端超长标题按高度上限截断。
  final int expandedMaxLines;

  static _TitleLayout measure({
    required BuildContext context,
    required String title,
    required TextStyle style,
  }) {
    final mediaQuery = MediaQuery.of(context);
    final maxWidth = math.max(
      0.0,
      mediaQuery.size.width -
          MovieDetailTitleBar._leadingPadding -
          MovieDetailTitleBar._trailingPadding,
    );
    final painter = TextPainter(
      text: TextSpan(text: title, style: style),
      textDirection: Directionality.of(context),
      textScaler: mediaQuery.textScaler,
    )..layout(maxWidth: maxWidth);
    final metrics = painter.computeLineMetrics();
    final lineCount = metrics.length;
    final textHeight = painter.height;
    final lineHeight = lineCount > 0 ? textHeight / lineCount : 0.0;
    painter.dispose();
    // 空标题没有可测量的行高，退化为标准单行标题栏。
    if (lineCount == 0 || textHeight <= 0 || lineHeight <= 0) {
      return const _TitleLayout(
        collapsedHeight: kToolbarHeight,
        expandedHeight: kToolbarHeight,
        expandedMaxLines: 1,
      );
    }

    // 收起态按实际单行高度计算，随系统字号放大自动加高，避免标题被垂直裁剪。
    final collapsedHeight = math.max(
      kToolbarHeight,
      lineHeight +
          MovieDetailTitleBar._topGap +
          MovieDetailTitleBar._bottomPadding,
    );

    // 展开态不超过屏幕可用高度的一定比例；同时保证不低于收起态高度。
    final availableHeight =
        (mediaQuery.size.height - mediaQuery.padding.top) *
        MovieDetailTitleBar._maxHeightFactor;
    final preferredHeight =
        textHeight +
        MovieDetailTitleBar._bottomPadding +
        MovieDetailTitleBar._topGap;
    final expandedHeight = math.max(
      collapsedHeight,
      math.min(preferredHeight, math.max(collapsedHeight, availableHeight)),
    );

    // 极端超长标题按可容纳行数截断；常规标题保留全部行数。
    final capacity =
        (expandedHeight -
            MovieDetailTitleBar._bottomPadding -
            MovieDetailTitleBar._topGap) /
        lineHeight;
    final maxLines = math.max(1, capacity.floor());
    return _TitleLayout(
      collapsedHeight: collapsedHeight,
      expandedHeight: expandedHeight,
      expandedMaxLines: math.min(lineCount, maxLines),
    );
  }
}

/// 标题本体：根据 [FlexibleSpaceBarSettings] 的当前高度切换多行/单行形态。
///
/// 折叠高度由 [SliverAppBar] 随滚动距离直接驱动，因此滚动一开始标题即切为单行，
/// 高度连续收缩到 toolbar 高度后固定在顶部。
class _CollapsingTitle extends StatelessWidget {
  const _CollapsingTitle({
    required this.title,
    required this.style,
    required this.expandedMaxLines,
  });

  final String title;
  final TextStyle style;
  final int expandedMaxLines;

  @override
  Widget build(BuildContext context) {
    final settings = context
        .dependOnInheritedWidgetOfExactType<FlexibleSpaceBarSettings>();
    final collapsed =
        settings != null && settings.currentExtent < settings.maxExtent - 0.5;
    return Padding(
      padding: const EdgeInsets.only(
        left: MovieDetailTitleBar._leadingPadding,
        right: MovieDetailTitleBar._trailingPadding,
        bottom: MovieDetailTitleBar._bottomPadding,
      ),
      child: Align(
        alignment: Alignment.bottomLeft,
        child: Text(
          title,
          key: const Key('movie-detail-title-text'),
          maxLines: collapsed ? 1 : expandedMaxLines,
          overflow: TextOverflow.ellipsis,
          style: style,
        ),
      ),
    );
  }
}
