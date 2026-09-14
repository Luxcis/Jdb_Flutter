import 'package:flutter/material.dart';
import 'package:jade/core/models/actor.dart';
import 'package:jade/core/models/list_model.dart';
import 'package:jade/core/models/magnet.dart';
import 'package:jade/core/models/movie.dart';
import 'package:jade/core/widgets/movie_cover_image.dart';
import 'package:jade/features/movie_detail/models/movie_review_sort.dart';
import 'package:jade/features/movie_detail/services/detail_section_state.dart';
import 'package:jade/features/movie_detail/widgets/basic_info_sections.dart';
import 'package:jade/features/movie_detail/widgets/movie_detail_lists.dart';
import 'package:jade/features/movie_detail/widgets/movie_info_card.dart';

/// 影片详情页顶部封面区（含动态高度）。
class MovieDetailHero extends StatelessWidget {
  const MovieDetailHero({super.key, required this.detail});

  final MovieDetail detail;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = (constraints.maxWidth / 1.45).clamp(220.0, 360.0);
        return SizedBox(
          width: double.infinity,
          height: height,
          child: ColoredBox(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: MovieCoverImage(
              detail.coverUrl,
              variant: MovieImageVariant.cover,
              semanticLabel: detail.title,
              fit: BoxFit.cover,
              allowBlur: true,
            ),
          ),
        );
      },
    );
  }
}

/// 影片详情页底部四 Tab 容器：基本信息 / 磁链下载 / 短评 / 相关清单。
///
/// 三个数据区块各挂自己的 [ListenableBuilder]：任一区块状态变化只重建该
/// Tab 的子树，不触发整页与其他区块重建；「基本信息」Tab 由不可变的
/// [ReviewStatusState] 驱动，仅在短评状态变化时重建。
class MovieDetailTabs extends StatelessWidget {
  const MovieDetailTabs({
    super.key,
    required this.detail,
    required this.magnetsState,
    required this.reviewsState,
    required this.relatedListsState,
    required this.onRetryMagnets,
    required this.onRetryRelatedLists,
    required this.reviewStatus,
    required this.onReviewSortChanged,
    required this.onWantWatch,
    required this.onWatched,
    required this.onDeleteReview,
    required this.onSaveToList,
    required this.onPreviewTap,
    required this.onActorTap,
  });

  final MovieDetail detail;
  final DetailSectionState<Magnet> magnetsState;
  final ReviewSectionState reviewsState;
  final DetailSectionState<ListModel> relatedListsState;
  final VoidCallback onRetryMagnets;
  final VoidCallback onRetryRelatedLists;
  final ReviewStatusState reviewStatus;
  final ValueChanged<MovieReviewSort> onReviewSortChanged;
  final VoidCallback onWantWatch;
  final VoidCallback onWatched;
  final VoidCallback onDeleteReview;
  final VoidCallback onSaveToList;
  final VoidCallback onPreviewTap;
  final ValueChanged<ActorSummary> onActorTap;

