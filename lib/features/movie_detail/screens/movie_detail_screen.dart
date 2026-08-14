import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jade/core/models/actor.dart';
import 'package:jade/core/models/list_model.dart';
import 'package:jade/core/models/magnet.dart';
import 'package:jade/core/models/movie.dart';
import 'package:jade/core/models/review.dart';
import 'package:jade/core/models/tag.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/api_exception.dart';
import 'package:jade/core/router/routes.dart';
import 'package:jade/core/widgets/actor_card.dart';
import 'package:jade/core/widgets/error_retry_widget.dart';
import 'package:jade/core/widgets/image_gallery_viewer.dart';
import 'package:jade/core/widgets/list_summary_tile.dart';
import 'package:jade/core/widgets/magnet_list_tile.dart';
import 'package:jade/core/widgets/movie_card.dart';
import 'package:jade/core/widgets/movie_cover_image.dart';
import 'package:jade/core/widgets/movie_screenshot_image.dart';
import 'package:jade/core/widgets/review_tile.dart';
import 'package:jade/core/widgets/star_rating.dart';
import 'package:jade/core/widgets/tag_chip.dart';
import 'package:jade/features/movie_detail/models/movie_preview_args.dart';
import 'package:jade/features/movie_detail/models/movie_review_status.dart';
import 'package:jade/features/movie_detail/services/movie_detail_service.dart';
import 'package:jade/features/movie_detail/widgets/movie_review_actions.dart';
import 'package:jade/features/movie_detail/widgets/top_ranking_tile.dart';
import 'package:jade/features/movie_detail/widgets/watched_review_sheet.dart';

class MovieDetailPage extends StatefulWidget {
  const MovieDetailPage({super.key, required this.id});

  final String id;

  @override
  State<MovieDetailPage> createState() => _MovieDetailPageState();
}

