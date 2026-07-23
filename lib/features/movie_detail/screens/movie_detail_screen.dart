import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:jade/core/models/actor.dart';
import 'package:jade/core/models/list_model.dart';
import 'package:jade/core/models/magnet.dart';
import 'package:jade/core/models/movie.dart';
import 'package:jade/core/models/review.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/widgets/actor_card.dart';
import 'package:jade/core/widgets/error_retry_widget.dart';
import 'package:jade/core/widgets/movie_card.dart';
import 'package:jade/core/widgets/movie_cover_image.dart';
import 'package:jade/core/widgets/movie_screenshot_image.dart';
import 'package:jade/core/widgets/star_rating.dart';
import 'package:jade/core/widgets/tag_chip.dart';
import 'package:jade/features/movie_detail/services/movie_detail_service.dart';

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
    return Scaffold(
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
          onActorTap: (actor) => context.push('/actor/${actor.id}'),
          onMovieTap: (movie) => context.push('/movie/${movie.id}'),
        ),
      ),
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
    required this.onActorTap,
    required this.onMovieTap,
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
  final ValueChanged<ActorSummary> onActorTap;
  final ValueChanged<MovieSummary> onMovieTap;

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
            onActorTap: onActorTap,
            onMovieTap: onMovieTap,
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
    required this.onActorTap,
    required this.onMovieTap,
  });

  final MovieDetail detail;
  final ValueChanged<ActorSummary> onActorTap;
  final ValueChanged<MovieSummary> onMovieTap;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const PageStorageKey('movie-detail-basic-info'),
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: _MovieInfoCard(detail: detail),
        ),
        if (detail.tags.isNotEmpty) _CategorySection(tags: detail.tags),
        if (detail.actors.isNotEmpty)
          _ActorSection(actors: detail.actors, onActorTap: onActorTap),
        if (detail.screenshots.isNotEmpty)
          _ScreenshotSection(urls: detail.screenshots),
        if (detail.actorMovies.isNotEmpty)
          _MovieRowSection(
            title: 'TA还出演过',
            movies: detail.actorMovies,
            onMovieTap: onMovieTap,
          ),
        if (detail.relativeMovies.isNotEmpty)
          _MovieRowSection(
            title: '你可能也喜欢',
            movies: detail.relativeMovies,
            onMovieTap: onMovieTap,
          ),
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
  const _MovieInfoCard({required this.detail});

  final MovieDetail detail;

  @override
  Widget build(BuildContext context) {
    final metadata = <(String, String?)>[
      ('发行日期', detail.releaseDate),
      ('时长', detail.duration == null ? null : '${detail.duration}分钟'),
      ('导演', detail.director),
      ('片商', detail.maker),
      ('系列', detail.series),
    ];
    final actionStyle = FilledButton.styleFrom(
      minimumSize: const Size(0, 32),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      visualDensity: VisualDensity.compact,
      textStyle: Theme.of(context).textTheme.labelMedium,
    );

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          key: const Key('movie-detail-info-column'),
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 6,
          children: [
            _MetadataLine(label: '番号', value: detail.number),
            for (final (label, value) in metadata)
              if (value != null && value.isNotEmpty)
                _MetadataLine(label: label, value: value),
            if (detail.score != null)
              Row(
                spacing: 6,
                children: [
                  const Text('评分: '),
                  StarRating(score: detail.score!, semanticLabel: '影片评分'),
                  Text(detail.score!.toString()),
                ],
              ),
            Wrap(
              key: const Key('movie-detail-actions'),
              spacing: 8,
              runSpacing: 6,
              children: [
                FilledButton(
                  style: actionStyle,
                  onPressed: () {},
                  child: const Text('想看'),
                ),
                FilledButton(
                  style: actionStyle,
                  onPressed: () {},
                  child: const Text('看过'),
                ),
                FilledButton(
                  style: actionStyle,
                  onPressed: () {},
                  child: const Text('存入清单'),
                ),
              ],
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
}

class _MetadataLine extends StatelessWidget {
  const _MetadataLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Text('$label: $value');
  }
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({required this.tags});

  final List<String> tags;

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
                  for (final tag in tags) TagChip(label: tag, compact: true),
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
  final ValueChanged<ActorSummary> onActorTap;

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: '演员',
      height: 112,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: actors.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, index) => SizedBox(
          width: 80,
          child: ActorCard(
            actor: actors[index],
            onTap: () => onActorTap(actors[index]),
          ),
        ),
      ),
    );
  }
}

class _ScreenshotSection extends StatelessWidget {
  const _ScreenshotSection({required this.urls});

