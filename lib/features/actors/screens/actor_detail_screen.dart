import 'package:flutter/material.dart';
import 'package:jade/core/models/actor.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/widgets/actor_avatar_image.dart';
import 'package:jade/core/widgets/movie_grid_view.dart';
import 'package:jade/features/actors/services/actor_movie_controller.dart';
import 'package:jade/features/actors/services/actor_service.dart';
import 'package:jade/features/actors/widgets/actor_movie_filter_sheet.dart';

class ActorDetailPage extends StatefulWidget {
  const ActorDetailPage({super.key, required this.id});

  final String id;

  @override
  State<ActorDetailPage> createState() => _ActorDetailPageState();
}

class _ActorDetailPageState extends State<ActorDetailPage> {
  ActorMovieController? _controller;
  ActorDetail? _detail;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = ApiClient.instanceOrNull;
    if (api == null) {
      if (!mounted) return;
      setState(() {
        _detail = ActorDetail(
          id: widget.id,
          name: '演员详情',
          avatarUrl: '',
        );
        _isLoading = false;
      });
      return;
    }

    try {
      final detail = await ActorService(api).getDetail(widget.id);
      if (!mounted) return;
      final type = detail.type;
      setState(() {
        _detail = detail;
        _isLoading = false;
      });
      if (type != null) {
        final controller = ActorMovieController(
          actorId: widget.id,
          type: type,
          filterTags: detail.filterTags,
          tags: detail.tags,
          service: ActorService(api),
        );
        _controller = controller;
        await controller.initialize();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _showInfo() {
    final detail = _detail;
    if (detail == null) return;
    final height = MediaQuery.sizeOf(context).height / 3;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      constraints: BoxConstraints.tightFor(height: height),
      builder: (_) => _ActorInfoContent(detail: detail),
    );
  }

  void _showFilter() {
    final controller = _controller;
    if (controller == null) return;
    final height = MediaQuery.sizeOf(context).height * 2 / 3;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      constraints: BoxConstraints.tightFor(height: height),
      builder: (_) => ActorMovieFilterSheet(controller: controller),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('演员详情')),
        body: Center(child: Text(_error!)),
      );
    }

    final detail = _detail!;
    final controller = _controller;
    return Scaffold(
      appBar: AppBar(
        title: const Text('演员详情'),
        actions: [
          IconButton(
            tooltip: '筛选',
            onPressed: _showFilter,
            icon: const Icon(Icons.filter_alt_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                SizedBox(
                  width: 84,
                  height: 84,
                  child: ActorAvatarImage(detail),
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
                TextButton(
                  onPressed: _showInfo,
                  child: const Text('更多信息'),
                ),
              ],
            ),
          ),
          Expanded(
            child: controller != null
                ? MovieGridView(controller: controller.movies)
                : const Center(child: Text('暂无影片数据')),
          ),
        ],
      ),
    );
  }
}

/// 演员更多信息的底部面板内容。
class _ActorInfoContent extends StatelessWidget {
  const _ActorInfoContent({required this.detail});

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
    return ListView(
      children: [
        const ListTile(title: Text('更多信息')),
        ...rows.map(
          (row) => ListTile(title: Text(row.$1), subtitle: Text(row.$2)),
        ),
      ],
    );
  }
}
