import 'package:flutter/material.dart';
import 'package:jade/core/models/actor.dart';
import 'package:jade/core/widgets/actor_card.dart';
import 'package:jade/core/widgets/error_retry_widget.dart';
import 'package:jade/core/widgets/pagination_controller.dart';

class ActorGridView extends StatelessWidget {
  const ActorGridView({super.key, required this.controller, this.onActorTap});

  final PaginationController<ActorSummary> controller;
  final void Function(ActorSummary)? onActorTap;

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
        return LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = (constraints.maxWidth / 120).floor().clamp(
              3,
              6,
            );
            const horizontalPadding = 16.0;
            const crossAxisSpacing = 12.0;
            final tileWidth =
                (constraints.maxWidth -
                    horizontalPadding * 2 -
                    crossAxisSpacing * (crossAxisCount - 1)) /
                crossAxisCount;
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
                        mainAxisSpacing: 12,
                        crossAxisSpacing: crossAxisSpacing,
                        mainAxisExtent: ActorCard.mainAxisExtent(
                          context,
                          tileWidth,
                        ),
                      ),
                      itemCount: controller.items.length + (hasTail ? 1 : 0),
                      padding: const EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                        vertical: 12,
                      ),
                      itemBuilder: (_, index) {
                        if (index < controller.items.length) {
                          return ActorCard(
                            actor: controller.items[index],
                            onTap: onActorTap != null
                                ? () => onActorTap!(controller.items[index])
                                : null,
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
