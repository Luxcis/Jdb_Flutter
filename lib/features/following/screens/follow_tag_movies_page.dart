import 'package:flutter/material.dart';
import 'package:jade/core/models/movie.dart';
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/api_data.dart';
import 'package:jade/core/network/endpoints.dart';
import 'package:jade/core/widgets/movie_grid_view.dart';
import 'package:jade/core/widgets/pagination_controller.dart';
import 'package:jade/core/widgets/sort_segmented.dart';

class FollowTagMoviesPage extends StatefulWidget {
  const FollowTagMoviesPage({super.key, required this.value});

  final String value;

  @override
  State<FollowTagMoviesPage> createState() => _FollowTagMoviesPageState();
}

class _FollowTagMoviesPageState extends State<FollowTagMoviesPage> {
  static const _sortOptions = [
    (label: '更新日期', value: 'update'),
    (label: '发布日期', value: 'release'),
  ];

  late final PaginationController<MovieSummary> _ctrl;
  late String _sort;
  late String _orderBy;

  @override
  void initState() {
    super.initState();
    _sort = 'update';
    _orderBy = 'desc';
    _ctrl = PaginationController<MovieSummary>(fetch: _fetchPage)..fetchMore();
  }

  Future<PagedResult<MovieSummary>> _fetchPage(int page) async {
    final api = ApiClient.instanceOrNull;
    if (api == null) {
      return PagedResult(
        items: const [],
        currentPage: page,
        totalPages: page,
        total: 0,
      );
    }
    final query = <String, dynamic>{
      'filter_by': widget.value,
      'sort_by': _sort,
      if (_sort == 'release') 'order_by': _orderBy,
      'page': page,
      'limit': 48,
    };
    final response = await api.get(Endpoints.moviesTags, queryParameters: query);
    return apiPageResult(
      response.data,
      keys: const ['movies'],
      page: page,
      pageSize: 48,
      fromJson: (json) => MovieSummary.fromJson(normalizeMovieSummaryJson(json)),
    );
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
      appBar: AppBar(title: const Text('标签影片')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SortSegmented<String>(
                  key: const Key('follow-tag-sort'),
                  compact: true,
                  options: _sortOptions,
                  value: _sort,
                  onChanged: _changeSort,
                ),
                IconButton(
                  key: const Key('follow-tag-order-toggle'),
                  tooltip: _orderBy == 'asc' ? '倒序' : '正序',
                  onPressed: _sort == 'release' ? _toggleOrder : null,
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
