import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jade/core/models/movie.dart';
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/providers/auth_provider.dart';
import 'package:jade/core/widgets/error_retry_widget.dart';
import 'package:jade/core/widgets/login_guide_card.dart';
import 'package:jade/core/widgets/movie_grid_view.dart';
import 'package:jade/core/widgets/movie_list_tile.dart';
import 'package:jade/core/widgets/pagination_controller.dart';
import 'package:jade/core/widgets/search_entry.dart';
import 'package:jade/core/widgets/sort_segmented.dart';
import 'package:jade/features/rankings/services/ranking_service.dart';
import 'package:provider/provider.dart';

class RankingsPage extends StatefulWidget {
  const RankingsPage({super.key, this.initialTabIndex = 2})
    : assert(initialTabIndex >= 0 && initialTabIndex < 6);

  final int initialTabIndex;

  @override
  State<RankingsPage> createState() => _RankingsPageState();
}

class _RankingsPageState extends State<RankingsPage>
    with TickerProviderStateMixin {
  static const tabs = ['Top250', '看热播', '有码', '无码', '欧美', 'FC2'];

  late final TabController _tabController;
  var _top250Filter = const Top250Filter();
  late int _selectedTabIndex;

  @override
  void initState() {
    super.initState();
    _selectedTabIndex = widget.initialTabIndex;
    _tabController = TabController(
      length: tabs.length,
      initialIndex: widget.initialTabIndex,
      vsync: this,
    );
    _tabController.addListener(_handleTabChanged);
  }

  @override
  void didUpdateWidget(covariant RankingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTabIndex == widget.initialTabIndex ||
        _tabController.index == widget.initialTabIndex) {
      return;
    }
    _tabController.index = widget.initialTabIndex;
  }

  void _handleTabChanged() {
    final index = _tabController.index;
    if (!mounted || _selectedTabIndex == index) return;
    setState(() => _selectedTabIndex = index);
  }

  void _showTop250Filter() {
    final sheetHeight = MediaQuery.sizeOf(context).height * 2 / 3;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      constraints: BoxConstraints.tightFor(height: sheetHeight),
      builder: (_) => _Top250FilterSheet(
        value: _top250Filter,
        onChanged: (value) => setState(() => _top250Filter = value),
      ),
    );
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('排行榜'),
        actions: [
          if (_selectedTabIndex == 0)
            IconButton(
              tooltip: '筛选 Top250',
              onPressed: _showTop250Filter,
              icon: const Icon(Icons.filter_alt_outlined),
            ),
          const SearchIconButton(),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: tabs.map((tab) => Tab(text: tab)).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _Top250Tab(filter: _top250Filter),
          const _HotPlayTab(),
          const _RankTab(type: '0'),
          const _RankTab(type: '1'),
          const _RankTab(type: '2'),
          const _RankTab(type: '3'),
        ],
      ),
    );
  }
}

@immutable
class Top250Filter {
  const Top250Filter({
    this.type = 'all',
    this.typeValue = '',
    this.startRank = 1,
    this.ignoreWatched = false,
  });

  final String type;
  final String typeValue;
  final int startRank;
  final bool ignoreWatched;

  Top250Filter copyWith({
    String? type,
    String? typeValue,
    int? startRank,
    bool? ignoreWatched,
  }) {
    return Top250Filter(
      type: type ?? this.type,
      typeValue: typeValue ?? this.typeValue,
      startRank: startRank ?? this.startRank,
      ignoreWatched: ignoreWatched ?? this.ignoreWatched,
    );
  }
}

class _Top250Tab extends StatefulWidget {
  const _Top250Tab({required this.filter});

  final Top250Filter filter;

  @override
  State<_Top250Tab> createState() => _Top250TabState();
}

