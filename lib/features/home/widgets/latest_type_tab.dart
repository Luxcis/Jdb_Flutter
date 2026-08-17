import 'dart:async';

import 'package:flutter/material.dart';
import 'package:jade/core/models/movie.dart';
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/widgets/movie_grid_view.dart';
import 'package:jade/core/widgets/pagination_controller.dart';
import 'package:jade/core/widgets/sort_segmented.dart';
import 'package:jade/core/widgets/sort_select.dart';
import 'package:jade/features/home/services/latest_movies_service.dart';

class LatestTypeTab extends StatefulWidget {
  const LatestTypeTab({
    super.key,
    required this.type,
    required this.defaultFilter,
    this.dataSource,
  });

  final String type;
  final String defaultFilter;
  final LatestMoviesDataSource? dataSource;

  @override
  State<LatestTypeTab> createState() => _LatestTypeTabState();
}

class _LatestTypeTabState extends State<LatestTypeTab>
    with AutomaticKeepAliveClientMixin {
  static const _filterOptions = [
    (label: '全部', value: 'all'),
    (label: '可播放', value: 'can_play'),
    (label: '含磁链', value: 'magnets'),
    (label: '含字幕', value: 'subtitle'),
  ];
  static const _sortOptions = [
    (label: '发布日期', value: 'release'),
    (label: '更新时间', value: 'update'),
  ];

  late final LatestMoviesDataSource _source;
  late final PaginationController<MovieSummary> _controller;
  late String _filter;
  var _sort = 'update';

  bool get _filterIsAll => _filter == 'all';

  @override
  void initState() {
    super.initState();
    final api = ApiClient.instanceOrNull;
    _source =
        widget.dataSource ??
        (api == null
            ? const UnavailableLatestMoviesDataSource()
            : LatestMoviesService(api));
    _filter = widget.defaultFilter;
    _controller = PaginationController<MovieSummary>(fetch: _fetchPage);
    unawaited(_controller.fetchMore());
  }

  Future<PagedResult<MovieSummary>> _fetchPage(int page) => _source.getMovies(
    type: widget.type,
    filterBy: _filter,
    sortBy: _filterIsAll ? 'release' : _sort,
    page: page,
  );

  void _changeFilter(String value) {
    if (value == _filter) return;
    setState(() => _filter = value);
    _controller.reloadWith(_fetchPage);
  }

  void _changeSort(String? value) {
    if (value == null || value == _sort) return;
    setState(() => _sort = value);
    _controller.reloadWith(_fetchPage);
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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
          child: SortSegmented<String>(
            key: const Key('latest-tab-filter'),
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
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              SortSelect<String>(
                key: const Key('latest-tab-sort'),
                compact: true,
                options: _sortOptions,
                value: _filterIsAll ? 'release' : _sort,
                onChanged: _filterIsAll ? null : _changeSort,
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Expanded(child: MovieGridView(controller: _controller)),
      ],
    );
  }
}
