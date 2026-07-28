import 'package:flutter/material.dart';
import 'package:jade/core/models/movie.dart';
import 'package:jade/core/widgets/error_retry_widget.dart';
import 'package:jade/core/widgets/movie_card.dart';
import 'package:jade/core/widgets/pagination_controller.dart';

class MovieGridView extends StatelessWidget {
  const MovieGridView({
    super.key,
    required this.controller,
    this.onMovieTap,
    this.showShuffle = false,
    this.crossAxisCount = 3,
  });
  final PaginationController<MovieSummary> controller;
  final void Function(MovieSummary)? onMovieTap;
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
        return NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n is ScrollEndNotification && n.metrics.extentAfter < 200) {
              controller.fetchMore();
            }
            return false;
          },
          child: RefreshIndicator(
            onRefresh: controller.refresh,
            child: CustomScrollView(
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
                    itemBuilder: (_, i) => MovieCard(
                      movie: controller.items[i],
                      onTap: onMovieTap != null
                          ? () => onMovieTap!(controller.items[i])
                          : null,
                    ),
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
          ),
        );
      },
    );
  }
}
