import 'package:flutter/material.dart';
import 'package:jade/core/models/actor.dart';
import 'package:jade/core/widgets/actor_card.dart';
import 'package:jade/core/widgets/empty_state.dart';
import 'package:jade/core/widgets/error_retry_widget.dart';
import 'package:jade/core/widgets/pagination_controller.dart';

class ActorGridView extends StatelessWidget {
  const ActorGridView({
    super.key,
    required this.controller,
    this.onActorTap,
    this.selectionMode = false,
    this.selectedIds = const {},
    this.onToggleSelect,
    this.emptyMessage,
  });

  /// 演员网格统一起来自宽度的布局推导：列数 3–6（每列目标宽约 120）、
  /// 左右 content padding 16、卡距 12。fullWidth 为 LayoutBuilder 的总可用宽。
  static ({int crossAxisCount, double crossAxisSpacing, double tileWidth})
  metricsForWidth(double fullWidth) {
    final crossAxisCount = (fullWidth / 120).floor().clamp(3, 6);
    const crossAxisSpacing = 12.0;
    const horizontalPadding = 16.0;
    final tileWidth =
        (fullWidth -
            horizontalPadding * 2 -
            crossAxisSpacing * (crossAxisCount - 1)) /
        crossAxisCount;
    return (
      crossAxisCount: crossAxisCount,
      crossAxisSpacing: crossAxisSpacing,
      tileWidth: tileWidth,
    );
  }

  /// 与 metricsForWidth 配对的网格常量：两侧 content padding、卡距、卡间主轴距。
  static const horizontalPadding = 16.0;
  static const crossAxisSpacing = 12.0;
  static const mainAxisSpacing = 12.0;

  final PaginationController<ActorSummary> controller;
  final void Function(ActorSummary)? onActorTap;

  /// When true, tapping an item toggles selection instead of opening details.
  final bool selectionMode;
  final Set<String> selectedIds;
  final void Function(ActorSummary)? onToggleSelect;

  /// 列表为空时的提示文案；为 null 时不显示空态（保持原空白网格行为）。
  final String? emptyMessage;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (controller.error != null && controller.items.isEmpty) {
          return ErrorRetryWidget(
            message: controller.error.toString(),
            onRetry: controller.refresh,
          );
        }
        if (controller.isLoading && controller.items.isEmpty) {
          return const Center(
            child: SizedBox.square(
              key: Key('actor-grid-initial-loading'),
              dimension: 36,
              child: CircularProgressIndicator(),
            ),
          );
        }
        if (controller.items.isEmpty && emptyMessage != null) {
          return EmptyState(message: emptyMessage!);
        }
        return LayoutBuilder(
          builder: (context, constraints) {
            final metrics = metricsForWidth(constraints.maxWidth);
            final crossAxisCount = metrics.crossAxisCount;
            final crossAxisSpacing = metrics.crossAxisSpacing;
            final tileWidth = metrics.tileWidth;
            final hasTail =
                controller.items.isNotEmpty &&
                ((!controller.isRefreshing && controller.isLoading) ||
                    controller.error != null);

            return NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if ((notification is ScrollUpdateNotification ||
                        notification is ScrollEndNotification) &&
                    notification.metrics.extentAfter < 200) {
                  controller.fetchMore();
                }
                return false;
              },
              child: RefreshIndicator(
                onRefresh: () => controller.refresh(preserveItems: true),
                child: Stack(
                  children: [
                    GridView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        mainAxisSpacing: mainAxisSpacing,
                        crossAxisSpacing: crossAxisSpacing,
                        mainAxisExtent: ActorCard.mainAxisExtent(
                          context,
                          tileWidth,
                        ),
                      ),
                      itemCount: controller.items.length + (hasTail ? 1 : 0),
                      padding: const EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                        vertical: mainAxisSpacing,
                      ),
                      itemBuilder: (_, index) {
                        if (index < controller.items.length) {
                          return ActorCard(
                            actor: controller.items[index],
                            onTap: selectionMode
                                ? (onToggleSelect == null
                                      ? null
                                      : () => onToggleSelect!(
                                          controller.items[index],
                                        ))
                                : onActorTap != null
                                ? () => onActorTap!(controller.items[index])
                                : null,
                            selected:
                                selectionMode &&
                                selectedIds.contains(
                                  controller.items[index].id,
                                ),
                          );
                        }

                        if (controller.isLoading) {
                          return const Center(
                            child: SizedBox.square(
                              key: Key('actor-grid-tail-loading'),
                              dimension: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          );
                        }

                        return Center(
                          child: TextButton(
                            key: const Key('actor-grid-tail-retry'),
                            onPressed: controller.fetchMore,
                            child: const Text('重试'),
                          ),
                        );
                      },
                    ),
                    if (controller.isRefreshing)
                      const Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: LinearProgressIndicator(
                          key: Key('actor-grid-refreshing'),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
