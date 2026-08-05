import 'package:flutter/material.dart';
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/widgets/empty_state.dart';
import 'package:jade/core/widgets/error_retry_widget.dart';
import 'package:jade/core/widgets/pagination_controller.dart';
import 'package:jade/features/articles/models/article.dart';
import 'package:jade/features/articles/services/article_service.dart';
import 'package:jade/features/articles/widgets/article_card.dart';

class ArticlesPage extends StatefulWidget {
  const ArticlesPage({super.key});
  @override
  State<ArticlesPage> createState() => _ArticlesPageState();
}

class _ArticlesPageState extends State<ArticlesPage> {
  late final PaginationController<ArticleSummary> _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = PaginationController<ArticleSummary>(fetch: _fetchPage)
      ..fetchMore();
  }

  Future<PagedResult<ArticleSummary>> _fetchPage(int page) async {
    final api = ApiClient.instanceOrNull;
    if (api == null) {
      return PagedResult(items: const [], currentPage: page, totalPages: page, total: 0);
    }
    return ArticleService(api).getArticles(page: page);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AV资讯')),
      body: ListenableBuilder(
        listenable: _ctrl,
        builder: (context, _) {
          if (_ctrl.error != null && _ctrl.items.isEmpty) {
            return ErrorRetryWidget(
              message: _ctrl.error.toString(),
              onRetry: _ctrl.refresh,
            );
          }
          if (_ctrl.isLoading && _ctrl.items.isEmpty) {
            return const Center(
              key: Key('articles-initial-loading'),
              child: CircularProgressIndicator(),
            );
          }
          return NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification.metrics.extentAfter < 400) {
                _ctrl.fetchMore();
              }
              return false;
            },
            child: RefreshIndicator(
              onRefresh: () => _ctrl.refresh(preserveItems: true),
              child: Stack(
                children: [
                  CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      if (_ctrl.items.isEmpty)
                        const SliverFillRemaining(child: EmptyState())
                      else
                        SliverPadding(
                          padding: const EdgeInsets.all(8),
                          sliver: SliverList.builder(
                            itemCount: _ctrl.items.length,
                            itemBuilder: (_, i) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: ArticleCard(article: _ctrl.items[i]),
                            ),
                          ),
                        ),
                      if (_ctrl.error != null && _ctrl.items.isNotEmpty)
                        SliverToBoxAdapter(
                          child: TextButton.icon(
                            key: const Key('articles-load-more-retry'),
                            onPressed: _ctrl.fetchMore,
                            icon: const Icon(Icons.refresh),
                            label: const Text('加载失败，点击重试'),
                          ),
                        ),
                      if (_ctrl.isLoading)
                        const SliverToBoxAdapter(
                          child: Padding(
                            key: Key('articles-loading-more'),
                            padding: EdgeInsets.all(16),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                        ),
                    ],
                  ),
                  if (_ctrl.isRefreshing)
                    const Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: LinearProgressIndicator(
                        key: Key('articles-refreshing'),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
