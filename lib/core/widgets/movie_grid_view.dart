import 'package:flutter/material.dart';
import 'package:jade/core/models/movie.dart';
import 'package:jade/core/widgets/empty_state.dart';
import 'package:jade/core/widgets/error_retry_widget.dart';
import 'package:jade/core/widgets/movie_card.dart';
import 'package:jade/core/widgets/pagination_controller.dart';

class MovieGridView extends StatefulWidget {
  const MovieGridView({
    super.key,
    required this.controller,
    this.showShuffle = false,
    this.crossAxisCount = 3,
    this.scrollToTopOnReload = false,
  });
  final PaginationController<MovieSummary> controller;
  final bool showShuffle;
  final int crossAxisCount;

  /// 条件变化触发 reload（reloadEpoch 变化）时自动滚回顶部。
  /// 默认关闭，仅由需要该行为的页面开启；追加加载不自增 epoch。
  /// 下拉刷新也会自增，但它只在顶部触发，配合 offset!=0 守卫无可见影响。
  final bool scrollToTopOnReload;

  @override
  State<MovieGridView> createState() => _MovieGridViewState();
}

class _MovieGridViewState extends State<MovieGridView> {
  final ScrollController _scrollController = ScrollController();
  int? _seenReloadEpoch;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _syncReloadEpoch() {
    final epoch = widget.controller.reloadEpoch;
    final seen = _seenReloadEpoch;
    _seenReloadEpoch = epoch;
    if (!widget.scrollToTopOnReload || seen == null || seen == epoch) return;
    // 网格此时可能尚未布局滚动视图，统一延迟到帧末并按挂载状态执行。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      if (_scrollController.offset != 0) _scrollController.jumpTo(0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        _syncReloadEpoch();
        if (widget.controller.error != null && widget.controller.items.isEmpty) {
          return ErrorRetryWidget(
            message: widget.controller.error.toString(),
            onRetry: widget.controller.refresh,
          );
        }
        if (widget.controller.isLoading && widget.controller.items.isEmpty) {
          return const Center(
            key: Key('movie-grid-initial-loading'),
            child: CircularProgressIndicator(),
          );
        }
        if (widget.controller.items.isEmpty) {
          return const EmptyState();
        }
        return NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification.metrics.extentAfter < 400) {
              widget.controller.fetchMore();
            }
            return false;
          },
          child: RefreshIndicator(
            onRefresh: () => widget.controller.refresh(preserveItems: true),
            child: Stack(
              children: [
                CustomScrollView(
                  controller: _scrollController,
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.all(8),
                      sliver: SliverGrid.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: widget.crossAxisCount,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          childAspectRatio: 0.56,
                        ),
                        itemCount: widget.controller.items.length,
                        itemBuilder: (context, index) =>
                            MovieCard(movie: widget.controller.items[index]),
                      ),
                    ),
                    if (widget.controller.error != null &&
                        widget.controller.items.isNotEmpty)
                      SliverToBoxAdapter(
                        child: TextButton.icon(
                          key: const Key('movie-grid-load-more-retry'),
                          onPressed: widget.controller.fetchMore,
                          icon: const Icon(Icons.refresh),
                          label: const Text('加载失败，点击重试'),
                        ),
                      ),
                    if (widget.controller.isLoading)
                      const SliverToBoxAdapter(
                        child: Padding(
                          key: Key('movie-grid-loading-more'),
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      ),
                  ],
                ),
                if (widget.controller.isRefreshing)
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
