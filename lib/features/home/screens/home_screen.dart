import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/widgets/empty_state.dart';
import 'package:jade/core/widgets/error_retry_widget.dart';
import 'package:jade/core/widgets/movie_card.dart';
import 'package:jade/core/widgets/movie_cover_image.dart';
import 'package:jade/core/widgets/section_header.dart';
import 'package:jade/features/home/providers/home_provider.dart';
import 'package:jade/features/home/services/home_service.dart';
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
    provider.loadAll().then((_) {
      if (mounted) setState(() => _provider = provider);
    });
    setState(() => _provider = provider);
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

  void _showRefreshError() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('换一组失败，请重试')));
  }

  @override
  Widget build(BuildContext context) {
    final p = _provider;
    if (p == null || p.isLoading) {
      return const Scaffold(
        body: SafeArea(child: Center(child: CircularProgressIndicator())),
      );
    }
    if (p.error != null) {
      return Scaffold(
        body: SafeArea(
          child: ErrorRetryWidget(message: p.error!, onRetry: _load),
        ),
      );
    }
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(child: TofuScroll()),
            SliverToBoxAdapter(
              child: SectionHeader(title: '佳片推荐', trailing: '往期推荐', bold: true),
            ),
            if (p.recommends.isNotEmpty)
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 220,
                  child: PageView.builder(
                    itemCount: p.recommends.length,
                    itemBuilder: (_, i) => GestureDetector(
                      onTap: () => context.push('/movie/${p.recommends[i].id}'),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          MovieCoverImage(
                            p.recommends[i].coverUrl,
                            variant: MovieImageVariant.cover,
                            semanticLabel: p.recommends[i].title,
                          ),
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              color: Colors.black54,
                              padding: const EdgeInsets.all(8),
                              child: Text(
                                p.recommends[i].title,
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            SliverToBoxAdapter(
              child: SectionHeader(title: '最新上架', trailing: '全部'),
            ),
            _buildGrid(p.latest),
            _shuffleButton(
              key: const Key('home-latest-shuffle'),
              isLoading: p.isLatestRefreshing,
              onPressed: _refreshLatest,
            ),
            SliverToBoxAdapter(
              child: SectionHeader(title: '近期磁链更新', trailing: '全部'),
            ),
            _buildGrid(p.magnetUpdates),
            _shuffleButton(
              key: const Key('home-magnets-shuffle'),
              isLoading: p.isMagnetRefreshing,
              onPressed: _refreshMagnets,
            ),
          ],
        ),
      ),
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
