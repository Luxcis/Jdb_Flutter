import 'package:flutter/material.dart';
import 'package:jade/core/models/movie.dart';
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/providers/auth_provider.dart';
import 'package:jade/core/widgets/error_retry_widget.dart';
import 'package:jade/core/widgets/login_guide_card.dart';
import 'package:jade/core/widgets/movie_grid_view.dart';
import 'package:jade/core/widgets/movie_list_tile.dart';
import 'package:jade/core/widgets/pagination_controller.dart';
import 'package:jade/core/widgets/sort_segmented.dart';
import 'package:jade/features/rankings/services/ranking_service.dart';
import 'package:provider/provider.dart';

class RankingsPage extends StatefulWidget {
  const RankingsPage({super.key});

  @override
  State<RankingsPage> createState() => _RankingsPageState();
}

class _RankingsPageState extends State<RankingsPage>
    with TickerProviderStateMixin {
  static const tabs = ['Top250', '看热播', '有码', '无码', '欧美', 'FC2'];

  late final TabController _tabController;

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
          tabs: tabs.map((tab) => Tab(text: tab)).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _Top250Tab(),
          _HotPlayTab(),
          _RankTab(type: '0'),
          _RankTab(type: '1'),
          _RankTab(type: '2'),
          _RankTab(type: '3'),
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

class _Top250TabState extends State<_Top250Tab>
    with AutomaticKeepAliveClientMixin {
  late final PaginationController<MovieSummary> _controller =
      PaginationController(fetch: _fetchPage);

  Future<PagedResult<MovieSummary>> _fetchPage(int _) async {
    final api = ApiClient.instanceOrNull;
    if (api == null) return _emptyMoviePage();
    return RankingService(api).getTop250();
  }

  @override
  void initState() {
    super.initState();
    _controller.fetchMore();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final auth = context.watch<AuthProvider>();
    if (!auth.isLogged) {
      return const LoginGuideCard(
        message: '登录后查看 Top250 排行榜',
        loginPath: '/rankings',
      );
    }
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        if (_controller.error != null && _controller.items.isEmpty) {
          return ErrorRetryWidget(
            message: _controller.error.toString(),
            onRetry: _controller.refresh,
          );
        }
        if (_controller.isLoading && _controller.items.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        return RefreshIndicator(
          onRefresh: _controller.refresh,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: _controller.items.length,
            itemBuilder: (_, index) =>
                MovieListTile(movie: _controller.items[index], rank: index + 1),
          ),
        );
      },
    );
  }
}

class _HotPlayTab extends StatefulWidget {
  const _HotPlayTab();

  @override
  State<_HotPlayTab> createState() => _HotPlayTabState();
}

class _HotPlayTabState extends State<_HotPlayTab>
    with AutomaticKeepAliveClientMixin {
  var _filterBy = 'high_score';
  var _period = 'daily';
  late final PaginationController<MovieSummary> _controller =
      PaginationController(fetch: _fetchPage);

  Future<PagedResult<MovieSummary>> _fetchPage(int _) async {
    final api = ApiClient.instanceOrNull;
    if (api == null) return _emptyMoviePage();
    return RankingService(
      api,
    ).getPlayback(filterBy: _filterBy, period: _period);
  }

  @override
  void initState() {
    super.initState();
    _controller.fetchMore();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  void _updateFilterBy(String value) {
    if (_filterBy == value) return;
    setState(() => _filterBy = value);
    _controller.reloadWith(_fetchPage);
  }

  void _updatePeriod(String value) {
    if (_period == value) return;
    setState(() => _period = value);
    _controller.reloadWith(_fetchPage);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            spacing: 8,
            children: [
              _FilterChipRow(
                label: '范围',
                options: const [
                  (label: '高分', value: 'high_score'),
                  (label: '全部', value: 'all'),
                ],
                value: _filterBy,
                onSelected: _updateFilterBy,
              ),
              _FilterChipRow(
                label: '周期',
                options: const [
                  (label: '日榜', value: 'daily'),
                  (label: '周榜', value: 'weekly'),
                  (label: '月榜', value: 'monthly'),
                ],
                value: _period,
                onSelected: _updatePeriod,
              ),
            ],
          ),
        ),
        Expanded(child: MovieGridView(controller: _controller)),
      ],
    );
  }
}

class _RankTab extends StatefulWidget {
  const _RankTab({required this.type});

  final String type;

  @override
  State<_RankTab> createState() => _RankTabState();
}

class _RankTabState extends State<_RankTab> with AutomaticKeepAliveClientMixin {
  static const periods = [
    (label: '日榜', value: 'daily'),
    (label: '周榜', value: 'weekly'),
    (label: '月榜', value: 'monthly'),
  ];

  var _period = 'daily';
  late final PaginationController<MovieSummary> _controller =
      PaginationController(fetch: _fetchPage);

  Future<PagedResult<MovieSummary>> _fetchPage(int page) async {
    final api = ApiClient.instanceOrNull;
    if (api == null) return _emptyMoviePage(page: page);
    return RankingService(
      api,
    ).getRanking(type: widget.type, period: _period, page: page);
  }

  @override
  void initState() {
    super.initState();
    _controller.fetchMore();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  void _updatePeriod(String value) {
    if (_period == value) return;
    setState(() => _period = value);
    _controller.reloadWith(_fetchPage);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: SortSegmented<String>(
            options: periods,
            value: _period,
            onChanged: _updatePeriod,
          ),
        ),
        Expanded(child: MovieGridView(controller: _controller)),
      ],
    );
  }
}

class _FilterChipRow extends StatelessWidget {
  const _FilterChipRow({
    required this.label,
    required this.options,
    required this.value,
    required this.onSelected,
  });

  final String label;
  final List<({String label, String value})> options;
  final String value;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 40,
            child: Text(label, style: Theme.of(context).textTheme.labelLarge),
          ),
          for (final option in options)
            ChoiceChip(
              label: Text(option.label),
              selected: value == option.value,
              onSelected: (_) => onSelected(option.value),
            ),
        ],
      ),
    );
  }
}

PagedResult<MovieSummary> _emptyMoviePage({int page = 1}) =>
    PagedResult(items: const [], currentPage: page, totalPages: page, total: 0);
