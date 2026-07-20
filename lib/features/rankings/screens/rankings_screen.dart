import 'package:flutter/material.dart';
import 'package:jade/core/widgets/movie_grid_view.dart';
import 'package:jade/core/widgets/movie_list_tile.dart';
import 'package:jade/core/widgets/sort_segmented.dart';
import 'package:jade/core/widgets/pagination_controller.dart';
import 'package:jade/core/models/movie.dart';
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/providers/auth_provider.dart';
import 'package:jade/core/widgets/login_guide_card.dart';
import 'package:jade/features/rankings/services/ranking_service.dart';
import 'package:provider/provider.dart';

class RankingsPage extends StatefulWidget {
  const RankingsPage({super.key});
  @override
  State<RankingsPage> createState() => _RankingsPageState();
}

class _RankingsPageState extends State<RankingsPage> with TickerProviderStateMixin {
  late final TabController _tabController;
  static const tabs = ['Top250', '看热播', '有码', '无码', '欧美', 'FC2'];

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
        title: const Text('排行榜'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: tabs.map((t) => Tab(text: t)).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _Top250Tab(),
          _HotPlayTab(),
          _RankTab(type: 1, showActor: true),
          _RankTab(type: 2, showActor: true),
          _RankTab(type: 3, showActor: true),
          _RankTab(type: 5, showActor: false),
        ],
      ),
    );
  }
}

class _Top250Tab extends StatefulWidget {
  const _Top250Tab();
  @override
  State<_Top250Tab> createState() => _Top250TabState();
}

class _Top250TabState extends State<_Top250Tab> {
  late final _ctrl = PaginationController<MovieSummary>(
    fetch: (page) async {
      final api = ApiClient.instanceOrNull;
      if (api == null) return PagedResult(items: [], currentPage: 1, totalPages: 1, total: 0);
      return RankingService(api).getTop250(page: page);
    },
  );

  @override
  void initState() {
    super.initState();
    _ctrl.fetchMore();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (!auth.isLogged) {
      return const LoginGuideCard(
        message: '登录后查看 Top250 排行榜',
        loginPath: '/rankings',
      );
    }
    return ListenableBuilder(
      listenable: _ctrl,
      builder: (_, _) => RefreshIndicator(
        onRefresh: _ctrl.refresh,
        child: ListView.builder(
          itemCount: _ctrl.items.length,
          itemBuilder: (_, i) => MovieListTile(
            movie: _ctrl.items[i],
            rank: i + 1,
          ),
        ),
      ),
    );
  }
}

class _HotPlayTab extends StatefulWidget {
  const _HotPlayTab();
  @override
  State<_HotPlayTab> createState() => _HotPlayTabState();
}

class _HotPlayTabState extends State<_HotPlayTab> {
  var _filter = 'high_rating';
  var _period = 'daily';
  late PaginationController<MovieSummary> _ctrl = _buildCtrl();

  PaginationController<MovieSummary> _buildCtrl() {
    return PaginationController<MovieSummary>(
      fetch: (page) async {
        final api = ApiClient.instanceOrNull;
        if (api == null) return PagedResult(items: [], currentPage: 1, totalPages: 1, total: 0);
        return RankingService(api).getPlayback(period: _period, page: page);
      },
    );
  }

  void _update() {
    setState(() {
      _ctrl = _buildCtrl();
    });
    _ctrl.fetchMore();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(8),
        child: Row(children: [
          SortSegmented<String>(
            options: const [
              (label: '高评价', value: 'high_rating'),
              (label: '全部', value: 'all'),
            ],
            value: _filter,
            onChanged: (v) {
              _filter = v;
              _update();
            },
          ),
          const SizedBox(width: 8),
          SortSegmented<String>(
            options: const [
              (label: '日榜', value: 'daily'),
              (label: '周榜', value: 'weekly'),
              (label: '月榜', value: 'monthly'),
            ],
            value: _period,
            onChanged: (v) {
              _period = v;
              _update();
            },
          ),
        ]),
      ),
      Expanded(child: MovieGridView(controller: _ctrl)),
    ]);
  }
}

class _RankTab extends StatefulWidget {
  final int type;
  final bool showActor;
  const _RankTab({required this.type, required this.showActor});
  @override
  State<_RankTab> createState() => _RankTabState();
}

class _RankTabState extends State<_RankTab> {
  var _period = 'daily';
  late PaginationController<MovieSummary> _ctrl = _buildCtrl();

  PaginationController<MovieSummary> _buildCtrl() {
    return PaginationController<MovieSummary>(
      fetch: (page) async {
        final api = ApiClient.instanceOrNull;
        if (api == null) return PagedResult(items: [], currentPage: 1, totalPages: 1, total: 0);
        return RankingService(api).getRanking(type: widget.type, period: _period, page: page);
      },
    );
  }

  void _update() {
    setState(() {
      _ctrl = _buildCtrl();
    });
    _ctrl.fetchMore();
  }

  @override
  Widget build(BuildContext context) {
    final periods = widget.showActor
        ? ['日榜', '周榜', '月榜', '演员月榜']
        : ['日榜', '周榜', '月榜'];
    final values = widget.showActor
        ? ['daily', 'weekly', 'monthly', 'actor_monthly']
        : ['daily', 'weekly', 'monthly'];
    final opts = List.generate(
      periods.length,
      (i) => (label: periods[i], value: values[i]),
    );
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(8),
        child: SortSegmented<String>(
          options: opts,
          value: _period,
          onChanged: (v) {
            _period = v;
            _update();
          },
        ),
      ),
      Expanded(child: MovieGridView(controller: _ctrl)),
    ]);
  }
}
