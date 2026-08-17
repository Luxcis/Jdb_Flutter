import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/router/routes.dart';
import 'package:jade/core/widgets/empty_state.dart';
import 'package:jade/core/widgets/error_retry_widget.dart';
import 'package:jade/core/widgets/movie_card.dart';
import 'package:jade/core/widgets/search_entry.dart';
import 'package:jade/core/widgets/section_header.dart';
import 'package:jade/features/home/providers/home_provider.dart';
import 'package:jade/features/home/services/home_service.dart';
import 'package:jade/features/home/widgets/recommend_carousel.dart';
import 'package:jade/features/home/widgets/tofu_scroll.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  HomeProvider? _provider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _load() {
    final api = ApiClient.instanceOrNull;
    if (api == null) return;
    final provider = HomeProvider(HomeService(api));
    setState(() => _provider = provider);
    for (final kind in HomeSectionKind.values) {
      provider.loadSection(kind).then((_) {
        if (mounted) setState(() {});
      });
    }
  }

  Future<void> _retrySection(HomeSectionKind kind) async {
    final provider = _provider;
    if (provider == null) return;
    setState(() {});
    await provider.retrySection(kind);
    if (mounted) setState(() {});
  }

  Future<void> _refreshLatest() async {
    final provider = _provider;
    if (provider == null || provider.isLatestRefreshing) return;
    final refresh = provider.reshuffleLatest();
    setState(() {});
    try {
      await refresh;
    } catch (_) {
      if (mounted) _showRefreshError();
    } finally {
      if (mounted) setState(() {});
    }
  }

  Future<void> _refreshMagnets() async {
    final provider = _provider;
    if (provider == null || provider.isMagnetRefreshing) return;
    final refresh = provider.reshuffleMagnets();
    setState(() {});
    try {
      await refresh;
    } catch (_) {
      if (mounted) _showRefreshError();
    } finally {
      if (mounted) setState(() {});
    }
  }

  void _openHistoryRecommend() {
    context.push(AppRoutes.historyRecommend);
  }

  void _showRefreshError() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('换一组失败，请重试')));
  }

  @override
  Widget build(BuildContext context) {
    final p = _provider;
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(child: HomeSearchBar()),
            const SliverToBoxAdapter(child: TofuScroll()),
            SliverToBoxAdapter(
              child: SectionHeader(
                title: '佳片推荐',
                trailing: '往期推荐',
                bold: true,
                onTrailing: _openHistoryRecommend,
              ),
            ),
            _recommendSection(p?.recommends),
            SliverToBoxAdapter(
              child: SectionHeader(
                title: '最新上架',
                trailing: '全部',
                onTrailing: () => context.push(
                  Uri(
                    path: AppRoutes.latestMovies,
                    queryParameters: {
                      'section': 'latest',
                      'title': '最新影片',
                    },
                  ).toString(),
                ),
              ),
            ),
            _gridSection(p?.latest, kind: HomeSectionKind.latest),
            _shuffleButton(
              key: const Key('home-latest-shuffle'),
              isLoading: p?.isLatestRefreshing ?? false,
              onPressed: _refreshLatest,
            ),
            SliverToBoxAdapter(
              child: SectionHeader(
                title: '近期磁链更新',
                trailing: '全部',
                onTrailing: () => context.push(
                  Uri(
                    path: AppRoutes.latestMovies,
                    queryParameters: {
                      'section': 'magnets',
                      'title': '磁链更新',
                    },
                  ).toString(),
                ),
              ),
            ),
            _gridSection(p?.magnetUpdates, kind: HomeSectionKind.magnets),
            _shuffleButton(
              key: const Key('home-magnets-shuffle'),
              isLoading: p?.isMagnetRefreshing ?? false,
              onPressed: _refreshMagnets,
            ),
          ],
        ),
      ),
    );
  }

  Widget _recommendSection(HomeSection? section) {
    if (section == null || section.isLoading) {
      return _sectionLoading(
        height: 220,
        key: const Key('home-loading-recommends'),
      );
    }
    if (section.error != null) {
      return _sectionError(
        message: section.error!,
        onRetry: () => _retrySection(HomeSectionKind.recommends),
      );
    }
    if (section.isEmpty) return const SliverToBoxAdapter(child: EmptyState());
    return SliverToBoxAdapter(
      child: SizedBox(
        height: 220,
        child: RecommendCarousel(
          movies: section.items,
          onMovieTap: (movie) => context.push('/movie/${movie.id}'),
        ),
      ),
    );
  }

  Widget _gridSection(HomeSection? section, {required HomeSectionKind kind}) {
    if (section == null || section.isLoading) {
      return _sectionLoading(
        height: 640,
        key: Key('home-loading-${kind.name}'),
      );
    }
    if (section.error != null) {
      return _sectionError(
        message: section.error!,
        onRetry: () => _retrySection(kind),
      );
    }
    return _buildGrid(section.items);
  }

  Widget _sectionLoading({required double height, required Key key}) {
    return SliverToBoxAdapter(
      child: SizedBox(
        height: height,
        key: key,
        child: const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget _sectionError({
    required String message,
    required VoidCallback onRetry,
  }) {
    return SliverToBoxAdapter(
      child: ErrorRetryWidget(message: message, onRetry: onRetry),
    );
  }

  Widget _buildGrid(List items) {
    if (items.isEmpty) return const SliverToBoxAdapter(child: EmptyState());
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 0.56,
        ),
        delegate: SliverChildBuilderDelegate(
          (_, index) => MovieCard(movie: items[index]),
          childCount: items.length > 9 ? 9 : items.length,
        ),
      ),
    );
  }

  Widget _shuffleButton({
    required Key key,
    required bool isLoading,
    required VoidCallback onPressed,
  }) {
    return SliverToBoxAdapter(
      child: SizedBox(
        height: 72,
        child: Center(
          child: TextButton(
            key: key,
            onPressed: isLoading ? null : onPressed,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 6,
              children: [
                const Text('换一组'),
                if (isLoading)
                  const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  const Icon(Icons.refresh),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
