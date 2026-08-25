import 'package:flutter/material.dart';
import 'package:jade/core/models/list_model.dart';
import 'package:jade/core/models/magnet.dart';
import 'package:jade/core/models/review.dart';
import 'package:jade/core/widgets/list_summary_tile.dart';
import 'package:jade/core/widgets/magnet_list_tile.dart';
import 'package:jade/core/widgets/review_tile.dart';
import 'package:jade/features/movie_detail/models/movie_review_sort.dart';
import 'package:jade/features/movie_detail/widgets/movie_section.dart';

/// 磁链下载列表（含错误/空态，独立可重试）。
class MovieMagnetList extends StatelessWidget {
  const MovieMagnetList({
    super.key,
    required this.magnets,
    required this.error,
    required this.loading,
    required this.onRetry,
  });

  final List<Magnet> magnets;
  final Object? error;
  final bool loading;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) {
      return ScrollableTabError(message: '磁链加载失败', onRetry: onRetry);
    }
    if (magnets.isEmpty) return const Center(child: Text('暂无磁链'));
    return ListView.separated(
      key: const PageStorageKey('movie-detail-magnets'),
      itemCount: magnets.length,
      separatorBuilder: (context, index) => const MagnetListDivider(),
      itemBuilder: (_, index) {
        final magnet = magnets[index];
        return MagnetListTile(magnet: magnet);
      },
    );
  }
}

/// 相关清单列表（含错误/空态，独立可重试）。
class MovieRelatedListList extends StatelessWidget {
  const MovieRelatedListList({
    super.key,
    required this.lists,
    required this.error,
    required this.loading,
    required this.onRetry,
  });

  final List<ListModel> lists;
  final Object? error;
  final bool loading;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) {
      return ScrollableTabError(message: '相关清单加载失败', onRetry: onRetry);
    }
    if (lists.isEmpty) return const Center(child: Text('暂无相关清单'));
    return ListView.separated(
      key: const PageStorageKey('movie-detail-related-lists'),
      itemCount: lists.length,
      separatorBuilder: (context, index) => detailTabDivider(context),
      itemBuilder: (_, index) {
        final list = lists[index];
        return ListSummaryTile(list: list);
      },
    );
  }
}

/// 短评列表（含排序头）。
class MovieReviewList extends StatelessWidget {
  const MovieReviewList({
    super.key,
    required this.reviews,
    required this.loading,
    required this.sort,
    required this.onSortChanged,
  });

  final List<Review> reviews;
  final bool loading;
  final MovieReviewSort sort;
  final ValueChanged<MovieReviewSort> onSortChanged;

  @override
  Widget build(BuildContext context) {
    if (reviews.isEmpty) {
      return ListView(
        key: const PageStorageKey('movie-detail-reviews'),
        children: [
          MovieReviewSortHeader(
            sort: sort,
            loading: loading,
            onSortChanged: onSortChanged,
          ),
          SizedBox(
            height: 180,
            child: Center(
              child: loading
                  ? const CircularProgressIndicator()
                  : const Text('暂无短评'),
            ),
          ),
        ],
      );
    }
    return ListView.separated(
      key: const PageStorageKey('movie-detail-reviews'),
      itemCount: reviews.length + 1,
      separatorBuilder: (context, index) => detailTabDivider(context),
      itemBuilder: (_, index) {
        if (index == 0) {
          return MovieReviewSortHeader(
            sort: sort,
            loading: loading,
            onSortChanged: onSortChanged,
          );
        }
        return ReviewTile(review: reviews[index - 1]);
      },
    );
  }
}

/// 短评排序头（排序按钮 + 加载进度）。
class MovieReviewSortHeader extends StatelessWidget {
  const MovieReviewSortHeader({
    super.key,
    required this.sort,
    required this.loading,
    required this.onSortChanged,
  });

  final MovieReviewSort sort;
  final bool loading;
  final ValueChanged<MovieReviewSort> onSortChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        MovieReviewSortBar(
          sort: sort,
          onSortChanged: loading ? null : onSortChanged,
        ),
        if (loading) const LinearProgressIndicator(minHeight: 2),
      ],
    );
  }
}

/// 短评排序按钮组（最热 / 最新）。
class MovieReviewSortBar extends StatelessWidget {
  const MovieReviewSortBar({super.key, required this.sort, required this.onSortChanged});

  final MovieReviewSort sort;
  final ValueChanged<MovieReviewSort>? onSortChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        SegmentedButton<MovieReviewSort>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: MovieReviewSort.hotly, label: Text('最热')),
            ButtonSegment(value: MovieReviewSort.recently, label: Text('最新')),
          ],
          selected: {sort},
          onSelectionChanged: onSortChanged == null
              ? null
              : (values) => onSortChanged!(values.single),
        ),
      ],
    );
  }
}