class _MovieDetailPageState extends State<MovieDetailPage> {
  MovieDetailService? _service;
  MovieDetail? _detail;
  List<Magnet> _magnets = [];
  Object? _magnetsError;
  bool _magnetsLoading = true;
  List<Review> _reviews = [];
  _ReviewSort _reviewSort = _ReviewSort.hotly;
  bool _reviewsLoading = false;
  List<ListModel> _relatedLists = [];
  Object? _relatedListsError;
  bool _relatedListsLoading = true;
  bool _loading = true;
  bool _saveToListOpening = false;
  Review? _currentReview;
  bool _reviewMutationLoading = false;
  int _reviewMutationGeneration = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _magnets = [];
      _magnetsError = null;
      _magnetsLoading = true;
      _reviews = [];
      _reviewSort = _ReviewSort.hotly;
      _reviewsLoading = false;
      _relatedLists = [];
      _relatedListsError = null;
      _relatedListsLoading = true;
      _currentReview = null;
      _reviewMutationLoading = false;
    });
    try {
      final api = ApiClient.instanceOrNull;
      if (api == null) {
        setState(() {
          _error = '网络客户端未初始化';
          _loading = false;
        });
        return;
      }
      final service = MovieDetailService(api);
      final detail = await service.getDetail(widget.id);
      if (!mounted) return;
      setState(() {
        _service = service;
        _detail = detail;
        _currentReview = detail.review;
        _loading = false;
      });
      unawaited(_loadMagnets(service));
      unawaited(_loadReviews(service));
      unawaited(_loadRelatedLists(service));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadMagnets(MovieDetailService service) async {
    if (mounted) {
      setState(() {
        _magnetsLoading = true;
        _magnetsError = null;
      });
    }
    try {
      final magnets = await service.getMagnets(widget.id);
      if (!mounted) return;
      setState(() {
        _magnets = magnets;
        _magnetsLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _magnetsError = error;
        _magnetsLoading = false;
      });
    }
  }

  Future<void> _loadReviews(
    MovieDetailService service, {
    _ReviewSort sort = _ReviewSort.hotly,
  }) async {
    if (mounted) {
      setState(() {
        _reviewsLoading = true;
        _reviewSort = sort;
      });
    }
    try {
      final reviews = await service.getReviews(widget.id, sortBy: sort.value);
      if (!mounted) return;
      setState(() {
        _reviews = reviews;
        _reviewsLoading = false;
      });
    } catch (_) {
      // 短评继续沿用空状态，不影响本次磁链与相关清单错误处理。
      if (!mounted) return;
      setState(() => _reviewsLoading = false);
    }
  }

  Future<void> _loadRelatedLists(MovieDetailService service) async {
    if (mounted) {
      setState(() {
        _relatedListsLoading = true;
        _relatedListsError = null;
      });
    }
    try {
      final lists = await service.getRelatedLists(widget.id);
      if (!mounted) return;
      setState(() {
        _relatedLists = lists;
        _relatedListsLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _relatedListsError = error;
        _relatedListsLoading = false;
      });
    }
  }

  void _retryMagnets() {
    final service = _service;
    if (service != null) unawaited(_loadMagnets(service));
  }

  void _retryRelatedLists() {
    final service = _service;
    if (service != null) unawaited(_loadRelatedLists(service));
  }

  void _changeReviewSort(_ReviewSort sort) {
    if (_reviewsLoading || _reviewSort == sort) return;
    final service = _service;
    if (service != null) unawaited(_loadReviews(service, sort: sort));
  }

  Future<void> _createOrUpdateReview(
    MovieReviewStatus status, {
    int? score,
    String? content,
  }) async {
    if (_reviewMutationLoading) return;
    final service = _service;
    if (service == null) return;
    setState(() => _reviewMutationLoading = true);
    try {
      final review = await service.createOrUpdateReview(
        movieId: widget.id,
        status: status,
        score: score,
        content: content,
      );
      if (!mounted) return;
      final generation = ++_reviewMutationGeneration;
      setState(() => _currentReview = review);
      unawaited(_refreshDetailAfterReview(generation));
    } on DioException catch (error) {
      if (_isAuthError(error)) return;
      rethrow;
    } finally {
      if (mounted) {
        setState(() => _reviewMutationLoading = false);
      } else {
        _reviewMutationLoading = false;
      }
    }
  }

  Future<void> _deleteCurrentReview() async {
    if (_reviewMutationLoading) return;
    final service = _service;
    final review = _currentReview;
    if (service == null || review == null) return;
    setState(() => _reviewMutationLoading = true);
    try {
      await service.deleteReview(movieId: widget.id, reviewId: review.id);
      if (!mounted) return;
      final generation = ++_reviewMutationGeneration;
      setState(() => _currentReview = null);
      unawaited(_refreshDetailAfterReview(generation));
    } on DioException catch (error) {
      if (_isAuthError(error)) return;
      rethrow;
    } finally {
      if (mounted) {
        setState(() => _reviewMutationLoading = false);
      } else {
        _reviewMutationLoading = false;
      }
    }
  }

  Future<void> _refreshDetailAfterReview(int generation) async {
    final service = _service;
    if (service == null) return;
    try {
      final detail = await service.getDetail(widget.id);
      if (!mounted || generation != _reviewMutationGeneration) return;
      setState(() {
        _detail = detail;
        _currentReview = detail.review;
      });
    } on DioException catch (error) {
      if (!mounted ||
          generation != _reviewMutationGeneration ||
          _isAuthError(error)) {
        return;
      }
      _showSnackBar('状态已更新，详情刷新失败');
    } catch (_) {
      if (mounted && generation == _reviewMutationGeneration) {
        _showSnackBar('状态已更新，详情刷新失败');
      }
    }
  }

  Future<void> _markWantWatch() async {
    try {
      await _createOrUpdateReview(MovieReviewStatus.wantWatch);
    } catch (_) {
      if (mounted) _showSnackBar('操作失败，请重试');
    }
  }

  Future<void> _submitWatchedReview({
    required int score,
    required String content,
  }) {
    return _createOrUpdateReview(
      MovieReviewStatus.watched,
      score: score,
      content: content,
    );
  }

  Future<void> _removeCurrentReview() async {
    try {
      await _deleteCurrentReview();
    } catch (_) {
      if (mounted) _showSnackBar('操作失败，请重试');
    }
  }

  Future<void> _openWatchedReviewSheet() {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => WatchedReviewSheet(
        onSubmit: ({required score, required content}) =>
            _submitWatchedReview(score: score, content: content),
      ),
    );
  }

  Future<void> _openSaveToListSheet() async {
    if (_saveToListOpening) return;
    final api = ApiClient.instanceOrNull;
    final service = _service ?? (api == null ? null : MovieDetailService(api));
    if (service == null) return;
    setState(() => _saveToListOpening = true);
    try {
      final lists = await service.getSimpleLists(widget.id);
      if (!mounted) return;
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (context) => _SaveToListSheet(
          service: service,
          movieId: widget.id,
          initialLists: lists,
        ),
      );
    } on DioException catch (error) {
      if (!mounted) return;
      if (_isAuthError(error)) {
        return;
      }
      _showSnackBar('清单加载失败');
    } catch (error) {
      if (!mounted) return;
      _showSnackBar('清单加载失败');
    } finally {
      if (mounted) {
        setState(() => _saveToListOpening = false);
      }
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  bool _isAuthError(DioException error) {
    if (error.response?.statusCode == 401) return true;
    final apiError = error.error;
    if (apiError is ApiException) return apiError.isAuthError;
    final data = error.response?.data;
    if (data is Map) {
      final action = data['action'];
      return action == ApiErrorActions.jwtVerificationError ||
          action == ApiErrorActions.nonExistentUser;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(
        body: ErrorRetryWidget(message: _error!, onRetry: _load),
      );
    }

    final detail = _detail!;
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: Text(
              detail.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          body: DefaultTabController(
            length: 4,
            child: _MovieDetailTabs(
              detail: detail,
              magnets: _magnets,
              magnetsError: _magnetsError,
              magnetsLoading: _magnetsLoading,
              onRetryMagnets: _retryMagnets,
              reviews: _reviews,
              reviewsLoading: _reviewsLoading,
              reviewSort: _reviewSort,
              onReviewSortChanged: _changeReviewSort,
              relatedLists: _relatedLists,
              relatedListsError: _relatedListsError,
              relatedListsLoading: _relatedListsLoading,
              onRetryRelatedLists: _retryRelatedLists,
              review: _currentReview,
              reviewMutationLoading: _reviewMutationLoading,
              onWantWatch: () => unawaited(_markWantWatch()),
              onWatched: () => unawaited(_openWatchedReviewSheet()),
              onDeleteReview: () => unawaited(_removeCurrentReview()),
              onSaveToList: _openSaveToListSheet,
              onPreviewTap: () => context.push(
                AppRoutes.moviePreviewLocation(detail.id),
                extra: MoviePreviewArgs(
                  movieId: detail.id,
                  title: detail.title,
                  videoUrl: MoviePreviewArgs.replaceHostWithLine(
                    detail.previewVideoUrl!,
                    ApiClient.instanceOrNull?.domainManager.currentUrl,
                  ),
                ),
              ),
              onActorTap: (actor) => context.push('/actor/${actor.id}'),
            ),
          ),
        ),
        if (_saveToListOpening)
          const Positioned.fill(
            child: ColoredBox(
              key: Key('movie-save-to-list-loading-overlay'),
              color: Color(0x66000000),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }
}

class _MovieHero extends StatelessWidget {
  const _MovieHero({required this.detail});

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
            ),
          ),
        );
      },
    );
  }
}

