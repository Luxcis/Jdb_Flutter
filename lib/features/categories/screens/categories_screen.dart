import 'package:flutter/material.dart';
import 'package:jade/core/models/movie.dart';
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/core/widgets/movie_grid_view.dart';
import 'package:jade/core/widgets/sort_select.dart';
import 'package:jade/core/widgets/filter_drawer.dart';
import 'package:jade/core/widgets/pagination_controller.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/features/categories/services/category_service.dart';

class CategoriesPage extends StatefulWidget {
  const CategoriesPage({super.key});
  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage>
    with TickerProviderStateMixin {
  late final TabController _tabController;
  final tabs = ['有码', '无码', '欧美', 'FC2', '动漫'];
  final types = [1, 2, 3, 5, 6];
  var _sortBy = 'date';
  int _currentTab = 0;

  static const _sortOptionsByTab = [
    [('最新', 'date'), ('热门', 'hot'), ('评分', 'rating')],
    [('最新', 'date'), ('收藏', 'collect'), ('评分', 'rating')],
    [('最新', 'date'), ('热门', 'hot'), ('时长', 'duration')],
    [('最新', 'date'), ('热门', 'hot'), ('番号', 'number')],
    [('最新', 'date'), ('热门', 'hot'), ('评分', 'rating')],
  ];

  static const _filterSchemas = [
    FilterSchema(
      groups: [
        FilterGroup(
          label: '状态',
          items: [
            (label: '全部', value: 'all'),
            (label: '可播放', value: 'playable'),
            (label: '含磁链', value: 'magnet'),
            (label: '字幕', value: 'subtitle'),
          ],
        ),
        FilterGroup(
          label: '年份',
          items: [
            (label: '全部', value: 'all'),
            (label: '今年', value: 'this_year'),
            (label: '去年', value: 'last_year'),
          ],
        ),
      ],
    ),
    FilterSchema(
      groups: [
        FilterGroup(
          label: '状态',
          items: [
            (label: '全部', value: 'all'),
            (label: '含磁链', value: 'magnet'),
            (label: '字幕', value: 'subtitle'),
          ],
        ),
        FilterGroup(
          label: '片源',
          items: [
            (label: '全部', value: 'all'),
            (label: '无码破解', value: 'uncensored'),
            (label: '流出', value: 'leaked'),
          ],
        ),
      ],
    ),
    FilterSchema(
      groups: [
        FilterGroup(
          label: '地区',
          items: [
            (label: '全部', value: 'all'),
            (label: '欧美', value: 'western'),
            (label: '国产', value: 'domestic'),
          ],
        ),
        FilterGroup(
          label: '状态',
          items: [(label: '全部', value: 'all'), (label: '含磁链', value: 'magnet')],
        ),
      ],
    ),
    FilterSchema(
      groups: [
        FilterGroup(
          label: '状态',
          items: [(label: '全部', value: 'all'), (label: '含磁链', value: 'magnet')],
        ),
        FilterGroup(
          label: '编号',
          items: [
            (label: '全部', value: 'all'),
            (label: 'FC2', value: 'fc2'),
            (label: 'PPV', value: 'ppv'),
          ],
        ),
      ],
    ),
    FilterSchema(
      groups: [
        FilterGroup(
          label: '状态',
          items: [
            (label: '全部', value: 'all'),
            (label: '字幕', value: 'subtitle'),
          ],
        ),
        FilterGroup(
          label: '类型',
          items: [
            (label: '全部', value: 'all'),
            (label: '动画', value: 'anime'),
            (label: '同人', value: 'doujin'),
          ],
        ),
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: tabs.length, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      setState(() {
        _currentTab = _tabController.index;
        _sortBy = _sortOptionsByTab[_currentTab].first.$2;
      });
    });
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
        title: const Text('类别'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: tabs.map((t) => Tab(text: t)).toList(),
        ),
      ),
      body: Column(
        children: [
          Row(
            children: [
              SortSelect<(String, String)>(
                options: _sortOptionsByTab[_currentTab]
                    .map((o) => (label: o.$1, value: o))
                    .toList(),
                value: _sortOptionsByTab[_currentTab].firstWhere(
                  (o) => o.$2 == _sortBy,
                ),
                onChanged: (v) {
                  if (v != null) {
                    setState(() => _sortBy = v.$2);
                  }
                },
              ),
              const Spacer(),
              Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.filter_list),
                  tooltip: '筛选',
                  onPressed: () => Scaffold.of(context).openEndDrawer(),
                ),
              ),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: types
                  .map(
                    (t) => _CategoryMovieGrid(
                      key: ValueKey('$t-$_sortBy'),
                      type: t,
                      sortBy: _sortBy,
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
      endDrawer: FilterDrawer(
        schema: _filterSchemas[_currentTab],
        onChanged: (_) {},
      ),
    );
  }
}

class _CategoryMovieGrid extends StatefulWidget {
  const _CategoryMovieGrid({
    super.key,
    required this.type,
    required this.sortBy,
  });

  final int type;
  final String sortBy;

  @override
  State<_CategoryMovieGrid> createState() => _CategoryMovieGridState();
}

class _CategoryMovieGridState extends State<_CategoryMovieGrid> {
  late final PaginationController<MovieSummary> _controller =
      PaginationController(
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
          return CategoryService(
            api,
          ).getMovies(type: widget.type, sortBy: widget.sortBy, page: page);
        },
      );

  @override
  void initState() {
    super.initState();
    _controller.fetchMore();
  }

  @override
  Widget build(BuildContext context) {
    return MovieGridView(controller: _controller);
  }
}
