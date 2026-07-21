import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jade/core/models/actor.dart';
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/providers/auth_provider.dart';
import 'package:jade/core/widgets/actor_grid_view.dart';
import 'package:jade/core/widgets/cached_image.dart';
import 'package:jade/core/widgets/filter_drawer.dart';
import 'package:jade/core/widgets/login_guide_card.dart';
import 'package:jade/core/widgets/pagination_controller.dart';
import 'package:jade/core/widgets/section_header.dart';
import 'package:jade/features/actors/services/actor_service.dart';
import 'package:provider/provider.dart';

class ActorsPage extends StatefulWidget {
  const ActorsPage({super.key});
  @override
  State<ActorsPage> createState() => _ActorsPageState();
}

class _ActorsPageState extends State<ActorsPage> with TickerProviderStateMixin {
  late final TabController _tabController;
  static const tabs = ['推荐', '有码(女)', '有码(男)', '无码', '欧美(女)', '欧美(男)'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('演员'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: tabs.map((t) => Tab(text: t)).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          const _RecommendTab(),
          const _ActorListTab(type: 'censored_female', showFilter: true),
          const _ActorListTab(type: 'censored_male'),
          const _ActorListTab(type: 'uncensored'),
          const _ActorListTab(type: 'western_female'),
          const _ActorListTab(type: 'western_male'),
        ],
      ),
    );
  }
}

class _RecommendTab extends StatefulWidget {
  const _RecommendTab();
  @override
  State<_RecommendTab> createState() => _RecommendTabState();
}

class _RecommendTabState extends State<_RecommendTab> {
  List<ActorSummary> _newcomers = [];
  List<ActorSummary> _monthly = [];
  List<ActorSummary> _dmm = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() async {
    final api = ApiClient.instanceOrNull;
    if (api == null) return;
    final svc = ActorService(api);
    final all = await svc.getRecommends();
    setState(() {
      _newcomers = all.sublist(0, all.length > 9 ? 9 : all.length);
      _monthly = all;
      _dmm = all;
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (!auth.isLogged) {
      return const LoginGuideCard(message: '登录后可查看演员推荐', loginPath: '/actors');
    }
    return CustomScrollView(
      slivers: [
        SectionHeader(title: '新人', bold: true).sliver,
        _actorSliverGrid(_newcomers),
        SectionHeader(title: '月排名', trailing: '全部').sliver,
        _actorSliverGrid(_monthly),
        SectionHeader(title: 'Fanza(DMM)推荐', bold: true).sliver,
        _actorSliverGrid(_dmm),
      ],
    );
  }

  Widget _actorSliverGrid(List<ActorSummary> actors) {
    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.8,
      ),
      delegate: SliverChildBuilderDelegate(
        (_, i) => GestureDetector(
          onTap: () => context.push('/actor/${actors[i].id}'),
          child: Column(
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: ClipOval(child: CachedImage(actors[i].avatarUrl)),
              ),
              Text(actors[i].name),
            ],
          ),
        ),
        childCount: actors.length,
      ),
    );
  }
}

class _ActorListTab extends StatefulWidget {
  final String type;
  final bool showFilter;
  const _ActorListTab({required this.type, this.showFilter = false});
  @override
  State<_ActorListTab> createState() => _ActorListTabState();
}

class _ActorListTabState extends State<_ActorListTab> {
  late final _ctrl = PaginationController<ActorSummary>(
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
      return ActorService(api).getActors(type: widget.type, page: page);
    },
  );

  @override
  void initState() {
    super.initState();
    _ctrl.fetchMore();
  }

  @override
  Widget build(BuildContext context) {
    final grid = ActorGridView(
      controller: _ctrl,
      onActorTap: (actor) => context.push('/actor/${actor.id}'),
    );
    if (!widget.showFilter) return grid;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        actions: [
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.filter_list),
              tooltip: '筛选',
              onPressed: () => Scaffold.of(context).openEndDrawer(),
            ),
          ),
        ],
      ),
      endDrawer: const FilterDrawer(
        schema: FilterSchema(
          groups: [
            FilterGroup(
              label: '排序',
              items: [
                (label: '人气', value: 'popular'),
                (label: '最新', value: 'new'),
                (label: '影片数', value: 'movie_count'),
              ],
            ),
            FilterGroup(
              label: '地区',
              items: [
                (label: '全部', value: 'all'),
                (label: '日本', value: 'jp'),
                (label: '欧美', value: 'western'),
              ],
            ),
          ],
        ),
        onChanged: _noopActorFilter,
      ),
      body: grid,
    );
  }
}

void _noopActorFilter(Map<String, String> _) {}
