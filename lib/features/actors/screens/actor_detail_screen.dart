import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jade/core/models/actor.dart';
import 'package:jade/core/models/movie.dart';
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/widgets/cached_image.dart';
import 'package:jade/core/widgets/movie_grid_view.dart';
import 'package:jade/core/widgets/pagination_controller.dart';
import 'package:jade/features/actors/services/actor_service.dart';

class ActorDetailPage extends StatefulWidget {
  const ActorDetailPage({super.key, required this.id});

  final String id;

  @override
  State<ActorDetailPage> createState() => _ActorDetailPageState();
}

class _ActorDetailPageState extends State<ActorDetailPage> {
  late final PaginationController<MovieSummary> _moviesController;
  ActorDetail? _detail;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _moviesController = PaginationController<MovieSummary>(
      fetch: (page) async {
        final api = ApiClient.instanceOrNull;
        if (api == null) {
          return const PagedResult(
            items: [],
            currentPage: 1,
            totalPages: 1,
            total: 0,
          );
        }
        return ActorService(api).getActorMovies(widget.id, page: page);
      },
    );
    _load();
  }

  Future<void> _load() async {
    final api = ApiClient.instanceOrNull;
    if (api == null) {
      setState(() {
        _detail = ActorDetail(id: widget.id, name: '演员详情', avatarUrl: '');
        _isLoading = false;
      });
      return;
    }

    try {
      final detail = await ActorService(api).getDetail(widget.id);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _isLoading = false;
      });
      await _moviesController.fetchMore();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('演员详情')),
        body: Center(child: Text(_error!)),
      );
    }

    final detail = _detail!;
    return Scaffold(
      appBar: AppBar(
        title: Text(detail.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      endDrawer: _ActorInfoDrawer(detail: detail),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                SizedBox(
                  width: 84,
                  height: 84,
                  child: ClipOval(child: CachedImage(detail.avatarUrl)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        detail.name,
                        style: Theme.of(context).textTheme.titleLarge,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Text('出演过 ${detail.movieCount} 部影片'),
                    ],
                  ),
                ),
                Builder(
                  builder: (context) => TextButton(
                    onPressed: () => Scaffold.of(context).openEndDrawer(),
                    child: const Text('更多信息'),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: MovieGridView(
              controller: _moviesController,
              onMovieTap: (movie) => context.go('/movie/${movie.id}'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActorInfoDrawer extends StatelessWidget {
  const _ActorInfoDrawer({required this.detail});

  final ActorDetail detail;

  @override
  Widget build(BuildContext context) {
    final rows = [
      ('姓名', detail.name),
      ('出演过', '${detail.movieCount} 部影片'),
      ('生日', detail.birthday ?? '-'),
      ('年龄', detail.age?.toString() ?? '-'),
      ('身高', detail.height ?? '-'),
      ('罩杯', detail.cup ?? '-'),
      ('胸围', detail.bust ?? '-'),
      ('腰围', detail.waist ?? '-'),
      ('臀围', detail.hip ?? '-'),
      ('出生地', detail.birthplace ?? '-'),
    ];
    return Drawer(
      child: SafeArea(
        child: ListView(
          children: [
            const ListTile(title: Text('更多信息')),
            ...rows.map(
              (row) => ListTile(title: Text(row.$1), subtitle: Text(row.$2)),
            ),
          ],
        ),
      ),
    );
  }
}
