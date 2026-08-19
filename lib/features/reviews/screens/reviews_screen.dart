import 'package:flutter/material.dart';
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/core/models/review.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/widgets/empty_state.dart';
import 'package:jade/core/widgets/error_retry_widget.dart';
import 'package:jade/core/widgets/pagination_controller.dart';
import 'package:jade/core/widgets/review_tile.dart';
import 'package:jade/features/reviews/models/review_period.dart';
import 'package:jade/features/reviews/services/reviews_service.dart';

class ReviewsPage extends StatefulWidget {
  const ReviewsPage({super.key});

  @override
  State<ReviewsPage> createState() => _ReviewsPageState();
}

class _ReviewsPageState extends State<ReviewsPage>
    with TickerProviderStateMixin {
  static const tabs = ['最新', '上周热评', '月度热评', '季度热评', '年度热评', '全部'];
  static const periods = [
    ReviewPeriod.latest,
    ReviewPeriod.weekly,
    ReviewPeriod.monthly,
    ReviewPeriod.quarterly,
    ReviewPeriod.yearly,
    ReviewPeriod.all,
  ];

  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('看短评'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: [for (final tab in tabs) Tab(text: tab)],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [for (final period in periods) _HotReviewList(period: period)],
      ),
    );
  }
}

class _HotReviewList extends StatefulWidget {
  const _HotReviewList({required this.period});

  final ReviewPeriod period;

  @override
  State<_HotReviewList> createState() => _HotReviewListState();
}

class _HotReviewListState extends State<_HotReviewList>
    with AutomaticKeepAliveClientMixin {
  late final PaginationController<Review> _controller =
      PaginationController(fetch: _fetchPage);

  Future<PagedResult<Review>> _fetchPage(int page) async {
    final api = ApiClient.instanceOrNull;
    if (api == null) {
      throw StateError('网络客户端未初始化');
    }
    return ReviewsService(api).getHotReviews(period: widget.period, page: page);
  }

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _controller.fetchMore();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
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
        if (_controller.items.isEmpty) {
          return const EmptyState(message: '暂无短评');
        }
        final showFooter = _controller.isLoading || _controller.error != null;
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
                child: ListView.separated(
                  key: Key('hot-reviews-${widget.period.value}'),
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: _controller.items.length + (showFooter ? 1 : 0),
                  separatorBuilder: (_, _) => const Divider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                  ),
                  itemBuilder: (context, index) {
                    if (index == _controller.items.length) {
                      if (_controller.isLoading) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      return Center(
                        child: TextButton.icon(
                          onPressed: _controller.fetchMore,
                          icon: const Icon(Icons.refresh),
                          label: const Text('加载失败，点击重试'),
                        ),
                      );
                    }
                    return ReviewTile(review: _controller.items[index]);
                  },
                ),
              ),
              if (_controller.isRefreshing)
                const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(
                    key: Key('reviews-refreshing'),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
