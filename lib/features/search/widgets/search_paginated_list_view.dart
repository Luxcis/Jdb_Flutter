import 'package:flutter/material.dart';
import 'package:jade/core/widgets/empty_state.dart';
import 'package:jade/core/widgets/error_retry_widget.dart';
import 'package:jade/core/widgets/pagination_controller.dart';

class SearchPaginatedListView<T> extends StatelessWidget {
  const SearchPaginatedListView({
    super.key,
    required this.controller,
    required this.itemBuilder,
    required this.emptyMessage,
  });

  final PaginationController<T> controller;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      if (controller.error != null && controller.items.isEmpty) {
        return ErrorRetryWidget(
          message: controller.error.toString(),
          onRetry: controller.refresh,
        );
      }
      if (controller.isLoading && controller.items.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }
      if (controller.items.isEmpty) return EmptyState(message: emptyMessage);

      final hasTail = controller.isLoading || controller.error != null;
      return NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if ((notification is ScrollUpdateNotification ||
                  notification is ScrollEndNotification) &&
              notification.metrics.extentAfter < 200) {
            controller.fetchMore();
          }
          return false;
        },
        child: ListView.separated(
          itemCount: controller.items.length + (hasTail ? 1 : 0),
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            if (index < controller.items.length) {
              return itemBuilder(context, controller.items[index]);
            }
            if (controller.isLoading) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              );
            }
            return Center(
              child: TextButton(
                key: const Key('search-list-tail-retry'),
                onPressed: controller.fetchMore,
                child: const Text('重试'),
              ),
            );
          },
        ),
      );
    },
  );
}
