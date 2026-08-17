import 'package:flutter/material.dart';
import 'package:jade/core/models/movie.dart';
import 'package:jade/core/widgets/empty_state.dart';
import 'package:jade/core/widgets/error_retry_widget.dart';
import 'package:jade/core/widgets/movie_card.dart';
import 'package:jade/core/widgets/pagination_controller.dart';

class MovieGridView extends StatelessWidget {
  const MovieGridView({
    super.key,
    required this.controller,
    this.showShuffle = false,
    this.crossAxisCount = 3,
  });
  final PaginationController<MovieSummary> controller;
  final bool showShuffle;
  final int crossAxisCount;

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
            key: Key('movie-grid-initial-loading'),
            child: CircularProgressIndicator(),
          );
        }
        if (controller.items.isEmpty) {
          return const EmptyState();
        }
        return NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification.metrics.extentAfter < 400) {
              controller.fetchMore();
            }
            return false;
          },
          child: RefreshIndicator(
            onRefresh: controller.refresh,
            child: Stack(
              children: [
                CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.all(8),
                      sliver: SliverGrid.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          childAspectRatio: 0.56,
                        ),
                        itemCount: controller.items.length,
                        itemBuilder: (context, index) =>
                            MovieCard(movie: controller.items[index]),
                      ),
                    ),
                    if (controller.error != null && controller.items.isNotEmpty)
                      SliverToBoxAdapter(
                        child: TextButton.icon(
                          key: const Key('movie-grid-load-more-retry'),
                          onPressed: controller.fetchMore,
                          icon: const Icon(Icons.refresh),
                          label: const Text('加载失败，点击重试'),
                        ),
                      ),
                    if (controller.isLoading)
                      const SliverToBoxAdapter(
                        child: Padding(
                          key: Key('movie-grid-loading-more'),
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      ),
                  ],
                ),
                if (controller.isRefreshing)
                  const Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: LinearProgressIndicator(
                      key: Key('movie-grid-refreshing'),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