class _Top250TabState extends State<_Top250Tab>
    with AutomaticKeepAliveClientMixin {
  static const _pageSize = 50;
  static const _maxRank = 250;

  var _wasLoggedIn = false;
  late final PaginationController<MovieSummary> _controller =
      PaginationController(fetch: _fetchPage);

  int get _logicalTotalPages =>
      ((_maxRank - widget.filter.startRank + 1) / _pageSize).ceil();

  Future<PagedResult<MovieSummary>> _fetchPage(int page) async {
    final api = ApiClient.instanceOrNull;
    if (api == null) return _emptyMoviePage(page: page);
    final result = await RankingService(api).getTop250(
      startRank: widget.filter.startRank + (page - 1) * _pageSize,
      type: widget.filter.type,
      typeValue: widget.filter.typeValue,
      ignoreWatched: widget.filter.ignoreWatched,
      limit: _pageSize,
    );
    final isLastPage =
        result.items.length < _pageSize || page >= _logicalTotalPages;
    return PagedResult(
      items: result.items,
      currentPage: page,
      totalPages: isLastPage ? page : _logicalTotalPages,
      total: _maxRank - widget.filter.startRank + 1,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isLoggedIn = context.watch<AuthProvider>().isLogged;
    if (isLoggedIn && !_wasLoggedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !context.read<AuthProvider>().isLogged) return;
        _controller.reloadWith(_fetchPage);
      });
    }
    _wasLoggedIn = isLoggedIn;
  }

  @override
  void didUpdateWidget(covariant _Top250Tab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filter.type != widget.filter.type ||
        oldWidget.filter.typeValue != widget.filter.typeValue ||
        oldWidget.filter.startRank != widget.filter.startRank ||
        oldWidget.filter.ignoreWatched != widget.filter.ignoreWatched) {
      _controller.reloadWith(_fetchPage);
    }
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
        final showFooter =
            _controller.isLoading ||
            (_controller.error != null && _controller.items.isNotEmpty);
        return RefreshIndicator(
          onRefresh: () => _controller.refresh(preserveItems: true),
          child: Stack(
            children: [
              NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification is ScrollEndNotification &&
                      notification.metrics.extentAfter < 200 &&
                      _controller.error == null) {
                    _controller.fetchMore();
                  }
                  return false;
                },
                child: ListView.builder(
                  key: const Key('top250-list'),
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: _controller.items.length + (showFooter ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _controller.items.length) {
                      if (_controller.isLoading) {
                        return const Padding(
                          key: Key('top250-loading-more'),
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      return _Top250LoadMoreError(
                        onRetry: _controller.fetchMore,
                      );
                    }
                    final movie = _controller.items[index];
                    return MovieListTile(
                      movie: movie,
                      rank: widget.filter.startRank + index,
                      onTap: () => context.push('/movie/${movie.id}'),
                    );
                  },
                ),
              ),
              if (_controller.isRefreshing)
                const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(key: Key('top250-refreshing')),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _Top250LoadMoreError extends StatelessWidget {
  const _Top250LoadMoreError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton.icon(
        key: const Key('top250-load-more-retry'),
        onPressed: onRetry,
        icon: const Icon(Icons.refresh),
        label: const Text('加载失败，点击重试'),
      ),
    );
  }
}

class _Top250FilterSheet extends StatefulWidget {
  const _Top250FilterSheet({required this.value, required this.onChanged});

  final Top250Filter value;
  final ValueChanged<Top250Filter> onChanged;

  @override
  State<_Top250FilterSheet> createState() => _Top250FilterSheetState();
}

class _Top250FilterSheetState extends State<_Top250FilterSheet> {
  static const _videoTypes = [
    (label: '有码', value: '0'),
    (label: '无码', value: '1'),
    (label: '欧美', value: '2'),
    (label: 'FC2', value: '3'),
  ];
  static const _startRanks = [1, 51, 101, 151, 201];

  late Top250Filter _value = widget.value;

  void _emit(Top250Filter value) {
    setState(() => _value = value);
    widget.onChanged(value);
  }

  @override
  Widget build(BuildContext context) {
    final years = [
      for (var year = DateTime.now().year; year >= 2008; year--) year,
    ];
    return ListView(
      key: const Key('top250-filter-list'),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        Text('筛选', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _CompactChoiceChip(
              label: '全部',
              selected: _value.type == 'all',
              onSelected: () =>
                  _emit(_value.copyWith(type: 'all', typeValue: '')),
            ),
            for (final type in _videoTypes)
              _CompactChoiceChip(
                label: type.label,
                selected:
                    _value.type == 'video_type' &&
                    _value.typeValue == type.value,
                onSelected: () => _emit(
                  _value.copyWith(type: 'video_type', typeValue: type.value),
                ),
              ),
            for (final year in years)
              _CompactChoiceChip(
                label: '$year',
                selected: _value.type == 'year' && _value.typeValue == '$year',
                onSelected: () =>
                    _emit(_value.copyWith(type: 'year', typeValue: '$year')),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text('起始排名', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final startRank in _startRanks)
              _CompactChoiceChip(
                label: '$startRank',
                selected: _value.startRank == startRank,
                onSelected: () => _emit(_value.copyWith(startRank: startRank)),
              ),
          ],
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('未标「看过」'),
          subtitle: const Text('仅查看还未被标记「看过」的影片'),
          value: _value.ignoreWatched,
          onChanged: (value) => _emit(_value.copyWith(ignoreWatched: value)),
        ),
      ],
    );
  }
}

class _CompactChoiceChip extends StatelessWidget {
  const _CompactChoiceChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      labelPadding: const EdgeInsets.symmetric(horizontal: 6),
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
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            key: const Key('hot-play-filter-row'),
            children: [
              Expanded(
                flex: 2,
                child: SortSegmented<String>(
                  key: const Key('hot-play-range-filter'),
                  compact: true,
                  expanded: true,
                  options: const [
                    (label: '高分', value: 'high_score'),
                    (label: '全部', value: 'all'),
                  ],
                  value: _filterBy,
                  onChanged: _updateFilterBy,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: SortSegmented<String>(
                  key: const Key('hot-play-period-filter'),
                  compact: true,
                  expanded: true,
                  options: const [
                    (label: '日榜', value: 'daily'),
                    (label: '周榜', value: 'weekly'),
                    (label: '月榜', value: 'monthly'),
                  ],
                  value: _period,
                  onChanged: _updatePeriod,
                ),
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
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: SortSegmented<String>(
            key: const Key('rank-period-filter'),
            compact: true,
            expanded: true,
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

PagedResult<MovieSummary> _emptyMoviePage({int page = 1}) =>
    PagedResult(items: const [], currentPage: page, totalPages: page, total: 0);