class _MovieDetailTabs extends StatelessWidget {
  const _MovieDetailTabs({
    required this.detail,
    required this.magnets,
    required this.magnetsError,
    required this.magnetsLoading,
    required this.onRetryMagnets,
    required this.reviews,
    required this.reviewsLoading,
    required this.reviewSort,
    required this.onReviewSortChanged,
    required this.relatedLists,
    required this.relatedListsError,
    required this.relatedListsLoading,
    required this.onRetryRelatedLists,
    required this.review,
    required this.reviewMutationLoading,
    required this.onWantWatch,
    required this.onWatched,
    required this.onDeleteReview,
    required this.onSaveToList,
    required this.onPreviewTap,
    required this.onActorTap,
  });

  final MovieDetail detail;
  final List<Magnet> magnets;
  final Object? magnetsError;
  final bool magnetsLoading;
  final VoidCallback onRetryMagnets;
  final List<Review> reviews;
  final bool reviewsLoading;
  final _ReviewSort reviewSort;
  final ValueChanged<_ReviewSort> onReviewSortChanged;
  final List<ListModel> relatedLists;
  final Object? relatedListsError;
  final bool relatedListsLoading;
  final VoidCallback onRetryRelatedLists;
  final Review? review;
  final bool reviewMutationLoading;
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
        SliverToBoxAdapter(child: _MovieHero(detail: detail)),
        SliverPersistentHeader(
          pinned: true,
          delegate: _MovieDetailTabHeaderDelegate(
            tabBar: tabBar,
            backgroundColor: Theme.of(context).colorScheme.surface,
            dividerColor: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ],
      body: TabBarView(
        children: [
          _BasicInfoTab(
            detail: detail,
            review: review,
            reviewMutationLoading: reviewMutationLoading,
            onWantWatch: onWantWatch,
            onWatched: onWatched,
            onDeleteReview: onDeleteReview,
            onSaveToList: onSaveToList,
            onPreviewTap: onPreviewTap,
            onActorTap: onActorTap,
          ),
          _MagnetList(
            magnets: magnets,
            error: magnetsError,
            loading: magnetsLoading,
            onRetry: onRetryMagnets,
          ),
          _ReviewList(
            reviews: reviews,
            loading: reviewsLoading,
            sort: reviewSort,
            onSortChanged: onReviewSortChanged,
          ),
          _RelatedListList(
            lists: relatedLists,
            error: relatedListsError,
            loading: relatedListsLoading,
            onRetry: onRetryRelatedLists,
          ),
        ],
      ),
    );
  }
}

