import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jade/core/models/actor.dart';
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/widgets/actor_card.dart';
import 'package:jade/core/widgets/actor_grid_view.dart';
import 'package:jade/core/widgets/empty_state.dart';
import 'package:jade/core/widgets/error_retry_widget.dart';
import 'package:jade/core/widgets/pagination_controller.dart';
import 'package:jade/core/widgets/section_header.dart';
import 'package:jade/core/widgets/search_entry.dart';
import 'package:jade/core/widgets/sort_segmented.dart';
import 'package:jade/features/actors/models/actor_filter.dart';
import 'package:jade/features/actors/models/actor_recommend.dart';
import 'package:jade/features/actors/services/actor_service.dart';
import 'package:jade/features/actors/widgets/actor_filter_sheet.dart';

class ActorsPage extends StatefulWidget {
  const ActorsPage({super.key, this.service});

  final ActorService? service;

  @override
  State<ActorsPage> createState() => _ActorsPageState();
}

class _ActorsPageState extends State<ActorsPage> with TickerProviderStateMixin {
  static const _tabs = ['推荐', '有码(女)', '有码(男)', '无码', '欧美(女)', '欧美(男)'];

  late final TabController _tabController;
  late final ActorService? _service;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    final api = ApiClient.instanceOrNull;
    _service = widget.service ?? (api == null ? null : ActorService(api));
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
        actions: const [SearchIconButton()],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: _tabs.map((label) => Tab(text: label)).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _RecommendTab(service: _service),
          _ActorListTab(
            service: _service,
            category: ActorListCategory.censoredFemale,
          ),
          _ActorListTab(
            service: _service,
            category: ActorListCategory.censoredMale,
          ),
          _ActorListTab(
            service: _service,
            category: ActorListCategory.uncensored,
          ),
          _ActorListTab(
            service: _service,
            category: ActorListCategory.westernFemale,
          ),
          _ActorListTab(
            service: _service,
            category: ActorListCategory.westernMale,
          ),
        ],
      ),
    );
  }
}

class _RecommendTab extends StatefulWidget {
  const _RecommendTab({required this.service});

  final ActorService? service;

  @override
  State<_RecommendTab> createState() => _RecommendTabState();
}

class _RecommendTabState extends State<_RecommendTab> {
  ActorRecommend? _data;
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    if (widget.service == null) {
      _loading = false;
      _error = StateError('演员服务尚未就绪');
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    final service = widget.service;
    if (service == null) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = StateError('演员服务尚未就绪');
      });
      return;
    }

    try {
      final data = await service.getRecommends();
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error;
      });
    }
  }

  void _retry() {
    setState(() {
      _loading = true;
      _error = null;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final error = _error;
    if (error != null) {
      return ErrorRetryWidget(message: error.toString(), onRetry: _retry);
    }
    final data = _data;
    if (data == null) {
      return ErrorRetryWidget(message: '演员推荐数据不可用', onRetry: _retry);
    }
    if (data.newActors.isEmpty &&
        data.monthlyActors.isEmpty &&
        data.recommendActors.isEmpty) {
      return const EmptyState(message: '暂无演员推荐');
    }

    return CustomScrollView(
      slivers: [
        const SectionHeader(title: '新人', bold: true).sliver,
        _actorSliverGrid(data.newActors),
        const SectionHeader(title: '月排名').sliver,
        _actorSliverGrid(data.monthlyActors),
        const SectionHeader(title: 'Fanza(DMM)推荐', bold: true).sliver,
        _actorSliverGrid(data.recommendActors),
      ],
    );
  }

  Widget _actorSliverGrid(List<ActorSummary> actors) {
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = (constraints.crossAxisExtent / 120)
            .floor()
            .clamp(3, 6);
        const horizontalPadding = 16.0;
        const crossAxisSpacing = 12.0;
        final tileWidth =
            (constraints.crossAxisExtent -
                horizontalPadding * 2 -
                crossAxisSpacing * (crossAxisCount - 1)) /
            crossAxisCount;
        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: horizontalPadding),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: 12,
              crossAxisSpacing: crossAxisSpacing,
              mainAxisExtent: ActorCard.mainAxisExtent(context, tileWidth),
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => ActorCard(
                actor: actors[index],
                onTap: () => context.push('/actor/${actors[index].id}'),
              ),
              childCount: actors.length,
            ),
          ),
        );
      },
    );
  }
}

class _ActorListTab extends StatefulWidget {
  const _ActorListTab({required this.service, required this.category});

  final ActorService? service;
  final ActorListCategory category;

  @override
  State<_ActorListTab> createState() => _ActorListTabState();
}

enum _ActorRange { all, monthly }

class _ActorListTabState extends State<_ActorListTab>
    with AutomaticKeepAliveClientMixin {
  static const _rangeOptions = [
    (label: '全部', value: _ActorRange.all),
    (label: '月榜', value: _ActorRange.monthly),
  ];

  late final PaginationController<ActorSummary> _controller;
  ActorFilter _filter = const ActorFilter();
  _ActorRange _range = _ActorRange.all;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _controller = PaginationController<ActorSummary>(fetch: _fetchPage);
    _controller.fetchMore();
  }

  Future<PagedResult<ActorSummary>> _fetchPage(int page) {
    final service = widget.service;
    if (service == null) {
      return Future.error(StateError('演员服务尚未就绪'));
    }
    if (_range == _ActorRange.monthly) {
      return service.getRankingActors(type: int.parse(widget.category.type));
    }
    return service.getActors(
      category: widget.category,
      page: page,
      filter: _filter,
    );
  }

  Future<void> _openFilter() async {
    final next = await showModalBottomSheet<ActorFilter>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => ActorFilterSheet(initialValue: _filter),
    );
    if (!mounted || next == null || next == _filter) return;
    setState(() => _filter = next);
    await _controller.reloadWith(_fetchPage, preserveItems: true);
  }

  void _changeRange(_ActorRange value) {
    if (value == _range) return;
    setState(() => _range = value);
    _controller.reloadWith(_fetchPage);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final grid = ActorGridView(
      controller: _controller,
      onActorTap: (actor) => context.push('/actor/${actor.id}'),
    );
    if (!widget.category.supportsRanking && !widget.category.supportsFilter) {
      return grid;
    }

    final rangeSelector = SortSegmented<_ActorRange>(
      key: const Key('actor-range-filter'),
      compact: true,
      expanded: true,
      options: _rangeOptions,
      value: _range,
      onChanged: _changeRange,
    );

    final Widget header;
    if (widget.category.supportsRanking && widget.category.supportsFilter) {
      // 有码女：筛选按钮与切换器同一行，筛选仅在「全部」时可用。
      header = Row(
        children: [
          Expanded(child: rangeSelector),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _range == _ActorRange.all ? _openFilter : null,
            icon: const Icon(Icons.filter_list),
            tooltip: '筛选演员',
          ),
        ],
      );
    } else {
      header = rangeSelector;
    }

    return Column(
      children: [
        Padding(padding: const EdgeInsets.fromLTRB(8, 8, 8, 0), child: header),
        const SizedBox(height: 4),
        Expanded(child: grid),
      ],
    );
  }
}
