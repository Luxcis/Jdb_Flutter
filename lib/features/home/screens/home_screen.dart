import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jade/core/widgets/section_header.dart';
import 'package:jade/core/widgets/movie_card.dart';
import 'package:jade/core/widgets/empty_state.dart';
import 'package:jade/core/widgets/error_retry_widget.dart';
import 'package:jade/features/home/widgets/tofu_scroll.dart';
import 'package:jade/features/home/providers/home_provider.dart';
import 'package:jade/features/home/services/home_service.dart';
import 'package:jade/core/network/api_client.dart';

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
    final api = ApiClient.instance;
    final provider = HomeProvider(HomeService(api));
    provider.loadAll().then((_) {
      if (mounted) setState(() => _provider = provider);
    });
    setState(() => _provider = provider);
  }

  @override
  Widget build(BuildContext context) {
    final p = _provider;
    if (p == null || p.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (p.error != null) {
      return Scaffold(body: ErrorRetryWidget(message: p.error!, onRetry: _load));
    }
    return Scaffold(
      body: CustomScrollView(slivers: [
        const SliverToBoxAdapter(child: TofuScroll()),
        SliverToBoxAdapter(child: SectionHeader(
          title: '佳片推荐', trailing: '往期推荐', bold: true,
        )),
        if (p.recommends.isNotEmpty)
          SliverToBoxAdapter(
            child: SizedBox(
              height: 220,
              child: PageView.builder(
                itemCount: p.recommends.length,
                itemBuilder: (_, i) => GestureDetector(
                  onTap: () => context.go('/movie/${p.recommends[i].id}'),
                  child: Stack(fit: StackFit.expand, children: [
                    Image.network(p.recommends[i].coverUrl, fit: BoxFit.cover),
                    Positioned(bottom: 0, left: 0, right: 0,
                      child: Container(color: Colors.black54,
                        padding: const EdgeInsets.all(8),
                        child: Text(p.recommends[i].title,
                          style: const TextStyle(color: Colors.white)))),
                  ]),
                ),
              ),
            ),
          ),
        SliverToBoxAdapter(child: SectionHeader(
          title: '最新上架', trailing: '全部',
        )),
        _buildGrid(p.latest, () => p.reshuffleLatest()),
        SliverToBoxAdapter(child: SectionHeader(
          title: '近期磁链更新', trailing: '全部',
        )),
        _buildGrid(p.magnetUpdates, () => p.reshuffleMagnets()),
      ]),
    );
  }

  Widget _buildGrid(List items, VoidCallback onShuffle) {
    if (items.isEmpty) return const SliverToBoxAdapter(child: EmptyState());
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, mainAxisSpacing: 8, crossAxisSpacing: 8,
          childAspectRatio: 0.56,
        ),
        delegate: SliverChildBuilderDelegate(
          (_, i) => MovieCard(movie: items[i],
            onTap: () => context.go('/movie/${items[i].id}')),
          childCount: items.length > 9 ? 9 : items.length,
        ),
      ),
    );
  }
}