  @override
  Widget build(BuildContext context) {
    const tabBar = TabBar(
      key: Key('movie-detail-tab-bar'),
      tabs: [
        Tab(text: '基本信息'),
        Tab(text: '磁链下载'),
        Tab(text: '短评'),
        Tab(text: '相关清单'),
      ],
    );
    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) => [
        SliverToBoxAdapter(child: MovieDetailHero(detail: detail)),
        SliverPersistentHeader(
          pinned: true,
          delegate: MovieDetailTabHeaderDelegate(
            tabBar: tabBar,
            backgroundColor: Theme.of(context).colorScheme.surface,
            dividerColor: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ],
      body: TabBarView(
        children: [
          ListenableBuilder(
            listenable: reviewStatus,
            builder: (_, _) => MovieDetailBasicInfoTab(
              detail: detail,
              reviewStatus: reviewStatus,
              onWantWatch: onWantWatch,
              onWatched: onWatched,
              onDeleteReview: onDeleteReview,
              onSaveToList: onSaveToList,
              onPreviewTap: onPreviewTap,
              onActorTap: onActorTap,
            ),
          ),
          ListenableBuilder(
            listenable: magnetsState,
            builder: (_, _) => MovieMagnetList(
              magnets: magnetsState.items,
              error: magnetsState.error,
              loading: magnetsState.loading,
              onRetry: onRetryMagnets,
            ),
          ),
          ListenableBuilder(
            listenable: reviewsState,
            builder: (_, _) => MovieReviewList(
              reviews: reviewsState.items,
              loading: reviewsState.loading,
              sort: reviewsState.sort,
              onSortChanged: onReviewSortChanged,
            ),
          ),
          ListenableBuilder(
            listenable: relatedListsState,
            builder: (_, _) => MovieRelatedListList(
              lists: relatedListsState.items,
              error: relatedListsState.error,
              loading: relatedListsState.loading,
              onRetry: onRetryRelatedLists,
            ),
          ),
        ],
      ),
    );
  }
}

/// 详情页固定 TabBar 的 SliverPersistentHeader delegate。
class MovieDetailTabHeaderDelegate extends SliverPersistentHeaderDelegate {
  const MovieDetailTabHeaderDelegate({
    required this.tabBar,
    required this.backgroundColor,
    required this.dividerColor,
  });

  final TabBar tabBar;
  final Color backgroundColor;
  final Color dividerColor;

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border(bottom: BorderSide(color: dividerColor)),
      ),
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(MovieDetailTabHeaderDelegate oldDelegate) {
    return tabBar != oldDelegate.tabBar ||
        backgroundColor != oldDelegate.backgroundColor ||
        dividerColor != oldDelegate.dividerColor;
  }
}

/// 「基本信息」Tab 内容：信息卡 + 类别 + 演员 + 剧照 + 相关影片行。
class MovieDetailBasicInfoTab extends StatelessWidget {
  const MovieDetailBasicInfoTab({
    super.key,
    required this.detail,
    required this.reviewStatus,
    required this.onWantWatch,
    required this.onWatched,
    required this.onDeleteReview,
    required this.onSaveToList,
    required this.onPreviewTap,
    required this.onActorTap,
  });

  final MovieDetail detail;
  final ReviewStatusState reviewStatus;
  final VoidCallback onWantWatch;
  final VoidCallback onWatched;
  final VoidCallback onDeleteReview;
  final VoidCallback onSaveToList;
  final VoidCallback onPreviewTap;
  final ValueChanged<ActorSummary> onActorTap;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const PageStorageKey('movie-detail-basic-info'),
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: MovieInfoCard(
            detail: detail,
            review: reviewStatus.review,
            reviewMutationLoading: reviewStatus.mutationLoading,
            onWantWatch: onWantWatch,
            onWatched: onWatched,
            onDeleteReview: onDeleteReview,
            onSaveToList: onSaveToList,
          ),
        ),
        if (detail.tagItems.isNotEmpty)
          MovieCategorySection(tags: detail.tagItems, type: detail.type),
        if (detail.actors.isNotEmpty)
          MovieActorSection(actors: detail.actors, onActorTap: onActorTap),
        if (detail.previewVideoUrl != null || detail.screenshots.isNotEmpty)
          MovieScreenshotSection(
            urls: detail.screenshots,
            previewCoverUrl:
                detail.previewVideoUrl == null ? null : detail.coverUrl,
            previewTitle: detail.title,
            onPreviewTap: onPreviewTap,
          ),
        if (detail.actorMovies.isNotEmpty)
          MovieRowSection(title: 'TA还出演过', movies: detail.actorMovies),
        if (detail.relativeMovies.isNotEmpty)
          MovieRowSection(title: '你可能也喜欢', movies: detail.relativeMovies),
      ],
    );
  }
}
