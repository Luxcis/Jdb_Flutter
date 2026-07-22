import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jade/core/models/actor.dart';
import 'package:jade/core/models/magnet.dart';
import 'package:jade/core/models/movie.dart';
import 'package:jade/core/models/review.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/widgets/actor_card.dart';
import 'package:jade/core/widgets/cached_image.dart';
import 'package:jade/core/widgets/error_retry_widget.dart';
import 'package:jade/core/widgets/movie_card.dart';
import 'package:jade/core/widgets/movie_cover_image.dart';
import 'package:jade/core/widgets/tag_chip.dart';
import 'package:jade/features/movie_detail/services/movie_detail_service.dart';

class MovieDetailPage extends StatefulWidget {
  const MovieDetailPage({super.key, required this.id});

  final String id;

  @override
  State<MovieDetailPage> createState() => _MovieDetailPageState();
}

class _MovieDetailPageState extends State<MovieDetailPage> {
  MovieDetail? _detail;
  List<Magnet> _magnets = [];
  List<Review> _reviews = [];
  List<MovieSummary> _mayAlsoLike = [];
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
        _detail = detail;
        _loading = false;
      });

      final magnetsFuture = _loadMagnets(service);
      final reviewsFuture = _loadReviews(service);
      final mayAlsoLikeFuture = _loadMayAlsoLike(service);
      final magnets = await magnetsFuture;
      final reviews = await reviewsFuture;
      final mayAlsoLike = await mayAlsoLikeFuture;
      if (!mounted) return;
      setState(() {
        _magnets = magnets;
        _reviews = reviews;
        _mayAlsoLike = mayAlsoLike;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<List<Magnet>> _loadMagnets(MovieDetailService service) async {
    try {
      return await service.getMagnets(widget.id);
    } catch (_) {
      return const [];
    }
  }

  Future<List<Review>> _loadReviews(MovieDetailService service) async {
    try {
      return await service.getReviews(widget.id);
    } catch (_) {
      return const [];
    }
  }

  Future<List<MovieSummary>> _loadMayAlsoLike(
    MovieDetailService service,
  ) async {
    try {
      return await service.getMayAlsoLike(widget.id);
    } catch (_) {
      return const [];
    }
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
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _MovieHero(detail: detail)),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            sliver: SliverToBoxAdapter(child: _MovieInfoCard(detail: detail)),
          ),
          if (detail.tags.isNotEmpty)
            SliverToBoxAdapter(child: _CategorySection(tags: detail.tags)),
          if (detail.actors.isNotEmpty)
            SliverToBoxAdapter(
              child: _ActorSection(
                actors: detail.actors,
                onActorTap: (actor) => context.push('/actor/${actor.id}'),
              ),
            ),
          if (detail.screenshots.isNotEmpty)
            SliverToBoxAdapter(
              child: _ScreenshotSection(urls: detail.screenshots),
            ),
          if (_mayAlsoLike.isNotEmpty)
            SliverToBoxAdapter(
              child: _MovieRowSection(
                title: 'TA还出演过',
                movies: _mayAlsoLike,
                onMovieTap: (movie) => context.push('/movie/${movie.id}'),
              ),
            ),
          if (_mayAlsoLike.isNotEmpty)
            SliverToBoxAdapter(
              child: _MovieRowSection(
                title: '你可能也喜欢',
                movies: _mayAlsoLike,
                onMovieTap: (movie) => context.push('/movie/${movie.id}'),
              ),
            ),
          SliverToBoxAdapter(
            child: _AuxiliaryTabs(magnets: _magnets, reviews: _reviews),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
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

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 8,
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
                  Text(detail.score!.toStringAsFixed(1)),
                ],
              ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(onPressed: () {}, child: const Text('想看')),
                FilledButton(onPressed: () {}, child: const Text('看过')),
                FilledButton(onPressed: () {}, child: const Text('存入清单')),
              ],
            ),
            Divider(color: Theme.of(context).colorScheme.outlineVariant),
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '类别:',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [for (final tag in tags) TagChip(label: tag)],
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
            child: CachedImage(urls[index]),
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

class _AuxiliaryTabs extends StatelessWidget {
  const _AuxiliaryTabs({required this.magnets, required this.reviews});

  final List<Magnet> magnets;
  final List<Review> reviews;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: SizedBox(
        height: 320,
        child: Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: DefaultTabController(
            length: 3,
            child: Column(
              children: [
                const TabBar(
                  tabs: [
                    Tab(text: '磁链下载'),
                    Tab(text: '短评'),
                    Tab(text: '相关清单'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _MagnetList(magnets: magnets),
                      _ReviewList(reviews: reviews),
                      const Center(child: Text('相关清单')),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MagnetList extends StatelessWidget {
  const _MagnetList({required this.magnets});

  final List<Magnet> magnets;

  @override
  Widget build(BuildContext context) {
    if (magnets.isEmpty) return const Center(child: Text('暂无磁链'));
    return ListView.builder(
      itemCount: magnets.length,
      itemBuilder: (_, index) => ListTile(
        title: Text(magnets[index].title ?? magnets[index].hash),
        subtitle: Text(magnets[index].size ?? ''),
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