class _BasicInfoTab extends StatelessWidget {
  const _BasicInfoTab({
    required this.detail,
    required this.review,
    required this.reviewMutationLoading,
    required this.onWantWatch,
    required this.onWatched,
    required this.onDeleteReview,
    required this.onSaveToList,
    required this.onPreviewTap,
    required this.onActorTap,
  });

  final MovieDetail detail;
  final Review? review;
  final bool reviewMutationLoading;
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
          child: _MovieInfoCard(
            detail: detail,
            review: review,
            reviewMutationLoading: reviewMutationLoading,
            onWantWatch: onWantWatch,
            onWatched: onWatched,
            onDeleteReview: onDeleteReview,
            onSaveToList: onSaveToList,
          ),
        ),
        if (detail.tagItems.isNotEmpty)
          _CategorySection(tags: detail.tagItems, type: detail.type),
        if (detail.actors.isNotEmpty)
          _ActorSection(actors: detail.actors, onActorTap: onActorTap),
        if (detail.previewVideoUrl != null || detail.screenshots.isNotEmpty)
          _ScreenshotSection(
            urls: detail.screenshots,
            previewCoverUrl: detail.previewVideoUrl == null
                ? null
                : detail.coverUrl,
            previewTitle: detail.title,
            onPreviewTap: onPreviewTap,
          ),
        if (detail.actorMovies.isNotEmpty)
          _MovieRowSection(title: 'TA还出演过', movies: detail.actorMovies),
        if (detail.relativeMovies.isNotEmpty)
          _MovieRowSection(title: '你可能也喜欢', movies: detail.relativeMovies),
      ],
    );
  }
}

