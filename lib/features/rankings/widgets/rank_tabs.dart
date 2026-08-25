import 'package:flutter/material.dart';
import 'package:jade/core/models/movie.dart';
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/widgets/movie_grid_view.dart';
import 'package:jade/core/widgets/pagination_controller.dart';
import 'package:jade/core/widgets/sort_segmented.dart';
import 'package:jade/features/rankings/services/ranking_service.dart';

/// 空翻页结果（用于 ApiClient 未初始化时的兜底）。
PagedResult<MovieSummary> emptyMoviePage({int page = 1}) =>
    PagedResult(items: const [], currentPage: page, totalPages: page, total: 0);

/// 看热播榜 Tab：高评价/全部 + 日/周/月榜。
class HotPlayTab extends StatefulWidget {
  const HotPlayTab({super.key});

  @override
  State<HotPlayTab> createState() => _HotPlayTabState();
}

class _HotPlayTabState extends State<HotPlayTab>
    with AutomaticKeepAliveClientMixin {
  var _filterBy = 'high_score';
  var _period = 'daily';
  late final PaginationController<MovieSummary> _controller =
      PaginationController(fetch: _fetchPage);

  Future<PagedResult<MovieSummary>> _fetchPage(int _) async {
    final api = ApiClient.instanceOrNull;
    if (api == null) return emptyMoviePage();
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

/// 有码/无码/欧美/FC2 排行榜 Tab：日/周/月榜。
class RankTab extends StatefulWidget {
  const RankTab({super.key, required this.type});

  final String type;

  @override
  State<RankTab> createState() => _RankTabState();
}

class _RankTabState extends State<RankTab> with AutomaticKeepAliveClientMixin {
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
    if (api == null) return emptyMoviePage(page: page);
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
