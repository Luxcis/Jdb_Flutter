import 'package:flutter/material.dart';
import 'package:jade/core/widgets/actor_grid_view.dart';
import 'package:jade/core/widgets/movie_grid_view.dart';
import 'package:jade/core/widgets/movie_list_tile.dart';
import 'package:jade/core/widgets/sort_segmented.dart';
import 'package:jade/core/widgets/pagination_controller.dart';
import 'package:jade/core/models/actor.dart';
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

class _RankingsPageState extends State<RankingsPage>
    with TickerProviderStateMixin {
  late final TabController _tabController;
  static const tabs = ['Top250', '看热播', '日榜', '周榜', '月榜', '演员榜'];

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
          _RankTab(type: 'day'),
          _RankTab(type: 'week'),
          _RankTab(type: 'month'),
          _ActorRankTab(),
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
      if (api == null) {
        return PagedResult(items: [], currentPage: 1, totalPages: 1, total: 0);
      }
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
          itemBuilder: (_, i) =>
              MovieListTile(movie: _ctrl.items[i], rank: i + 1),
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
  var _filterBy = 'day';
  var _period = 'all';
  late PaginationController<MovieSummary> _ctrl = _buildCtrl();

  PaginationController<MovieSummary> _buildCtrl() {
    return PaginationController<MovieSummary>(
      fetch: (page) async {
        final api = ApiClient.instanceOrNull;
        if (api == null) {
          return PagedResult(
            items: [],
            currentPage: 1,
            totalPages: 1,
            total: 0,
          );
        }
        return RankingService(
          api,
        ).getPlayback(filterBy: _filterBy, period: _period, page: page);
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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Expanded(
                child: SortSegmented<String>(
                  options: const [
                    (label: '日榜', value: 'day'),
                    (label: '周榜', value: 'week'),
                    (label: '月榜', value: 'month'),
                  ],
                  value: _filterBy,
                  onChanged: (v) {
                    _filterBy = v;
                    _update();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SortSegmented<String>(
                  options: const [
                    (label: '全部', value: 'all'),
                    (label: '本月', value: 'month'),
                  ],
                  value: _period,
                  onChanged: (v) {
                    _period = v;
                    _update();
                  },
                ),
              ),
            ],
          ),
        ),
        Expanded(child: MovieGridView(controller: _ctrl)),
      ],
    );
  }
}

class _RankTab extends StatefulWidget {
  final String type;
  const _RankTab({required this.type});
  @override
  State<_RankTab> createState() => _RankTabState();
}

class _RankTabState extends State<_RankTab> {
  var _period = 'all';
  late PaginationController<MovieSummary> _ctrl = _buildCtrl();

  PaginationController<MovieSummary> _buildCtrl() {
    return PaginationController<MovieSummary>(
      fetch: (page) async {
        final api = ApiClient.instanceOrNull;
        if (api == null) {
          return PagedResult(
            items: [],
            currentPage: 1,
            totalPages: 1,
            total: 0,
          );
        }
        return RankingService(
          api,
        ).getRanking(type: widget.type, period: _period, page: page);
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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: SortSegmented<String>(
            options: const [
              (label: '全部', value: 'all'),
              (label: '月', value: 'month'),
              (label: '周', value: 'week'),
              (label: '日', value: 'day'),
            ],
            value: _period,
            onChanged: (v) {
              _period = v;
              _update();
            },
          ),
        ),
        Expanded(child: MovieGridView(controller: _ctrl)),
      ],
    );
  }
}

class _ActorRankTab extends StatefulWidget {
  const _ActorRankTab();

  @override
  State<_ActorRankTab> createState() => _ActorRankTabState();
}

class _ActorRankTabState extends State<_ActorRankTab> {
  var _type = 'month';
  var _period = 'month';
  late PaginationController<ActorSummary> _ctrl = _buildCtrl();

  PaginationController<ActorSummary> _buildCtrl() {
    return PaginationController<ActorSummary>(
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
        return RankingService(
          api,
        ).getActorRanking(type: _type, period: _period, page: page);
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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Expanded(
                child: SortSegmented<String>(
                  options: const [
                    (label: '月榜', value: 'month'),
                    (label: '周榜', value: 'week'),
                    (label: '日榜', value: 'day'),
                  ],
                  value: _type,
                  onChanged: (v) {
                    _type = v;
                    _update();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SortSegmented<String>(
                  options: const [
                    (label: '本月', value: 'month'),
                    (label: '全部', value: 'all'),
                    (label: '本周', value: 'week'),
                    (label: '今日', value: 'day'),
                  ],
                  value: _period,
                  onChanged: (v) {
                    _period = v;
                    _update();
                  },
                ),
              ),
            ],
          ),
        ),
        Expanded(child: ActorGridView(controller: _ctrl)),
      ],
    );
  }
}
