import 'package:flutter/material.dart';
import 'package:jade/core/models/movie.dart';
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/widgets/movie_grid_view.dart';
import 'package:jade/core/widgets/pagination_controller.dart';
import 'package:jade/core/widgets/sort_segmented.dart';
import 'package:jade/core/widgets/sort_select.dart';
import 'package:jade/features/common/services/tag_movies_service.dart';

typedef _SortOption = ({String label, String value});

class CommonListPage extends StatefulWidget {
  const CommonListPage({
    super.key,
    required this.title,
    required this.type,
    required this.category,
    required this.id,
    this.dataSource,
  });

  final String title;
  final int type;
  final String category;
  final String id;
  final TagMoviesDataSource? dataSource;

  @override
  State<CommonListPage> createState() => _CommonListPageState();
}

class _CommonListPageState extends State<CommonListPage> {
  static const _filterOptions = [
    (label: '全部', value: 'all'),
    (label: '可播放', value: 'playable'),
    (label: '含磁链', value: 'magnet'),
    (label: '字幕', value: 'subtitle'),
  ];

  static const _commonSortOptions = [
    (label: '发布日期', value: 'release'),
    (label: '评分', value: 'score'),
    (label: '热度', value: 'hit'),
    (label: '想看人数', value: 'want_watch_count'),
    (label: '看过人数', value: 'watched_count'),
  ];

  static const _listSortOptions = [
    (label: '存入时间', value: 'update'),
    (label: '创建时间', value: 'release'),
    (label: '评分', value: 'score'),
  ];

  late final List<_SortOption> _sortOptions;
  late final TagMoviesDataSource _dataSource;
  late final PaginationController<MovieSummary> _ctrl;
  var _filter = 'magnet';
  late String _sort;
  var _orderBy = 'desc';

  @override
  void initState() {
    super.initState();
    _sortOptions = switch (widget.category) {
      'l' => _listSortOptions,
      'c' => [..._commonSortOptions, const (label: '番号', value: 'digit')],
      _ => _commonSortOptions,
    };
    _sort = widget.category == 'l' ? 'update' : 'hit';
    _dataSource =
        widget.dataSource ??
        switch (ApiClient.instanceOrNull) {
          final api? => TagMoviesService(api),
          null => const UnavailableTagMoviesDataSource(),
        };
    _ctrl = PaginationController<MovieSummary>(fetch: _fetchPage)..fetchMore();
  }

  String get _filterApi => switch (_filter) {
    'all' => '',
    'playable' => 'p',
    'magnet' => 'm',
    'subtitle' => 'c',
    _ => '',
  };

  bool get _canToggleOrder => _sort == 'release' && widget.category != 'l';

  Future<PagedResult<MovieSummary>> _fetchPage(int page) => _dataSource.getMovies(
    type: widget.type,
    category: widget.category,
    id: widget.id,
    filter: _filterApi,
    sortBy: _sort,
    orderBy: _orderBy,
    page: page,
  );

  void _changeFilter(String value) {
    if (value == _filter) return;
    setState(() => _filter = value);
    _ctrl.reloadWith(_fetchPage);
  }

  void _changeSort(String? value) {
    if (value == null || value == _sort) return;
    setState(() => _sort = value);
    _ctrl.reloadWith(_fetchPage);
  }

  void _toggleOrder() {
    setState(() => _orderBy = _orderBy == 'asc' ? 'desc' : 'asc');
    _ctrl.reloadWith(_fetchPage);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: SortSegmented<String>(
              key: const Key('common-list-filter'),
              compact: true,
              expanded: true,
              options: _filterOptions,
              value: _filter,
              onChanged: _changeFilter,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: SortSelect<String>(
                    key: const Key('common-list-sort'),
                    options: _sortOptions,
                    value: _sort,
                    onChanged: _changeSort,
                  ),
                ),
                IconButton(
                  key: const Key('common-list-order-toggle'),
                  tooltip: _orderBy == 'asc' ? '倒序' : '正序',
                  onPressed: _canToggleOrder ? _toggleOrder : null,
                  icon: Icon(
                    _orderBy == 'asc'
                        ? Icons.arrow_upward
                        : Icons.arrow_downward,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(child: MovieGridView(controller: _ctrl)),
        ],
      ),
    );
  }
}
