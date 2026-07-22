import 'dart:async';

import 'package:flutter/material.dart';
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

  Future<void> _loadReviews(MovieDetailService service) async {
    try {
      final reviews = await service.getReviews(widget.id);
      if (!mounted) return;
      setState(() => _reviews = reviews);
    } catch (_) {
      // 短评继续沿用空状态，不影响本次磁链与相关清单错误处理。
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
        actions: [
          IconButton(
            tooltip: '更多',
            onPressed: () {},
            icon: const Icon(Icons.more_vert),
          ),
        ],
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
          _ReviewList(reviews: reviews),
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
                children: [
                  const Text('评分: '),
                  Icon(
                    Icons.star_rounded,
                    size: 20,
                    color: Theme.of(context).colorScheme.tertiary,
                  ),
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
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final tag in tags) TagChip(label: tag, compact: true),
              ],
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
      trailing: Text('全部 ${urls.length} ›'),
      height: 164,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: urls.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, index) => AspectRatio(
          aspectRatio: 16 / 9,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: MovieScreenshotImage(urls[index]),
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
    this.trailing,
  });

  final String title;
  final double height;
  final Widget child;
  final Widget? trailing;

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
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (trailing != null)
                  DefaultTextStyle.merge(
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    child: trailing!,
                  ),
              ],
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
    return ListView.builder(
      itemCount: magnets.length,
      itemBuilder: (_, index) {
        final magnet = magnets[index];
        final metadata = [
          if (magnet.isHighDefinition) '高清',
          if (magnet.size case final size?) size,
          if (magnet.publishDate case final date?) date,
        ];
        return ListTile(
          title: Text(magnet.title ?? magnet.hash),
          subtitle: metadata.isEmpty ? null : Text(metadata.join(' · ')),
        );
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
    return ListView.builder(
      itemCount: lists.length,
      itemBuilder: (_, index) {
        final list = lists[index];
        return ListTile(
          title: Text(list.name),
          subtitle: Text('${list.movieCount} 部影片 · ${list.viewedCount} 次浏览'),
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
  const _ReviewList({required this.reviews});

  final List<Review> reviews;

  @override
  Widget build(BuildContext context) {
    if (reviews.isEmpty) return const Center(child: Text('暂无短评'));
    return ListView.builder(
      itemCount: reviews.length,
      itemBuilder: (_, index) => ListTile(
        title: Text(reviews[index].content ?? ''),
        subtitle: Text('评分: ${reviews[index].score ?? '?'}'),
      ),
    );
  }
}