class _MovieDetailTabHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _MovieDetailTabHeaderDelegate({
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
  bool shouldRebuild(_MovieDetailTabHeaderDelegate oldDelegate) {
    return tabBar != oldDelegate.tabBar ||
        backgroundColor != oldDelegate.backgroundColor ||
        dividerColor != oldDelegate.dividerColor;
  }
}

class _MovieInfoCard extends StatelessWidget {
  const _MovieInfoCard({
    required this.detail,
    required this.review,
    required this.reviewMutationLoading,
    required this.onWantWatch,
    required this.onWatched,
    required this.onDeleteReview,
    required this.onSaveToList,
  });

  final MovieDetail detail;
  final Review? review;
  final bool reviewMutationLoading;
  final VoidCallback onWantWatch;
  final VoidCallback onWatched;
  final VoidCallback onDeleteReview;
  final VoidCallback onSaveToList;

  @override
  Widget build(BuildContext context) {
    final metadata =
        <({String label, String? value, String? category, String? id})>[
          (label: '发行日期', value: detail.releaseDate, category: null, id: null),
          (
            label: '时长',
            value: detail.duration == null ? null : '${detail.duration}分钟',
            category: null,
            id: null,
          ),
          (
            label: '导演',
            value: detail.director,
            category: 'd',
            id: detail.directorId,
          ),
          (label: '片商', value: detail.maker, category: 'm', id: detail.makerId),
          (
            label: '发行商',
            value: detail.publisher,
            category: 'p',
            id: detail.publisherId,
          ),
          (
            label: '系列',
            value: detail.series,
            category: 's',
            id: detail.seriesId,
          ),
        ];
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          key: const Key('movie-detail-info-column'),
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 6,
          children: [
            _MetadataLine(
              label: '番号',
              value: detail.number,
              onTap: _commonListCallback(
                context,
                label: '番号',
                value: detail.numberLetter,
                category: 'c',
                id: detail.numberLetter,
              ),
            ),
            for (final item in metadata)
              if (item.value != null && item.value!.isNotEmpty)
                _MetadataLine(
                  label: item.label,
                  value: item.value!,
                  onTap: _commonListCallback(
                    context,
                    label: item.label,
                    value: item.value,
                    category: item.category,
                    id: item.id,
                  ),
                ),
            if (detail.score != null)
              Row(
                spacing: 6,
                children: [
                  const Text('评分: '),
                  StarRating(score: detail.score!, semanticLabel: '影片评分'),
                  Text(detail.score!.toString()),
                ],
              ),
            for (final ranking in detail.topRankings)
              if ((ranking.title ?? '').isNotEmpty)
                TopRankingTile(
                  ranking: ranking.ranking,
                  title: ranking.title ?? '',
                ),
            MovieReviewActions(
              key: const Key('movie-detail-actions'),
              review: review,
              loading: reviewMutationLoading,
              onWantWatch: onWantWatch,
              onWatched: onWatched,
              onDelete: onDeleteReview,
              onSaveToList: onSaveToList,
            ),
            Divider(
              key: const Key('movie-detail-actions-divider'),
              height: 12,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            Text(
              '${detail.wantWatchCount}人想看，${detail.watchedCount}人看过',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  VoidCallback? _commonListCallback(
    BuildContext context, {
    required String label,
    required String? value,
    required String? category,
    required String? id,
  }) {
    final targetValue = value?.trim();
    final targetCategory = category?.trim();
    final targetId = id?.trim();
    if (targetValue == null ||
        targetValue.isEmpty ||
        targetCategory == null ||
        targetCategory.isEmpty ||
        targetId == null ||
        targetId.isEmpty) {
      return null;
    }

    return () => context.push(
      Uri(
        path: AppRoutes.commonList,
        queryParameters: {
          'title': '$label - $targetValue',
          'type': '${detail.type}',
          'category': targetCategory,
          'id': targetId,
        },
      ).toString(),
    );
  }
}

class _MetadataLine extends StatelessWidget {
  const _MetadataLine({required this.label, required this.value, this.onTap});

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final foregroundColor = Theme.of(context).colorScheme.onSurface;
    final textStyle = DefaultTextStyle.of(
      context,
    ).style.copyWith(color: foregroundColor);
    final valueText = Text(
      value,
      style: textStyle.copyWith(
        decoration: onTap == null ? null : TextDecoration.underline,
        decorationColor: foregroundColor,
      ),
    );
    final valueWidget = onTap == null
        ? valueText
        : Semantics(
            button: true,
            label: '查看$value的$label影片列表',
            excludeSemantics: true,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(4),
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: valueText,
                ),
              ),
            ),
          );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 4,
      children: [
        Text('$label:', style: textStyle),
        Flexible(child: valueWidget),
      ],
    );
  }
}