  final List<String> urls;

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: '预告片 / 剧照',
      height: 164,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: urls.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, index) => Semantics(
          button: true,
          label: '查看剧照 ${index + 1}，共 ${urls.length} 张',
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Material(
              clipBehavior: Clip.antiAlias,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                key: Key('movie-detail-screenshot-$index'),
                onTap: () => showDialog<void>(
                  context: context,
                  useSafeArea: false,
                  builder: (_) =>
                      _ScreenshotViewer(urls: urls, initialIndex: index),
                ),
                child: MovieScreenshotImage(urls[index]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ScreenshotViewer extends StatefulWidget {
  const _ScreenshotViewer({required this.urls, required this.initialIndex});

  final List<String> urls;
  final int initialIndex;

  @override
  State<_ScreenshotViewer> createState() => _ScreenshotViewerState();
}

class _ScreenshotViewerState extends State<_ScreenshotViewer> {
  late final PageController _controller;
  final Map<int, bool> _zoomedPages = {};
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleZoomChanged(int index, bool zoomed) {
    if (_zoomedPages[index] == zoomed) return;
    setState(() => _zoomedPages[index] = zoomed);
  }

  bool _handleBoundarySwipe(int index, _ScreenshotPageDirection direction) {
    final targetIndex = switch (direction) {
      _ScreenshotPageDirection.previous => index - 1,
      _ScreenshotPageDirection.next => index + 1,
    };
    if (targetIndex < 0 || targetIndex >= widget.urls.length) return false;
    unawaited(
      _controller.animateToPage(
        targetIndex,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      ),
    );
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      key: const Key('movie-screenshot-viewer'),
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          leading: IconButton(
            tooltip: '关闭',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
          ),
          title: Text('${_currentIndex + 1} / ${widget.urls.length}'),
          centerTitle: true,
        ),
        body: PageView.builder(
          key: const Key('movie-screenshot-pages'),
          controller: _controller,
          physics: _zoomedPages[_currentIndex] ?? false
              ? const NeverScrollableScrollPhysics()
              : const PageScrollPhysics(),
          itemCount: widget.urls.length,
          onPageChanged: (index) => setState(() => _currentIndex = index),
          itemBuilder: (_, index) => _ZoomableScreenshot(
            key: ValueKey(widget.urls[index]),
            url: widget.urls[index],
            index: index,
            onZoomChanged: (zoomed) => _handleZoomChanged(index, zoomed),
            onBoundarySwipe: (direction) =>
                _handleBoundarySwipe(index, direction),
          ),
        ),
      ),
    );
  }
}

enum _ScreenshotPageDirection { previous, next }

class _ZoomableScreenshot extends StatefulWidget {
  const _ZoomableScreenshot({
    super.key,
    required this.url,
    required this.index,
    required this.onZoomChanged,
    required this.onBoundarySwipe,
  });

  final String url;
  final int index;
  final ValueChanged<bool> onZoomChanged;
  final bool Function(_ScreenshotPageDirection direction) onBoundarySwipe;

  @override
  State<_ZoomableScreenshot> createState() => _ZoomableScreenshotState();
}

