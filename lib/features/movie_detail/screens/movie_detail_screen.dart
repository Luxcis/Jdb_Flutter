import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/models/movie.dart';
import 'package:jade/core/models/magnet.dart';
import 'package:jade/core/models/review.dart';
import 'package:jade/core/widgets/cached_image.dart';
import 'package:jade/core/widgets/actor_card.dart';
import 'package:jade/core/widgets/movie_card.dart';
import 'package:jade/core/widgets/error_retry_widget.dart';
import 'package:jade/core/widgets/tag_chip.dart';
import 'package:jade/features/movie_detail/services/movie_detail_service.dart';

class MovieDetailPage extends StatefulWidget {
  final String id;
  const MovieDetailPage({super.key, required this.id});

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
  void initState() { super.initState(); _load(); }

  void _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final api = ApiClient.instanceOrNull; if (api == null) return;
      final svc = MovieDetailService(api);
      final detail = await svc.getDetail(widget.id);
      if (!mounted) return;
      setState(() { _detail = detail; _loading = false; });
      final results = await Future.wait([svc.getMagnets(widget.id), svc.getReviews(widget.id), svc.getMayAlsoLike(widget.id)]);
      if (mounted) setState(() { _magnets = results[0] as List<Magnet>; _reviews = results[1] as List<Review>; _mayAlsoLike = results[2] as List<MovieSummary>; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_error != null) return Scaffold(body: ErrorRetryWidget(message: _error!, onRetry: _load));
    final d = _detail!;
    return Scaffold(
      appBar: AppBar(title: Text(d.title, maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: CustomScrollView(slivers: [
        SliverToBoxAdapter(child: SizedBox(height: 300, child: CachedImage(d.coverUrl))),
        SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('番号: ${d.number}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 4),
          if (d.releaseDate != null) Text('发行日期: ${d.releaseDate}'),
          if (d.duration != null) Text('时长: ${d.duration}分钟'),
          if (d.director != null) Text('导演: ${d.director}'),
          if (d.maker != null) Text('片商: ${d.maker}'),
          if (d.score != null) Text('评分: ${d.score}'),
          const SizedBox(height: 12),
          Row(children: [
            ElevatedButton(onPressed: () {}, child: const Text('想看')),
            const SizedBox(width: 8),
            ElevatedButton(onPressed: () {}, child: const Text('看过')),
          ]),
          Text('${d.wantWatchCount}人想看, ${d.watchedCount}人看过', style: const TextStyle(color: Colors.grey)),
          if (d.tags.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Wrap(spacing: 4, children: d.tags.map((t) => TagChip(label: t)).toList())),
        ]))),
        if (d.actors.isNotEmpty) SliverToBoxAdapter(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(padding: EdgeInsets.all(12), child: Text('演员', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
          SizedBox(height: 110, child: ListView.builder(scrollDirection: Axis.horizontal, itemCount: d.actors.length,
            itemBuilder: (_, i) => Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: ActorCard(actor: d.actors[i], onTap: () => context.go('/actor/${d.actors[i].id}'))))),
        ])),
        if (_mayAlsoLike.isNotEmpty) SliverToBoxAdapter(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(padding: EdgeInsets.all(12), child: Text('你可能也喜欢', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
          SizedBox(height: 220, child: ListView.builder(scrollDirection: Axis.horizontal, itemCount: _mayAlsoLike.length,
            itemBuilder: (_, i) => SizedBox(width: 130, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: MovieCard(movie: _mayAlsoLike[i], onTap: () => context.go('/movie/${_mayAlsoLike[i].id}')))))),
        ])),
        const SliverToBoxAdapter(child: SizedBox(height: 60)),
      ]),
      bottomSheet: DraggableScrollableSheet(initialChildSize: 0.06, minChildSize: 0.06, maxChildSize: 0.5,
        builder: (_, scroll) => Column(children: [
          Container(margin: const EdgeInsets.symmetric(vertical: 6), height: 4, width: 32, decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2))),
          Expanded(child: DefaultTabController(length: 3, child: Column(children: [
            const TabBar(tabs: [Tab(text: '磁链'), Tab(text: '短评'), Tab(text: '清单')]),
            Expanded(child: TabBarView(children: [
              ListView.builder(itemCount: _magnets.length, itemBuilder: (_, i) => ListTile(title: Text(_magnets[i].title ?? _magnets[i].hash), subtitle: Text(_magnets[i].size ?? ''))),
              ListView.builder(itemCount: _reviews.length, itemBuilder: (_, i) => ListTile(title: Text(_reviews[i].content ?? ''), subtitle: Text('评分: ${_reviews[i].score ?? '?'}'))),
              const Center(child: Text('相关清单')),
            ])),
          ]))),
        ])),
    );
  }
}