class _SaveToListSheet extends StatefulWidget {
  const _SaveToListSheet({
    required this.service,
    required this.movieId,
    required this.initialLists,
  });

  final MovieDetailService service;
  final String movieId;
  final List<ListModel> initialLists;

  @override
  State<_SaveToListSheet> createState() => _SaveToListSheetState();
}

class _SaveToListSheetState extends State<_SaveToListSheet> {
  static const int _pageSize = 48;

  final TextEditingController _nameController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final Set<String> _pendingListIds = {};
  List<ListModel> _lists = [];
  int _page = 1;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  bool _creating = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_loadMoreIfNeeded);
    _lists = widget.initialLists;
    _hasMore = widget.initialLists.length >= _pageSize;
    _loading = false;
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_loadMoreIfNeeded)
      ..dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadFirstPage() async {
    if (mounted) {
      setState(() {
        _page = 1;
        _loading = true;
        _error = null;
        _hasMore = false;
      });
    }
    try {
      final lists = await widget.service.getSimpleLists(
        widget.movieId,
        page: 1,
        limit: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        _lists = lists;
        _hasMore = lists.length >= _pageSize;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  void _loadMoreIfNeeded() {
    if (!_hasMore || _loading || _loadingMore) return;
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.extentAfter > 240) return;
    unawaited(_loadNextPage());
  }

  Future<void> _loadNextPage() async {
    setState(() => _loadingMore = true);
    final nextPage = _page + 1;
    try {
      final lists = await widget.service.getSimpleLists(
        widget.movieId,
        page: nextPage,
        limit: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        _page = nextPage;
        _lists = [..._lists, ...lists];
        _hasMore = lists.length >= _pageSize;
        _loadingMore = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
      _showMessage('清单加载失败');
    }
  }

  Future<void> _toggleList(ListModel list) async {
    if (_pendingListIds.contains(list.id)) return;
    final index = _lists.indexWhere((item) => item.id == list.id);
    if (index < 0) return;
    final nextHasMovie = !list.hasMovie;
    final nextCount = (list.movieCount + (nextHasMovie ? 1 : -1)).clamp(
      0,
      1 << 31,
    );
    setState(() {
      _pendingListIds.add(list.id);
      _lists[index] = list.copyWith(
        hasMovie: nextHasMovie,
        movieCount: nextCount,
      );
    });
    try {
      await widget.service.toggleMovieInList(
        listId: list.id,
        listName: list.name,
        movieId: widget.movieId,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _lists[index] = list);
      _showMessage(nextHasMovie ? '添加失败' : '移除失败');
    } finally {
      if (mounted) {
        setState(() => _pendingListIds.remove(list.id));
      }
    }
  }

  Future<void> _createList() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _creating) return;
    setState(() => _creating = true);
    try {
      await widget.service.createListWithMovie(
        name: name,
        movieId: widget.movieId,
      );
      if (!mounted) return;
      _nameController.clear();
      await _loadFirstPage();
    } catch (error) {
      if (!mounted) return;
      _showMessage('创建清单失败');
    } finally {
      if (mounted) {
        setState(() => _creating = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.78,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                '存入清单',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(
                spacing: 8,
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('movie-list-name-field'),
                      controller: _nameController,
                      enabled: !_creating,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => unawaited(_createList()),
                      decoration: const InputDecoration(
                        labelText: '新清单名称',
                        isDense: true,
                      ),
                    ),
                  ),
                  FilledButton(
                    key: const Key('movie-list-create-button'),
                    onPressed: _creating
                        ? null
                        : () => unawaited(_createList()),
                    child: Text(_creating ? '创建中' : '创建'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ErrorRetryWidget(message: '清单加载失败', onRetry: _loadFirstPage);
    }
    if (_lists.isEmpty) {
      return const Center(child: Text('暂无清单'));
    }
    return ListView.builder(
      controller: _scrollController,
      itemCount: _lists.length + (_loadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _lists.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final list = _lists[index];
        final pending = _pendingListIds.contains(list.id);
        return CheckboxListTile(
          value: list.hasMovie,
          onChanged: pending ? null : (_) => unawaited(_toggleList(list)),
          title: Text(list.name),
          subtitle: Text('${list.movieCount} 部影片，被查看 ${list.viewedCount} 次'),
          controlAffinity: ListTileControlAffinity.leading,
          secondary: pending
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : null,
        );
      },
    );
  }
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({required this.tags, required this.type});

  final List<Tag> tags;
  final int type;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const Key('movie-detail-categories'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 6,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '类别:',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                spacing: 4,
                children: [
                  for (final tag in tags)
                    TagChip(
                      label: tag.name,
                      compact: true,
                      onTap: tag.id.trim().isEmpty
                          ? null
                          : () => context.push(
                              Uri(
                                path: AppRoutes.commonList,
                                queryParameters: {
                                  'title': '类别 - ${tag.name}',
                                  'type': '$type',
                                  'category': 't',
                                  'id': tag.id.trim(),
                                },
                              ).toString(),
                            ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActorSection extends StatelessWidget {
  const _ActorSection({required this.actors, required this.onActorTap});

  final List<ActorSummary> actors;

  List<ActorSummary> get _sortedActors {
    final sorted = [...actors]
      ..sort((a, b) => (a.gender ?? 0).compareTo(b.gender ?? 0));
    return sorted;
  }

  final ValueChanged<ActorSummary> onActorTap;

  @override
  Widget build(BuildContext context) {
    final sorted = _sortedActors;
    final actorCardHeight = ActorCard.mainAxisExtent(context, 80);
    return _Section(
      title: '演员',
      height: actorCardHeight < 112 ? 112 : actorCardHeight,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: sorted.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, index) => SizedBox(
          width: 80,
          child: ActorCard(
            actor: sorted[index],
            onTap: () => onActorTap(sorted[index]),
          ),
        ),
      ),
    );
  }
}

class _ScreenshotSection extends StatelessWidget {
  const _ScreenshotSection({
    required this.urls,
    required this.previewCoverUrl,
    required this.previewTitle,
    required this.onPreviewTap,
  });

  final List<String> urls;
  final String? previewCoverUrl;
  final String previewTitle;
  final VoidCallback onPreviewTap;

  @override
  Widget build(BuildContext context) {
    final hasPreview = previewCoverUrl != null;
    return _Section(
      title: '预告片 / 剧照',
      height: 164,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: urls.length + (hasPreview ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, index) {
          if (index == 0 && hasPreview) {
            return Semantics(
              button: true,
              label: '播放《$previewTitle》预告片',
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Material(
                  clipBehavior: Clip.antiAlias,
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    key: const Key('movie-detail-preview'),
                    onTap: onPreviewTap,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        MovieCoverImage(
                          previewCoverUrl!,
                          variant: MovieImageVariant.cover,
                          fit: BoxFit.cover,
                        ),
                        const Center(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Color(0x99000000),
                              shape: BoxShape.circle,
                            ),
                            child: Padding(
                              padding: EdgeInsets.all(10),
                              child: Icon(
                                Icons.play_arrow_rounded,
                                key: Key('movie-detail-preview-play-icon'),
                                color: Colors.white,
                                size: 32,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }

          final screenshotIndex = index - (hasPreview ? 1 : 0);
          return Semantics(
            button: true,
            label: '查看剧照 ${screenshotIndex + 1}，共 ${urls.length} 张',
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Material(
                clipBehavior: Clip.antiAlias,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  key: Key('movie-detail-screenshot-$screenshotIndex'),
                  onTap: () => showDialog<void>(
                    context: context,
                    useSafeArea: false,
                    builder: (_) => ImageGalleryViewer(
                      urls: urls,
                      initialIndex: screenshotIndex,
                    ),
                  ),
                  child: MovieScreenshotImage(urls[screenshotIndex]),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MovieRowSection extends StatelessWidget {
  const _MovieRowSection({required this.title, required this.movies});

  final String title;
  final List<MovieSummary> movies;

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: title,
      height: 232,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        scrollDirection: Axis.horizontal,
        itemCount: movies.length,
        separatorBuilder: (_, _) => const SizedBox(width: 4),
        itemBuilder: (_, index) => SizedBox(
          width: 140,
          child: MovieCard(movie: movies[index], showTitle: false),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.height,
    required this.child,
  });

  final String title;
  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 10,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          SizedBox(height: height, child: child),
        ],
      ),
    );
  }
}

class _MagnetList extends StatelessWidget {
  const _MagnetList({
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
      return _ScrollableTabError(message: '磁链加载失败', onRetry: onRetry);
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

class _RelatedListList extends StatelessWidget {
  const _RelatedListList({
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
      return _ScrollableTabError(message: '相关清单加载失败', onRetry: onRetry);
    }
    if (lists.isEmpty) return const Center(child: Text('暂无相关清单'));
    return ListView.separated(
      key: const PageStorageKey('movie-detail-related-lists'),
      itemCount: lists.length,
      separatorBuilder: (context, index) => _detailTabDivider(context),
      itemBuilder: (_, index) {
        final list = lists[index];
        return ListSummaryTile(list: list);
      },
    );
  }
}

class _ScrollableTabError extends StatelessWidget {
  const _ScrollableTabError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: ErrorRetryWidget(message: message, onRetry: onRetry),
        ),
      ),
    );
  }
}

class _ReviewList extends StatelessWidget {
  const _ReviewList({
    required this.reviews,
    required this.loading,
    required this.sort,
    required this.onSortChanged,
  });

  final List<Review> reviews;
  final bool loading;
  final _ReviewSort sort;
  final ValueChanged<_ReviewSort> onSortChanged;

  @override
  Widget build(BuildContext context) {
    if (reviews.isEmpty) {
      return ListView(
        key: const PageStorageKey('movie-detail-reviews'),
        children: [
          _ReviewSortHeader(
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
      separatorBuilder: (context, index) => _detailTabDivider(context),
      itemBuilder: (_, index) {
        if (index == 0) {
          return _ReviewSortHeader(
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

class _ReviewSortHeader extends StatelessWidget {
  const _ReviewSortHeader({
    required this.sort,
    required this.loading,
    required this.onSortChanged,
  });

  final _ReviewSort sort;
  final bool loading;
  final ValueChanged<_ReviewSort> onSortChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ReviewSortBar(
          sort: sort,
          onSortChanged: loading ? null : onSortChanged,
        ),
        if (loading) const LinearProgressIndicator(minHeight: 2),
      ],
    );
  }
}

enum _ReviewSort {
  hotly('hotly'),
  recently('recently');

  const _ReviewSort(this.value);

  final String value;
}

class _ReviewSortBar extends StatelessWidget {
  const _ReviewSortBar({required this.sort, required this.onSortChanged});

  final _ReviewSort sort;
  final ValueChanged<_ReviewSort>? onSortChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        SegmentedButton<_ReviewSort>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: _ReviewSort.hotly, label: Text('最热')),
            ButtonSegment(value: _ReviewSort.recently, label: Text('最新')),
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

Widget _detailTabDivider(BuildContext context) {
  return Divider(
    height: 1,
    indent: 16,
    endIndent: 16,
    color: Theme.of(context).colorScheme.outlineVariant,
  );
}
