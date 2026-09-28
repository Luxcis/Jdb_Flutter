import 'package:flutter/material.dart';
import 'package:jade/core/models/movie.dart';
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/core/widgets/movie_grid_view.dart';
import 'package:jade/core/widgets/pagination_controller.dart';
import 'package:jade/core/widgets/sort_segmented.dart';
import 'package:jade/core/providers/following_tags_provider.dart';
import 'package:jade/features/following/services/follow_tag_movies_service.dart';
import 'package:provider/provider.dart';

class FollowTagMoviesScreen extends StatefulWidget {
  const FollowTagMoviesScreen({super.key, required this.value});

  final String value;

  @override
  State<FollowTagMoviesScreen> createState() => _FollowTagMoviesScreenState();
}

class _FollowTagMoviesScreenState extends State<FollowTagMoviesScreen> {
  static const _sortOptions = [
    (label: '更新日期', value: 'update'),
    (label: '发布日期', value: 'release'),
  ];

  late final PaginationController<MovieSummary> _ctrl;
  late final FollowTagMoviesService? _service;
  late String _sort;
  late String _orderBy;

  @override
  void initState() {
    super.initState();
    // 装配点判空一次：未登录/无连接时 service 为 null，分页返回空结果。
    _service = FollowTagMoviesService.resolve();
    _sort = 'update';
    _orderBy = 'desc';
    _ctrl = PaginationController<MovieSummary>(fetch: _fetchPage)..fetchMore();
  }

  Future<PagedResult<MovieSummary>> _fetchPage(int page) async {
    final service = _service;
    if (service == null) {
      return PagedResult(
        items: const [],
        currentPage: page,
        totalPages: page,
        total: 0,
      );
    }
    return service.getMovies(
      filterBy: widget.value,
      sortBy: _sort,
      orderBy: _orderBy,
      page: page,
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

  /// 导航栏标题：优先使用关注标签名称，缺失时回退到占位文案。
  String get _title {
    final provider = context.watch<FollowingTagsProvider>();
    for (final tag in provider.tags) {
      if (tag.value == widget.value) {
        return tag.name.isEmpty ? '标签影片' : tag.name;
      }
    }
    return '标签影片';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_title)),
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
