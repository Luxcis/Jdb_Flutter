import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jade/core/models/movie.dart';
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/providers/auth_provider.dart';
import 'package:jade/core/widgets/error_retry_widget.dart';
import 'package:jade/core/widgets/login_guide_card.dart';
import 'package:jade/core/widgets/movie_list_tile.dart';
import 'package:jade/core/widgets/pagination_controller.dart';
import 'package:jade/features/rankings/models/top250_filter.dart';
import 'package:jade/features/rankings/services/ranking_service.dart';
import 'package:jade/features/rankings/widgets/rank_tabs.dart';
import 'package:provider/provider.dart';

/// Top250 排行榜 Tab：需登录，含筛选、下拉刷新与无限滚动。
class Top250Tab extends StatefulWidget {
  const Top250Tab({super.key, required this.filter});

  final Top250Filter filter;

  @override
  State<Top250Tab> createState() => _Top250TabState();
}

class _Top250TabState extends State<Top250Tab>
    with AutomaticKeepAliveClientMixin {
  static const _pageSize = 50;
  static const _maxRank = 250;

  var _wasLoggedIn = false;
  late final PaginationController<MovieSummary> _controller =
      PaginationController(fetch: _fetchPage);

  int get _logicalTotalPages =>
      ((_maxRank - widget.filter.startRank + 1) / _pageSize).ceil();

  Future<PagedResult<MovieSummary>> _fetchPage(int page) async {
    final api = ApiClient.instanceOrNull;
    if (api == null) return emptyMoviePage(page: page);
    final result = await RankingService(api).getTop250(
      startRank: widget.filter.startRank + (page - 1) * _pageSize,
      type: widget.filter.type,
      typeValue: widget.filter.typeValue,
      ignoreWatched: widget.filter.ignoreWatched,
      limit: _pageSize,
    );
    final isLastPage =
        result.items.length < _pageSize || page >= _logicalTotalPages;
    return PagedResult(
      items: result.items,
      currentPage: page,
      totalPages: isLastPage ? page : _logicalTotalPages,
      total: _maxRank - widget.filter.startRank + 1,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isLoggedIn = context.watch<AuthProvider>().isLogged;
    if (isLoggedIn && !_wasLoggedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !context.read<AuthProvider>().isLogged) return;
        _controller.reloadWith(_fetchPage);
      });
    }
    _wasLoggedIn = isLoggedIn;
  }

  @override
  void didUpdateWidget(covariant Top250Tab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filter.type != widget.filter.type ||
        oldWidget.filter.typeValue != widget.filter.typeValue ||
        oldWidget.filter.startRank != widget.filter.startRank ||
        oldWidget.filter.ignoreWatched != widget.filter.ignoreWatched) {
      _controller.reloadWith(_fetchPage);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final auth = context.watch<AuthProvider>();
    if (!auth.isLogged) {
      return const LoginGuideCard(
        message: '登录后查看 Top250 排行榜',
        loginPath: '/rankings',
      );
    }
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        if (_controller.error != null && _controller.items.isEmpty) {
          return ErrorRetryWidget(
            message: _controller.error.toString(),
            onRetry: _controller.refresh,
          );
        }
        if (_controller.isLoading && _controller.items.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        final showFooter =
            _controller.isLoading ||
            (_controller.error != null && _controller.items.isNotEmpty);
        return RefreshIndicator(
          onRefresh: () => _controller.refresh(preserveItems: true),
          child: Stack(
            children: [
              NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification is ScrollEndNotification &&
                      notification.metrics.extentAfter < 200 &&
                      _controller.error == null) {
                    _controller.fetchMore();
                  }
                  return false;
                },
                child: ListView.builder(
                  key: const Key('top250-list'),
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: _controller.items.length + (showFooter ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _controller.items.length) {
                      if (_controller.isLoading) {
                        return const Padding(
                          key: Key('top250-loading-more'),
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      return Top250LoadMoreError(
                        onRetry: _controller.fetchMore,
                      );
                    }
                    final movie = _controller.items[index];
                    return MovieListTile(
                      movie: movie,
                      rank: widget.filter.startRank + index,
                      onTap: () => context.push('/movie/${movie.id}'),
                    );
                  },
                ),
              ),
              if (_controller.isRefreshing)
                const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(key: Key('top250-refreshing')),
                ),
            ],
          ),
        );
      },
    );
  }
}

class Top250LoadMoreError extends StatelessWidget {
  const Top250LoadMoreError({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton.icon(
        key: const Key('top250-load-more-retry'),
        onPressed: onRetry,
        icon: const Icon(Icons.refresh),
        label: const Text('加载失败，点击重试'),
      ),
    );
  }
}