class _ZoomableScreenshotState extends State<_ZoomableScreenshot> {
  late final TransformationController _transformationController;
  Offset? _doubleTapPosition;
  bool _isZoomed = false;
  bool _pageSwitchTriggered = false;
  double _boundaryDragDistance = 0;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    _transformationController.addListener(_handleTransformationChanged);
  }

  @override
  void dispose() {
    _transformationController.removeListener(_handleTransformationChanged);
    _transformationController.dispose();
    super.dispose();
  }

  void _handleTransformationChanged() {
    final zoomed = _transformationController.value.getMaxScaleOnAxis() > 1.01;
    if (_isZoomed == zoomed) return;
    _isZoomed = zoomed;
    widget.onZoomChanged(zoomed);
  }

  void _handleDoubleTapDown(TapDownDetails details) {
    _doubleTapPosition = details.localPosition;
  }

  void _handleDoubleTap() {
    if (_isZoomed) {
      _transformationController.value = Matrix4.identity();
      return;
    }
    final size = context.size;
    final position = _doubleTapPosition;
    if (size == null || position == null) return;
    const scale = 2.5;
    final translationX = (-position.dx * (scale - 1)).clamp(
      size.width * (1 - scale),
      0.0,
    );
    final translationY = (-position.dy * (scale - 1)).clamp(
      size.height * (1 - scale),
      0.0,
    );
    _transformationController.value = Matrix4.identity()
      ..setEntry(0, 0, scale)
      ..setEntry(1, 1, scale)
      ..setEntry(0, 3, translationX)
      ..setEntry(1, 3, translationY);
  }

  void _handleInteractionUpdate(ScaleUpdateDetails details) {
    if (!_isZoomed || _pageSwitchTriggered) return;
    final size = context.size;
    if (size == null) return;
    final matrix = _transformationController.value;
    final scale = matrix.getMaxScaleOnAxis();
    final translationX = matrix.storage[12];
    final minimumTranslationX = size.width * (1 - scale);
    final horizontalDelta = details.focalPointDelta.dx;
    const edgeTolerance = 1.0;
    final draggingPastPrevious =
        translationX >= -edgeTolerance && horizontalDelta > 0;
    final draggingPastNext =
        translationX <= minimumTranslationX + edgeTolerance &&
        horizontalDelta < 0;

    if (!draggingPastPrevious && !draggingPastNext) {
      _boundaryDragDistance = 0;
      return;
    }
    _boundaryDragDistance += horizontalDelta.abs();
    if (_boundaryDragDistance < 48) return;
    final direction = draggingPastPrevious
        ? _ScreenshotPageDirection.previous
        : _ScreenshotPageDirection.next;
    _pageSwitchTriggered = widget.onBoundarySwipe(direction);
    _boundaryDragDistance = 0;
  }

  void _handleInteractionEnd(ScaleEndDetails details) {
    _boundaryDragDistance = 0;
    _pageSwitchTriggered = false;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onDoubleTapDown: _handleDoubleTapDown,
      onDoubleTap: _handleDoubleTap,
      child: InteractiveViewer(
        key: Key('movie-screenshot-zoom-${widget.index}'),
        transformationController: _transformationController,
        minScale: 1,
        maxScale: 4,
        onInteractionUpdate: _handleInteractionUpdate,
        onInteractionEnd: _handleInteractionEnd,
        child: SizedBox.expand(
          child: MovieScreenshotImage(
            widget.url,
            key: Key('movie-screenshot-page-${widget.index}'),
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}

class _MovieRowSection extends StatelessWidget {
  const _MovieRowSection({
    required this.title,
    required this.movies,
    required this.onMovieTap,
  });

  final String title;
  final List<MovieSummary> movies;
  final ValueChanged<MovieSummary> onMovieTap;

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
          child: MovieCard(
            movie: movies[index],
            showTitle: false,
            onTap: () => onMovieTap(movies[index]),
          ),
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
      separatorBuilder: (context, index) => _detailTabDivider(context),
      itemBuilder: (_, index) {
        final magnet = magnets[index];
        return _MagnetTile(magnet: magnet);
      },
    );
  }
}

class _MagnetTile extends StatelessWidget {
  const _MagnetTile({required this.magnet});

  final Magnet magnet;

  String get _magnetUri {
    final hash = magnet.hash.trim();
    return hash.startsWith('magnet:?') ? hash : 'magnet:?xt=urn:btih:$hash';
  }

  Future<void> _copyMagnet(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: _magnetUri));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('磁力链接已复制')));
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final subtitle = [
      '${magnet.filesCount} 个文件',
      if (magnet.size != null && magnet.size!.isNotEmpty) magnet.size!,
    ].join(' / ');
    return Semantics(
      button: true,
      label: '复制磁力链接 ${magnet.title ?? magnet.hash}',
      child: InkWell(
        onTap: () => _copyMagnet(context),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 10,
            children: [
              Row(
                spacing: 10,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.file_download_outlined,
                    size: 22,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  Expanded(
                    child: Text(
                      magnet.title ?? magnet.hash,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (magnet.isHighDefinition) const _InfoBadge(label: '高清'),
                  if (magnet.hasSubtitle)
                    const _InfoBadge(
                      label: '字幕',
                      colorRole: _BadgeColorRole.pink,
                    ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      subtitle,
                      style: textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  if (magnet.publishDate != null)
                    Text(
                      magnet.publishDate!,
                      style: textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
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
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 10,
          ),
          title: Text(
            list.name,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('${list.movieCount} 部影片，被查看 ${list.viewedCount} 次'),
          ),
          trailing: const Icon(Icons.chevron_right),
        );
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
        return _ReviewTile(review: reviews[index - 1]);
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

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.review});

  final Review review;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final authorName = review.author?.name ?? '';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          Row(
            spacing: 8,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (authorName.isNotEmpty)
                Text(
                  authorName,
                  style: textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              if (review.watchedCount > 0)
                Expanded(
                  child: Text(
                    '看过${review.watchedCount}部影片',
                    style: textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              else
                const Spacer(),
              if (review.score != null)
                StarRating(
                  score: review.score!,
                  semanticLabel: '$authorName 短评评分',
                  size: 17,
                ),
            ],
          ),
          if (review.content != null && review.content!.isNotEmpty)
            Text(review.content!, style: textTheme.bodyLarge),
          Row(
            children: [
              Icon(
                Icons.thumb_up_alt_outlined,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 4),
              Text(
                review.likedCount.toString(),
                style: textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              if (review.createdAt != null)
                Text(
                  review.createdAt!,
                  style: textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ],
      ),
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

enum _BadgeColorRole { blue, pink }

class _InfoBadge extends StatelessWidget {
  const _InfoBadge({
    required this.label,
    this.colorRole = _BadgeColorRole.blue,
  });

  final String label;
  final _BadgeColorRole colorRole;

  @override
  Widget build(BuildContext context) {
    final (foreground, background) = switch (colorRole) {
      _BadgeColorRole.blue => (
        Theme.of(context).colorScheme.primary,
        Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.35),
      ),
      _BadgeColorRole.pink => (Colors.pink.shade600, Colors.pink.shade50),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: foreground,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
